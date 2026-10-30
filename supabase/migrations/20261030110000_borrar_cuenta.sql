-- Cruce · borrar la cuenta (cambio usuarios-y-cuenta, S4)
-- Antes: no había cómo borrar una cuenta, y borrar un usuario desde el panel fallaba si estaba en un parche (el
-- trigger parche_participants_before_update chocaba con el "on delete set null" de parche_participants.user_id) o si
-- tenía movimientos (movements.payer_id y created_by apuntan al perfil, que se borraba en cascada).
-- Ahora:
--   - delete_my_account() borra el usuario de Auth de quien llama (con su correo, identidades y sesiones).
--   - Antes de borrarlo, el trigger forget_account (en auth.users, así también sirve un borrado desde el panel):
--       1. cierra sus cruces completos abiertos, como al desvincular, y borra su cruce pendiente con su código CRZ-;
--       2. rechaza las propuestas de pasar al cruce por confirmar donde está su lugar (ya no tienen dónde caer);
--       3. deja sus lugares en los parches como "Cuenta borrada" (account_deleted_at), con sus gastos y pagos;
--       4. deja su perfil como lápida: "Cuenta borrada", sin @usuario ni color, con deleted_at.
--   - El perfil ya no se borra en cascada con el usuario (se quita la llave profiles.id → auth.users): la lápida
--     conserva el id, así los movimientos, los cruces y los saldos siguen igual. Un perfil solo se crea con
--     id = auth.uid(), así que no aparecen perfiles de usuarios que no existieron.
--   - Una lápida no se edita (la sesión borrada sigue vigente hasta que vence el token).
--   - parche_participants.user_id puede pasar a null solo si esa cuenta ya no existe en auth.users.
-- Aditiva: no borra datos.

-- ─────────────────────────────────────────────────────────────
-- Columnas y llaves
-- ─────────────────────────────────────────────────────────────

alter table public.profiles drop constraint profiles_id_fkey;

-- El color se borra con la cuenta: solo una lápida se queda sin color.
alter table public.profiles
  alter column avatar_color drop not null,
  add constraint avatar_color_required check (avatar_color is not null or deleted_at is not null);

-- Cuándo se borró la cuenta de quien tenía ese lugar; null mientras exista (o si nunca tuvo la app).
alter table public.parche_participants add column account_deleted_at timestamptz;

-- ─────────────────────────────────────────────────────────────
-- Triggers
-- ─────────────────────────────────────────────────────────────

-- Una cuenta borrada no se edita: ni el nombre, ni el color, ni el @usuario.
create function public.profiles_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.deleted_at is not null then
    raise exception 'Esa cuenta se borró' using hint = 'notAllowed';
  end if;
  return new;
end $$;

create trigger profiles_before_update
  before update on public.profiles
  for each row execute function public.profiles_before_update();

-- Igual que en colores.sql, salvo que la lápida (sin color) no toca los colores de sus lugares en los parches.
create or replace function public.profiles_color_sync() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.avatar_color is null then
    return null;
  end if;
  update public.parche_participants set avatar_color = new.avatar_color
    where user_id = new.id and avatar_color is distinct from new.avatar_color;
  return null;
end $$;

-- Igual que en codigos.sql, salvo que un lugar puede quedarse sin cuenta cuando esa cuenta ya no existe en auth.users
-- (el "on delete set null" al borrar el usuario). security definer para leer auth.users.
create or replace function public.parche_participants_before_update() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.parche_id is distinct from old.parche_id or new.joined_at is distinct from old.joined_at then
    raise exception 'No se puede cambiar el parche ni el orden de una persona' using hint = 'notAllowed';
  end if;
  if old.user_id is not null and new.user_id is distinct from old.user_id
     and not (new.user_id is null and not exists (select 1 from auth.users where id = old.user_id)) then
    raise exception 'Ese lugar ya es de alguien' using hint = 'notAllowed';
  end if;
  new.claimed_code := coalesce(old.claimed_code, case when new.user_id is not null then old.claim_code end);
  if new.user_id is not null then
    new.claim_code := null;
  end if;
  return new;
end $$;

-- Antes de borrar un usuario de Auth (desde la app o desde el panel), con el usuario todavía presente.
create function public.forget_account() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- 1. Cruces: los completos y abiertos se cierran como al desvincular; el pendiente (solo él) se borra con su código.
  update public.ledgers l set closed_at = now(), closed_by = old.id
   where l.closed_at is null
     and exists (select 1 from public.ledger_members m where m.ledger_id = l.id and m.user_id = old.id)
     and (select count(*) from public.ledger_members m where m.ledger_id = l.id) = 2;
  delete from public.ledgers l
   where l.created_by = old.id
     and (select count(*) from public.ledger_members m where m.ledger_id = l.id) < 2;

  -- 2. Propuestas de pasar al cruce por confirmar con alguno de sus lugares: quedan rechazadas (con su aviso).
  update public.parche_cruce_transfers t set status = 'rejected', responded_at = now()
   where t.status = 'pending'
     and exists (select 1 from public.parche_participants pp
                 where pp.user_id = old.id and pp.id in (t.from_id, t.to_id));

  -- 3. Sus lugares en los parches: "Cuenta borrada", con sus gastos y pagos. Después la llave pone user_id en null.
  update public.parche_participants set display_name = 'Cuenta borrada', account_deleted_at = now()
   where user_id = old.id;

  -- 4. El perfil queda como lápida: el @usuario queda libre de inmediato.
  update public.profiles
     set display_name = 'Cuenta borrada', username = null, avatar_color = null, deleted_at = now()
   where id = old.id and deleted_at is null;
  return old;
end $$;

create trigger forget_account
  before delete on auth.users
  for each row execute function public.forget_account();

-- ─────────────────────────────────────────────────────────────
-- Función que llama la app
-- ─────────────────────────────────────────────────────────────

-- delete_my_account() → nada. Borra la cuenta de quien llama (ver forget_account). No se puede deshacer: si vuelve con
-- el mismo correo, Auth le crea un usuario nuevo y nada se reconecta.
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_session();
  delete from auth.users where id = auth.uid();
end $$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
revoke all on function public.profiles_before_update() from public, anon, authenticated;
revoke all on function public.forget_account() from public, anon, authenticated;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
