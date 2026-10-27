-- Movimientos desde la app (CP5): los dos del cruce los editan y los borran (borrado suave), un tercero no ve ni
-- toca nada, nadie anota a nombre de otro y guardar dos veces el mismo movimiento (upsert por id) deja uno solo.
-- Las consultas van con el rol de la app (authenticated) para que RLS aplique, igual que desde PostgREST.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

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

-- Joan anota una cena, con el id que genera la app.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.movements (id, ledger_id, payer_id, amount, concept, category, created_by)
    values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
            '11111111-1111-1111-1111-111111111111', 60000, 'Cena', 'comida', '11111111-1111-1111-1111-111111111111')$$,
  'Joan anota un gasto en su cruce');
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 1000, 'Falso',
            '22222222-2222-2222-2222-222222222222')$$,
  '42501', null, 'Nadie anota a nombre de otro');

-- Guardar otra vez el mismo movimiento (upsert por id, como lo hace la app) no lo duplica.
insert into public.movements (id, ledger_id, payer_id, amount, concept, category, created_by)
  values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
          '11111111-1111-1111-1111-111111111111', 64000, 'Cena', 'comida', '11111111-1111-1111-1111-111111111111')
  on conflict (id) do update set amount = excluded.amount;
select is((select count(*) from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 1::bigint,
  'Guardar dos veces el mismo movimiento deja uno solo');
select is((select amount from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 64000::bigint,
  'El segundo guardado reemplaza los datos');

-- Jesús edita y borra (suave) el gasto que anotó Joan.
reset role;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;
update public.movements set amount = 60000 where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select is((select amount from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 60000::bigint,
  'La otra persona del cruce puede editar un gasto que anotó la otra');
update public.movements set deleted_at = now() where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select ok((select deleted_at is not null from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'La otra persona del cruce puede eliminarlo (borrado suave)');

-- Un tercero no ve ni toca nada del cruce.
reset role;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.movements where ledger_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint,
  'Un tercero no ve los movimientos del cruce');
update public.movements set amount = 1 where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1000, 'Intruso',
            '33333333-3333-3333-3333-333333333333')$$,
  '42501', null, 'Un tercero no anota en un cruce ajeno, aunque ponga como pagador a un miembro (RLS)');
reset role;
select is((select amount from public.movements where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 60000::bigint,
  'Un tercero no puede editar un movimiento ajeno (RLS lo deja sin filas)');

select * from finish();
rollback;
