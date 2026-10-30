-- Pasar al cruce (corrección 1): la oferta sale solo del plan "Para saldar", la otra persona la acepta o la rechaza
-- y aceptar crea el movimiento en el cruce y salda esa transferencia en el parche, en una sola operación.
-- Se actúa como el rol authenticated con request.jwt.claims, igual que una petición real de la app.
begin;
create extension if not exists pgtap with schema extensions;
select plan(52);

-- ─────────────────────────────────────────────────────────────
-- Ayudas
-- ─────────────────────────────────────────────────────────────
create function pg_temp.pid(p text) returns uuid language sql as $$
  select current_setting('t.' || p)::uuid
$$;
create function pg_temp.lines(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'participant_id', current_setting('t.' || p[i]), 'amount', p[i + 1]::bigint) order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 2) as i
$$;
create function pg_temp.shares(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'participant_id', current_setting('t.' || p[i]), 'amount', p[i + 1]::bigint,
    'input', nullif(p[i + 2], '')::int) order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 3) as i
$$;
create function pg_temp.items(variadic p text[]) returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'amount', p[i]::bigint,
    'participant_ids', (select jsonb_agg(current_setting('t.' || n)) from unnest(string_to_array(p[i + 1], ',')) as n))
    order by i), '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 2) as i
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
-- "Carlos→Jesús:125000, …" en el orden del plan (se lee como postgres: las funciones son internas).
create function pg_temp.plan_text() returns text language sql as $$
  select coalesce(string_agg(f.display_name || '→' || t.display_name || ':' || p.amount, ', ' order by p.ord), '')
  from public.parche_settlement_plan(current_setting('t.parche')::uuid) with ordinality as p(from_id, to_id, amount, ord)
  join public.parche_participants f on f.id = p.from_id
  join public.parche_participants t on t.id = p.to_id
$$;
-- "Joan:47000, Jesús:125000, …" en el orden del parche.
create function pg_temp.balances_text() returns text language sql as $$
  select string_agg(pp.display_name || ':' || b.net, ', ' order by b.position)
  from public.parche_balances(current_setting('t.parche')::uuid) as b
  join public.parche_participants pp on pp.id = b.participant_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Datos, creados como postgres (sin RLS)
