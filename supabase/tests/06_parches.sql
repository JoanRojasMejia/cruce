-- Parches: grupos de varias personas, aparte del cruce de dos.
-- Se actúa como el rol authenticated con request.jwt.claims, igual que una petición real de la app.
-- Los ids de participantes se guardan en variables de sesión (t.j, t.a, …) porque authenticated no lee tablas temporales.
begin;
create extension if not exists pgtap with schema extensions;
select plan(89);

-- ─────────────────────────────────────────────────────────────
-- Ayudas
-- ─────────────────────────────────────────────────────────────
create function pg_temp.pid(p text) returns uuid language sql as $$
  select current_setting('t.' || p)::uuid
$$;
-- Pares (persona, monto) → [{participant_id, amount}].
create function pg_temp.lines(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'participant_id', current_setting('t.' || p[i]), 'amount', p[i + 1]::bigint) order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 2) as i
$$;
-- Tríos (persona, monto, dato de entrada o '') → [{participant_id, amount, input}].
create function pg_temp.shares(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'participant_id', current_setting('t.' || p[i]), 'amount', p[i + 1]::bigint,
    'input', nullif(p[i + 2], '')::int) order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 3) as i
$$;
-- Pares (monto, 'persona,persona') → [{amount, participant_ids}].
create function pg_temp.items(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'amount', p[i]::bigint,
    'participant_ids', (select jsonb_agg(current_setting('t.' || n)) from unnest(string_to_array(p[i + 1], ',')) as n))
    order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 2) as i
$$;
-- La pista (hint) del error que lanza una sentencia; la app la usa para saber qué pasó.
create function pg_temp.error_hint(p_sql text) returns text language plpgsql as $$
declare
  v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint;
  return v_hint;
end $$;
create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;

-- ─────────────────────────────────────────────────────────────
-- Estructura y permisos
-- ─────────────────────────────────────────────────────────────
select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename like 'parche%' and roles = '{authenticated}'),
  9::bigint, 'Cada tabla de parches tiene su política de lectura para authenticated');
select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename like 'parche%' and roles <> '{authenticated}'),
  0::bigint, 'Ninguna política de parches aplica a otro rol que authenticated');
select is(
  (select count(*) from pg_tables t, unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) as priv
   where t.schemaname = 'public' and t.tablename like 'parche%'
     and has_table_privilege('anon', format('public.%I', t.tablename), priv)),
  0::bigint, 'anon no tiene ningún permiso sobre las tablas de parches');
