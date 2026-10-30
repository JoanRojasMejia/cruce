-- Una cuenta borrada no vuelve a entrar a cruces: su sesión puede seguir viva hasta una hora (el JWT no se revoca),
-- pero la lápida del perfil no puede crear un cruce, canjear un código ni ser miembro de uno. Y el rechazo automático
-- de "pasar al cruce" al borrar la cuenta lleva el nombre de quien la borró ("Cuenta borrada"), no "Alguien".
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

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

insert into auth.users (id, email) values
  ('18000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('18000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('18000000-0000-0000-0000-000000000003', 'ana@example.com');
insert into public.profiles (id, display_name) values
  ('18000000-0000-0000-0000-000000000001', 'Joan'),
  ('18000000-0000-0000-0000-000000000002', 'Jesús'),
  ('18000000-0000-0000-0000-000000000003', 'Ana');

-- Joan y Jesús tienen un cruce; en el parche Finca, Joan pagó $60.000 a medias y Jesús propone pasar su deuda al cruce.
select pg_temp.as_user('18000000-0000-0000-0000-000000000001');
create temp table first_code as select public.create_ledger_with_invite() as code;
select pg_temp.as_user('18000000-0000-0000-0000-000000000002');
select public.redeem_invite((select code from first_code));
select pg_temp.as_user('18000000-0000-0000-0000-000000000001');
select set_config('t.parche', public.create_parche('Finca')::text, true);
select set_config('t.jo', (select id::text from public.parche_participants where parche_id = pg_temp.pid('parche')), true);
select pg_temp.as_user('18000000-0000-0000-0000-000000000002');
select public.join_parche((select code from public.parches where id = pg_temp.pid('parche')));
select set_config('t.j', (select id::text from public.parche_participants
  where parche_id = pg_temp.pid('parche') and user_id = '18000000-0000-0000-0000-000000000002'), true);
select pg_temp.as_user('18000000-0000-0000-0000-000000000001');
select public.save_parche_expense('18e00000-0000-0000-0000-000000000001', pg_temp.pid('parche'),
  'Almuerzo', 60000, 0, 60000, '2026-10-25 20:00:00+00', 'equal',
  pg_temp.lines('jo', '60000'), pg_temp.shares('jo', '30000', 'j', '30000'));
select public.close_parche(pg_temp.pid('parche'));
select pg_temp.as_user('18000000-0000-0000-0000-000000000002');
select public.propose_parche_debt_to_cruce(pg_temp.pid('parche'), pg_temp.pid('jo'));

-- Ana deja un código para invitar antes de que Joan borre su cuenta.
select pg_temp.as_user('18000000-0000-0000-0000-000000000003');
create temp table ana_code as select public.create_ledger_with_invite() as code;

-- Joan borra su cuenta, pero su sesión sigue viva.
select pg_temp.as_user('18000000-0000-0000-0000-000000000001');
select public.delete_my_account();

select is(
  (select actor_id from public.parche_activity
    where parche_id = pg_temp.pid('parche') and kind = 'debtRejectedForCruce'),
  pg_temp.pid('jo'),
  'El rechazo automático lo firma el lugar de quien borró su cuenta (se lee "Cuenta borrada", no "Alguien")');

create temp table before_hash as
  select md5(string_agg(l.id::text || coalesce(l.closed_at::text, ''), ',' order by l.id)) as ledgers,
         (select count(*) from public.ledger_members) as members,
         (select count(*) from public.invites where redeemed_at is null) as open_codes
  from public.ledgers l;

select throws_ok($$select public.create_ledger_with_invite()$$, 'P0001', 'Tu cuenta ya no existe',
  'Con la sesión de una cuenta borrada no se crea un cruce');
select throws_ok($$select public.redeem_invite((select code from ana_code))$$, 'P0001', 'Tu cuenta ya no existe',
  'Con la sesión de una cuenta borrada no se canjea un código');
select is(
  (select md5(string_agg(l.id::text || coalesce(l.closed_at::text, ''), ',' order by l.id)) from public.ledgers l)
    || (select count(*) from public.ledger_members) || (select count(*) from public.invites where redeemed_at is null),
  (select ledgers || members || open_codes from before_hash),
  'Los intentos rechazados no cambian cruces, miembros ni códigos');

-- La guarda también vale para quien escriba en ledger_members por otro camino.
reset role;
select throws_ok(
  $$insert into public.ledger_members (ledger_id, user_id, tike_variant)
    select ledger_id, '18000000-0000-0000-0000-000000000001', 'verde' from public.invites
    where code = (select code from ana_code)$$,
  'P0001', 'Tu cuenta ya no existe', 'Una cuenta borrada no puede ser miembro de un cruce');

-- Las cuentas vivas siguen igual: Jesús canjea el código de Ana.
select pg_temp.as_user('18000000-0000-0000-0000-000000000002');
select is((public.redeem_invite((select code from ana_code)) ->> 'ok')::boolean, true,
  'Una cuenta viva sigue canjeando códigos como antes');

select * from finish();
rollback;