-- ─────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('10000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('10000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('10000000-0000-0000-0000-000000000003', 'ana@example.com'),
  ('10000000-0000-0000-0000-000000000004', 'carlos@example.com');
insert into public.profiles (id, display_name) values
  ('10000000-0000-0000-0000-000000000001', 'Joan'),
  ('10000000-0000-0000-0000-000000000002', 'Jesús'),
  ('10000000-0000-0000-0000-000000000003', 'Ana'),
  ('10000000-0000-0000-0000-000000000004', 'Carlos');
-- Cruces abiertos: Joan y Jesús, Jesús y Carlos, Joan y Carlos.
insert into public.ledgers (id, created_by) values
  ('d1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001'),
  ('d1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002'),
  ('d1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('d1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'rosa', 'yellow'),
  ('d1000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'verde', 'violet'),
  ('d1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'rosa', 'yellow'),
  ('d1000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000004', 'verde', 'violet'),
  ('d1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'rosa', 'yellow'),
  ('d1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004', 'verde', 'violet');

select set_config('t.parche', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('t.c', 'c1000000-0000-0000-0000-000000000004', true);

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
select ok(
  has_function_privilege('authenticated', 'public.propose_parche_debt_to_cruce(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.accept_parche_cruce_transfer(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.reject_parche_cruce_transfer(uuid)', 'execute'),
  'La app (authenticated) puede proponer, aceptar y rechazar');
select ok(
  not has_function_privilege('anon', 'public.propose_parche_debt_to_cruce(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.accept_parche_cruce_transfer(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.reject_parche_cruce_transfer(uuid)', 'execute'),
  'Sin sesión (anon) no se puede proponer, aceptar ni rechazar');
select ok(
  not has_function_privilege('authenticated', 'public.parche_settlement_plan(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.parche_balances(uuid)', 'execute'),
  'El plan y los saldos del parche son ayudas internas: la app no los llama');

-- ─────────────────────────────────────────────────────────────
-- Santa Marta, igual que MockParches: Joan, Jesús, Ana y Carlos (sin la app)
-- ─────────────────────────────────────────────────────────────
set local role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select public.create_parche('Santa Marta', 'Joan', pg_temp.pid('parche'));
select set_config('t.jo', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select set_config('t.code', (select code from public.parches where id = pg_temp.pid('parche')), true);
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select public.join_parche(current_setting('t.code'), 'Jesús');
select set_config('t.j', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select pg_temp.as_user('10000000-0000-0000-0000-000000000003');
select public.join_parche(current_setting('t.code'), 'Ana');
select set_config('t.a', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select public.add_parche_participant(pg_temp.pid('parche'), 'Carlos', pg_temp.pid('c'));
select set_config('t.soy', (select claim_code from public.parche_participants where id = pg_temp.pid('c')), true);
-- En una sola transacción todos entran con el mismo now(): se ordenan como en MockParches (Joan, Jesús, Ana, Carlos).
reset role;
alter table public.parche_participants disable trigger parche_participants_before_update;
update public.parche_participants set joined_at = now() - make_interval(hours => 72 - n)
  from (values (pg_temp.pid('jo'), 0), (pg_temp.pid('j'), 1), (pg_temp.pid('a'), 2), (pg_temp.pid('c'), 3)) as o(id, n)
  where parche_participants.id = o.id;
alter table public.parche_participants enable trigger parche_participants_before_update;
set local role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');

-- Almuerzo en Taganga: por consumo con 10 % de propina, pagado por Ana.
select public.save_parche_expense('e1000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
  'Almuerzo en Taganga', 200000, 10, 220000, '2026-10-25 13:00:00+00', 'items',
  pg_temp.lines('a', '220000'),
  pg_temp.shares('jo', '33000', '', 'j', '110000', '', 'a', '55000', '', 'c', '22000', ''),
  pg_temp.items('30000', 'jo', '100000', 'j', '50000', 'a', '20000', 'c'));
-- Hospedaje: $600.000 por partes iguales entre los 4; Jesús puso $400.000 y Joan $200.000.
select public.save_parche_expense('e1000000-0000-0000-0000-000000000002', pg_temp.pid('parche'),
  'Hospedaje', 600000, 0, 600000, '2026-10-23 20:00:00+00', 'shares',
  pg_temp.lines('j', '400000', 'jo', '200000'),
  pg_temp.shares('jo', '150000', '1', 'j', '150000', '1', 'a', '150000', '1', 'c', '150000', '1'));
-- Taxi al aeropuerto entre Joan, Jesús y Ana, pagado por Joan.
select public.save_parche_expense('e1000000-0000-0000-0000-000000000003', pg_temp.pid('parche'),
  'Taxi al aeropuerto', 45000, 0, 45000, '2026-10-26 09:00:00+00', 'equal',
  pg_temp.lines('jo', '45000'),
  pg_temp.shares('jo', '15000', '1', 'j', '15000', '1', 'a', '15000', '1'));
-- Ana anota que Carlos le pagó $50.000 a Joan: queda pendiente y no cuenta.
select pg_temp.as_user('10000000-0000-0000-0000-000000000003');
select public.record_parche_payment('b1000000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
  pg_temp.pid('c'), pg_temp.pid('jo'), 50000);

reset role;
select is(pg_temp.balances_text(), 'Joan:47000, Jesús:125000, Ana:0, Carlos:-172000',
  'Saldos de Santa Marta: +47.000 / +125.000 / 0 / −172.000 (el pago pendiente no cuenta)');
select is(pg_temp.plan_text(), 'Carlos→Jesús:125000, Carlos→Joan:47000',
  'Para saldar: Carlos le paga $125.000 a Jesús y $47.000 a Joan (igual que ParcheCalculator.minimumTransfers)');
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('jo'), pg_temp.pid('j')), 35000::bigint,
  'Joan le debe directamente $35.000 a Jesús (lo que antes se ofrecía por error)');
set local role authenticated;

-- ─────────────────────────────────────────────────────────────
-- Con el plan, entre Joan y Jesús no hay nada que pasar
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select throws_ok($$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$,
  'P0001', 'El parche sigue abierto', 'Solo se propone con el parche cerrado');
select public.close_parche(pg_temp.pid('parche'));
select throws_ok($$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$,
  'P0001', 'Para saldar no hay un pago entre ustedes',
  'Joan no le puede proponer nada a Jesús: en Para saldar no hay un pago entre ellos');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$),
  'nothingToMove', 'El error trae la pista nothingToMove');
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.jo')::uuid)$$),
  'nothingToMove', 'Jesús tampoco le puede proponer nada a Joan');
select is(pg_temp.error_hint(
  $$select public.move_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.jo')::uuid)$$),
  'nothingToMove', 'La función vieja (apps anteriores) sigue la misma regla');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.c')::uuid)$$),
  'notAllowed', 'Con alguien sin la app no se propone');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.a')::uuid)$$),
  'noSharedCruce', 'Sin un cruce juntos no se propone');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$),
  'notAllowed', 'Nadie se propone una deuda a sí mismo');