select is(
  (select count(*) from pg_tables t, unnest(array['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) as priv
   where t.schemaname = 'public' and t.tablename like 'parche%'
     and has_table_privilege('authenticated', format('public.%I', t.tablename), priv)),
  0::bigint, 'authenticated solo lee las tablas de parches; escribe con las funciones');
select has_index('public', 'parche_participants', 'parche_participants_user_id_idx', array['user_id'],
  'parche_participants tiene índice en user_id');

-- ─────────────────────────────────────────────────────────────
-- Datos, creados como postgres (sin RLS)
-- ─────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'jesus@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'ana@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carlos@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'joan@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'fuera@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Jesús'),
  ('22222222-2222-2222-2222-222222222222', 'Ana'),
  ('33333333-3333-3333-3333-333333333333', 'Carlos'),
  ('44444444-4444-4444-4444-444444444444', 'Joan'),
  ('55555555-5555-5555-5555-555555555555', 'Fuera');
-- Jesús y Joan comparten un cruce.
insert into public.ledgers (id, created_by) values
  ('d0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('d0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('d0000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'verde', 'violet');

select set_config('t.parche', 'a0000000-0000-0000-0000-000000000001', true);
select set_config('t.c', 'c0000000-0000-0000-0000-000000000003', true);

set local role authenticated;

-- ─────────────────────────────────────────────────────────────
-- Crear, unirse y agregar sin la app
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(public.create_parche('  Santa Marta ', 'Jesús', 'a0000000-0000-0000-0000-000000000001'),
  'a0000000-0000-0000-0000-000000000001'::uuid, 'Jesús crea el parche con el id que genera la app');
select matches((select code from public.parches where id = pg_temp.pid('parche')),
  '^PCH-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$', 'El código es PCH- y 6 caracteres sin ambiguos');
select is((select status::text || '/' || name from public.parches where id = pg_temp.pid('parche')),
  'open/Santa Marta', 'El parche nace abierto y con el nombre sin espacios a los lados');
select is((select array_agg(user_id) from public.parche_participants where parche_id = pg_temp.pid('parche')),
  array['11111111-1111-1111-1111-111111111111'::uuid], 'Jesús es su único participante');
select public.create_parche('Santa Marta', 'Jesús', 'a0000000-0000-0000-0000-000000000001');
select is((select count(*) from public.parches), 1::bigint, 'Crear otra vez con el mismo id no crea otro parche');
select throws_ok($$select public.create_parche('   ', 'Jesús')$$,
  'P0001', 'El nombre del parche debe tener entre 1 y 60 caracteres', 'Un parche sin nombre no se crea');
select set_config('t.j', (select id::text from public.parche_participants
  where user_id = '11111111-1111-1111-1111-111111111111'), true);
select set_config('t.code', (select code from public.parches where id = pg_temp.pid('parche')), true);

-- Ana se une.
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(public.join_parche(' ' || lower(current_setting('t.code')) || ' ', 'Ana'), pg_temp.pid('parche'),
  'Ana se une con el código, sin importar mayúsculas ni espacios');
select public.join_parche(current_setting('t.code'), 'Ana');
select is((select count(*) from public.parche_participants where user_id = '22222222-2222-2222-2222-222222222222'),
  1::bigint, 'Unirse dos veces no agrega a Ana dos veces');
select throws_ok($$select public.join_parche('PCH-ZZZZZZ', 'Ana')$$,
  'P0001', 'Ese código no existe', 'Un código que no existe se rechaza');
select is(pg_temp.error_hint($$select public.join_parche('PCH-ZZZZZZ', 'Ana')$$), 'invalidCode',
  'El error de código inválido trae la pista invalidCode');
select set_config('t.a', (select id::text from public.parche_participants
  where user_id = '22222222-2222-2222-2222-222222222222'), true);

-- Jesús agrega a Carlos, que no tiene la app.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select ok(
  (select p.user_id is null and p.claim_code ~ '^SOY-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$' and p.display_name = 'Carlos'
   from public.add_parche_participant(pg_temp.pid('parche'), ' Carlos ', pg_temp.pid('c')) as p),
  'Carlos queda sin la app y con su código SOY-');
select public.add_parche_participant(pg_temp.pid('parche'), 'Carlos', pg_temp.pid('c'));
select is((select count(*) from public.parche_participants where display_name = 'Carlos'), 1::bigint,
  'Agregar otra vez con el mismo id no duplica a Carlos');
select throws_ok($$select public.add_parche_participant(current_setting('t.parche')::uuid, '')$$,
  'P0001', 'El nombre debe tener entre 1 y 40 caracteres', 'Una persona sin nombre no se agrega');
select set_config('t.soy', (select claim_code from public.parche_participants where id = pg_temp.pid('c')), true);

-- Joan se une.
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select public.join_parche(current_setting('t.code'), 'Joan');
select set_config('t.jo', (select id::text from public.parche_participants
  where user_id = '44444444-4444-4444-4444-444444444444'), true);

-- Alguien de fuera no ve nada ni puede escribir.
select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
select is((select count(*) from public.parches), 0::bigint, 'Alguien de fuera no ve el parche');
select is((select count(*) from public.parche_participants), 0::bigint, 'Alguien de fuera no ve sus participantes');
select throws_ok($$select public.mark_parche_seen(current_setting('t.parche')::uuid)$$,
  'P0001', 'Ese parche no existe', 'Alguien de fuera no puede marcar el parche como visto');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000099', current_setting('t.parche')::uuid,
    'Intruso', 1000, 0, 1000, now(), 'equal', pg_temp.lines('j', '1000'), pg_temp.shares('j', '1000', '1'))$$,
  'P0001', 'Ese parche no existe', 'Alguien de fuera no puede anotar gastos');

-- ─────────────────────────────────────────────────────────────
-- Gastos
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
-- Almuerzo por consumo con 10 % de propina, pagado por Ana.
select is(public.save_parche_expense('e0000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
    'Almuerzo', 200000, 10, 220000, '2026-10-25 13:00:00+00', 'items',
    pg_temp.lines('a', '220000'),
    pg_temp.shares('j', '110000', '', 'a', '55000', '', 'c', '22000', '', 'jo', '33000', ''),
    pg_temp.items('100000', 'j', '50000', 'a', '20000', 'c', '30000', 'jo')),
  'e0000000-0000-0000-0000-000000000001'::uuid, 'Jesús anota el almuerzo por consumo con propina');
select is((select recorded_by from public.parche_expenses where id = 'e0000000-0000-0000-0000-000000000001'),
  pg_temp.pid('j'), 'El gasto queda anotado por el participante de Jesús');
-- Hospedaje en partes iguales entre los 4, pagado por Jesús.
select is(public.save_parche_expense('e0000000-0000-0000-0000-000000000002', pg_temp.pid('parche'),
    'Hospedaje', 256000, 0, 256000, '2026-10-25 20:00:00+00', 'equal',
    pg_temp.lines('j', '256000'),
    pg_temp.shares('j', '64000', '1', 'a', '64000', '1', 'c', '64000', '1', 'jo', '64000', '1')),
  'e0000000-0000-0000-0000-000000000002'::uuid, 'Jesús anota el hospedaje en partes iguales');
-- Taxi entre 3 (se borrará).
select is(public.save_parche_expense('e0000000-0000-0000-0000-000000000003', pg_temp.pid('parche'),
    'Taxi', 30000, 0, 30000, '2026-10-25 21:00:00+00', 'equal',
    pg_temp.lines('j', '30000'),
    pg_temp.shares('j', '10000', '1', 'a', '10000', '1', 'jo', '10000', '1')),
  'e0000000-0000-0000-0000-000000000003'::uuid, 'Jesús anota un taxi entre algunos');
-- Agua de $3 con dos pagadores: sirve para ver el redondeo de la deuda directa.
select is(public.save_parche_expense('e0000000-0000-0000-0000-000000000004', pg_temp.pid('parche'),
    'Agua', 3, 0, 3, '2026-10-25 22:00:00+00', 'shares',
    pg_temp.lines('j', '2', 'a', '1'),
    pg_temp.shares('j', '1', '1', 'a', '1', '1', 'c', '1', '1')),
  'e0000000-0000-0000-0000-000000000004'::uuid, 'Un gasto puede tener varios pagadores');

-- Validación de sumas (trigger diferido, que la función revisa antes de terminar).
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000009', current_setting('t.parche')::uuid,
    'Cena', 220000, 0, 220000, now(), 'equal', pg_temp.lines('a', '200000'),
    pg_temp.shares('j', '110000', '1', 'a', '110000', '1'))$$,
  '23514', 'Los pagos no suman el total del gasto', 'Si los pagadores no suman el total, no se guarda');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000009', current_setting('t.parche')::uuid,
    'Cena', 220000, 0, 220000, now(), 'equal', pg_temp.lines('a', '220000'),
    pg_temp.shares('j', '110000', '1', 'a', '100000', '1'))$$,
  '23514', 'Las partes no suman el total del gasto', 'Si las partes no suman el total, no se guarda');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000009', current_setting('t.parche')::uuid,
    'Cena', 1000, 0, 1000, now(), 'equal',
    jsonb_build_array(jsonb_build_object('participant_id', gen_random_uuid(), 'amount', 1000)),
    pg_temp.shares('j', '1000', '1'))$$,
  '23503', null, 'Un pagador que no existe no se acepta');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000009', current_setting('t.parche')::uuid,
    'Cena', 1000, 10, 1000, now(), 'equal', pg_temp.lines('j', '1000'), pg_temp.shares('j', '1000', '1'))$$,
  '23514', null, 'El total tiene que ser el monto base más la propina');
