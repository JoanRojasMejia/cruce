-- RLS endurecido: las políticas solo aplican a authenticated, evalúan auth.uid() una vez por consulta
-- y tienen índices en las columnas que filtran. Sin sesión (anon) no se ve ni se escribe nada.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

-- Cada política aplica solo a authenticated (no a public, que incluye anon).
select policy_roles_are('public', 'profiles', 'perfil propio o de mi pareja de cuenta', array['authenticated'],
  'La política de ver perfiles aplica solo a authenticated');
select policy_roles_are('public', 'profiles', 'crear mi perfil', array['authenticated'],
  'La política de crear perfil aplica solo a authenticated');
select policy_roles_are('public', 'profiles', 'editar mi perfil', array['authenticated'],
  'La política de editar perfil aplica solo a authenticated');
select policy_roles_are('public', 'ledgers', 'ver mis cuentas', array['authenticated'],
  'La política de ver cuentas aplica solo a authenticated');
select policy_roles_are('public', 'ledgers', 'editar mis cuentas', array['authenticated'],
  'La política de editar cuentas aplica solo a authenticated');
select policy_roles_are('public', 'ledger_members', 'ver miembros de mis cuentas', array['authenticated'],
  'La política de ver miembros aplica solo a authenticated');
select policy_roles_are('public', 'movements', 'ver movimientos de mis cuentas', array['authenticated'],
  'La política de ver movimientos aplica solo a authenticated');
select policy_roles_are('public', 'movements', 'crear movimientos en mis cuentas', array['authenticated'],
  'La política de crear movimientos aplica solo a authenticated');
select policy_roles_are('public', 'movements', 'editar movimientos de mis cuentas', array['authenticated'],
  'La política de editar movimientos aplica solo a authenticated');
select policy_roles_are('public', 'invites', 'ver mis invitaciones', array['authenticated'],
  'La política de ver invitaciones aplica solo a authenticated');

-- Postgres guarda (select auth.uid()) como "( SELECT auth.uid() AS uid)"; cualquier otro auth.uid() se evalúa fila por fila.
select is(
  (select count(*) from pg_policies
   where schemaname = 'public'
     and replace(coalesce(qual, '') || ' ' || coalesce(with_check, ''), '( SELECT auth.uid() AS uid)', '') like '%auth.uid()%'),
  0::bigint,
  'Ninguna política llama a auth.uid() fila por fila');

-- Índices en las columnas que filtran las políticas.
select has_index('public', 'ledger_members', 'ledger_members_user_id_idx', array['user_id'],
  'ledger_members tiene índice en user_id');
select has_index('public', 'invites', 'invites_created_by_idx', array['created_by'],
  'invites tiene índice en created_by');

-- Datos, creados como postgres (sin RLS), igual que en 04_rls.sql.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'joan@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'jesus@example.com');
insert into public.profiles (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'Joan'),
  ('22222222-2222-2222-2222-222222222222', 'Jesús');
insert into public.ledgers (id, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
insert into public.ledger_members (ledger_id, user_id, tike_variant, avatar_color) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'rosa', 'yellow'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'verde', 'violet');
insert into public.movements (id, ledger_id, payer_id, amount, concept, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 60000, 'Cena', '11111111-1111-1111-1111-111111111111');
insert into public.invites (code, ledger_id, created_by) values
  ('CRZ-1234', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

-- Sin sesión: rol anon, como una petición con la llave pública y sin usuario.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*) from public.ledgers), 0::bigint, 'Sin sesión no se ven cuentas');
select is((select count(*) from public.ledger_members), 0::bigint, 'Sin sesión no se ven miembros');
select is((select count(*) from public.movements), 0::bigint, 'Sin sesión no se ven movimientos');
select is((select count(*) from public.ledger_balances), 0::bigint, 'Sin sesión no se ven saldos');
select is((select count(*) from public.profiles), 0::bigint, 'Sin sesión no se ven perfiles');
select is((select count(*) from public.invites), 0::bigint, 'Sin sesión no se ven invitaciones');
select throws_ok(
  $$insert into public.movements (ledger_id, payer_id, amount, concept, created_by)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 1000, 'Sin sesión', '11111111-1111-1111-1111-111111111111')$$,
  '42501', null, 'Sin sesión no se pueden crear movimientos');

select * from finish();
rollback;
