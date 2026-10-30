-- Cruce · parches sin relaciones ambiguas para PostgREST
-- Problema: cerrar_parche.sql agregó la llave foránea parches (id, created_by) → parche_participants (parche_id, id).
-- Con ella hay dos relaciones entre parches y parche_participants (esa y parche_participants.parche_id → parches), y
-- PostgREST ya no sabe cuál usar: la consulta de la app `parches?select=…,parche_participants(*),…` responde
-- PGRST201 ("more than one relationship was found") y la app no carga ningún parche. Las versiones de la app que ya
-- están instaladas piden lo mismo, así que se arregla aquí y no solo en la app.
-- Ahora:
--   - Se quita esa llave foránea (no se borra ningún dato).
--   - La misma garantía la da un trigger: created_by, si no es null, es un participante de ese mismo parche
--     (pista invalidData, como los demás datos que no cuadran).
--   - Lo que hacía `on delete set null (created_by)`: si se borra el participante que creó el parche, created_by
--     queda en null. Lo hace un trigger en parche_participants, y parches_before_update ahora deja poner null cuando
--     ese participante ya no existe (antes, la llave chocaba con esa misma regla y el borrado fallaba).
--   - La llave transfer_proposed_by_in_parche de parche_cruce_transfers se queda: va a parche_participants y no a
--     parches, así que no crea otra relación entre parches y parche_participants.
-- Aditiva: no cambia filas ni la firma de ninguna función.

alter table public.parches drop constraint created_by_in_parche;

-- created_by es un participante de ese mismo parche (lo que revisaba la llave foránea).
create function public.parches_created_by_in_parche() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.created_by is not null and not exists (
    select 1 from public.parche_participants pp where pp.parche_id = new.id and pp.id = new.created_by
  ) then
    raise exception 'Quien creó el parche debe ser alguien del parche' using hint = 'invalidData';
  end if;
  return new;
end $$;

create trigger parches_created_by_in_parche
  before insert or update of created_by on public.parches
  for each row execute function public.parches_created_by_in_parche();

-- Si se borra el participante que creó el parche, created_by queda en null (lo que hacía on delete set null).
-- Cuando se borra el parche entero, la fila ya no está y el update no hace nada.
create function public.parche_participants_clear_creator() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.parches set created_by = null where id = old.parche_id and created_by = old.id;
  return old;
end $$;

create trigger parche_participants_clear_creator
  after delete on public.parche_participants
  for each row execute function public.parche_participants_clear_creator();

-- Igual que en cerrar_parche.sql, salvo que created_by puede pasar a null cuando ese participante ya no existe.
create or replace function public.parches_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.code is distinct from old.code or new.created_at is distinct from old.created_at then
    raise exception 'No se puede cambiar el código ni la fecha de un parche' using hint = 'notAllowed';
  end if;
  if old.created_by is not null and new.created_by is distinct from old.created_by
     and not (new.created_by is null
              and not exists (select 1 from public.parche_participants pp where pp.id = old.created_by)) then
    raise exception 'No se puede cambiar quién creó el parche' using hint = 'notAllowed';
  end if;
  if old.status = 'closed' and new.status = 'open' then
    raise exception 'Un parche cerrado no se reabre' using hint = 'notAllowed';
  end if;
  if old.status = 'open' and new.status = 'closed' then
    new.closed_at := coalesce(new.closed_at, now());
  elsif new.status = 'closed' then
    new.closed_at := old.closed_at;
  end if;
  return new;
end $$;

revoke all on function public.parches_created_by_in_parche() from public, anon, authenticated;
revoke all on function public.parche_participants_clear_creator() from public, anon, authenticated;

-- PostgREST vuelve a leer el esquema (sin la relación de más).
notify pgrst, 'reload schema';