select is((select count(*) from public.parche_expenses where id = 'e0000000-0000-0000-0000-000000000009'), 0::bigint,
  'Los gastos rechazados no quedan guardados');

-- Reintento idempotente y edición (Ana edita un gasto que anotó Jesús).
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select public.save_parche_expense('e0000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
    'Almuerzo', 200000, 10, 220000, '2026-10-25 13:00:00+00', 'items',
    pg_temp.lines('a', '220000'),
    pg_temp.shares('j', '110000', '', 'a', '55000', '', 'c', '22000', '', 'jo', '33000', ''),
    pg_temp.items('100000', 'j', '50000', 'a', '20000', 'c', '30000', 'jo'));
select is((select count(*) from public.parche_activity where kind = 'expenseEdited'), 0::bigint,
  'Reenviar el mismo gasto no lo cambia ni deja aviso');
select public.save_parche_expense('e0000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
    'Almuerzo en la playa', 200000, 10, 220000, '2026-10-25 13:00:00+00', 'items',
    pg_temp.lines('a', '220000'),
    pg_temp.shares('j', '110000', '', 'a', '55000', '', 'c', '22000', '', 'jo', '33000', ''),
    pg_temp.items('100000', 'j', '50000', 'a', '20000', 'c', '30000', 'jo'));
