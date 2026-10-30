-- Cruce · @usuario único (cambio usuarios-y-cuenta, S2 y S3)
-- Antes: a las personas solo se les veía el nombre, así que dos "Juan" no se distinguían.
-- Ahora:
--   - profiles.username: de 3 a 20 caracteres (minúsculas, números, punto y guion bajo), único. Como solo admite
--     minúsculas, el índice único ya es "sin importar mayúsculas". La app sigue identificando a las personas por id.
--   - Un perfil nuevo recibe una sugerencia a partir de su nombre (username_suggestion); la entrada la confirma o la
--     cambia, y Tu perfil la cambia después. Los perfiles que ya existían la reciben aquí, en el orden en que se crearon.
--   - check_username y set_username devuelven {ok, username} o {ok: false, error, message} (format, taken), como
--     code_error, en vez de lanzar. El @usuario no se cambia con update directo.
--   - profiles.deleted_at: un perfil borrado queda como lápida (ver 20261030110000_borrar_cuenta.sql) y es el único
--     que se queda sin @usuario.
--   - Dónde se lee: my_cruces() (columnas nuevas al final; las de antes no cambian), check_invite/preview_invite
--     (inviter_username) y participant_username(parche_participants), un campo calculado de PostgREST para los del
--     parche.
-- Aditiva: no borra datos.

-- ─────────────────────────────────────────────────────────────
-- Columnas
-- ─────────────────────────────────────────────────────────────

alter table public.profiles
  add column username text constraint username_format check (username ~ '^[a-z0-9._]{3,20}$'),
  -- Cuándo se borró la cuenta; null mientras existe.
  add column deleted_at timestamptz;
create unique index profiles_username_idx on public.profiles (username);

-- ─────────────────────────────────────────────────────────────
-- Sugerencia
-- ─────────────────────────────────────────────────────────────

-- El @usuario que se le sugiere a un nombre: minúsculas sin tildes, espacios y guiones a punto, sin otros caracteres,
-- sin puntos repetidos ni en los extremos y de máximo 20. Un nombre de 1 o 2 caracteres se completa con ".cruce"; uno
-- sin letras ni números queda "usuario". Si está ocupado (sin contar el perfil p_exclude), le agrega 2, 3… recortando la
-- base para no pasar de 20.
create function public.username_suggestion(p_name text, p_exclude uuid default null) returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_base      text;
  v_candidate text;
  v_n         int := 1;
begin
  v_base := translate(lower(btrim(coalesce(p_name, ''))), 'áàäâãåéèëêíìïîóòöôõúùüûñç', 'aaaaaaeeeeiiiiooooouuuunc');
  v_base := regexp_replace(v_base, '[[:space:]-]+', '.', 'g');
  v_base := regexp_replace(v_base, '[^a-z0-9._]', '', 'g');
  v_base := regexp_replace(v_base, '\.{2,}', '.', 'g');
  v_base := btrim(v_base, '._');
  if v_base = '' then
    v_base := 'usuario';
  elsif char_length(v_base) < 3 then
    v_base := v_base || '.cruce';
  end if;
  v_base := rtrim(left(v_base, 20), '._');
  v_candidate := v_base;
  while exists (select 1 from public.profiles where username = v_candidate and id is distinct from p_exclude) loop
    v_n := v_n + 1;
    v_candidate := rtrim(left(v_base, 20 - char_length(v_n::text)), '._') || v_n;
  end loop;
  return v_candidate;
end $$;

-- Un perfil nuevo sin @usuario recibe la sugerencia de su nombre: si la app se cierra en el paso "Elige tu @usuario",
-- la persona ya tiene uno.
create function public.profiles_username_default() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.username is null and new.deleted_at is null then
    new.username := public.username_suggestion(new.display_name);
  end if;
  return new;
end $$;

create trigger profiles_username_default
  before insert on public.profiles
  for each row execute function public.profiles_username_default();

-- Relleno: los perfiles que ya existían, del más viejo al más nuevo (el primer "Juan" queda "juan").
do $$
declare
  v_profile record;
begin
  for v_profile in select id, display_name from public.profiles where username is null order by created_at, id loop
    update public.profiles set username = public.username_suggestion(v_profile.display_name)
      where id = v_profile.id;
  end loop;
end $$;

-- Solo una lápida se queda sin @usuario.
alter table public.profiles
  add constraint username_required check (username is not null or deleted_at is not null);

-- ─────────────────────────────────────────────────────────────
-- Revisar y cambiar el @usuario
-- ─────────────────────────────────────────────────────────────

-- Lo que se escribió, en la forma en que se guarda: sin espacios a los lados, sin la @ inicial y en minúsculas.
create function public.normalize_username(p_username text) returns text
language sql immutable set search_path = '' as $$
  select lower(ltrim(btrim(coalesce(p_username, '')), '@'))
$$;

-- Un solo lugar para el texto de cada error del @usuario.
create function public.username_error(p_error text) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', false, 'error', p_error, 'message',
    case p_error
      when 'taken' then 'Ese @usuario ya está ocupado. Prueba con otro.'
      else 'Tu @usuario debe tener de 3 a 20 caracteres: minúsculas, números, punto o guion bajo.'
    end)
$$;

