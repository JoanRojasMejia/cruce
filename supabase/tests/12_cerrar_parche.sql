-- Quién cierra un parche (corrección 6, D1): solo quien lo creó. Los demás reciben notAllowed con su nombre.
-- Si quien lo creó ya no tiene la app, lo cierra cualquiera del parche con la app. Cerrar queda en la actividad.
-- Se actúa como el rol authenticated con request.jwt.claims, igual que una petición real de la app.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

-- ─────────────────────────────────────────────────────────────
-- Ayudas
-- ─────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────
-- Estructura
-- ─────────────────────────────────────────────────────────────
select has_column('public', 'parches', 'created_by', 'parches guarda quién lo creó');
-- Una sola relación entre parches y parche_participants (parche_participants.parche_id). Con otra, PostgREST no sabe
-- cuál usar para `parches?select=…,parche_participants(*)` y responde PGRST201 (parches_sin_ambiguedad.sql).
select is(
  (select count(*) from pg_constraint
    where contype = 'f'
      and ((conrelid = 'public.parches'::regclass and confrelid = 'public.parche_participants'::regclass)
        or (conrelid = 'public.parche_participants'::regclass and confrelid = 'public.parches'::regclass))),
  1::bigint, 'Una sola llave foránea une parches y parche_participants');
select is(
  (select count(*) from public.parches p
    where p.created_by is distinct from coalesce(
      (select a.actor_id from public.parche_activity a
        where a.parche_id = p.id and a.kind = 'parcheCreated' and a.actor_id is not null
        order by a.created_at, a.id limit 1),
      (select pp.id from public.parche_participants pp where pp.parche_id = p.id order by pp.joined_at, pp.id limit 1))),
  0::bigint, 'Todos los parches que ya había tienen created_by: quien hizo el aviso parcheCreated');

-- ─────────────────────────────────────────────────────────────
-- Datos: Joan crea "Santa Marta", Jesús y Ana se unen y Joan agrega a Carlos sin la app
-- ─────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('12000000-0000-0000-0000-000000000001', 'joan@example.com'),
  ('12000000-0000-0000-0000-000000000002', 'jesus@example.com'),
  ('12000000-0000-0000-0000-000000000003', 'ana@example.com'),
  -- Existe en Auth pero no es del parche (una sesión sin cuenta recibe accountDeleted, ver 18_cuenta_borrada_sin_sesion).
  ('12000000-0000-0000-0000-000000000009', 'pedro@example.com');
select set_config('t.parche', 'a1200000-0000-0000-0000-000000000001', true);
select set_config('t.cena', 'a1200000-0000-0000-0000-000000000002', true);

set local role authenticated;
select pg_temp.as_user('12000000-0000-0000-0000-000000000001');
select public.create_parche('Santa Marta', 'Joan', pg_temp.pid('parche'));
select set_config('t.jo', public.my_parche_participant_id(pg_temp.pid('parche'))::text, true);
select set_config('t.code', (select code from public.parches where id = pg_temp.pid('parche')), true);
select pg_temp.as_user('12000000-0000-0000-0000-000000000002');
select public.join_parche(current_setting('t.code'), 'Jesús');
select pg_temp.as_user('12000000-0000-0000-0000-000000000003');
select public.join_parche(current_setting('t.code'), 'Ana');
select pg_temp.as_user('12000000-0000-0000-0000-000000000001');
select public.add_parche_participant(pg_temp.pid('parche'), 'Carlos');

select is((select created_by from public.parches where id = pg_temp.pid('parche')), pg_temp.pid('jo'),
  'create_parche guarda a Joan (su participante) como quien creó el parche');
select is(
  (select created_by from public.parches where id = pg_temp.pid('parche')),
  (select actor_id from public.parche_activity where parche_id = pg_temp.pid('parche') and kind = 'parcheCreated'),
  'created_by es el mismo participante del aviso parcheCreated');
select is(public.create_parche('Santa Marta', 'Joan', pg_temp.pid('parche')), pg_temp.pid('parche'),
  'Repetir create_parche con el mismo id no cambia nada');
select is((select created_by from public.parches where id = pg_temp.pid('parche')), pg_temp.pid('jo'),
  'Y quien lo creó sigue siendo Joan');

-- ─────────────────────────────────────────────────────────────
-- Solo quien lo creó lo cierra
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('12000000-0000-0000-0000-000000000002');
select throws_ok($$select public.close_parche(current_setting('t.parche')::uuid)$$,
  'P0001', 'Solo Joan puede cerrar el parche', 'Jesús no lo puede cerrar: "Solo Joan puede cerrar el parche"');
select is(pg_temp.error_hint($$select public.close_parche(current_setting('t.parche')::uuid)$$), 'notAllowed',
  'El error trae la pista notAllowed');