select ok(
  (select actor_id = pg_temp.pid('a') and recorded_by_id = pg_temp.pid('j') and concept = 'Almuerzo en la playa'
   from public.parche_activity where kind = 'expenseEdited'),
  'La edición deja el aviso "Ana editó un gasto que anotaste" para Jesús');
select ok(
  (select concept = 'Almuerzo en la playa' and recorded_by = pg_temp.pid('j') and updated_by = pg_temp.pid('a')
   from public.parche_expenses where id = 'e0000000-0000-0000-0000-000000000001'),
  'El gasto cambia, sigue anotado por Jesús y queda editado por Ana');

-- Borrado suave.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.delete_parche_expense('e0000000-0000-0000-0000-000000000003');
select ok(
  (select deleted_at is not null and deleted_by = pg_temp.pid('j')
   from public.parche_expenses where id = 'e0000000-0000-0000-0000-000000000003'),
  'Borrar es un borrado suave que guarda quién borró');
select public.delete_parche_expense('e0000000-0000-0000-0000-000000000003');
select is((select count(*) from public.parche_activity where kind = 'expenseDeleted'), 1::bigint,
  'Borrar otra vez no hace nada');
select public.save_parche_expense('e0000000-0000-0000-0000-000000000003', pg_temp.pid('parche'),
    'Taxi editado', 30000, 0, 30000, '2026-10-25 21:00:00+00', 'equal',
    pg_temp.lines('j', '30000'),
    pg_temp.shares('j', '10000', '1', 'a', '10000', '1', 'jo', '10000', '1'));
select is((select concept from public.parche_expenses where id = 'e0000000-0000-0000-0000-000000000003'), 'Taxi',
  'Un gasto borrado no se edita');

-- ─────────────────────────────────────────────────────────────
-- Pagos y confirmación
-- ─────────────────────────────────────────────────────────────
-- Ana anota que Carlos le pagó a Jesús: queda pendiente hasta que Jesús confirme.
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select ok(
  (select confirmed_at is null and recorded_by = pg_temp.pid('a')
   from public.record_parche_payment('b0000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
     pg_temp.pid('c'), pg_temp.pid('j'), 87500)),
  'Un pago anotado por otra persona a alguien con la app queda pendiente');
select public.record_parche_payment('b0000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
  pg_temp.pid('c'), pg_temp.pid('j'), 87500);
select is((select count(*) from public.parche_payments where id = 'b0000000-0000-0000-0000-000000000001'), 1::bigint,
  'Reenviar el mismo pago no lo duplica');
select throws_ok($$select public.confirm_parche_payment('b0000000-0000-0000-0000-000000000001')$$,
  'P0001', 'Solo quien recibió el pago puede confirmarlo', 'Solo quien recibió confirma');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select ok((select confirmed_at is not null from public.confirm_parche_payment('b0000000-0000-0000-0000-000000000001')),
  'Jesús confirma el pago que recibió');
select public.confirm_parche_payment('b0000000-0000-0000-0000-000000000001');
select is((select count(*) from public.parche_activity where kind = 'paymentConfirmed'), 1::bigint,
  'Confirmar otra vez no hace nada');
select ok(
  (select confirmed_at is not null
   from public.record_parche_payment('b0000000-0000-0000-0000-000000000002', pg_temp.pid('parche'),
     pg_temp.pid('c'), pg_temp.pid('j'), 1000)),
  'Un pago anotado por quien lo recibió cuenta de una vez');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select ok(
  (select confirmed_at is not null
   from public.record_parche_payment('b0000000-0000-0000-0000-000000000003', pg_temp.pid('parche'),
     pg_temp.pid('a'), pg_temp.pid('c'), 500)),
  'Un pago a alguien sin la app cuenta de una vez');
select throws_ok(
  $$select public.record_parche_payment(gen_random_uuid(), current_setting('t.parche')::uuid,
    current_setting('t.a')::uuid, current_setting('t.a')::uuid, 500)$$,
  'P0001', 'El pago no es válido', 'Nadie se paga a sí mismo');

