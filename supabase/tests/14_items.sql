-- Ítems con nombre en el reparto por consumo (corrección 14): el nombre es opcional, de hasta 40 caracteres, y
-- save_parche_expense lo guarda sin cambiar su firma (una versión anterior que no manda "name" sigue funcionando).
-- Se actúa como el rol authenticated con request.jwt.claims, igual que una petición real de la app.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create function pg_temp.pid(p text) returns uuid language sql as $$
  select current_setting('t.' || p)::uuid
$$;
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
-- Guarda el almuerzo de $30.000 (sin propina) por consumo entre Joan y Jesús, con los ítems que se pasen.
create function pg_temp.lunch(p_items jsonb) returns uuid language sql as $$
  select public.save_parche_expense('e1400000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
    'Almuerzo', 30000, 0, 30000, '2026-10-29 13:00:00+00', 'items',
    jsonb_build_array(jsonb_build_object('participant_id', pg_temp.pid('jo'), 'amount', 30000)),
    jsonb_build_array(
      jsonb_build_object('participant_id', pg_temp.pid('jo'), 'amount', 20000, 'input', null),
      jsonb_build_object('participant_id', pg_temp.pid('je'), 'amount', 10000, 'input', null)),
    p_items)
$$;

-- ─────────────────────────────────────────────────────────────
-- Estructura
-- ─────────────────────────────────────────────────────────────
select has_column('public', 'parche_expense_items', 'name', 'parche_expense_items tiene el nombre del ítem');
select col_is_null('public', 'parche_expense_items', 'name', 'El nombre es opcional');

-- ─────────────────────────────────────────────────────────────
-- Datos: Joan crea "Almuerzo" y Jesús se une
-- ─────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('14000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('14000000-0000-0000-0000-000000000002', 'jesus@example.com');
select set_config('t.parche', 'a1400000-0000-0000-0000-000000000001', true);

set local role authenticated;
select pg_temp.as_user('14000000-0000-0000-0000-000000000001');
select public.create_parche('Almuerzo', 'Joan', pg_temp.pid('parche'));
select set_config('t.jo', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select set_config('t.code', (select code from public.parches where id = pg_temp.pid('parche')), true);
select pg_temp.as_user('14000000-0000-0000-0000-000000000002');
select public.join_parche(current_setting('t.code'), 'Jesús');
select set_config('t.je', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select pg_temp.as_user('14000000-0000-0000-0000-000000000001');

-- ─────────────────────────────────────────────────────────────
-- Guardar con nombres
-- ─────────────────────────────────────────────────────────────
select lives_ok($$select pg_temp.lunch(jsonb_build_array(
    jsonb_build_object('amount', 20000, 'participant_ids', jsonb_build_array(pg_temp.pid('jo')), 'name', ' Mojarra '),
    jsonb_build_object('amount', 10000, 'participant_ids', jsonb_build_array(pg_temp.pid('je')), 'name', '')))$$,
  'Joan guarda el almuerzo con un ítem con nombre y otro sin nombre');
select is(
  (select array_agg(name order by position) from public.parche_expense_items
    where expense_id = 'e1400000-0000-0000-0000-000000000001'),
  array['Mojarra', null]::text[], 'El nombre queda sin espacios y uno vacío queda sin nombre');
select is((select count(*) from public.parche_activity
           where expense_id = 'e1400000-0000-0000-0000-000000000001'), 1::bigint, 'Un solo aviso: lo anotó');

-- ─────────────────────────────────────────────────────────────
-- Reenviar lo mismo no cambia nada; cambiar solo un nombre es una edición
-- ─────────────────────────────────────────────────────────────
select lives_ok($$select pg_temp.lunch(jsonb_build_array(
    jsonb_build_object('amount', 20000, 'participant_ids', jsonb_build_array(pg_temp.pid('jo')), 'name', 'Mojarra'),
    jsonb_build_object('amount', 10000, 'participant_ids', jsonb_build_array(pg_temp.pid('je')))))$$,
  'Reenviar el mismo gasto (sin "name" en el segundo ítem) funciona');
select is((select count(*) from public.parche_activity
           where expense_id = 'e1400000-0000-0000-0000-000000000001'), 1::bigint,
  'Reenviar lo mismo no deja otro aviso');
select lives_ok($$select pg_temp.lunch(jsonb_build_array(
    jsonb_build_object('amount', 20000, 'participant_ids', jsonb_build_array(pg_temp.pid('jo')), 'name', 'Mojarra'),
    jsonb_build_object('amount', 10000, 'participant_ids', jsonb_build_array(pg_temp.pid('je')), 'name', 'Limonada')))$$,
  'Joan le pone nombre al segundo ítem');
select is(
  (select array_agg(name order by position) from public.parche_expense_items
    where expense_id = 'e1400000-0000-0000-0000-000000000001'),
  array['Mojarra', 'Limonada']::text[], 'Los dos ítems quedan con su nombre');
select is((select count(*) from public.parche_activity
           where expense_id = 'e1400000-0000-0000-0000-000000000001' and kind = 'expenseEdited'), 1::bigint,
  'Cambiar solo un nombre cuenta como edición');

-- ─────────────────────────────────────────────────────────────
-- Límite y versiones anteriores
-- ─────────────────────────────────────────────────────────────
select is(pg_temp.error_hint($$select pg_temp.lunch(jsonb_build_array(
    jsonb_build_object('amount', 20000, 'participant_ids', jsonb_build_array(pg_temp.pid('jo')),
      'name', repeat('a', 41)),
    jsonb_build_object('amount', 10000, 'participant_ids', jsonb_build_array(pg_temp.pid('je')))))$$),
  'invalidData', 'Un nombre de 41 caracteres da invalidData');
select lives_ok($$select pg_temp.lunch(jsonb_build_array(
    jsonb_build_object('amount', 20000, 'participant_ids', jsonb_build_array(pg_temp.pid('jo'))),
    jsonb_build_object('amount', 10000, 'participant_ids', jsonb_build_array(pg_temp.pid('je')))))$$,
  'Una versión anterior que no manda "name" sigue guardando');
select is(
  (select array_agg(name order by position) from public.parche_expense_items
    where expense_id = 'e1400000-0000-0000-0000-000000000001'),
  array[null, null]::text[], 'Sus ítems quedan sin nombre');

select * from finish();
rollback;
