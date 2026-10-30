-- Intentos fallidos al unirse a un parche y al quedarse con un lugar (S5): join_parche y claim_parche_place cuentan
-- los códigos que no sirven en el mismo límite de 5 por hora que CRZ- y preview_parche_code.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;
create function pg_temp.attempts(p_user text) returns bigint language sql as $$
  select count(*) from public.invite_attempts where user_id = p_user::uuid
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

insert into auth.users (id, email) values
  ('17000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('17000000-0000-0000-0000-000000000002', 'adivina@example.com'),
  ('17000000-0000-0000-0000-000000000003', 'carlos@example.com'),
  ('17000000-0000-0000-0000-000000000004', 'mezcla@example.com'),
  ('17000000-0000-0000-0000-000000000005', 'crz@example.com');
insert into public.profiles (id, display_name) values
  ('17000000-0000-0000-0000-000000000001', 'Joan'),
  ('17000000-0000-0000-0000-000000000002', 'Adivina'),
  ('17000000-0000-0000-0000-000000000003', 'Carlos'),
  ('17000000-0000-0000-0000-000000000004', 'Mezcla'),
  ('17000000-0000-0000-0000-000000000005', 'Crz');

select pg_temp.as_user('17000000-0000-0000-0000-000000000001');
select set_config('t.parche', public.create_parche('Santa Marta')::text, true);
select set_config('t.pch', (select code from public.parches where id = current_setting('t.parche')::uuid), true);
create temp table carlos as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Carlos');
create temp table diego as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Diego');

-- ─────────────────────────────────────────────────────────────
-- Cada código que no sirve cuenta; uno válido no
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('17000000-0000-0000-0000-000000000002');
select is(public.join_parche('PCH-ZZZZZZ'), null::uuid, 'Unirse con un PCH- que no existe no une a nadie');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000002'), 1::bigint, 'Y cuenta como intento fallido');
select is(public.claim_parche_place('SOY-ZZZZZZ'), null::uuid, 'Quedarse con un SOY- que no existe no toma nada');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000002'), 2::bigint, 'Y también cuenta');

select pg_temp.as_user('17000000-0000-0000-0000-000000000003');
select is(public.claim_parche_place((select claim_code from carlos)), current_setting('t.parche')::uuid,
  'Carlos se queda con su lugar');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000003'), 0::bigint, 'Un código válido no cuenta');
select is(public.claim_parche_place((select claim_code from carlos)), null::uuid,
  'Su mismo SOY- otra vez (ya es suyo) no sirve');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000003'), 1::bigint, 'Y cuenta, como en la vista previa');
select is(public.join_parche(current_setting('t.pch')), current_setting('t.parche')::uuid,
  'Unirse al parche donde ya está devuelve el parche');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000003'), 1::bigint, 'Sin contar un intento');
select is(pg_temp.error_hint(format('select public.claim_parche_place(%L)', (select claim_code from diego))),
  'alreadyParticipant', 'Quedarse con otro lugar del mismo parche sigue lanzando alreadyParticipant');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000003'), 1::bigint, 'Sin contar un intento');

select pg_temp.as_user('17000000-0000-0000-0000-000000000002');
select is(public.claim_parche_place((select claim_code from carlos)), null::uuid,
  'El SOY- que ya usó Carlos no le sirve a otra persona');
select is(pg_temp.attempts('17000000-0000-0000-0000-000000000002'), 3::bigint, 'Y cuenta');

-- ─────────────────────────────────────────────────────────────
-- Con 5 intentos, ni un código válido
-- ─────────────────────────────────────────────────────────────
select public.join_parche('PCH-ZZZZZY');
select public.join_parche('PCH-ZZZZZX');
select is(pg_temp.error_hint(format('select public.join_parche(%L)', current_setting('t.pch'))), 'tooManyAttempts',
  'Con 5 intentos, unirse con un PCH- válido se rechaza por demasiados intentos');
select is((select count(*) from public.parche_participants where user_id = '17000000-0000-0000-0000-000000000002'),
  0::bigint, 'Y no lo une');
select is(pg_temp.error_hint(format('select public.claim_parche_place(%L)', (select claim_code from diego))),
  'tooManyAttempts', 'Quedarse con un lugar válido también se rechaza');
select is((select user_id from public.parche_participants where id = (select id from diego)), null::uuid,
  'Y el lugar sigue libre');
select throws_ok(format('select public.join_parche(%L)', current_setting('t.pch')), 'P0001',
  'Hiciste demasiados intentos. Espera una hora e intenta de nuevo.', 'Con el mensaje de siempre');

-- ─────────────────────────────────────────────────────────────
-- Se suman con CRZ- y la vista previa; el límite de CRZ- no cambia
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('17000000-0000-0000-0000-000000000004');
select public.redeem_invite('CRZ-0000'), public.redeem_invite('CRZ-0001'), public.redeem_invite('CRZ-0002'),
       public.preview_invite('CRZ-0003');
select is(public.claim_parche_place('SOY-ZZZZZZ'), null::uuid, 'Con 4 intentos de CRZ-, un SOY- que no existe');
select is(public.preview_parche_code(current_setting('t.pch')) ->> 'error', 'too_many_attempts',
  'Completa los 5: la vista previa del siguiente código dice demasiados intentos');

select pg_temp.as_user('17000000-0000-0000-0000-000000000005');
select public.redeem_invite('CRZ-0000'), public.redeem_invite('CRZ-0001'), public.redeem_invite('CRZ-0002'),
       public.redeem_invite('CRZ-0003'), public.redeem_invite('CRZ-0004');
select is(public.redeem_invite('CRZ-0005') ->> 'error', 'too_many_attempts', 'El límite de CRZ- sigue igual');

select * from finish();
rollback;