-- ─────────────────────────────────────────────────────────────
-- Deuda directa entre dos (la calcula la base; redondeo hacia abajo, como ParcheCalculator.directDebt)
-- ─────────────────────────────────────────────────────────────
reset role;
-- Jesús → Ana: 110.000 del almuerzo − 64.000 del hospedaje + (1 × 1 / 3 = 0) − (1 × 2 / 3 = 0) del agua.
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('j'), pg_temp.pid('a')), 46000::bigint,
  'La deuda directa redondea cada fracción hacia abajo');
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('a'), pg_temp.pid('j')), -46000::bigint,
  'La deuda directa al revés es la misma con signo contrario');
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('jo'), pg_temp.pid('j')), 64000::bigint,
  'Joan le debe directamente $64.000 a Jesús; el taxi borrado no cuenta');
set local role authenticated;

-- ─────────────────────────────────────────────────────────────
-- Quedarse con el lugar
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$select public.claim_parche_place(current_setting('t.soy'))$$,
  'P0001', 'Ya estás en este parche', 'Quien ya es participante no se queda con otro lugar');
select is(pg_temp.error_hint($$select public.claim_parche_place(current_setting('t.soy'))$$), 'alreadyParticipant',
  'El error trae la pista alreadyParticipant');
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select is(public.claim_parche_place(lower(current_setting('t.soy'))), pg_temp.pid('parche'),
  'Carlos se queda con su lugar con el código SOY-');
select ok(
  (select user_id = '33333333-3333-3333-3333-333333333333' and claim_code is null
   from public.parche_participants where id = pg_temp.pid('c')),
  'El lugar pasa a ser de Carlos, sin crear otra persona, y el código deja de servir');
select is((select count(*) from public.parche_expenses where parche_id = pg_temp.pid('parche')), 4::bigint,
  'Carlos ve los gastos del parche, también el borrado');
select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
select throws_ok($$select public.claim_parche_place(current_setting('t.soy'))$$,
  'P0001', 'Ese código no existe', 'Un código SOY- usado ya no sirve');

-- ─────────────────────────────────────────────────────────────
-- Cerrar
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.jo')::uuid)$$,
  'P0001', 'El parche sigue abierto', 'La deuda solo pasa al cruce con el parche cerrado');
-- Solo quien creó el parche lo cierra (Jesús); 12_cerrar_parche prueba que los demás no pueden.
select public.close_parche(pg_temp.pid('parche'));
select ok((select status = 'closed' and closed_at is not null from public.parches where id = pg_temp.pid('parche')),
  'Jesús, quien lo creó, cierra el parche');
select public.close_parche(pg_temp.pid('parche'));
select is((select count(*) from public.parche_activity where kind = 'parcheClosed'), 1::bigint,
  'Cerrar otra vez no hace nada');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000005', current_setting('t.parche')::uuid,
    'Postre', 1000, 0, 1000, now(), 'equal', pg_temp.lines('jo', '1000'), pg_temp.shares('jo', '1000', '1'))$$,
  'P0001', 'El parche está cerrado', 'Con el parche cerrado no se anotan gastos');
select is(pg_temp.error_hint(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000005', current_setting('t.parche')::uuid,
    'Postre', 1000, 0, 1000, now(), 'equal', pg_temp.lines('jo', '1000'), pg_temp.shares('jo', '1000', '1'))$$),
  'parcheClosed', 'El error trae la pista parcheClosed');
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000004', current_setting('t.parche')::uuid,
    'Agua cara', 3, 0, 3, now(), 'shares', pg_temp.lines('j', '2', 'a', '1'),
    pg_temp.shares('j', '1', '1', 'a', '1', '1', 'c', '1', '1'))$$,
  'P0001', 'El parche está cerrado', 'Con el parche cerrado no se editan gastos');
select throws_ok($$select public.delete_parche_expense('e0000000-0000-0000-0000-000000000002')$$,
  'P0001', 'El parche está cerrado', 'Con el parche cerrado no se borran gastos');
select throws_ok($$select public.add_parche_participant(current_setting('t.parche')::uuid, 'Tarde')$$,
  'P0001', 'El parche está cerrado', 'Con el parche cerrado no se agregan personas sin la app');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select ok(
  (select confirmed_at is not null
   from public.record_parche_payment('b0000000-0000-0000-0000-000000000004', pg_temp.pid('parche'),
     pg_temp.pid('a'), pg_temp.pid('j'), 100)),
  'Con el parche cerrado se siguen anotando pagos');
