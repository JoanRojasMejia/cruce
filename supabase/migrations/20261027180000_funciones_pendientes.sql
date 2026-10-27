-- Funciones pendientes (CP11): desvincular cierra el cruce para los dos.
-- - ledgers.closed_at y closed_by: cuándo y quién lo cerró. Se cierra solo con close_cruce().
-- - Un cruce cerrado es de solo lectura: un trigger rechaza anotar, editar o eliminar sus movimientos, vengan de
--   donde vengan (la app, la cola sin conexión o move_parche_debt_to_cruce), y otro, cambiar su reparto por defecto.
-- - La regla de un cruce por pareja cuenta solo los cruces abiertos: la pareja puede volver con un código nuevo.
-- - my_cruces() devuelve también closed_at y default_other_percent, con los abiertos primero.
-- Las migraciones anteriores ya están en la nube: las funciones se redefinen aquí.

alter table public.ledgers
  add column closed_at timestamptz,
  add column closed_by uuid references public.profiles (id) on delete set null;

-- ─────────────────────────────────────────────────────────────
-- Cerrar un cruce
-- ─────────────────────────────────────────────────────────────

-- close_cruce(p_ledger) → la fecha en que quedó cerrado. Cualquiera de los dos lo cierra; si ya estaba cerrado,
-- devuelve la fecha de antes y no cambia nada. Error notFound: no existe, no es de quien llama o no está completo.
create function public.close_cruce(p_ledger uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_closed timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;
  if not exists (select 1 from public.ledger_members where ledger_id = p_ledger and user_id = auth.uid())
     or (select count(*) from public.ledger_members where ledger_id = p_ledger) < 2 then
    raise exception 'Ese cruce no existe' using hint = 'notFound';
  end if;

  update public.ledgers set closed_at = now(), closed_by = auth.uid()
    where id = p_ledger and closed_at is null
    returning closed_at into v_closed;
  if v_closed is null then
    select closed_at into v_closed from public.ledgers where id = p_ledger;
  end if;
  return v_closed;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Un cruce cerrado es de solo lectura
-- ─────────────────────────────────────────────────────────────

-- "for share" choca con el update de close_cruce: si alguien está cerrando el cruce en ese momento, espera a que
-- termine y lee el closed_at ya confirmado. Sin el candado, un gasto que llega justo mientras se cierra se colaría.
create function public.enforce_open_cruce() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_closed timestamptz;
begin
  select closed_at into v_closed from public.ledgers where id = new.ledger_id for share;
  if v_closed is not null then
    raise exception 'Este cruce está cerrado' using errcode = 'check_violation', hint = 'cruceClosed';
  end if;
  return new;
end $$;

create trigger movements_open_cruce
  before insert or update on public.movements
  for each row execute function public.enforce_open_cruce();

-- El reparto por defecto tampoco cambia en un cruce cerrado (la app ya no lo ofrece; esto lo asegura).
create function public.enforce_open_ledger() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.closed_at is not null and new.default_other_percent is distinct from old.default_other_percent then
    raise exception 'Este cruce está cerrado' using errcode = 'check_violation', hint = 'cruceClosed';
  end if;
  return new;
end $$;

create trigger ledgers_open_cruce
  before update on public.ledgers
  for each row execute function public.enforce_open_ledger();

-- ─────────────────────────────────────────────────────────────
-- Un cruce abierto por pareja
-- ─────────────────────────────────────────────────────────────

create or replace function public.enforce_one_cruce_per_pair() returns trigger
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
    join public.ledgers l on l.id = a.ledger_id
    where a.user_id = new.user_id and b.user_id = v_other and a.ledger_id <> new.ledger_id
      and l.closed_at is null
  ) then
    raise exception 'Ya tienen un cruce entre los dos' using errcode = 'unique_violation', hint = 'alreadyLinked';
  end if;
  return new;
end $$;