select is((select count(*) from public.parche_cruce_transfers where parche_id = pg_temp.pid('parche')), 0::bigint,
  'No quedó ninguna propuesta');
select is((select count(*) from public.movements where ledger_id = 'd1000000-0000-0000-0000-000000000001'), 0::bigint,
  'El cruce de Joan y Jesús no tiene movimientos');

-- Carlos se queda con su lugar: ahora sí tiene la app y comparte cruce con Jesús y con Joan.
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select public.claim_parche_place(current_setting('t.soy'));

-- ─────────────────────────────────────────────────────────────
-- Proponer y aceptar: Carlos → Jesús $125.000
-- ─────────────────────────────────────────────────────────────
select set_config('t.cj', (select id::text
  from public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('j'))), true);
select ok(
  (select status = 'pending' and from_id = pg_temp.pid('c') and to_id = pg_temp.pid('j') and amount = 125000
     and proposed_by = pg_temp.pid('c') and movement_id is null and responded_at is null
   from public.parche_cruce_transfers where id = pg_temp.pid('cj')),
  'Carlos propone pasar a su cruce los $125.000 que le debe a Jesús: queda por confirmar');
select is((select count(*) from public.movements where ledger_id = 'd1000000-0000-0000-0000-000000000002'), 0::bigint,
  'Mientras no la acepten, el cruce no tiene movimiento');
select is((select id from public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('j'))),
  pg_temp.pid('cj'), 'Proponer otra vez devuelve la misma propuesta');
select is((select count(*) from public.parche_cruce_transfers where parche_id = pg_temp.pid('parche')), 1::bigint,
  'Proponer otra vez no crea otra');
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select is((select status from public.parche_cruce_transfers where id = pg_temp.pid('cj')), 'pending',
  'Jesús también la ve por confirmar');
reset role;
select is(pg_temp.balances_text(), 'Joan:47000, Jesús:125000, Ana:0, Carlos:-172000',
  'Una propuesta por confirmar no cambia los saldos del parche');
select is(public.parche_direct_debt(pg_temp.pid('parche'), pg_temp.pid('c'), pg_temp.pid('j')), 100000::bigint,
  'Ni la deuda directa (Carlos le debe directamente $100.000 a Jesús)');
set local role authenticated;

select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select throws_ok($$select public.accept_parche_cruce_transfer(current_setting('t.cj')::uuid)$$,
  'P0001', 'Solo la otra persona puede responder', 'Quien propuso no la acepta');
