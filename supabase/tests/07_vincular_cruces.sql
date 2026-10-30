-- Vincular cruces: un cruce por pareja, un solo cruce pendiente por persona,
-- ver de quién es un código antes de unirse y la lista de cruces completos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'ana@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'intruso@example.com');
-- El color es de cada perfil (11_colores), no del rol en el cruce: Joan verde y Jesús rosado.
insert into public.profiles (id, display_name, avatar_color) values
  ('11111111-1111-1111-1111-111111111111', 'Joan', 'green'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús', 'pink'),
  ('33333333-3333-3333-3333-333333333333', 'Ana', 'yellow'),
  ('44444444-4444-4444-4444-444444444444', 'Intruso', 'yellow');

-- ── Un solo cruce pendiente por persona ──────────────────────
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
create temp table joan_code as select public.create_ledger_with_invite() as code;
select is(public.create_ledger_with_invite(), (select code from joan_code),
  'Pedir el código otra vez devuelve el mismo mientras nadie se une');
select is((select count(*) from public.ledger_members where user_id = '11111111-1111-1111-1111-111111111111'), 1::bigint,
  'Pedir el código dos veces deja una sola cuenta pendiente');

update public.invites set expires_at = now() - interval '1 minute' where code = (select code from joan_code);
create temp table joan_code2 as select public.create_ledger_with_invite() as code;
select isnt((select code from joan_code2), (select code from joan_code), 'Si el código pendiente venció, sale uno nuevo');
select is(
  (select ledger_id from public.invites where code = (select code from joan_code2)),
  (select ledger_id from public.ledger_members where user_id = '11111111-1111-1111-1111-111111111111'),
  'El código nuevo es de la misma cuenta pendiente');
select is((select count(*) from public.ledger_members where user_id = '11111111-1111-1111-1111-111111111111'), 1::bigint,
  'Un código vencido no crea otra cuenta');

-- ── Ver de quién es un código ────────────────────────────────
select is(public.preview_invite((select code from joan_code2))->>'error', 'own',
  'La vista previa del código propio da el mismo error que canjearlo');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.preview_invite(' ' || lower((select code from joan_code2)) || ' '),
  '{"ok": true, "inviter_name": "Joan", "inviter_username": "joan"}'::jsonb,
  'La vista previa dice de quién es el código, sin importar mayúsculas ni espacios');
select ok(
  (select count(*) = 0 from public.ledger_members where user_id = '22222222-2222-2222-2222-222222222222')
  and (select redeemed_at is null from public.invites where code = (select code from joan_code2)),
  'Ver el código no une a nadie ni lo marca como usado');

-- ── Unirse devuelve el nombre ────────────────────────────────
create temp table jesus_join as select public.redeem_invite((select code from joan_code2)) as r;
select is((select r->>'inviter_name' from jesus_join), 'Joan', 'Unirse devuelve el nombre de quien invitó');
select ok((select (r->>'ok')::boolean from jesus_join), 'Jesús se une a la cuenta de Joan');

-- ── La lista de cruces ───────────────────────────────────────
select results_eq(
  $$select partner_name, my_tike, my_color, partner_tike, partner_color from public.my_cruces()$$,
  $$values ('Joan'::text, 'verde'::text, 'pink'::text, 'rosa'::text, 'green'::text)$$,
  'Jesús ve su cruce con Joan, con el color del perfil y el recibo de cada lado');
select results_eq(
  $$select my_avatar, partner_avatar from public.my_cruces()$$,
  $$values ('violet'::text, 'yellow'::text)$$,
  'my_avatar y partner_avatar siguen con el color del rol, para las versiones anteriores de la app');

-- ── Un cruce por pareja ──────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
create temp table joan_code3 as select public.create_ledger_with_invite() as code;
select results_eq($$select partner_name from public.my_cruces()$$, $$values ('Jesús'::text)$$,
  'La lista no incluye la cuenta pendiente, que solo tiene a Joan');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.preview_invite((select code from joan_code3)),
  '{"ok": false, "error": "already_linked", "message": "Ya tienes un cruce con Joan"}'::jsonb,
  'La vista previa avisa que ya hay un cruce con esa persona');
