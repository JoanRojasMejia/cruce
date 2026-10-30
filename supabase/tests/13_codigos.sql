-- Una sola pantalla de código (corrección 10, D2): errores separados para un código que no existe, que venció, que ya
-- se usó o que es tuyo, en CRZ-, PCH- y SOY-; vista previa de PCH- y SOY- sin entrar, con el mismo límite de intentos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

create function pg_temp.as_user(p_user text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || p_user || '","role":"authenticated"}', true);
$$;
create function pg_temp.attempts(p_user text) returns bigint language sql as $$
  select count(*) from public.invite_attempts where user_id = p_user::uuid
$$;

insert into auth.users (id, email) values
  ('30000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('30000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('30000000-0000-0000-0000-000000000003', 'ana@example.com'),
  ('30000000-0000-0000-0000-000000000004', 'pedro@example.com'),
  ('30000000-0000-0000-0000-000000000005', 'curioso@example.com');
insert into public.profiles (id, display_name) values
  ('30000000-0000-0000-0000-000000000001', 'Joan'),
  ('30000000-0000-0000-0000-000000000002', 'Jesús'),
  ('30000000-0000-0000-0000-000000000003', 'Ana'),
  ('30000000-0000-0000-0000-000000000004', 'Pedro'),
  ('30000000-0000-0000-0000-000000000005', 'Curioso');

-- ─────────────────────────────────────────────────────────────
-- CRZ-: no existe, tuyo, ya usado y vencido
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('30000000-0000-0000-0000-000000000001');
create temp table joan_code as select public.create_ledger_with_invite() as code;
select is(public.preview_invite((select code from joan_code)),
  '{"ok": false, "error": "own", "message": "Ese código es tuyo. Mándaselo a la otra persona para que lo use."}'::jsonb,
  'Tu propio código CRZ- dice que es tuyo');

select pg_temp.as_user('30000000-0000-0000-0000-000000000002');
select is(public.preview_invite('CRZ-XXXX'),
  '{"ok": false, "error": "invalid", "message": "Ese código no existe. Revisa que esté bien escrito."}'::jsonb,
  'Un CRZ- que no existe dice que no existe');
select is(public.redeem_invite('CRZ-XXXX') ->> 'error', 'invalid', 'Canjear un CRZ- que no existe da el mismo error');
select ok((public.redeem_invite((select code from joan_code)) ->> 'ok')::boolean, 'Jesús se une con el código de Joan');

select pg_temp.as_user('30000000-0000-0000-0000-000000000003');
select is(public.preview_invite((select code from joan_code)),
  '{"ok": false, "error": "used", "message": "Ese código ya se usó. Pídele uno nuevo a quien te lo mandó."}'::jsonb,
  'Un CRZ- que ya se usó lo dice');
select is(public.redeem_invite((select code from joan_code)) ->> 'error', 'used', 'Canjear un CRZ- usado da "used"');

select pg_temp.as_user('30000000-0000-0000-0000-000000000004');
create temp table pedro_code as select public.create_ledger_with_invite() as code;
update public.invites set expires_at = now() - interval '1 minute' where code = (select code from pedro_code);
select pg_temp.as_user('30000000-0000-0000-0000-000000000003');
select is(public.preview_invite((select code from pedro_code)),
  '{"ok": false, "error": "expired", "message": "Ese código ya venció. Pídele uno nuevo a quien te lo mandó."}'::jsonb,
  'Un CRZ- vencido dice que venció');
select is(public.redeem_invite((select code from pedro_code)) ->> 'error', 'expired', 'Canjear un CRZ- vencido da "expired"');
select is(pg_temp.attempts('30000000-0000-0000-0000-000000000003'), 4::bigint,
  'Usado y vencido siguen contando como intentos fallidos');

-- Un código propio vencido sigue siendo tuyo.
select pg_temp.as_user('30000000-0000-0000-0000-000000000004');
select is(public.preview_invite((select code from pedro_code)) ->> 'error', 'own',
  'Tu propio código dice que es tuyo aunque haya vencido');

-- ─────────────────────────────────────────────────────────────
-- PCH-: vista previa
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('30000000-0000-0000-0000-000000000001');
select set_config('t.parche', public.create_parche('Santa Marta')::text, true);
select set_config('t.pch', (select code from public.parches where id = current_setting('t.parche')::uuid), true);
create temp table carlos as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Carlos');
create temp table diego as
  select * from public.add_parche_participant(current_setting('t.parche')::uuid, 'Diego');

select is(public.preview_parche_code(current_setting('t.pch')),
  jsonb_build_object('ok', true, 'kind', 'parche', 'parche_name', 'Santa Marta', 'already_member', true),
  'Quien ya está en el parche ve su nombre y que ya está');

select pg_temp.as_user('30000000-0000-0000-0000-000000000002');
select is(public.preview_parche_code(' ' || lower(current_setting('t.pch')) || ' '),
  jsonb_build_object('ok', true, 'kind', 'parche', 'parche_name', 'Santa Marta', 'already_member', false),
  'El PCH- dice a qué parche lleva, sin importar mayúsculas ni espacios');
select is((select count(*) from public.parche_participants
           where parche_id = current_setting('t.parche')::uuid and user_id = '30000000-0000-0000-0000-000000000002'),
  0::bigint, 'Ver el código no une a nadie');
select is(public.preview_parche_code('PCH-ZZZZZZ'),
  '{"ok": false, "error": "invalid", "message": "Ese código no existe. Revisa que esté bien escrito."}'::jsonb,
  'Un PCH- que no existe dice que no existe');
select is(public.preview_parche_code('HOLA') ->> 'error', 'invalid', 'Algo que no es PCH- ni SOY- tampoco existe');
select is(pg_temp.attempts('30000000-0000-0000-0000-000000000002'), 4::bigint,
  'Los PCH- que no existen cuentan como intentos fallidos (con el CRZ- de antes)');

-- ─────────────────────────────────────────────────────────────
-- SOY-: vista previa, ya usado y tuyo
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('30000000-0000-0000-0000-000000000003');
select is(public.preview_parche_code((select claim_code from carlos)),
  jsonb_build_object('ok', true, 'kind', 'place', 'parche_name', 'Santa Marta', 'person_name', 'Carlos'),
  'El SOY- dice de quién es el lugar y en qué parche');
select is(public.claim_parche_place((select claim_code from carlos)), current_setting('t.parche')::uuid,
  'Ana se queda con el lugar de Carlos');
select ok(
  (select claim_code is null and claimed_code = (select claim_code from carlos)
   from public.parche_participants where id = (select id from carlos)),
  'El código deja de servir para entrar, pero queda guardado como usado');
select is(public.preview_parche_code((select claim_code from diego)),
  jsonb_build_object('ok', false, 'error', 'already_participant',
    'message', 'Ya estás en Santa Marta, así que no puedes quedarte con ese lugar.'),
  'Quien ya está en el parche no se queda con otro lugar');
select is(public.preview_parche_code((select claim_code from carlos)),
  '{"ok": false, "error": "own", "message": "Ese lugar ya es tuyo."}'::jsonb,
  'Quien se quedó con el lugar ve que ya es suyo');
select is(pg_temp.attempts('30000000-0000-0000-0000-000000000003'), 5::bigint,
  '"Ya es tuyo" cuenta como intento fallido; "ya estás en el parche" no');

select pg_temp.as_user('30000000-0000-0000-0000-000000000004');
select is(public.preview_parche_code((select claim_code from carlos)),
  '{"ok": false, "error": "used", "message": "Ese código ya se usó. Pídele uno nuevo a quien te lo mandó."}'::jsonb,
  'Un SOY- que ya se usó lo dice, en vez de "no existe"');
select throws_ok(format('select public.claim_parche_place(%L)', (select claim_code from carlos)),
  'P0001', 'Ese código no existe', 'Quedarse con un lugar ya tomado sigue sin servir');
select is(public.preview_parche_code('SOY-ZZZZZZ') ->> 'error', 'invalid', 'Un SOY- que no existe dice que no existe');

-- Un código nuevo nunca repite uno usado.
select ok(position(
  'claimed_code = v_code' in pg_get_functiondef('public.generate_parche_code(text)'::regprocedure)) > 0,
  'Generar un código revisa también los SOY- ya usados');

-- ─────────────────────────────────────────────────────────────
-- Límite de intentos: CRZ-, PCH- y SOY- cuentan juntos
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('30000000-0000-0000-0000-000000000005');
select public.preview_parche_code('PCH-ZZZZZ' || n) from unnest(array['A', 'B', 'C']) as n;
select public.preview_invite('CRZ-X00' || n) from generate_series(1, 2) as n;
select is(public.preview_parche_code(current_setting('t.pch')) ->> 'error', 'too_many_attempts',
  'Con 5 intentos fallidos en una hora, ni un PCH- válido se ve');
select is(public.preview_invite('CRZ-0000') ->> 'error', 'too_many_attempts', 'Ni un CRZ-');
select is(pg_temp.attempts('30000000-0000-0000-0000-000000000005'), 5::bigint, 'El bloqueado no suma intentos');
update public.invite_attempts set attempted_at = now() - interval '61 minutes'
  where user_id = '30000000-0000-0000-0000-000000000005';
select ok((public.preview_parche_code(current_setting('t.pch')) ->> 'ok')::boolean,
  'Pasada una hora, se puede volver a intentar');

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$select public.preview_parche_code('PCH-ZZZZZZ')$$,
  'P0001', 'Necesitas iniciar sesión', 'Sin sesión no hay vista previa');
select ok(
  has_function_privilege('authenticated', 'public.preview_parche_code(text)', 'execute')
  and not has_function_privilege('anon', 'public.preview_parche_code(text)', 'execute'),
  'La vista previa es solo para quien entró');
select ok(
  not has_function_privilege('authenticated', 'public.code_error(text)', 'execute')
  and not has_function_privilege('authenticated', 'public.code_attempts_exhausted()', 'execute'),
  'Las ayudas de los códigos son internas');

select * from finish();
rollback;
