-- Privacidad (RLS): cada persona solo ve y escribe en sus propias cuentas.
-- Se actúa como el rol authenticated con request.jwt.claims, igual que una petición real de la app.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Datos, creados como postgres (sin RLS).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'tercero@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús'),
  ('33333333-3333-3333-3333-333333333333', 'Tercero');
insert into public.ledgers (id, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'verde', 'violet'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'rosa', 'yellow');
insert into public.movements (id, ledger_id, payer_id, amount, concept, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 60000, 'Cena', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 100000, 'Mercado', '22222222-2222-2222-2222-222222222222');
insert into public.invites (code, ledger_id, created_by) values
  ('CRZ-1234', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

-- Tercero: no ve nada de la cuenta de Joan y Jesús.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select is((select count(*) from public.ledgers where id = 'aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint,
  'Un tercero no ve la cuenta ajena');
select is((select count(*) from public.ledger_members where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint,
  'Un tercero no ve los miembros de la cuenta ajena');
select is((select count(*) from public.movements where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint,
  'Un tercero no ve los movimientos de la cuenta ajena');
select is((select count(*) from public.ledger_balances where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint,
  'Un tercero no ve el saldo de la cuenta ajena');
select is((select count(*) from public.profiles where id <> '33333333-3333-3333-3333-333333333333'), 0::bigint,
  'Un tercero no ve perfiles ajenos');
select is((select count(*) from public.invites), 0::bigint,
  'Un tercero no ve invitaciones ajenas');
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1000, 'Intruso', '33333333-3333-3333-3333-333333333333')$$,
  '42501', null, 'Un tercero no puede crear movimientos en la cuenta ajena (lo frena RLS, no la regla del pagador)');
select throws_ok(
  $$insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    values ('aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'verde', 'violet')$$,
  '42501', null, 'Nadie agrega miembros directamente; solo con redeem_invite');
update public.movements set amount = 1 where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001';

-- Joan: ve su cuenta y no puede anotar a nombre de Jesús.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select sum(amount) from public.movements where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 160000::numeric,
  'La edición del tercero no cambió nada');
select is((select count(*) from public.movements), 2::bigint,
  'Joan ve los movimientos de su cuenta');
select is((select count(*) from public.profiles), 2::bigint,
  'Joan ve su perfil y el de Jesús, no el del tercero');
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1000, 'Suplantar', '22222222-2222-2222-2222-222222222222')$$,
  '42501', null, 'Joan no puede anotar un movimiento a nombre de Jesús');
select lives_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 8000, 'Almuerzo')$$,
  'Joan anota un movimiento en su cuenta; created_by toma su id');
select lives_ok(
  $$update public.movements set deleted_at = now() where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'Joan puede borrar (suave) un movimiento de su cuenta');

-- Jesús: no ve la invitación de Joan, pero sí la cuenta.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select count(*) from public.invites), 0::bigint,
  'Jesús no ve las invitaciones que creó Joan');
select is((select count(*) from public.ledgers), 1::bigint,
  'Jesús ve la cuenta que comparte con Joan');

reset role;
select * from finish();
rollback;
