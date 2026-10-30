-- Cruce · color fijo por persona (corrección 3 de la revisión de diseño, decisión D7)
-- Antes: el color del avatar dependía del rol en cada cruce (quien creó, amarillo; quien se unió, violeta), así que la
-- misma persona salía de un color en un cruce y de otro en otro. En los parches el color salía del orden.
-- Ahora:
--   - Cada persona tiene un color fijo en profiles.avatar_color, de una paleta de 6 (amarillo, violeta, verde,
--     durazno, rosado y lima). Un perfil nuevo recibe uno al azar; se cambia en "Tu perfil" (política "editar mi
--     perfil": cada quien solo cambia el suyo).
--   - Los perfiles que ya existían quedan con el color que hoy tienen en su cruce más reciente (amarillo si no tienen).
--   - En los parches cada participante guarda su color (parche_participants.avatar_color): quien tiene la app, el de su
--     perfil (se copia al entrar, al quedarse con su lugar y cuando cambia su perfil); quien está sin la app, el
--     siguiente color libre dentro del parche, en el orden en que entró.
--   - my_cruces() devuelve el color del perfil de cada uno. El recibo rosa o verde (tike_variant) sigue siendo por
--     cruce: quien lo creó ve el rosa y quien se unió, el verde.
-- Aditiva: no borra datos. ledger_members.avatar_color se queda (ya no se lee) y su enum avatar_color no cambia.
-- La paleta es un tipo nuevo (person_color) y no valores nuevos de avatar_color, porque un valor agregado a un enum no se
-- puede usar en la misma transacción (y esta migración lo usa en el relleno).

-- ─────────────────────────────────────────────────────────────
-- Tipo
-- ─────────────────────────────────────────────────────────────

-- Igual que AvatarColor en Swift (rawValue) y que los tokens de CruceColor, en el orden de la paleta.
create type public.person_color as enum ('yellow', 'violet', 'green', 'peach', 'pink', 'lime');

-- ─────────────────────────────────────────────────────────────
-- Ayudas
-- ─────────────────────────────────────────────────────────────

-- El color que la persona tenía antes de esta migración: el de su cruce más reciente, igual que lo elegía la app
-- (primero los abiertos y luego los cerrados, del que se completó último; un cruce pendiente no cuenta).
-- Amarillo si no tiene cruces. Solo para el relleno y las pruebas.
create function public.legacy_avatar_color(p_user uuid) returns public.person_color
language sql stable set search_path = '' as $$
  select coalesce(
    (select me.avatar_color::text::public.person_color
     from public.ledger_members me
     join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
     join public.ledgers l on l.id = me.ledger_id
     where me.user_id = p_user
     order by l.closed_at is not null, greatest(me.joined_at, other.joined_at) desc, me.ledger_id
     limit 1),
    'yellow')
$$;

-- ─────────────────────────────────────────────────────────────
-- profiles.avatar_color
-- ─────────────────────────────────────────────────────────────

alter table public.profiles add column avatar_color public.person_color;
update public.profiles set avatar_color = public.legacy_avatar_color(id);
alter table public.profiles
  -- Un perfil nuevo recibe un color al azar de la paleta.
  alter column avatar_color set default (enum_range(null::public.person_color))[1 + floor(random() * 6)::int],
  alter column avatar_color set not null;

-- ─────────────────────────────────────────────────────────────
-- parche_participants.avatar_color
-- ─────────────────────────────────────────────────────────────

alter table public.parche_participants add column avatar_color public.person_color;

-- El siguiente color libre del parche, en el orden de la paleta. Si ya se usaron los 6, vuelve a empezar según cuántas
-- personas hay.
create function public.next_parche_color(p_parche uuid) returns public.person_color
language sql stable set search_path = '' as $$
  select coalesce(
    (select c.color
     from unnest(enum_range(null::public.person_color)) with ordinality as c(color, position)
     where not exists (
       select 1 from public.parche_participants
       where parche_id = p_parche and avatar_color = c.color)
     order by c.position
     limit 1),
    (enum_range(null::public.person_color))[
      1 + (select count(*) from public.parche_participants where parche_id = p_parche)::int % 6])
$$;

-- Relleno: primero quien tiene la app (el color de su perfil) y después, en el orden de entrada, quien está sin la app
-- (el siguiente color libre de su parche).
update public.parche_participants pp
  set avatar_color = coalesce(p.avatar_color, 'yellow')
  from public.profiles p
  where pp.user_id is not null and p.id = pp.user_id;
update public.parche_participants set avatar_color = 'yellow' where user_id is not null and avatar_color is null;
do $$
declare
  v_participant record;
begin
  for v_participant in
    select id, parche_id from public.parche_participants where user_id is null order by parche_id, joined_at, id
  loop
    update public.parche_participants
      set avatar_color = public.next_parche_color(v_participant.parche_id)
      where id = v_participant.id;
  end loop;
end $$;

alter table public.parche_participants alter column avatar_color set not null;

-- Al entrar (crear, unirse) o al quedarse con un lugar, el color es el del perfil; quien entra sin la app recibe el
-- siguiente color libre del parche y lo conserva.
create function public.parche_participants_color() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.user_id is not null then
    if tg_op = 'INSERT' or old.user_id is null then
      new.avatar_color := coalesce(
        (select avatar_color from public.profiles where id = new.user_id), 'yellow');
    end if;
  elsif tg_op = 'INSERT' then
    new.avatar_color := public.next_parche_color(new.parche_id);
  end if;
  return new;
end $$;

create trigger parche_participants_color
  before insert or update of user_id on public.parche_participants
  for each row execute function public.parche_participants_color();

-- Cuando alguien cambia su color en "Tu perfil", sus lugares en los parches cambian con él.
create function public.profiles_color_sync() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.parche_participants set avatar_color = new.avatar_color
    where user_id = new.id and avatar_color is distinct from new.avatar_color;
  return null;
end $$;

create trigger profiles_color_sync
  after update of avatar_color on public.profiles
  for each row when (new.avatar_color is distinct from old.avatar_color)
  execute function public.profiles_color_sync();

-- ─────────────────────────────────────────────────────────────
-- my_cruces(): el color de cada uno sale de su perfil
-- ─────────────────────────────────────────────────────────────

-- Misma forma que antes (my_avatar y partner_avatar siguen siendo text): se reemplaza sin borrarla y conserva sus
-- permisos.
create or replace function public.my_cruces()
returns table (
  ledger_id             uuid,
  partner_id            uuid,
  partner_name          text,
  my_tike               text,
  my_avatar             text,
  partner_tike          text,
  partner_avatar        text,
  linked_at             timestamptz,
  closed_at             timestamptz,
  default_other_percent smallint
)
language sql stable security invoker set search_path = '' as $$
  select me.ledger_id,
         other.user_id,
         p.display_name,
         me.tike_variant::text,
         mp.avatar_color::text,
         other.tike_variant::text,
         p.avatar_color::text,
         greatest(me.joined_at, other.joined_at),
         l.closed_at,
         l.default_other_percent
  from public.ledger_members me
  join public.ledger_members other on other.ledger_id = me.ledger_id and other.user_id <> me.user_id
  join public.profiles p on p.id = other.user_id
  join public.profiles mp on mp.id = me.user_id
  join public.ledgers l on l.id = me.ledger_id
  where me.user_id = (select auth.uid())
  order by l.closed_at is not null, greatest(me.joined_at, other.joined_at) desc, me.ledger_id
$$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────

-- Ayudas internas y funciones de triggers: no se llaman desde la app.
revoke all on function public.legacy_avatar_color(uuid) from public, anon, authenticated;
revoke all on function public.next_parche_color(uuid) from public, anon, authenticated;
revoke all on function public.parche_participants_color() from public, anon, authenticated;
revoke all on function public.profiles_color_sync() from public, anon, authenticated;