reset role;
select throws_ok($$update public.parches set status = 'open' where id = current_setting('t.parche')::uuid$$,
  'P0001', 'Un parche cerrado no se reabre', 'Un parche cerrado no se reabre ni desde la base');
set local role authenticated;

-- ─────────────────────────────────────────────────────────────
-- Pasar la deuda al cruce
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$,
  'P0001', 'No comparten un cruce', 'Ana y Jesús no comparten un cruce');
select is(pg_temp.error_hint(
  $$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$),
  'noSharedCruce', 'El error trae la pista noSharedCruce');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.c')::uuid)$$,
  'P0001', 'No comparten un cruce', 'Jesús y Carlos no comparten un cruce');
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$,
  'P0001', 'No puedes pasarte una deuda a ti mismo', 'Nadie pasa una deuda consigo mismo');
-- Joan y Jesús comparten un cruce y Joan le debe directamente $64.000, pero en "Para saldar" no hay un pago entre
-- ellos (Joan le paga a Ana y Jesús a Ana y a Carlos): no hay nada que pasar al cruce. Proponer, aceptar y rechazar
-- se prueban en 10_pasar_al_cruce.sql.
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$,
  'P0001', 'Para saldar no hay un pago entre ustedes', 'Sin un pago entre Joan y Jesús en el plan, no se ofrece nada');
select is(pg_temp.error_hint(
  $$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$),
  'nothingToMove', 'El error trae la pista nothingToMove');
select is((select count(*) from public.parche_cruce_transfers where parche_id = pg_temp.pid('parche')), 0::bigint,
  'No queda ninguna transferencia al cruce');
select is((select count(*) from public.movements where ledger_id = 'd0000000-0000-0000-0000-000000000001'), 0::bigint,
  'El cruce de Joan y Jesús no tiene movimientos');
reset role;
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('jo'), pg_temp.pid('j')), 64000::bigint,
  'La deuda directa entre los dos sigue en el parche');
select is(
  (select count(*) from public.parche_settlement_plan(pg_temp.pid('parche'))
   where (from_id, to_id) in ((pg_temp.pid('jo'), pg_temp.pid('j')), (pg_temp.pid('j'), pg_temp.pid('jo')))),
  0::bigint, 'El plan para saldar no tiene un pago entre Joan y Jesús');
set local role authenticated;

-- ─────────────────────────────────────────────────────────────
-- Otro parche: validación diferida y nada que pasar al cruce
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select set_config('t.cena', public.create_parche('Cena', 'Joan', 'a0000000-0000-0000-0000-000000000002')::text, true);
select set_config('t.cena_code', (select code from public.parches where id = pg_temp.pid('cena')), true);
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select public.join_parche(current_setting('t.cena_code'), 'Jesús');
select pg_temp.as_user('44444444-4444-4444-4444-444444444444');
select set_config('t.jo2', public.my_parche_participant_id(pg_temp.pid('cena'))::text, true);
reset role;
-- Directo en las tablas: el gasto se inserta antes que sus pagadores y partes; la suma se revisa al final.
select lives_ok(
  $sql$do $do$ begin
    insert into public.parche_expenses (id, parche_id, concept, base_amount, amount, split_method, recorded_by)
      values ('e0000000-0000-0000-0000-000000000011', current_setting('t.cena')::uuid, 'Pan', 1000, 1000, 'equal',
              current_setting('t.jo2')::uuid);
    insert into public.parche_expense_payers values ('e0000000-0000-0000-0000-000000000011', current_setting('t.jo2')::uuid, 1000);
    insert into public.parche_expense_shares values ('e0000000-0000-0000-0000-000000000011', current_setting('t.jo2')::uuid, 1000, 1);
    set constraints all immediate;
  end $do$$sql$,
  'La validación de sumas es diferida: se revisa cuando el gasto ya tiene pagadores y partes');
