-- Borrar la cuenta (S4): se borran el usuario de Auth, el nombre, el @usuario y el color; los cruces se cierran y la
-- otra persona conserva el historial con "Cuenta borrada"; en los parches el lugar y sus gastos quedan como
-- "Cuenta borrada" sin cambiar el saldo de nadie. El @usuario queda libre y el mismo correo es una cuenta nueva.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;
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
    'participant_id', current_setting('t.' || p[i]), 'amount', p[i + 1]::bigint, 'input', null) order by i),
    '[]'::jsonb)
  from generate_series(1, array_length(p, 1), 2) as i
$$;
-- "Joan:60000, Jesús:-30000, …" en el orden del parche (los nombres se leen después, así que se compara por id).
create function pg_temp.balances(p_parche uuid) returns text language sql as $$
  select string_agg(b.participant_id || ':' || b.net, ', ' order by b.position)
  from public.parche_balances(p_parche) as b
$$;

insert into auth.users (id, email) values
  ('16000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('16000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('16000000-0000-0000-0000-000000000003', 'ana@example.com'),
  ('16000000-0000-0000-0000-000000000004', 'pedro@example.com'),
  ('16000000-0000-0000-0000-000000000005', 'sinperfil@example.com');
insert into public.profiles (id, display_name) values
  ('16000000-0000-0000-0000-000000000001', 'Joan'),
  ('16000000-0000-0000-0000-000000000002', 'Jesús'),
  ('16000000-0000-0000-0000-000000000003', 'Ana'),
  ('16000000-0000-0000-0000-000000000004', 'Pedro');

-- ─────────────────────────────────────────────────────────────
-- Datos: el cruce de Joan y Jesús (ejemplo canónico), un cruce pendiente de Joan y dos parches que creó Joan
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
create temp table first_code as select public.create_ledger_with_invite() as code;
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select public.redeem_invite((select code from first_code));
select set_config('t.ledger', (select ledger_id::text from public.invites where code = (select code from first_code)), true);
insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
values
  (pg_temp.pid('ledger'), 'expense', '16000000-0000-0000-0000-000000000001', 60000, 'Cena', 'equal', 50,
   '16000000-0000-0000-0000-000000000001'),
  (pg_temp.pid('ledger'), 'expense', '16000000-0000-0000-0000-000000000002', 100000, 'Mercado', 'equal', 50,
   '16000000-0000-0000-0000-000000000002');
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
create temp table pending_code as select public.create_ledger_with_invite() as code;

-- Santa Marta: Joan pagó $90.000 entre Joan, Jesús y Carlos (sin la app). Se cierra y Jesús propone pasar su parte
-- al cruce: queda por confirmar.
select set_config('t.parche', public.create_parche('Santa Marta')::text, true);
select set_config('t.jo', (select id::text from public.parche_participants where parche_id = pg_temp.pid('parche')), true);
select set_config('t.c', (select id::text from public.add_parche_participant(pg_temp.pid('parche'), 'Carlos')), true);
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select public.join_parche((select code from public.parches where id = pg_temp.pid('parche')));
select set_config('t.j', (select id::text from public.parche_participants
  where parche_id = pg_temp.pid('parche') and user_id = '16000000-0000-0000-0000-000000000002'), true);
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
select public.save_parche_expense('16e00000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
  'Cena', 90000, 0, 90000, '2026-10-25 20:00:00+00', 'equal',
  pg_temp.lines('jo', '90000'), pg_temp.shares('jo', '30000', 'j', '30000', 'c', '30000'));
select public.close_parche(pg_temp.pid('parche'));
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select set_config('t.transfer',
  (select id::text from public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('jo'))), true);
-- Finca: Joan la creó y sigue abierta.
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
select set_config('t.finca', public.create_parche('Finca')::text, true);
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select public.join_parche((select code from public.parches where id = pg_temp.pid('finca')));
select pg_temp.as_user('16000000-0000-0000-0000-000000000004');
select public.join_parche((select code from public.parches where id = pg_temp.pid('finca')));
select set_config('t.pe', (select id::text from public.parche_participants
  where user_id = '16000000-0000-0000-0000-000000000004'), true);

