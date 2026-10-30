-- @usuario único (S2 y S3): de 3 a 20 caracteres (minúsculas, números, punto y guion bajo), único sin importar
-- mayúsculas, sugerido a partir del nombre y visible en my_cruces, en la vista previa de un CRZ- y en los del parche.
begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;
create function pg_temp.username(p_user text) returns text language sql as $$
  select username from public.profiles where id = p_user::uuid
$$;

insert into auth.users (id, email) values
  ('15000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('15000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('15000000-0000-0000-0000-000000000003', 'ana@example.com'),
  ('15000000-0000-0000-0000-000000000004', 'juan@example.com'),
  ('15000000-0000-0000-0000-000000000005', 'juan2@example.com'),
  ('15000000-0000-0000-0000-000000000006', 'joanr@example.com'),
  ('15000000-0000-0000-0000-000000000007', 'al@example.com'),
  ('15000000-0000-0000-0000-000000000008', 'emoji@example.com'),
  ('15000000-0000-0000-0000-000000000009', 'largo@example.com'),
  ('15000000-0000-0000-0000-000000000010', 'curioso@example.com');

-- ─────────────────────────────────────────────────────────────
-- La sugerencia al crear el perfil
-- ─────────────────────────────────────────────────────────────
select has_column('public', 'profiles', 'username', 'profiles tiene username');

insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000001', 'Joan');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000002', 'Jesús');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000003', 'Ana');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000004', 'Juan');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000005', 'JUAN');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000006', '  Joan R. Rojas-Peña ');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000007', 'Al');
insert into public.profiles (id, display_name) values ('15000000-0000-0000-0000-000000000008', '🥳🥳');
insert into public.profiles (id, display_name)
  values ('15000000-0000-0000-0000-000000000009', 'Maximiliano Alejandro de la Torre');

select is(pg_temp.username('15000000-0000-0000-0000-000000000001'), 'joan', 'Un perfil nuevo recibe su nombre en minúsculas');
select is(pg_temp.username('15000000-0000-0000-0000-000000000002'), 'jesus', 'Sin tildes');
select is(pg_temp.username('15000000-0000-0000-0000-000000000004'), 'juan', 'El primer Juan queda "juan"');
select is(pg_temp.username('15000000-0000-0000-0000-000000000005'), 'juan2',
  'El segundo Juan (aunque escriba en mayúsculas) recibe un sufijo');
select is(pg_temp.username('15000000-0000-0000-0000-000000000006'), 'joan.r.rojas.pena',
  'Espacios y guiones pasan a punto, sin puntos repetidos ni en los extremos y la ñ pasa a n');
select is(pg_temp.username('15000000-0000-0000-0000-000000000007'), 'al.cruce', 'Un nombre corto se completa');
select is(pg_temp.username('15000000-0000-0000-0000-000000000008'), 'usuario', 'Sin letras ni números queda "usuario"');
select is(pg_temp.username('15000000-0000-0000-0000-000000000009'), 'maximiliano.alejandr', 'Se recorta a 20 caracteres');
select is(public.username_suggestion('Maximiliano Alejandro'), 'maximiliano.alejand2',
  'Con sufijo se recorta la base para no pasar de 20');