set constraints all deferred;
select throws_ok(
  $sql$do $do$ begin
    insert into public.parche_expenses (id, parche_id, concept, base_amount, amount, split_method, recorded_by)
      values ('e0000000-0000-0000-0000-000000000012', current_setting('t.cena')::uuid, 'Vino', 1000, 1000, 'equal',
              current_setting('t.jo2')::uuid);
    insert into public.parche_expense_payers values ('e0000000-0000-0000-0000-000000000012', current_setting('t.jo2')::uuid, 900);
    insert into public.parche_expense_shares values ('e0000000-0000-0000-0000-000000000012', current_setting('t.jo2')::uuid, 1000, 1);
    set constraints all immediate;
  end $do$$sql$,
  '23514', 'Los pagos no suman el total del gasto', 'La validación diferida rechaza sumas que no cuadran');
set constraints all deferred;
set local role authenticated;
select throws_ok(
  $$select public.save_parche_expense('e0000000-0000-0000-0000-000000000013', current_setting('t.cena')::uuid,
    'Hielo', 1000, 0, 1000, now(), 'equal', pg_temp.lines('a', '1000'), pg_temp.shares('jo2', '1000', '1'))$$,
  '23514', 'Alguien del gasto no está en el parche', 'Un pagador de otro parche no se acepta');
select public.close_parche(pg_temp.pid('cena'));
select throws_ok($$select public.move_parche_debt_to_cruce(current_setting('t.cena')::uuid,
    (select id from public.parche_participants where parche_id = current_setting('t.cena')::uuid
       and user_id = '11111111-1111-1111-1111-111111111111'))$$,
  'P0001', 'Para saldar no hay un pago entre ustedes', 'Si no se deben nada, no hay nada que pasar al cruce');

-- ─────────────────────────────────────────────────────────────
-- Actividad y avisos sin ver
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(
  (select string_agg(kind::text || ':' || n, ',' order by kind)
   from (select kind, count(*) as n from public.parche_activity where parche_id = pg_temp.pid('parche') group by kind) as k),
  'parcheCreated:1,expenseCreated:4,expenseEdited:1,expenseDeleted:1,paymentRecorded:4,paymentConfirmed:1,'
  || 'participantAdded:1,participantJoined:2,placeClaimed:1,parcheClosed:1',
  'Los triggers escriben la actividad del parche');
select ok(
  (select actor_id = pg_temp.pid('j') and participant_id = pg_temp.pid('c')
   from public.parche_activity where kind = 'participantAdded'),
  'El aviso de persona agregada dice quién la agregó');
reset role;
update public.parche_participants set last_seen_at = null where id = current_setting('t.j')::uuid;
set local role authenticated;
select public.mark_parche_seen(pg_temp.pid('parche'));
select is((select last_seen_at from public.parche_participants where id = pg_temp.pid('j')), now(),
  'mark_parche_seen guarda cuándo Jesús abrió el parche');
select is(
  (select count(*) from public.parche_activity a, public.parche_participants p
   where p.id = pg_temp.pid('j') and a.parche_id = p.parche_id and a.created_at > p.last_seen_at),
  0::bigint, 'Después de abrirlo no le quedan avisos sin ver');

-- ─────────────────────────────────────────────────────────────
-- Fuera del parche, sin sesión y escrituras directas
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('55555555-5555-5555-5555-555555555555');
select is(
  (select (select count(*) from public.parches) + (select count(*) from public.parche_participants)
        + (select count(*) from public.parche_expenses) + (select count(*) from public.parche_expense_payers)
        + (select count(*) from public.parche_expense_shares) + (select count(*) from public.parche_expense_items)
        + (select count(*) from public.parche_payments) + (select count(*) from public.parche_cruce_transfers)
        + (select count(*) from public.parche_activity)),
  0::bigint, 'Alguien de fuera no ve nada de ningún parche');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select throws_ok(
  $$insert into public.parche_expenses (parche_id, concept, base_amount, amount, split_method, recorded_by)
    values (current_setting('t.parche')::uuid, 'Directo', 1000, 1000, 'equal', current_setting('t.a')::uuid)$$,
  '42501', null, 'La app no inserta gastos directo en la tabla');
select throws_ok($$update public.parches set name = 'Otro' where id = current_setting('t.parche')::uuid$$,
  '42501', null, 'La app no edita parches directo en la tabla');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$select count(*) from public.parches$$, '42501', null, 'Sin sesión no se leen parches');
select throws_ok($$select count(*) from public.parche_activity$$, '42501', null, 'Sin sesión no se lee la actividad');
select throws_ok($$select public.create_parche('Sin sesión', 'Nadie')$$, '42501', null,
  'Sin sesión no se puede llamar a las funciones de parches');
reset role;

select * from finish();
rollback;
