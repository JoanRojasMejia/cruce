-- Vincular cruces (CP4): varios cruces por persona, uno por pareja.
-- - Dos personas tienen como máximo un cruce entre ellas (trigger, además de los avisos de las funciones).
-- - Cada persona tiene como máximo un cruce pendiente: pedir el código otra vez devuelve el mismo.
-- - preview_invite dice de quién es un código antes de unirse; redeem_invite devuelve ese nombre.
-- - my_cruces lista los cruces completos de quien llama.
-- init.sql ya está en la nube: las funciones se redefinen aquí con create or replace.

-- Antes de la regla: si ya hubiera dos cruces entre la misma pareja, se detiene y hay que resolverlo a mano.
do $$
begin
  if exists (
    select 1
    from public.ledger_members a
    join public.ledger_members b on b.ledger_id = a.ledger_id and a.user_id < b.user_id
    group by a.user_id, b.user_id
    having count(*) > 1
  ) then
    raise exception 'Hay dos personas con más de un cruce entre ellas; resuélvelo antes de aplicar esta migración';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Un cruce por pareja
-- ─────────────────────────────────────────────────────────────

-- Cuando entra la segunda persona de una cuenta, revisa que esa pareja no tenga ya otra.
-- El candado por pareja evita que dos canjes al mismo tiempo se cuelen.
create function public.enforce_one_cruce_per_pair() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_other uuid;
begin
  select user_id into v_other from public.ledger_members
    where ledger_id = new.ledger_id and user_id <> new.user_id
    limit 1;
  if v_other is null then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'cruce:' || least(new.user_id, v_other)::text || ':' || greatest(new.user_id, v_other)::text, 0));

  if exists (
    select 1
    from public.ledger_members a
    join public.ledger_members b on b.ledger_id = a.ledger_id
    where a.user_id = new.user_id and b.user_id = v_other and a.ledger_id <> new.ledger_id
  ) then
    raise exception 'Ya tienen un cruce entre los dos' using errcode = 'unique_violation', hint = 'alreadyLinked';
  end if;
  return new;
end $$;

-- Corre después de ledger_members_max_two (orden alfabético): una tercera persona sigue dando su propio error.
create trigger ledger_members_one_cruce_per_pair
  before insert on public.ledger_members
  for each row execute function public.enforce_one_cruce_per_pair();

-- ─────────────────────────────────────────────────────────────
-- Código de invitación: un solo cruce pendiente por persona
-- ─────────────────────────────────────────────────────────────

-- Devuelve el código del cruce pendiente de quien llama (lo crea si no hay).
-- Si el código pendiente venció, genera otro para el mismo cruce.
create or replace function public.create_ledger_with_invite() returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_ledger   uuid;
  v_code     text;
  v_attempts int := 0;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  -- Dos pantallas abiertas al tiempo no deben crear dos cruces pendientes.
  perform pg_advisory_xact_lock(hashtextextended('pendiente:' || auth.uid()::text, 0));

  -- Pendiente: solo tiene a quien lo creó y nadie canjeó nunca uno de sus códigos. Así un cruce que estuvo completo
  -- (y perdió a la otra persona, por ejemplo al borrar su cuenta) no se reusa con alguien nuevo.
  select l.id into v_ledger
    from public.ledgers l
    where l.created_by = auth.uid()
      and (select count(*) from public.ledger_members m where m.ledger_id = l.id) = 1
      and not exists (select 1 from public.invites i where i.ledger_id = l.id and i.redeemed_at is not null)
    order by l.created_at desc
    limit 1;

  if v_ledger is null then
    insert into public.ledgers (created_by) values (auth.uid()) returning id into v_ledger;
    insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
      values (v_ledger, auth.uid(), 'rosa', 'yellow');
  else
    select code into v_code from public.invites
      where ledger_id = v_ledger and redeemed_at is null and expires_at > now()
      order by expires_at desc
      limit 1;
    if v_code is not null then
      return v_code;
    end if;
  end if;

  -- Un código se puede reusar solo si su invitación venció sin canjearse;
  -- las canjeadas se conservan como registro de quién se unió.
  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 200 then
      raise exception 'No se pudo generar un código, intenta de nuevo';
    end if;
    v_code := 'CRZ-' || lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from public.invites where code = v_code and (redeemed_at is not null or expires_at > now())
    );
  end loop;

  delete from public.invites where code = v_code;
  insert into public.invites (code, ledger_id, created_by) values (v_code, v_ledger, auth.uid());
  return v_code;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Revisar un código (lo comparten preview_invite y redeem_invite)
-- ─────────────────────────────────────────────────────────────