select pg_temp.as_user('10000000-0000-0000-0000-000000000003');
select is(pg_temp.error_hint($$select public.accept_parche_cruce_transfer(current_setting('t.cj')::uuid)$$),
  'notAllowed', 'Ana, que no es parte, no la acepta');
select is(pg_temp.error_hint($$select public.reject_parche_cruce_transfer(current_setting('t.cj')::uuid)$$),
  'notAllowed', 'Ni la rechaza');

select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select ok(
  (select status = 'accepted' and movement_id is not null and responded_at is not null
   from public.accept_parche_cruce_transfer(pg_temp.pid('cj'))),
  'Jesús acepta: la propuesta queda aceptada, con su movimiento');
select ok(
  (select m.kind = 'expense' and m.split_type = 'full_other' and m.amount = 125000 and m.owed_by_other = 125000
     and m.payer_id = '10000000-0000-0000-0000-000000000002' and m.concept = 'Parche Santa Marta'
     and m.created_by = '10000000-0000-0000-0000-000000000002'
     and m.ledger_id = 'd1000000-0000-0000-0000-000000000002'
   from public.movements m join public.parche_cruce_transfers t on t.movement_id = m.id
   where t.id = pg_temp.pid('cj')),
  'El cruce de Jesús y Carlos tiene un gasto de $125.000 "Parche Santa Marta" pagado por Jesús y todo para Carlos');
select is((select net from public.ledger_balances
           where ledger_id = 'd1000000-0000-0000-0000-000000000002' and user_id = '10000000-0000-0000-0000-000000000002'),
  125000::bigint, 'En su cruce, Carlos le debe $125.000 a Jesús');
select is((select id from public.accept_parche_cruce_transfer(pg_temp.pid('cj'))), pg_temp.pid('cj'),
  'Aceptar otra vez no hace nada');
select is((select count(*) from public.movements where ledger_id = 'd1000000-0000-0000-0000-000000000002'), 1::bigint,
  'Aceptar otra vez no crea otro movimiento');
select is(pg_temp.error_hint($$select public.reject_parche_cruce_transfer(current_setting('t.cj')::uuid)$$),
  'alreadyMoved', 'Una aceptada ya no se rechaza');
reset role;
select is(pg_temp.balances_text(), 'Joan:47000, Jesús:0, Ana:0, Carlos:-47000',
  'En el parche, la transferencia aceptada cuenta como un pago de Carlos a Jesús');
select is(pg_temp.plan_text(), 'Carlos→Joan:47000', 'Para saldar ya no tiene el pago de Carlos a Jesús');
set local role authenticated;
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.j')::uuid)$$),
  'alreadyMoved', 'La deuda de un par pasa al cruce una sola vez');

-- ─────────────────────────────────────────────────────────────
-- Proponer y rechazar: Carlos → Joan $47.000 (con la función vieja)
-- ─────────────────────────────────────────────────────────────
select set_config('t.cjo', (select id::text
  from public.move_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('jo'))), true);
select ok(
  (select status = 'pending' and movement_id is null and amount = 47000 and proposed_by = pg_temp.pid('c')
   from public.parche_cruce_transfers where id = pg_temp.pid('cjo')),
  'La función vieja ya no pasa la deuda de una vez: la deja por confirmar');
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select is(pg_temp.error_hint($$select public.reject_parche_cruce_transfer(current_setting('t.cjo')::uuid)$$),
  'notAllowed', 'Jesús, que no es parte, no la rechaza');
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select is(pg_temp.error_hint($$select public.reject_parche_cruce_transfer(current_setting('t.cjo')::uuid)$$),
  'notAllowed', 'Quien propuso no la rechaza');
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select ok(
  (select status = 'rejected' and responded_at is not null and movement_id is null
   from public.reject_parche_cruce_transfer(pg_temp.pid('cjo'))),
  'Joan la rechaza');
