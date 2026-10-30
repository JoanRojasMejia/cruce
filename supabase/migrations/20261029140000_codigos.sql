-- Cruce · una sola pantalla de código con errores separados (corrección 10 de la revisión de diseño, D2)
-- Los formatos no cambian (CRZ- + 4 dígitos que vence en 24 h; PCH- y SOY- + 6 caracteres sin ambiguos).
-- Ahora:
--   - check_invite (y por eso preview_invite y redeem_invite) separa los errores del código CRZ-: "invalid" (no
--     existe), "expired" (venció), "used" (ya se usó) y "own" (es tuyo). Sigue la forma {ok, error, message}, sigue
--     contando los intentos fallidos (5 por hora) y sigue "already_linked".
--   - Un código SOY- se guarda en parche_participants.claimed_code cuando alguien se queda con el lugar, así un código
--     reusado dice "ya se usó" en vez de "no existe". claim_code se sigue borrando al reclamar (como antes), y un código
--     nuevo nunca repite uno usado.
--   - preview_parche_code(p_code): dice a qué parche o a qué lugar lleva un código PCH- o SOY- sin entrar, con el mismo
--     límite de intentos fallidos que CRZ- (adivinar 6 caracteres necesita el límite).
-- Aditiva: no borra datos. join_parche y claim_parche_place no cambian.

-- ─────────────────────────────────────────────────────────────
-- Mensajes de los errores de código
-- ─────────────────────────────────────────────────────────────

-- Un solo lugar para el texto de cada error, igual en CRZ-, PCH- y SOY-.
create function public.code_error(p_error text) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', false, 'error', p_error, 'message',
    case p_error
      when 'expired' then 'Ese código ya venció. Pídele uno nuevo a quien te lo mandó.'
      when 'used' then 'Ese código ya se usó. Pídele uno nuevo a quien te lo mandó.'
      when 'own' then 'Ese código es tuyo. Mándaselo a la otra persona para que lo use.'
      when 'too_many_attempts' then 'Hiciste demasiados intentos. Espera una hora e intenta de nuevo.'
      else 'Ese código no existe. Revisa que esté bien escrito.'
    end)
$$;

-- 5 intentos fallidos en la última hora (CRZ-, PCH- y SOY- cuentan juntos). Bloquea por persona para que dos
-- pantallas al tiempo no se salten el límite.
create function public.code_attempts_exhausted() returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('intentos:' || auth.uid()::text, 0));
  return (select count(*) from public.invite_attempts
          where user_id = auth.uid() and attempted_at > now() - interval '1 hour') >= 5;
end $$;

-- ─────────────────────────────────────────────────────────────
-- CRZ-: errores separados
-- ─────────────────────────────────────────────────────────────

