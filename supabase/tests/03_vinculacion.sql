-- Vinculación: crear la cuenta con un código y unirse con él.
-- Para actuar como una persona se fija request.jwt.claims, que es lo que lee auth.uid().
begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'tercero@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'cuarto@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'quinto@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús'),
  ('33333333-3333-3333-3333-333333333333', 'Tercero'),
  ('44444444-4444-4444-4444-444444444444', 'Cuarto'),
  ('55555555-5555-5555-5555-555555555555', 'Quinto');

-- Joan crea la cuenta.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
create temp table joan_invite as select public.create_ledger_with_invite() as code;

select matches((select code from joan_invite), '^CRZ-[0-9]{4}$', 'El código tiene el formato CRZ-####');
select is(
  (select tike_variant::text || '/' || avatar_color::text from public.ledger_members where user_id = '11111111-1111-1111-1111-111111111111'),
  'rosa/yellow', 'Quien crea la cuenta queda con recibo rosa y avatar amarillo');
select ok(
  (select expires_at between now() + interval '23 hours 59 minutes' and now() + interval '24 hours 1 minute'
   from public.invites where code = (select code from joan_invite)),
  'El código vence en 24 horas');
-- redeem_invite no lanza errores de código: devuelve {ok, error, message} para que el intento fallido quede registrado.
select is(public.redeem_invite((select code from joan_invite)) ->> 'error', 'own', 'Nadie puede usar su propio código');

-- Jesús se une.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.redeem_invite('CRZ-XXXX'),
  '{"ok": false, "error": "invalid", "message": "Ese código no existe. Revisa que esté bien escrito."}'::jsonb,
  'Un código inexistente se rechaza con su mensaje en español');
select is(
  (public.redeem_invite(' ' || lower((select code from joan_invite)) || ' ') ->> 'ledger_id')::uuid,
  (select ledger_id from public.ledger_members where user_id = '11111111-1111-1111-1111-111111111111'),
  'Jesús se une con el código, sin importar mayúsculas ni espacios');
select is(
  (select tike_variant::text || '/' || avatar_color::text from public.ledger_members where user_id = '22222222-2222-2222-2222-222222222222'),
  'verde/violet', 'Quien se une queda con recibo verde y avatar violeta');
select ok(
  (select redeemed_by = '22222222-2222-2222-2222-222222222222' and redeemed_at is not null
   from public.invites where code = (select code from joan_invite)),
  'El código queda marcado como usado por Jesús');

-- Un tercero intenta usar el mismo código.
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is(public.redeem_invite((select code from joan_invite)) ->> 'error', 'used', 'Un código usado se rechaza');

-- El tercero crea su cuenta; su código vence y el cuarto intenta usarlo.
create temp table tercero_invite as select public.create_ledger_with_invite() as code;
update public.invites set expires_at = now() - interval '1 minute' where code = (select code from tercero_invite);
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select is(public.redeem_invite((select code from tercero_invite)) ->> 'error', 'expired', 'Un código vencido se rechaza');

-- Un código nuevo no puede pisar una invitación ya canjeada.
-- Con la misma semilla, random() da el mismo número: así el primer código generado coincide con el de Joan.
select setseed(0.42);
create temp table forced as select 'CRZ-' || lpad((floor(random() * 10000))::int::text, 4, '0') as code;
update public.invites set code = (select code from forced) where code = (select code from joan_invite);
select setseed(0.42);
create temp table cuarto_invite as select public.create_ledger_with_invite() as code;
select ok(
  exists (select 1 from public.invites
          where code = (select code from forced) and redeemed_by = '22222222-2222-2222-2222-222222222222'),
  'Generar un código no borra una invitación ya canjeada');
select isnt((select code from cuarto_invite), (select code from forced), 'El código nuevo es distinto al ya canjeado');

-- Límite de intentos: con 5 fallidos en la última hora, ni siquiera un código válido sirve.
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
-- Cinco códigos que no existen (no son dígitos, así que nunca coinciden con uno real).
select public.redeem_invite('CRZ-X00' || n) from generate_series(1, 5) as n;
select is(public.redeem_invite((select code from cuarto_invite)) ->> 'error', 'too_many_attempts',
  'Después de 5 intentos fallidos en una hora, el código se rechaza aunque sea válido');
select is((select count(*) from public.ledger_members where user_id = '55555555-5555-5555-5555-555555555555'), 0::bigint,
  'Quien llegó al límite no queda en ninguna cuenta');
select is((select count(*) from public.invite_attempts where user_id = '55555555-5555-5555-5555-555555555555'), 5::bigint,
  'Los intentos fallidos quedan registrados; el bloqueado no suma');
update public.invite_attempts set attempted_at = now() - interval '61 minutes'
  where user_id = '55555555-5555-5555-5555-555555555555';
select ok((public.redeem_invite((select code from cuarto_invite)) ->> 'ok')::boolean,
  'Pasada una hora, la misma persona puede volver a intentar');
select is(public.redeem_invite(' ') ->> 'message', 'Ese código no existe. Revisa que esté bien escrito.',
  'El mensaje de error está en español');

-- Sin sesión.
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$select public.create_ledger_with_invite()$$,
  'P0001', 'Necesitas iniciar sesión', 'Sin sesión no se crea una cuenta');

set local role anon;
select throws_ok(
  $$select public.create_ledger_with_invite()$$,
  '42501', null, 'El rol anónimo no puede llamar a la función');
reset role;

select * from finish();
rollback;
