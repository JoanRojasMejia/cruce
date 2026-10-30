-- Cruce · unirse a un parche y quedarse con un lugar cuentan los intentos fallidos (cambio usuarios-y-cuenta, S5)
-- Antes: solo preview_parche_code contaba los PCH- y SOY- que no sirven; llamando directo a join_parche o a
-- claim_parche_place se podían adivinar códigos sin límite.
-- Ahora las dos usan el mismo límite que CRZ- y la vista previa (5 intentos fallidos por hora, juntos):
--   - Con 5 intentos en la última hora lanzan tooManyAttempts antes de buscar el código, aunque sea válido.
--   - Un código que no sirve (un PCH- que no existe; un SOY- que no existe, que ya se usó o que ya es tuyo) registra el
--     intento y devuelve null en vez de lanzar invalidCode: una excepción desharía el registro del intento.
--   - Lo demás no cambia: alreadyParticipant, invalidData y un parche donde ya estás no cuentan.
-- Las versiones anteriores de la app llaman antes a preview_parche_code; un null solo les llega si el código dejó de
-- servir entre la vista previa y entrar (ahí ven un error genérico en vez de "Ese código no existe").

-- join_parche(p_code, p_display_name) → uuid del parche, o null si el código no existe (cuenta como intento fallido).
create or replace function public.join_parche(p_code text, p_display_name text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_parche  uuid;
  v_display text;
begin
  perform public.require_session();
  if public.code_attempts_exhausted() then
    raise exception 'Hiciste demasiados intentos. Espera una hora e intenta de nuevo.' using hint = 'tooManyAttempts';
  end if;
  select id into v_parche from public.parches where code = upper(btrim(coalesce(p_code, '')));
  if v_parche is null then
    insert into public.invite_attempts (user_id) values (auth.uid());
    return null;
  end if;
  if public.is_parche_member(v_parche) then
    return v_parche;
  end if;
  v_display := btrim(coalesce(nullif(btrim(p_display_name), ''),
                              (select display_name from public.profiles where id = auth.uid()), ''));
  if char_length(v_display) not between 1 and 40 then
    raise exception 'El nombre debe tener entre 1 y 40 caracteres' using hint = 'invalidData';
  end if;
  insert into public.parche_participants (parche_id, user_id, display_name, last_seen_at)
    values (v_parche, auth.uid(), v_display, now());
  return v_parche;
end $$;

-- claim_parche_place(p_code) → uuid del parche, o null si el código no sirve (no existe, ya se usó o ya es tuyo; cuenta
-- como intento fallido). Error alreadyParticipant ("Ya estás en este parche") sin contar.
create or replace function public.claim_parche_place(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_participant public.parche_participants%rowtype;
begin
  perform public.require_session();
  if public.code_attempts_exhausted() then
    raise exception 'Hiciste demasiados intentos. Espera una hora e intenta de nuevo.' using hint = 'tooManyAttempts';
  end if;
  select * into v_participant from public.parche_participants
    where claim_code = upper(btrim(coalesce(p_code, ''))) for update;
  if not found then
    insert into public.invite_attempts (user_id) values (auth.uid());
    return null;
  end if;
  if public.is_parche_member(v_participant.parche_id) then
    raise exception 'Ya estás en este parche' using hint = 'alreadyParticipant';
  end if;
  update public.parche_participants
    set user_id = auth.uid(), claim_code = null, last_seen_at = now()
    where id = v_participant.id;
  return v_participant.parche_id;
end $$;