-- Igual que en funciones_pendientes.sql, salvo los errores: primero si no existe, después si es tuyo (aunque haya
-- vencido o se haya usado) y después si ya se usó o venció.
create or replace function public.check_invite(p_code text, p_lock boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_invite public.invites%rowtype;
  v_error  text;
  v_name   text;
begin
  if public.code_attempts_exhausted() then
    return public.code_error('too_many_attempts');
  end if;

  if p_lock then
    select * into v_invite from public.invites where code = upper(trim(p_code)) for update;
  else
    select * into v_invite from public.invites where code = upper(trim(p_code));
  end if;

  if not found then
    v_error := 'invalid';
  elsif v_invite.created_by = auth.uid() then
    v_error := 'own';
  elsif v_invite.redeemed_at is not null then
    v_error := 'used';
  elsif v_invite.expires_at <= now() then
    v_error := 'expired';
  end if;

  if v_error is not null then
    insert into public.invite_attempts (user_id) values (auth.uid());
    return public.code_error(v_error);
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
-- SOY-: el código usado se guarda
-- ─────────────────────────────────────────────────────────────

alter table public.parche_participants
  add column claimed_code text unique check (claimed_code ~ '^SOY-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$');

-- Igual que en parches.sql, salvo que al reclamar el lugar el código pasa a claimed_code (y no se puede cambiar).
create or replace function public.parche_participants_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.parche_id is distinct from old.parche_id or new.joined_at is distinct from old.joined_at then
    raise exception 'No se puede cambiar el parche ni el orden de una persona' using hint = 'notAllowed';
  end if;
  if old.user_id is not null and new.user_id is distinct from old.user_id then
    raise exception 'Ese lugar ya es de alguien' using hint = 'notAllowed';
  end if;
  new.claimed_code := coalesce(old.claimed_code, case when new.user_id is not null then old.claim_code end);
  if new.user_id is not null then
    new.claim_code := null;
  end if;
  return new;
end $$;

-- Igual que en parches.sql, salvo que un código nuevo tampoco repite uno ya usado.
create or replace function public.generate_parche_code(p_prefix text) returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes    bytea;
  v_code     text;
  v_attempts int := 0;
begin
  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 50 then
      raise exception 'No se pudo generar un código, intenta de nuevo';
    end if;
    v_bytes := uuid_send(gen_random_uuid());
    v_code := p_prefix;
    for i in 0..5 loop
      v_code := v_code || substr(v_alphabet, get_byte(v_bytes, i) % 31 + 1, 1);
    end loop;
    exit when not exists (select 1 from public.parches where code = v_code)
      and not exists (select 1 from public.parche_participants where claim_code = v_code or claimed_code = v_code);
  end loop;
  return v_code;
end $$;

-- ─────────────────────────────────────────────────────────────
-- PCH- y SOY-: vista previa sin entrar
-- ─────────────────────────────────────────────────────────────

-- preview_parche_code(p_code) → jsonb. No cambia nada salvo registrar los intentos fallidos.
--   PCH-: {"ok": true, "kind": "parche", "parche_name", "already_member"} (abierto o cerrado, como join_parche).
--   SOY-: {"ok": true, "kind": "place", "parche_name", "person_name"}.
--   Errores {"ok": false, "error", "message"}: invalid (no existe o no es PCH-/SOY-), used (alguien ya se quedó con
--   ese lugar), own (ese lugar ya es tuyo), already_participant (ya estás en ese parche con otro lugar) y
--   too_many_attempts. invalid, used y own cuentan como intento fallido; already_participant no (como already_linked).
create function public.preview_parche_code(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_code        text := upper(btrim(coalesce(p_code, '')));
  v_parche      public.parches%rowtype;
  v_participant public.parche_participants%rowtype;
  v_error       text;
begin
  perform public.require_session();
  if public.code_attempts_exhausted() then
    return public.code_error('too_many_attempts');
  end if;

  if v_code like 'PCH-%' then
    select * into v_parche from public.parches where code = v_code;
    if found then
      return jsonb_build_object('ok', true, 'kind', 'parche', 'parche_name', v_parche.name,
        'already_member', public.is_parche_member(v_parche.id));
    end if;
    v_error := 'invalid';
  elsif v_code like 'SOY-%' then
    select * into v_participant from public.parche_participants where claim_code = v_code;
    if found then
      select * into v_parche from public.parches where id = v_participant.parche_id;
      if public.is_parche_member(v_parche.id) then
        return jsonb_build_object('ok', false, 'error', 'already_participant',
          'message', 'Ya estás en ' || v_parche.name || ', así que no puedes quedarte con ese lugar.');
      end if;
      return jsonb_build_object('ok', true, 'kind', 'place', 'parche_name', v_parche.name,
        'person_name', v_participant.display_name);
    end if;
    select * into v_participant from public.parche_participants where claimed_code = v_code;
    if not found then
      v_error := 'invalid';
    elsif v_participant.user_id = auth.uid() then
      v_error := 'own';
    else
      v_error := 'used';
    end if;
  else
    v_error := 'invalid';
  end if;

  insert into public.invite_attempts (user_id) values (auth.uid());
  if v_error = 'own' then
    return jsonb_build_object('ok', false, 'error', 'own', 'message', 'Ese lugar ya es tuyo.');
  end if;
  return public.code_error(v_error);
end $$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
revoke all on function public.code_error(text) from public, anon, authenticated;
revoke all on function public.code_attempts_exhausted() from public, anon, authenticated;
revoke all on function public.preview_parche_code(text) from public, anon;
grant execute on function public.preview_parche_code(text) to authenticated;
