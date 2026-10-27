-- Funciones pendientes (CP11): cerrar un cruce (desvincular), un cruce cerrado es de solo lectura, la pareja puede
-- volver con un código nuevo, my_cruces con cerrado y reparto, y cambiar el nombre y el reparto por defecto.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'ana@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'intruso@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús'),
  ('33333333-3333-3333-3333-333333333333', 'Ana'),
  ('44444444-4444-4444-4444-444444444444', 'Intruso');
-- Joan y Jesús (más viejo) y Joan y Ana (más reciente), cada uno con un gasto.
insert into public.ledgers (id, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color, joined_at) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow', now() - interval '2 days'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'verde', 'violet', now() - interval '2 days'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow', now() - interval '1 day'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'verde', 'violet', now() - interval '1 day');
insert into public.movements (id, ledger_id, payer_id, amount, concept, created_by) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 40000, 'Cena', '11111111-1111-1111-1111-111111111111');

-- ── Reparto por defecto y nombre ─────────────────────────────
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
update public.ledgers set default_other_percent = 70 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.profiles set display_name = 'Joan R.' where id = '11111111-1111-1111-1111-111111111111';
select results_eq(
  $$select partner_name, closed_at, default_other_percent from public.my_cruces()$$,
  $$values ('Ana'::text, null::timestamptz, 50::smallint), ('Jesús'::text, null::timestamptz, 70::smallint)$$,
  'my_cruces trae el reparto por defecto de cada cruce y ningún cruce cerrado');
select throws_ok(
  $$update public.ledgers set closed_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  '42501', null, 'Nadie cierra un cruce cambiando closed_at a mano');

reset role;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select partner_name, default_other_percent from public.my_cruces()$$,
  $$values ('Joan R.'::text, 70::smallint)$$,
  'Jesús ve el nombre nuevo de Joan y el mismo reparto por defecto');

-- ── Cerrar ───────────────────────────────────────────────────
reset role;
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.close_cruce('aaaaaaaa-0000-0000-0000-000000000001')$$,
  'P0001', 'Ese cruce no existe', 'Alguien de afuera no puede cerrar el cruce');

reset role;
select set_config('request.jwt.claims', '{}', true);
set local role authenticated;
select throws_ok($$select public.close_cruce('aaaaaaaa-0000-0000-0000-000000000001')$$,
  'P0001', 'Necesitas iniciar sesión', 'Sin sesión no se cierra');

reset role;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;
create temp table cierre as select public.close_cruce('aaaaaaaa-0000-0000-0000-000000000001') as at;
select isnt((select at from cierre), null, 'Jesús cierra su cruce con Joan y recibe la fecha');
select is(public.close_cruce('aaaaaaaa-0000-0000-0000-000000000001'), (select at from cierre),
  'Cerrarlo otra vez devuelve la misma fecha');

reset role;
select is((select closed_by from public.ledgers where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '22222222-2222-2222-2222-222222222222'::uuid, 'Queda registrado quién lo cerró');

-- ── Un cruce cerrado es de solo lectura ──────────────────────
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1000, 'Tarde',
            '11111111-1111-1111-1111-111111111111')$$,
  '23514', 'Este cruce está cerrado', 'No se anota en un cruce cerrado');
select throws_ok(
  $$update public.movements set amount = 1 where id = 'bbbbbbbb-0000-0000-0000-000000000001'$$,
  '23514', 'Este cruce está cerrado', 'No se edita un movimiento de un cruce cerrado');
select throws_ok(
  $$update public.movements set deleted_at = now() where id = 'bbbbbbbb-0000-0000-0000-000000000001'$$,
  '23514', 'Este cruce está cerrado', 'No se elimina un movimiento de un cruce cerrado');
select throws_ok(
  $$insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'settlement', '22222222-2222-2222-2222-222222222222', 20000,
            'Saldar cuentas', 'full_other', 100, '11111111-1111-1111-1111-111111111111')$$,
  '23514', 'Este cruce está cerrado', 'No se salda un cruce cerrado');
select is((select amount from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 40000::bigint,
  'El gasto del cruce cerrado sigue igual');
select lives_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1000, 'Café',
            '11111111-1111-1111-1111-111111111111')$$,
  'En el cruce abierto con Ana se sigue anotando');

-- Las funciones security definer (como pasar la deuda de un parche) escriben como dueño de la tabla:
-- el trigger las frena igual.
reset role;
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 5000, 'Parche Santa Marta',
            'full_other', 100, '11111111-1111-1111-1111-111111111111')$$,
  '23514', 'Este cruce está cerrado', 'Tampoco se escribe en un cruce cerrado sin RLS (security definer)');

-- El reparto por defecto tampoco cambia en un cruce cerrado.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$update public.ledgers set default_other_percent = 30 where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  '23514', 'Este cruce está cerrado', 'No se cambia el reparto de un cruce cerrado');
reset role;
-- Borrar la cuenta de quien cerró el cruce no lo impide: queda sin closed_by y sigue cerrado.
select is(
  (select confdeltype from pg_constraint where conrelid = 'public.ledgers'::regclass and conname = 'ledgers_closed_by_fkey'),
  'n'::"char", 'closed_by queda en null si se borra el perfil de quien cerró');

-- ── my_cruces con un cruce cerrado ───────────────────────────
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select partner_name, closed_at is not null from public.my_cruces()$$,
  $$values ('Ana'::text, false), ('Jesús'::text, true)$$,
  'my_cruces pone primero los abiertos y marca el cerrado');

-- ── Volver a vincularse ──────────────────────────────────────
reset role;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
create temp table joan_code as select public.create_ledger_with_invite() as code;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.preview_invite((select code from joan_code))->>'inviter_name', 'Joan R.',
  'Con el cruce cerrado, el código nuevo de Joan sirve para Jesús');
select is((public.redeem_invite((select code from joan_code))->>'ok')::boolean, true,
  'Jesús se une otra vez con el código nuevo');
set local role authenticated;
select results_eq($$select closed_at is not null from public.my_cruces()$$, $$values (false), (true)$$,
  'Jesús tiene un cruce nuevo abierto con Joan y conserva el cerrado');
select is((select count(*) from public.movements m join public.my_cruces() c on c.ledger_id = m.ledger_id
           where c.closed_at is null), 0::bigint, 'El cruce nuevo arranca sin movimientos');

-- Con el cruce nuevo abierto, otro código entre los dos vuelve a chocar con la regla.
reset role;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
create temp table joan_code2 as select public.create_ledger_with_invite() as code;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.redeem_invite((select code from joan_code2))->>'message', 'Ya tienes un cruce con Joan R.',
  'Dos cruces abiertos entre la misma pareja siguen sin poderse');
select throws_ok(
  $$insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    values ((select ledger_id from public.invites where code = (select code from joan_code2)),
            '22222222-2222-2222-2222-222222222222', 'verde', 'violet')$$,
  '23505', 'Ya tienen un cruce entre los dos', 'El trigger también frena un segundo cruce abierto');

select * from finish();
rollback;