-- ─────────────────────────────────────────────────────────────
-- Formato y unicidad en la base
-- ─────────────────────────────────────────────────────────────
select throws_ok($$update public.profiles set username = 'Joan' where id = '15000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'La base rechaza mayúsculas');
select throws_ok($$update public.profiles set username = 'jo' where id = '15000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'La base rechaza menos de 3 caracteres');
select throws_ok($$update public.profiles set username = 'jesus' where id = '15000000-0000-0000-0000-000000000001'$$,
  '23505', null, 'La base rechaza un @usuario repetido');
select throws_ok($$update public.profiles set username = null where id = '15000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'Un perfil vigente no se queda sin @usuario');

-- ─────────────────────────────────────────────────────────────
-- check_username y set_username
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('15000000-0000-0000-0000-000000000003');
select is(public.check_username('jo'),
  '{"ok": false, "error": "format", "message": "Tu @usuario debe tener de 3 a 20 caracteres: minúsculas, números, punto o guion bajo."}'::jsonb,
  'Muy corto: error de formato');
select is(public.check_username('ana rojas') ->> 'error', 'format', 'Con espacio: error de formato');
select is(public.check_username('josé') ->> 'error', 'format', 'Con tilde: error de formato');
select is(public.check_username(repeat('a', 21)) ->> 'error', 'format', 'Con 21 caracteres: error de formato');
select is(public.check_username('JESUS'),
  '{"ok": false, "error": "taken", "message": "Ese @usuario ya está ocupado. Prueba con otro."}'::jsonb,
  'Ocupado sin importar mayúsculas');
select is(public.check_username(' @Ana_1 '), '{"ok": true, "username": "ana_1"}'::jsonb,
  'Disponible: sin @, sin espacios y en minúsculas');
select is(public.check_username('ana'), '{"ok": true, "username": "ana"}'::jsonb, 'El propio está disponible');

select is(public.set_username('@Ana.R'), '{"ok": true, "username": "ana.r"}'::jsonb, 'Ana cambia su @usuario');
select is(pg_temp.username('15000000-0000-0000-0000-000000000003'), 'ana.r', 'Queda guardado');
select is(public.set_username('juan') ->> 'error', 'taken', 'No puede tomar uno ocupado');
select is(public.set_username('a b') ->> 'error', 'format', 'Ni uno con formato inválido');
select is(pg_temp.username('15000000-0000-0000-0000-000000000003'), 'ana.r', 'Un error no cambia el @usuario');

select pg_temp.as_user('15000000-0000-0000-0000-000000000010');
select is(public.check_username('ana'), '{"ok": true, "username": "ana"}'::jsonb,
  'El @usuario que Ana dejó queda libre');

select ok(not has_column_privilege('authenticated', 'public.profiles', 'username', 'UPDATE'),
  'La app no cambia el @usuario con update directo (solo con set_username)');
select ok(has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE')
  and has_column_privilege('authenticated', 'public.profiles', 'avatar_color', 'UPDATE'),
  'Nombre y color se siguen cambiando con update (versiones anteriores de la app)');
select ok(not has_function_privilege('anon', 'public.set_username(text)', 'execute')
  and not has_function_privilege('anon', 'public.check_username(text)', 'execute'),
  'Sin sesión no se revisa ni se cambia un @usuario');

-- ─────────────────────────────────────────────────────────────
-- Dónde se ve: my_cruces, vista previa del CRZ- y los del parche
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('15000000-0000-0000-0000-000000000001');
create temp table joan_code as select public.create_ledger_with_invite() as code;
select pg_temp.as_user('15000000-0000-0000-0000-000000000002');
select is(public.preview_invite((select code from joan_code)),
  jsonb_build_object('ok', true, 'inviter_name', 'Joan', 'inviter_username', 'joan'),
  'La vista previa de un CRZ- trae el @usuario de quien invita');
select ok((public.redeem_invite((select code from joan_code)) ->> 'ok')::boolean, 'Jesús se une');

select results_eq(
  $$select partner_name, partner_username, partner_deleted, my_username from public.my_cruces()$$,
  $$values ('Joan'::text, 'joan'::text, false, 'jesus'::text)$$,
  'my_cruces trae el @usuario de los dos y si la otra cuenta está borrada');
select results_eq(
  $$select partner_name, my_tike, my_avatar, partner_tike, partner_avatar, closed_at, default_other_percent,
           my_color = (select avatar_color::text from public.profiles where id = '15000000-0000-0000-0000-000000000002'),
           partner_color = (select avatar_color::text from public.profiles where id = '15000000-0000-0000-0000-000000000001')
    from public.my_cruces()$$,
  $$values ('Joan'::text, 'verde'::text, 'violet'::text, 'rosa'::text, 'yellow'::text, null::timestamptz,
            50::smallint, true, true)$$,
  'Las columnas de antes de my_cruces no cambian');

-- Los del parche: quien tiene la app trae su @usuario; quien está sin la app, no. Solo lo ve alguien del parche.
select pg_temp.as_user('15000000-0000-0000-0000-000000000001');
select set_config('t.parche', public.create_parche('Santa Marta')::text, true);
create temp table carlos as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Carlos');
select pg_temp.as_user('15000000-0000-0000-0000-000000000003');
select is(public.join_parche((select code from public.parches where id = current_setting('t.parche')::uuid)),
  current_setting('t.parche')::uuid, 'Ana entra al parche (no tiene cruce con Joan)');
select results_eq(
  $$select display_name, public.participant_username(pp) from public.parche_participants pp
    where parche_id = current_setting('t.parche')::uuid order by display_name$$,
  $$values ('Ana'::text, 'ana.r'::text), ('Carlos', null), ('Joan', 'joan')$$,
  'Ana ve el @usuario de Joan aunque no compartan un cruce, y Carlos (sin la app) no tiene');
select pg_temp.as_user('15000000-0000-0000-0000-000000000010');
select is((select public.participant_username(pp) from public.parche_participants pp
           where parche_id = current_setting('t.parche')::uuid and display_name = 'Joan'),
  null, 'Alguien de fuera del parche no ve el @usuario');
select ok(not has_function_privilege('anon', 'public.participant_username(public.parche_participants)', 'execute'),
  'Sin sesión no se pide');

-- ─────────────────────────────────────────────────────────────
-- Relleno: la misma sugerencia, en el orden de creación
-- ─────────────────────────────────────────────────────────────
select is((select count(*) from public.profiles where username is null), 0::bigint, 'Todos los perfiles tienen @usuario');
select is(public.username_suggestion('Joan'), 'joan2', 'La sugerencia salta los ocupados');
select is(public.username_suggestion('Joan', '15000000-0000-0000-0000-000000000001'), 'joan',
  'Sin contar el perfil propio, la sugerencia es su @usuario actual');

select * from finish();
rollback;