create temp table before_balances as
  select (select array_agg(net order by user_id) from public.ledger_balances where ledger_id = pg_temp.pid('ledger'))
           as cruce,
         pg_temp.balances(pg_temp.pid('parche')) as parche;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
select ok(has_function_privilege('authenticated', 'public.delete_my_account()', 'execute')
  and not has_function_privilege('anon', 'public.delete_my_account()', 'execute'),
  'Solo con sesión se borra la cuenta');
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$select public.delete_my_account()$$, 'P0001', 'Necesitas iniciar sesión', 'Sin sesión no borra nada');

-- ─────────────────────────────────────────────────────────────
-- Joan borra su cuenta
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
select lives_ok($$select public.delete_my_account()$$, 'Joan borra su cuenta');

select is((select count(*) from auth.users where id = '16000000-0000-0000-0000-000000000001'), 0::bigint,
  'Su usuario de Auth (con el correo) ya no existe');
select results_eq(
  $$select display_name, username, avatar_color::text, deleted_at is not null from public.profiles
    where id = '16000000-0000-0000-0000-000000000001'$$,
  $$values ('Cuenta borrada'::text, null::text, null::text, true)$$,
  'Su perfil queda como "Cuenta borrada", sin @usuario ni color');

-- Cruces
select isnt((select closed_at from public.ledgers where id = pg_temp.pid('ledger')), null,
  'Su cruce con Jesús queda cerrado');
select is((select closed_by from public.ledgers where id = pg_temp.pid('ledger')),
  '16000000-0000-0000-0000-000000000001'::uuid, 'Lo cerró quien borró su cuenta');
select is((select count(*) from public.movements where ledger_id = pg_temp.pid('ledger')), 2::bigint,
  'El historial del cruce se conserva');
select is((select array_agg(net order by user_id) from public.ledger_balances where ledger_id = pg_temp.pid('ledger')),
  (select cruce from before_balances), 'El saldo del cruce no cambia');
select is((select count(*) from public.ledger_members where ledger_id = pg_temp.pid('ledger')), 2::bigint,
  'El cruce sigue siendo de dos');
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select results_eq(
  $$select partner_name, partner_username, partner_deleted, closed_at is not null, partner_color, partner_avatar
    from public.my_cruces()$$,
  $$values ('Cuenta borrada'::text, null::text, true, true, null::text, 'yellow'::text)$$,
  'Jesús ve su cruce cerrado con "Cuenta borrada" (y el color del rol para las versiones anteriores)');
select is((select count(*) from public.ledgers where created_by = '16000000-0000-0000-0000-000000000001'), 1::bigint,
  'Su cruce pendiente se borró');
select pg_temp.as_user('16000000-0000-0000-0000-000000000003');
select is(public.preview_invite((select code from pending_code)) ->> 'error', 'invalid',
  'Su código CRZ- pendiente ya no existe');

-- Parches
select results_eq(
  $$select display_name, user_id, account_deleted_at is not null, claim_code from public.parche_participants
    where id = current_setting('t.jo')::uuid$$,
  $$values ('Cuenta borrada'::text, null::uuid, true, null::text)$$,
  'Su lugar en el parche queda como "Cuenta borrada", sin cuenta y sin código SOY-');
select is(pg_temp.balances(pg_temp.pid('parche')), (select parche from before_balances),
  'Los saldos del parche no cambian');
select is((select count(*) from public.parche_expenses e
           join public.parche_expense_payers p on p.expense_id = e.id
           where e.parche_id = pg_temp.pid('parche') and p.participant_id = pg_temp.pid('jo') and e.deleted_at is null),
  1::bigint, 'Su gasto sigue pagado por su lugar');
select is((select status from public.parche_cruce_transfers where id = pg_temp.pid('transfer')), 'rejected',
  'La propuesta de pasar al cruce que lo incluía queda rechazada');
select is((select count(*) from public.parche_activity
           where parche_id = pg_temp.pid('parche') and kind = 'debtRejectedForCruce'), 1::bigint,
  'Y queda en la actividad del parche');