select pg_temp.as_user('12000000-0000-0000-0000-000000000003');
select throws_ok($$select public.close_parche(current_setting('t.parche')::uuid)$$,
  'P0001', 'Solo Joan puede cerrar el parche', 'Ana tampoco');
select ok((select status = 'open' and closed_at is null from public.parches where id = pg_temp.pid('parche')),
  'El parche sigue abierto');
select is((select count(*) from public.parche_activity
           where parche_id = pg_temp.pid('parche') and kind = 'parcheClosed'), 0::bigint,
  'Y no hay aviso de cierre');
select pg_temp.as_user('12000000-0000-0000-0000-000000000009');
select is(pg_temp.error_hint($$select public.close_parche(current_setting('t.parche')::uuid)$$), 'notFound',
  'Alguien que no es del parche recibe notFound');

select pg_temp.as_user('12000000-0000-0000-0000-000000000001');
select lives_ok($$select public.close_parche(current_setting('t.parche')::uuid)$$, 'Joan, quien lo creó, lo cierra');
select ok((select status = 'closed' and closed_at is not null from public.parches where id = pg_temp.pid('parche')),
  'El parche queda cerrado');
select is(
  (select actor_id from public.parche_activity where parche_id = pg_temp.pid('parche') and kind = 'parcheClosed'),
  pg_temp.pid('jo'), 'Cerrar queda en la actividad, hecho por Joan');
select lives_ok($$select public.close_parche(current_setting('t.parche')::uuid)$$, 'Cerrarlo otra vez no falla');
select is((select count(*) from public.parche_activity
           where parche_id = pg_temp.pid('parche') and kind = 'parcheClosed'), 1::bigint,
  'Cerrar otra vez no hace nada: un solo aviso de cierre');

-- ─────────────────────────────────────────────────────────────
-- Quien lo creó ya no tiene cuenta: lo cierra cualquiera con la app
-- ─────────────────────────────────────────────────────────────
select pg_temp.as_user('12000000-0000-0000-0000-000000000003');
select public.create_parche('Cena', 'Ana', pg_temp.pid('cena'));
select set_config('t.cena_code', (select code from public.parches where id = pg_temp.pid('cena')), true);
select pg_temp.as_user('12000000-0000-0000-0000-000000000002');
select public.join_parche(current_setting('t.cena_code'), 'Jesús');
reset role;
-- La cuenta de Ana ya no existe: su lugar queda sin la app (user_id null), pero sigue siendo quien creó el parche.
-- (Hoy borrar una cuenta que está en un parche lo impide parche_participants_before_update; se simula sin el trigger,
-- como lo haría un futuro "borrar la cuenta".)
alter table public.parche_participants disable trigger parche_participants_before_update;
update public.parche_participants set user_id = null
 where parche_id = pg_temp.pid('cena') and user_id = '12000000-0000-0000-0000-000000000003';
alter table public.parche_participants enable trigger parche_participants_before_update;
select ok(
  (select pp.user_id is null from public.parches p join public.parche_participants pp on pp.id = p.created_by
    where p.id = pg_temp.pid('cena')),
  'Sin la cuenta de Ana, quien creó la Cena ya no tiene la app');
set local role authenticated;
select pg_temp.as_user('12000000-0000-0000-0000-000000000002');
select lives_ok($$select public.close_parche(current_setting('t.cena')::uuid)$$,
  'Entonces Jesús, que tiene la app, puede cerrarla');
select ok((select status = 'closed' from public.parches where id = pg_temp.pid('cena')), 'La Cena queda cerrada');

-- ─────────────────────────────────────────────────────────────
-- Quien creó el parche no cambia y borrar el parche sigue funcionando
-- ─────────────────────────────────────────────────────────────
reset role;
select throws_ok($$update public.parches set created_by = null where id = current_setting('t.parche')::uuid$$,
  'P0001', 'No se puede cambiar quién creó el parche', 'Quien creó el parche no cambia');
select is(
  pg_temp.error_hint(format(
    $$insert into public.parches (name, code, created_by) values ('Otro', public.generate_parche_code('PCH-'), %L)$$,
    pg_temp.pid('jo'))),
  'invalidData', 'created_by es un participante de ese mismo parche (no de otro)');
delete from public.parche_participants
 where parche_id = pg_temp.pid('cena') and id = (select created_by from public.parches where id = pg_temp.pid('cena'));
select is((select created_by from public.parches where id = pg_temp.pid('cena')), null::uuid,
  'Si se borra el participante que creó el parche, created_by queda en null');
select lives_ok($$delete from public.parches where id = current_setting('t.cena')::uuid$$,
  'Borrar un parche borra a los suyos sin chocar con created_by');

select * from finish();
rollback;