select is((select count(*) from public.movements where ledger_id = 'd1000000-0000-0000-0000-000000000003'), 0::bigint,
  'Rechazada, el cruce de Joan y Carlos no tiene movimiento');
select is(pg_temp.error_hint($$select public.accept_parche_cruce_transfer(current_setting('t.cjo')::uuid)$$),
  'notAllowed', 'Una rechazada ya no se acepta');
reset role;
select is(pg_temp.balances_text(), 'Joan:47000, Jesús:0, Ana:0, Carlos:-47000',
  'Rechazada, la deuda sigue en el parche');
select is(pg_temp.plan_text(), 'Carlos→Joan:47000', 'Y sigue en Para saldar');
set local role authenticated;
select is(
  (select string_agg(kind::text || ':' || n, ',' order by kind::text)
   from (select kind, count(*) as n from public.parche_activity
         where parche_id = pg_temp.pid('parche') and kind::text like 'debt%' group by kind) as k),
  'debtMovedToCruce:1,debtProposedToCruce:2,debtRejectedForCruce:1',
  'Proponer, aceptar y rechazar quedan en la actividad');
select ok(
  (select actor_id = pg_temp.pid('jo') and participant_id = pg_temp.pid('c') and other_participant_id = pg_temp.pid('jo')
     and amount = 47000
   from public.parche_activity where parche_id = pg_temp.pid('parche') and kind = 'debtRejectedForCruce'),
  'El aviso de rechazo dice quién rechazó, quién debía y a quién');

-- Después de un rechazo se puede volver a proponer (ahora lo propone Joan).
select set_config('t.cjo2', (select id::text
  from public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('c'))), true);
select ok(
  (select status = 'pending' and from_id = pg_temp.pid('c') and to_id = pg_temp.pid('jo') and amount = 47000
     and proposed_by = pg_temp.pid('jo')
   from public.parche_cruce_transfers where id = pg_temp.pid('cjo2')),
  'Después de un rechazo, el par puede volver a proponerlo');

-- Si las cuentas del parche cambian antes de aceptar, no se acepta un monto viejo.
select public.record_parche_payment('b1000000-0000-0000-0000-000000000002', pg_temp.pid('parche'),
  pg_temp.pid('c'), pg_temp.pid('jo'), 10000);
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select throws_ok($$select public.accept_parche_cruce_transfer(current_setting('t.cjo2')::uuid)$$,
  'P0001', 'Las cuentas del parche cambiaron: rechaza la propuesta y vuelvan a proponerla',
  'Con el plan cambiado, la propuesta vieja no se acepta');
select public.reject_parche_cruce_transfer(pg_temp.pid('cjo2'));
select set_config('t.cjo3', (select id::text
  from public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('jo'))), true);
select is((select amount from public.parche_cruce_transfers where id = pg_temp.pid('cjo3')), 37000::bigint,
  'La nueva propuesta toma el monto del plan de ahora');

-- Con el cruce cerrado (desvincular), ni se acepta ni se propone.
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select public.close_cruce('d1000000-0000-0000-0000-000000000003');
select is(pg_temp.error_hint($$select public.accept_parche_cruce_transfer(current_setting('t.cjo3')::uuid)$$),
  'noSharedCruce', 'Con el cruce cerrado no se acepta');
select is((select status from public.parche_cruce_transfers where id = pg_temp.pid('cjo3')), 'pending',
  'Y la propuesta sigue por confirmar');
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select is(pg_temp.error_hint(
  $$select public.propose_parche_debt_to_cruce(current_setting('t.parche')::uuid, current_setting('t.jo')::uuid)$$),
  'noSharedCruce', 'Con el cruce cerrado tampoco se propone');
reset role;
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values ('d1000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 37000, 'Parche Santa Marta',
            'full_other', 100, '10000000-0000-0000-0000-000000000001')$$,
  '23514', 'Este cruce está cerrado', 'Y la base no deja anotar el movimiento en un cruce cerrado');

select * from finish();
rollback;