-- check_username(p_username) → {"ok": true, "username"} (normalizado) o el error: format (no cumple el formato) o taken
-- (es de otra persona). El propio está disponible. No cambia nada.
create function public.check_username(p_username text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_username text := public.normalize_username(p_username);
begin
  perform public.require_session();
  if v_username !~ '^[a-z0-9._]{3,20}$' then
    return public.username_error('format');
  end if;
  if exists (select 1 from public.profiles where username = v_username and id <> auth.uid()) then
    return public.username_error('taken');
  end if;
  return jsonb_build_object('ok', true, 'username', v_username);
end $$;

-- set_username(p_username) → lo mismo que check_username; si está disponible, lo guarda en el perfil propio y el
-- anterior queda libre. Si otra persona lo toma al mismo tiempo, devuelve taken. Error notFound: sin perfil.
create function public.set_username(p_username text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_check jsonb;
begin
  v_check := public.check_username(p_username);
  if not (v_check ->> 'ok')::boolean then
    return v_check;
  end if;
  begin
    update public.profiles set username = v_check ->> 'username' where id = auth.uid();
  exception when unique_violation then
    return public.username_error('taken');
  end;
  if not found then
    raise exception 'Primero crea tu perfil' using hint = 'notFound';
  end if;
  return v_check;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Dónde se lee
-- ─────────────────────────────────────────────────────────────

-- Igual que en codigos.sql, salvo que una respuesta correcta trae también el @usuario de quien invita.
create or replace function public.check_invite(p_code text, p_lock boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_invite   public.invites%rowtype;
  v_error    text;
  v_name     text;
  v_username text;
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

  select display_name, username into v_name, v_username from public.profiles where id = v_invite.created_by;

  if exists (
    select 1
    from public.ledger_members a
    join public.ledger_members b on b.ledger_id = a.ledger_id
    join public.ledgers l on l.id = a.ledger_id
    where a.user_id = auth.uid() and b.user_id = v_invite.created_by and l.closed_at is null
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_linked', 'message', 'Ya tienes un cruce con ' || v_name);
  end if;

  return jsonb_build_object('ok', true, 'code', v_invite.code, 'ledger_id', v_invite.ledger_id, 'inviter_name', v_name,
    'inviter_username', v_username);
end $$;

-- Igual que en vincular_cruces.sql, con el @usuario de quien invita.
create or replace function public.preview_invite(p_code text) returns jsonb
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
  return jsonb_build_object('ok', true, 'inviter_name', v_check ->> 'inviter_name',
    'inviter_username', v_check ->> 'inviter_username');
end $$;

-- El @usuario de alguien del parche con la app, para quien está en ese parche (null si está sin la app o si quien
-- pregunta no es del parche). Es un campo calculado de PostgREST: parche_participants(*, participant_username).
-- security definer porque RLS de profiles solo deja ver a la pareja de cruce. Busca por id (no confía en el resto de la
-- fila que llega).
create function public.participant_username(p_participant public.parche_participants) returns text
language sql stable security definer set search_path = '' as $$
  select pr.username
  from public.parche_participants pp
  join public.profiles pr on pr.id = pp.user_id
  where pp.id = p_participant.id and public.is_parche_member(pp.parche_id)
$$;

-- my_cruces(): las columnas de 20261029130000_my_cruces_compat.sql sin cambios y, al final, el @usuario de cada uno y
-- si la otra cuenta se borró. Cambia la forma del resultado: hay que borrarla y crearla otra vez.
drop function public.my_cruces();

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
  default_other_percent smallint,
  my_color              text,
  partner_color         text,
  my_username           text,
  partner_username      text,
  partner_deleted       boolean
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
         l.default_other_percent,
         mp.avatar_color::text,
         p.avatar_color::text,
         mp.username,
         p.username,
         p.deleted_at is not null
  from public.ledger_members me
  join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
  join public.profiles p on p.id = other.user_id
  join public.profiles mp on mp.id = me.user_id
  join public.ledgers l on l.id = me.ledger_id
  where me.user_id = (select auth.uid())
  order by l.closed_at is not null, greatest(me.joined_at, other.joined_at) desc, me.ledger_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────

-- De un perfil, la app solo escribe el nombre y el color (y el id al crearlo); el @usuario va por set_username y
-- deleted_at solo lo pone la base.
revoke insert, update on public.profiles from anon, authenticated;
grant insert (id, display_name, avatar_color) on public.profiles to authenticated;
grant update (display_name, avatar_color) on public.profiles to authenticated;

revoke all on function public.username_suggestion(text, uuid) from public, anon, authenticated;
revoke all on function public.profiles_username_default() from public, anon, authenticated;
revoke all on function public.normalize_username(text) from public, anon, authenticated;
revoke all on function public.username_error(text) from public, anon, authenticated;
revoke all on function public.check_username(text) from public, anon;
revoke all on function public.set_username(text) from public, anon;
revoke all on function public.participant_username(public.parche_participants) from public, anon;
revoke all on function public.my_cruces() from public, anon;
grant execute on function public.check_username(text) to authenticated;
grant execute on function public.set_username(text) to authenticated;
grant execute on function public.participant_username(public.parche_participants) to authenticated;
grant execute on function public.my_cruces() to authenticated;