select is((select count(*) from public.parche_activity
           where parche_id = pg_temp.pid('parche') and kind = 'placeClaimed'), 0::bigint,
  'Soltar el lugar no deja un aviso de lugar reclamado');
select pg_temp.as_user('16000000-0000-0000-0000-000000000002');
select lives_ok($$select public.close_parche(pg_temp.pid('finca'))$$,
  'Jesús cierra Finca, que había creado la cuenta borrada');
select is((select status::text from public.parches where id = pg_temp.pid('finca')), 'closed', 'Finca queda cerrado');
select pg_temp.as_user('16000000-0000-0000-0000-000000000003');
select is(public.claim_parche_place('SOY-ZZZZZZ'), null::uuid, 'Su lugar no tiene código para reclamarlo');

-- ─────────────────────────────────────────────────────────────
-- El @usuario queda libre y el mismo correo es una cuenta nueva
-- ─────────────────────────────────────────────────────────────
select is(public.set_username('joan'), '{"ok": true, "username": "joan"}'::jsonb, 'Ana puede tomar "joan" de inmediato');

insert into auth.users (id, email) values ('16000000-0000-0000-0000-000000000011', 'joan@example.com');
insert into public.profiles (id, display_name) values ('16000000-0000-0000-0000-000000000011', 'Joan');
select pg_temp.as_user('16000000-0000-0000-0000-000000000011');
select is((select count(*) from public.my_cruces()), 0::bigint, 'Con el mismo correo es una cuenta nueva, sin cruces');
select is((select count(*) from public.parche_participants where user_id = '16000000-0000-0000-0000-000000000011'),
  0::bigint, 'Ni parches');
select is((select username from public.profiles where id = '16000000-0000-0000-0000-000000000011'), 'joan2',
  'Y recibe una sugerencia libre');

-- ─────────────────────────────────────────────────────────────
-- Lo que no se puede
-- ─────────────────────────────────────────────────────────────
select throws_ok(
  $$update public.parche_participants set user_id = null where id = current_setting('t.j')::uuid$$,
  'P0001', 'Ese lugar ya es de alguien', 'Nadie suelta el lugar de alguien que sigue teniendo su cuenta');
select throws_ok(
  $$update public.profiles set display_name = 'Joan otra vez' where id = '16000000-0000-0000-0000-000000000001'$$,
  'P0001', 'Esa cuenta se borró', 'Una cuenta borrada no se edita (aunque su sesión siga vigente un rato)');
select pg_temp.as_user('16000000-0000-0000-0000-000000000001');
select throws_ok($$select public.set_username('joan.vuelve')$$, 'P0001', 'Esa cuenta se borró',
  'Ni se le pone un @usuario');
select throws_ok($$insert into public.profiles (id, display_name) values ('16000000-0000-0000-0000-000000000001', 'Joan')$$,
  '23505', null, 'Ni se crea otra vez con el mismo id');

-- ─────────────────────────────────────────────────────────────
-- Borrar desde el panel, una cuenta sin perfil y borrar dos veces
-- ─────────────────────────────────────────────────────────────
select lives_ok($$delete from auth.users where id = '16000000-0000-0000-0000-000000000004'$$,
  'Borrar desde el panel a alguien que está en un parche ya no falla');
select results_eq(
  $$select p.display_name, p.deleted_at is not null, pp.display_name, pp.user_id
    from public.profiles p, public.parche_participants pp
    where p.id = '16000000-0000-0000-0000-000000000004' and pp.id = pg_temp.pid('pe')$$,
  $$values ('Cuenta borrada'::text, true, 'Cuenta borrada'::text, null::uuid)$$,
  'Y deja lo mismo que borrar la cuenta desde la app');
select pg_temp.as_user('16000000-0000-0000-0000-000000000005');
select lives_ok($$select public.delete_my_account()$$, 'Alguien que nunca creó su perfil también borra su cuenta');
select is((select count(*) from public.profiles where id = '16000000-0000-0000-0000-000000000005'), 0::bigint,
  'Y no le queda un perfil');

select * from finish();
rollback;