-- Igual que en vincular_cruces.sql, salvo que "already_linked" solo cuenta los cruces abiertos.
create or replace function public.check_invite(p_code text, p_lock boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_invite public.invites%rowtype;
  v_error  text;
  v_name   text;
begin
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
    join public.ledgers l on l.id = a.ledger_id
    where a.user_id = auth.uid() and b.user_id = v_invite.created_by and l.closed_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_linked', 'message', 'Ya tienes un cruce con ' || v_name);
  end if;

  return jsonb_build_object('ok', true, 'code', v_invite.code, 'ledger_id', v_invite.ledger_id, 'inviter_name', v_name);
end $$;

-- ─────────────────────────────────────────────────────────────
-- Pasar la deuda de un parche al cruce: solo a un cruce abierto
-- ─────────────────────────────────────────────────────────────

-- Igual que en parches.sql, salvo que busca el cruce abierto que comparten. Si solo comparten uno cerrado,
-- responde noSharedCruce, como si no compartieran ninguno.
create or replace function public.move_parche_debt_to_cruce(p_parche uuid, p_other uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
declare
  v_parche   public.parches%rowtype;
  v_me       uuid;
  v_other    public.parche_participants%rowtype;
  v_ledger   uuid;
  v_debt     bigint;
  v_movement uuid;
  v_transfer public.parche_cruce_transfers%rowtype;
begin
  perform public.require_session();
  -- Bloquea el parche: dos aceptaciones al tiempo no crean dos movimientos.
  select * into v_parche from public.parches where id = p_parche for update;
  v_me := public.my_parche_participant_id(p_parche);
  if v_parche.id is null or v_me is null then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  if v_parche.status = 'open' then
    raise exception 'El parche sigue abierto' using hint = 'parcheOpen';
  end if;
  select * into v_other from public.parche_participants where id = p_other and parche_id = p_parche;
  if not found then
    raise exception 'Esa persona no está en el parche' using hint = 'notFound';
  end if;
  if v_other.id = v_me then
    raise exception 'No puedes pasarte una deuda a ti mismo' using hint = 'notAllowed';
  end if;
  if v_other.user_id is null then
    raise exception 'Esa persona no tiene la app' using hint = 'notAllowed';
  end if;

  select mine.ledger_id into v_ledger
    from public.ledger_members mine
    join public.ledger_members theirs on theirs.ledger_id = mine.ledger_id and theirs.user_id = v_other.user_id
    join public.ledgers l on l.id = mine.ledger_id
    where mine.user_id = auth.uid() and l.closed_at is null
    order by l.created_at desc
    limit 1;
  if v_ledger is null then
    raise exception 'No comparten un cruce' using hint = 'noSharedCruce';
  end if;
  if exists (select 1 from public.parche_cruce_transfers
             where parche_id = p_parche and least(from_id, to_id) = least(v_me, v_other.id)
               and greatest(from_id, to_id) = greatest(v_me, v_other.id)) then
    raise exception 'La deuda entre ustedes ya pasó al cruce' using hint = 'alreadyMoved';
  end if;

  v_debt := public.parche_direct_debt(p_parche, v_me, v_other.id);
  if v_debt = 0 then
    raise exception 'No se deben nada entre ustedes' using hint = 'nothingToMove';
  end if;

  -- Paga quien recibe; todo le corresponde a quien debe.
  insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values (v_ledger, 'expense', case when v_debt > 0 then v_other.user_id else auth.uid() end, abs(v_debt),
            'Parche ' || v_parche.name, 'full_other', 100, auth.uid())
    returning id into v_movement;
  insert into public.parche_cruce_transfers (parche_id, from_id, to_id, amount, movement_id)
    values (p_parche, case when v_debt > 0 then v_me else v_other.id end,
            case when v_debt > 0 then v_other.id else v_me end, abs(v_debt), v_movement)
    returning * into v_transfer;
  return v_transfer;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Los cruces de quien llama, con si están cerrados y su reparto por defecto
-- ─────────────────────────────────────────────────────────────

-- Cambia la forma del resultado: hay que borrarla y crearla otra vez (dentro de la transacción de la migración).
drop function public.my_cruces();

-- Solo cruces completos (de dos personas): primero los abiertos y después los cerrados, cada grupo del que se
-- completó más recientemente al más viejo. security invoker: RLS sigue decidiendo qué filas se ven.
create function public.my_cruces()
returns table (
  ledger_id             uuid,
  partner_id            uuid,
  partner_name          text,
  my_tike               text,
  my_avatar             text,
  partner_tike          text,
  partner_avatar        text,
  linked_at             timestamptz,
  closed_at             timestamptz,
  default_other_percent smallint
)
language sql stable security invoker set search_path = '' as $$
  select me.ledger_id,
         other.user_id,
         p.display_name,
         me.tike_variant::text,
         me.avatar_color::text,
         other.tike_variant::text,
         other.avatar_color::text,
         greatest(me.joined_at, other.joined_at),
         l.closed_at,
         l.default_other_percent
  from public.ledger_members me
  join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
  join public.profiles p on p.id = other.user_id
  join public.ledgers l on l.id = me.ledger_id
  where me.user_id = (select auth.uid())
  order by l.closed_at is not null, greatest(me.joined_at, other.joined_at) desc, me.ledger_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
revoke all on function public.close_cruce(uuid) from public, anon;
revoke all on function public.enforce_open_cruce() from public, anon, authenticated;
revoke all on function public.enforce_open_ledger() from public, anon, authenticated;
revoke all on function public.my_cruces() from public, anon;
grant execute on function public.close_cruce(uuid) to authenticated;
grant execute on function public.my_cruces() to authenticated;