-- Devuelve {"ok": false, "error", "message"} o {"ok": true, "code", "ledger_id", "inviter_name"}.
-- error: "too_many_attempts", "invalid" (no existe, venció o ya se usó), "own" o "already_linked".
-- Registra un intento fallido para "invalid" y "own"; "already_linked" no es adivinar y no cuenta.
-- No se llama desde la app: solo desde las dos funciones de abajo.
create function public.check_invite(p_code text, p_lock boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_invite public.invites%rowtype;
  v_error  text;
  v_name   text;
begin
  -- Cuenta y registra los intentos de una persona de a una llamada a la vez: sin el candado, muchas peticiones
  -- simultáneas verían todas menos de 5 intentos y se saltarían el límite.
  perform pg_advisory_xact_lock(hashtextextended('intentos:' || auth.uid()::text, 0));

  if (select count(*) from public.invite_attempts
      where user_id = auth.uid() and attempted_at > now() - interval '1 hour') >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts',
      'message', 'Hiciste demasiados intentos. Espera una hora e intenta de nuevo.');
  end if;

  if p_lock then
    select * into v_invite from public.invites where code = upper(trim(p_code)) for update;
  else
    select * into v_invite from public.invites where code = upper(trim(p_code));
  end if;

  if not found or v_invite.redeemed_at is not null or v_invite.expires_at <= now() then
    v_error := 'invalid';
  elsif v_invite.created_by = auth.uid() then
    v_error := 'own';
  end if;

  if v_error is not null then
    insert into public.invite_attempts (user_id) values (auth.uid());
    return jsonb_build_object('ok', false, 'error', v_error,
      'message', case v_error when 'own' then 'No puedes usar tu propio código'
                              else 'El código no es válido o ya venció' end);
  end if;

  select display_name into v_name from public.profiles where id = v_invite.created_by;

  if exists (
    select 1
    from public.ledger_members a
    join public.ledger_members b on b.ledger_id = a.ledger_id
    where a.user_id = auth.uid() and b.user_id = v_invite.created_by
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_linked', 'message', 'Ya tienes un cruce con ' || v_name);
  end if;

  return jsonb_build_object('ok', true, 'code', v_invite.code, 'ledger_id', v_invite.ledger_id, 'inviter_name', v_name);
end $$;

-- Dice de quién es un código sin canjearlo: {"ok": true, "inviter_name": ...} o el mismo error que daría canjearlo.
-- Los códigos inválidos cuentan para el límite de intentos, así que adivinar nombres cuesta lo mismo que adivinar códigos.
create function public.preview_invite(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_check jsonb;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  v_check := public.check_invite(p_code, false);
  if not (v_check ->> 'ok')::boolean then
    return v_check;
  end if;
  return jsonb_build_object('ok', true, 'inviter_name', v_check ->> 'inviter_name');
end $$;

-- Canjea un código: agrega a quien lo usa (recibo verde, avatar violeta).
-- Devuelve {"ok": true, "ledger_id", "inviter_name"} o el error de check_invite.
-- Los errores de código se devuelven en vez de lanzarse: una excepción desharía el registro del intento fallido.
create or replace function public.redeem_invite(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_check  jsonb;
  v_ledger uuid;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  v_check := public.check_invite(p_code, true);
  if not (v_check ->> 'ok')::boolean then
    return v_check;
  end if;

  v_ledger := (v_check ->> 'ledger_id')::uuid;
  begin
    insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
      values (v_ledger, auth.uid(), 'verde', 'violet');
  exception when unique_violation then
    -- Carrera rara: las dos personas canjearon el código de la otra al mismo tiempo y la otra ganó.
    -- Se responde igual que si el cruce ya existiera, sin contarlo como intento fallido.
    return jsonb_build_object('ok', false, 'error', 'already_linked',
      'message', 'Ya tienes un cruce con ' || (v_check ->> 'inviter_name'));
  end;

  update public.invites set redeemed_by = auth.uid(), redeemed_at = now() where code = v_check ->> 'code';
  return jsonb_build_object('ok', true, 'ledger_id', v_ledger, 'inviter_name', v_check ->> 'inviter_name');
end $$;

-- ─────────────────────────────────────────────────────────────
-- Los cruces de quien llama
-- ─────────────────────────────────────────────────────────────

-- Solo cruces completos (de dos personas), del que se completó más recientemente al más viejo.
-- Con los colores y el recibo de cada lado: dependen de quién creó cada cruce.
-- security invoker: RLS sigue decidiendo qué filas se ven.
create function public.my_cruces()
returns table (
  ledger_id      uuid,
  partner_id     uuid,
  partner_name   text,
  my_tike        text,
  my_avatar      text,
  partner_tike   text,
  partner_avatar text,
  linked_at      timestamptz
)
language sql stable security invoker set search_path = '' as $$
  select me.ledger_id,
         other.user_id,
         p.display_name,
         me.tike_variant::text,
         me.avatar_color::text,
         other.tike_variant::text,
         other.avatar_color::text,
         greatest(me.joined_at, other.joined_at)
  from public.ledger_members me
  join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
  join public.profiles p on p.id = other.user_id
  where me.user_id = (select auth.uid())
  order by greatest(me.joined_at, other.joined_at) desc, me.ledger_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
revoke all on function public.enforce_one_cruce_per_pair() from public, anon, authenticated;
revoke all on function public.check_invite(text, boolean) from public, anon, authenticated;
revoke all on function public.preview_invite(text) from public, anon;
revoke all on function public.my_cruces() from public, anon;
grant execute on function public.preview_invite(text) to authenticated;
grant execute on function public.my_cruces() to authenticated;
