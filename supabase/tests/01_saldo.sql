-- Saldo: owed_by_other con cada reparto y la vista ledger_balances.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús');

-- Cuenta 1: el ejemplo canónico. Cuenta 2: casos de reparto y redondeo.
insert into public.ledgers (id, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'verde', 'violet'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'verde', 'violet');

insert into public.movements (id, ledger_id, payer_id, amount, concept, split_type, other_share_percent, created_by) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 60000, 'Cena', 'equal', 50, '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1001, 'Impar', 'equal', 50, '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 100000, 'Porcentaje', 'percentage', 30, '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1002, 'Medio peso', 'percentage', 25, '11111111-1111-1111-1111-111111111111'),
  ('bbbbbbbb-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 40000, 'Préstamo', 'full_other', 100, '11111111-1111-1111-1111-111111111111');

select is((select owed_by_other from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 30000::bigint,
  '50/50 de $60.000: el otro debe $30.000');
select is((select owed_by_other from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000002'), 501::bigint,
  '50/50 de $1.001 redondea al peso: $501');
select is((select owed_by_other from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000003'), 30000::bigint,
  '30 % de $100.000: $30.000');
select is((select owed_by_other from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000004'), 251::bigint,
  '25 % de $1.002 es 250,5: redondea hacia arriba a $251');
select is((select owed_by_other from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000005'), 40000::bigint,
  'Todo es del otro: debe el monto completo');

select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1000, 'Mal', 'equal', 30, '11111111-1111-1111-1111-111111111111')$$,
  '23514', null,
  'Un 50/50 con otro porcentaje se rechaza');

-- Ejemplo canónico: Joan paga cena $60.000 a medias, Jesús paga mercado $100.000 a medias.
insert into public.movements (id, ledger_id, payer_id, amount, concept, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 60000, 'Cena', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 100000, 'Mercado', '22222222-2222-2222-2222-222222222222');

select is((select net from public.ledger_balances where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001' and user_id = '11111111-1111-1111-1111-111111111111'),
  -20000::bigint, 'Ejemplo canónico: Joan le debe $20.000 a Jesús');
select is((select net from public.ledger_balances where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001' and user_id = '22222222-2222-2222-2222-222222222222'),
  20000::bigint, 'Ejemplo canónico: Jesús tiene +$20.000 a su favor');

-- Borrado suave: el mercado deja de contar.
update public.movements set deleted_at = now() where id = 'cccccccc-0000-0000-0000-000000000002';
select is((select net from public.ledger_balances where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001' and user_id = '11111111-1111-1111-1111-111111111111'),
  30000::bigint, 'Un movimiento borrado no cuenta en el saldo');

select * from finish();
rollback;
