-- Reglas de la cuenta: máximo dos personas, quien paga es miembro y saldar es "todo es del otro".
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'tercero@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús'),
  ('33333333-3333-3333-3333-333333333333', 'Tercero');
insert into public.ledgers (id, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'verde', 'violet');

select throws_ok(
  $$insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'rosa', 'yellow')$$,
  '23514', 'Esta cuenta ya tiene dos personas',
  'Una cuenta no acepta una tercera persona');

select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 1000, 'Ajeno', '11111111-1111-1111-1111-111111111111')$$,
  '23514', 'Quien pagó no pertenece a esta cuenta',
  'Quien paga tiene que ser miembro de la cuenta');

select throws_ok(
  $$insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'settlement', '22222222-2222-2222-2222-222222222222', 20000, 'Saldar', 'equal', 50, '11111111-1111-1111-1111-111111111111')$$,
  '23514', null,
  'Saldar solo se registra con reparto "todo es del otro"');

select * from finish();
rollback;