select is(public.redeem_invite((select code from joan_code3)),
  '{"ok": false, "error": "already_linked", "message": "Ya tienes un cruce con Joan"}'::jsonb,
  'Un segundo cruce con la misma persona se rechaza');
select is((select count(*) from public.my_cruces()), 1::bigint, 'Jesús sigue con un solo cruce con Joan');
select is((select count(*) from public.invite_attempts where user_id = '22222222-2222-2222-2222-222222222222'), 0::bigint,
  'Que ya exista el cruce no cuenta como intento fallido');

-- Directo en la tabla (como el dueño de la base, sin RLS): la regla la pone la base, no solo las funciones.
select throws_ok(
  $$insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    select ledger_id, '22222222-2222-2222-2222-222222222222', 'verde', 'violet'
    from public.invites where code = (select code from joan_code3)$$,
  '23505', 'Ya tienen un cruce entre los dos',
  'La base no deja a la misma pareja en una segunda cuenta');

-- ── Cruces con personas distintas ────────────────────────────
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
create temp table ana_code as select public.create_ledger_with_invite() as code;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select ok((public.redeem_invite((select code from ana_code))->>'ok')::boolean, 'Jesús sí puede tener un cruce con Ana');
-- En una transacción now() no avanza: se separan las fechas para probar el orden.
update public.ledger_members set joined_at = now() - interval '1 day'
  where ledger_id = (select ledger_id from public.invites where code = (select code from joan_code2));
select results_eq($$select partner_name from public.my_cruces()$$, $$values ('Ana'::text), ('Joan'::text)$$,
  'Jesús ve sus dos cruces, del más reciente al más viejo');

-- Con el rol de la app (RLS activo), la lista es la misma.
set local role authenticated;
select results_eq($$select partner_name from public.my_cruces()$$, $$values ('Ana'::text), ('Joan'::text)$$,
  'Con RLS, Jesús ve los mismos dos cruces con el nombre de cada persona');
reset role;

-- Un cruce que estuvo completo no vuelve a ser "pendiente" si pierde a la otra persona (por ejemplo, al borrar
-- su cuenta): Joan pide otro código y sale de una cuenta nueva, no de la que tiene su historia con Ana.
-- Se borra directo, como dueño de la base, porque la app no tiene cómo hacerlo.
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
create temp table ana_code2 as select public.create_ledger_with_invite() as code;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select public.redeem_invite((select code from ana_code2));
delete from public.ledger_members
  where user_id = '11111111-1111-1111-1111-111111111111'
    and ledger_id = (select ledger_id from public.invites where code = (select code from ana_code2));
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select isnt(
  (select ledger_id from public.invites where code = public.create_ledger_with_invite()),
  (select ledger_id from public.invites where code = (select code from ana_code2)),
  'Un cruce que ya estuvo completo no se reusa como cruce pendiente');

-- ── El límite de intentos también cuenta la vista previa ─────
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select public.preview_invite('CRZ-X00' || n) from generate_series(1, 5) as n;
select is((select count(*) from public.invite_attempts where user_id = '44444444-4444-4444-4444-444444444444'), 5::bigint,
  'Cada código inválido en la vista previa queda registrado como intento');
select is(public.preview_invite((select code from joan_code3)),
  '{"ok": false, "error": "too_many_attempts", "message": "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."}'::jsonb,
  'Con 5 fallos, la vista previa no revela el nombre aunque el código sea válido');
select is(public.redeem_invite((select code from joan_code3))->>'error', 'too_many_attempts',
  'Los fallos de la vista previa también bloquean el canje');

-- ── Sin sesión y rol anónimo ─────────────────────────────────
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$select public.preview_invite('CRZ-0000')$$, 'P0001', 'Necesitas iniciar sesión',
  'Sin sesión no se puede ver un código');
set local role anon;
select throws_ok($$select public.preview_invite('CRZ-0000')$$, '42501', null, 'El rol anónimo no puede ver códigos');
select throws_ok($$select * from public.my_cruces()$$, '42501', null, 'El rol anónimo no puede listar cruces');
reset role;

select * from finish();
rollback;
