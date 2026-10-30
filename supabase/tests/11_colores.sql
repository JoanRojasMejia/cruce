-- Color fijo por persona (corrección 3, decisión D7): el color vive en profiles y se ve igual en cada cruce y en cada
-- parche; quien está sin la app recibe el siguiente color libre del parche; cada quien cambia solo el suyo; el recibo
-- rosa o verde sigue siendo por cruce.
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;
-- "Carlos:violet, Jesús:yellow, …" por nombre (se lee como postgres). Dentro de la prueba todos entran en la misma
-- transacción, con el mismo joined_at, así que se ordena por nombre.
create function pg_temp.colors(p_parche uuid) returns text language sql as $$
  select string_agg(display_name || ':' || avatar_color, ', ' order by display_name)
  from public.parche_participants where parche_id = p_parche
$$;

-- ─────────────────────────────────────────────────────────────
-- Datos, creados como postgres (sin RLS)
-- ─────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('20000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('20000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('20000000-0000-0000-0000-000000000003', 'ana@example.com'),
  ('20000000-0000-0000-0000-000000000004', 'pedro@example.com'),
  ('20000000-0000-0000-0000-000000000005', 'nuevo@example.com');
insert into public.profiles (id, display_name) values
  ('20000000-0000-0000-0000-000000000001', 'Joan'),
  ('20000000-0000-0000-0000-000000000002', 'Jesús'),
  ('20000000-0000-0000-0000-000000000003', 'Ana'),
  ('20000000-0000-0000-0000-000000000004', 'Pedro');
-- Joan creó un cruce con Jesús (amarillo y rosa) y después se unió al de Ana (violeta y verde).
-- Jesús creó uno con Ana que ya está cerrado y es el más reciente. Pedro solo tiene un cruce pendiente.
insert into public.ledgers (id, created_by, closed_at) values
  ('e1000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', null),
  ('e1000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', null),
  ('e1000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', now()),
  ('e1000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', null);
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color, joined_at) values
  ('e1000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'rosa', 'yellow', now() - interval '3 days'),
  ('e1000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'verde', 'violet', now() - interval '3 days'),
  ('e1000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', 'rosa', 'yellow', now() - interval '2 days'),
  ('e1000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'verde', 'violet', now() - interval '2 days'),
  ('e1000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', 'rosa', 'yellow', now() - interval '1 day'),
  ('e1000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'verde', 'violet', now() - interval '1 day'),
  ('e1000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', 'rosa', 'yellow', now());

-- ─────────────────────────────────────────────────────────────
-- Relleno de los perfiles que ya existían
-- ─────────────────────────────────────────────────────────────
select is(public.legacy_avatar_color('20000000-0000-0000-0000-000000000001'), 'violet'::public.person_color,
  'Un perfil que ya existía queda con el color de su cruce más reciente');
select is(public.legacy_avatar_color('20000000-0000-0000-0000-000000000002'), 'violet'::public.person_color,
  'Un cruce cerrado no cuenta como el más reciente si hay uno abierto');
select is(public.legacy_avatar_color('20000000-0000-0000-0000-000000000004'), 'yellow'::public.person_color,
  'Con solo un cruce pendiente queda amarillo');
select is(public.legacy_avatar_color('20000000-0000-0000-0000-000000000005'), 'yellow'::public.person_color,
  'Sin cruces queda amarillo');

-- ─────────────────────────────────────────────────────────────
-- Perfil nuevo: un color de la paleta, al azar
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('20000000-0000-0000-0000-000000000005');
set local role authenticated;
insert into public.profiles (id, display_name) values ('20000000-0000-0000-0000-000000000005', 'Nuevo');
select ok((select avatar_color is not null from public.profiles where id = '20000000-0000-0000-0000-000000000005'),
  'Un perfil nuevo recibe un color de la paleta');
reset role;

create temp table random_profiles as
  select gen_random_uuid() as id from generate_series(1, 60);
insert into auth.users (id, email) select id, id || '@example.com' from random_profiles;
insert into public.profiles (id, display_name) select id, 'Azar' from random_profiles;
select ok((select count(distinct avatar_color) > 1 from public.profiles where display_name = 'Azar'),
  'El color de un perfil nuevo es al azar, no siempre el mismo');
select is(
  (select array_agg(e::text order by n) from unnest(enum_range(null::public.person_color)) with ordinality as x(e, n)),
  array['yellow', 'violet', 'green', 'peach', 'pink', 'lime'],
  'La paleta tiene los 6 colores de CruceColor, en orden');

-- Colores fijos para el resto de las pruebas.
update public.profiles set avatar_color = 'green' where id = '20000000-0000-0000-0000-000000000001';
update public.profiles set avatar_color = 'yellow' where id = '20000000-0000-0000-0000-000000000002';
update public.profiles set avatar_color = 'pink' where id = '20000000-0000-0000-0000-000000000003';
update public.profiles set avatar_color = 'lime' where id = '20000000-0000-0000-0000-000000000004';
update public.profiles set avatar_color = 'peach' where id = '20000000-0000-0000-0000-000000000005';

-- ─────────────────────────────────────────────────────────────
-- La misma persona, del mismo color en cada cruce; el recibo sigue siendo por cruce
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('20000000-0000-0000-0000-000000000001');
set local role authenticated;
select results_eq(
  $$select partner_name, my_color, partner_color, my_tike, partner_tike from public.my_cruces()$$,
  $$values ('Ana'::text, 'green'::text, 'pink'::text, 'verde'::text, 'rosa'::text),
           ('Jesús'::text, 'green'::text, 'yellow'::text, 'rosa'::text, 'verde'::text)$$,
  'Joan es verde en sus dos cruces, aunque en uno lo creó (rosa) y en el otro se unió (verde)');
-- Las versiones anteriores de la app leen my_avatar y partner_avatar como {yellow, violet}: siguen siendo el del rol.
select results_eq(
  $$select partner_name, my_avatar, partner_avatar from public.my_cruces()$$,
  $$values ('Ana'::text, 'violet'::text, 'yellow'::text), ('Jesús'::text, 'yellow'::text, 'violet'::text)$$,
  'my_avatar y partner_avatar siguen siendo el color del rol (amarillo quien creó, violeta quien se unió)');
reset role;

select pg_temp.as_user('20000000-0000-0000-0000-000000000002');
set local role authenticated;
select results_eq($$select partner_name, partner_color from public.my_cruces() where partner_name = 'Joan'$$,
  $$values ('Joan'::text, 'green'::text)$$, 'Jesús ve a Joan verde');
reset role;

select pg_temp.as_user('20000000-0000-0000-0000-000000000003');
set local role authenticated;
select results_eq($$select partner_name, partner_color from public.my_cruces() where partner_name = 'Joan'$$,
  $$values ('Joan'::text, 'green'::text)$$, 'Ana también ve a Joan verde');
reset role;

-- Un cruce nuevo con las funciones de siempre: quien lo crea ve el rosa y quien se une, el verde.
select pg_temp.as_user('20000000-0000-0000-0000-000000000005');
create temp table nuevo_code as select public.create_ledger_with_invite() as code;
select pg_temp.as_user('20000000-0000-0000-0000-000000000004');
select ok((public.redeem_invite((select code from nuevo_code))->>'ok')::boolean, 'Pedro se une al cruce de Nuevo');
set local role authenticated;
select results_eq(
  $$select my_tike, my_color, partner_tike, partner_color from public.my_cruces() where partner_name = 'Nuevo'$$,
  $$values ('verde'::text, 'lime'::text, 'rosa'::text, 'peach'::text)$$,
  'Quien se une ve el recibo verde; los colores son los de cada perfil, no los del rol');
select results_eq(
  $$select my_avatar, partner_avatar from public.my_cruces() where partner_name = 'Nuevo'$$,
  $$values ('violet'::text, 'yellow'::text)$$,
  'Un cruce nuevo también llena el color del rol para las versiones anteriores');
reset role;

-- ─────────────────────────────────────────────────────────────
-- Parches: el color del perfil, y quien está sin la app el siguiente libre
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('20000000-0000-0000-0000-000000000001');
select set_config('t.parche', public.create_parche('Santa Marta')::text, true);
create temp table parche_code as select code from public.parches where id = current_setting('t.parche')::uuid;
select pg_temp.as_user('20000000-0000-0000-0000-000000000002');
select public.join_parche((select code from parche_code));
select pg_temp.as_user('20000000-0000-0000-0000-000000000001');
create temp table carlos as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Carlos');
create temp table diego as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Diego');

select is(pg_temp.colors(current_setting('t.parche')::uuid),
  'Carlos:violet, Diego:peach, Jesús:yellow, Joan:green',
  'En el parche, quien tiene la app sale con el color de su perfil y quien no, con el siguiente color libre');
select is((select avatar_color::text from carlos), 'violet',
  'add_parche_participant devuelve el color de quien está sin la app');

set local role authenticated;
select is(
  (select avatar_color::text from public.parche_participants
   where parche_id = current_setting('t.parche')::uuid and display_name = 'Joan'),
  'green', 'La app lee el color de cada participante del parche');
reset role;

-- Un segundo parche: los colores libres se cuentan por parche.
select set_config('t.parche2', public.create_parche('Cena')::text, true);
select public.add_parche_participant(current_setting('t.parche2')::uuid, 'Carlos');
select is(pg_temp.colors(current_setting('t.parche2')::uuid), 'Carlos:yellow, Joan:green',
  'El color libre es por parche: en otro parche Carlos puede ser de otro color');

-- ─────────────────────────────────────────────────────────────
-- Cambiar el color en "Tu perfil": solo el propio, y se ve en los parches
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('20000000-0000-0000-0000-000000000002');
set local role authenticated;
update public.profiles set avatar_color = 'pink' where id = '20000000-0000-0000-0000-000000000002';
update public.profiles set avatar_color = 'lime' where id = '20000000-0000-0000-0000-000000000001';
reset role;
select is((select avatar_color::text from public.profiles where id = '20000000-0000-0000-0000-000000000002'), 'pink',
  'Jesús cambia su propio color');
select is((select avatar_color::text from public.profiles where id = '20000000-0000-0000-0000-000000000001'), 'green',
  'Jesús no puede cambiar el color de Joan');
select is(pg_temp.colors(current_setting('t.parche')::uuid),
  'Carlos:violet, Diego:peach, Jesús:pink, Joan:green',
  'El color nuevo de Jesús se ve en el parche y los de quien está sin la app no cambian');

select pg_temp.as_user('20000000-0000-0000-0000-000000000001');
set local role authenticated;
select results_eq($$select partner_color from public.my_cruces() where partner_name = 'Jesús'$$,
  $$values ('pink'::text)$$, 'Joan ve el color nuevo de Jesús en su cruce');
reset role;

select pg_temp.as_user('20000000-0000-0000-0000-000000000005');
set local role authenticated;
select throws_ok(
  $$update public.parche_participants set avatar_color = 'lime' where display_name = 'Carlos'$$,
  '42501', null, 'Nadie cambia a mano el color de alguien en un parche');
reset role;

-- ─────────────────────────────────────────────────────────────
-- Quedarse con un lugar: el color pasa a ser el del perfil
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('20000000-0000-0000-0000-000000000003');
select public.claim_parche_place((select claim_code from carlos));
select is(
  (select avatar_color::text from public.parche_participants where id = (select id from carlos)), 'pink',
  'Ana se queda con el lugar de Carlos y el lugar toma el color de su perfil');
select is((select avatar_color::text from public.parche_participants where id = (select id from diego)), 'peach',
  'Diego, sin la app, conserva su color');

-- ─────────────────────────────────────────────────────────────
-- Tike: sigue por cruce en ledger_members
-- ─────────────────────────────────────────────────────────────
select results_eq(
  $$select tike_variant::text from public.ledger_members
    where ledger_id = 'e1000000-0000-0000-0000-000000000001' order by joined_at, tike_variant$$,
  $$values ('rosa'::text), ('verde'::text)$$,
  'El recibo sigue guardado por cruce: quien lo creó rosa y quien se unió verde');
select ok(
  not has_function_privilege('authenticated', 'public.next_parche_color(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.legacy_avatar_color(uuid)', 'execute'),
  'Las ayudas del color son internas: la app no las llama');

select * from finish();
rollback;
