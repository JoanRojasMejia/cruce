-- Quién puede cerrar un parche (corrección 6, decisión D1 de Joan: "si solo el que crea el parche lo cierra").
--
--   - parches.created_by: el participante que creó el parche (como las demás tablas de parches, por participante y
--     no por cuenta). Los parches que ya existen lo toman de su aviso 'parcheCreated' (actor_id es el participante).
--   - close_parche: solo lo cierra quien lo creó. A los demás les responde notAllowed ("Solo Joan puede cerrar el
--     parche"). Si quien lo creó ya no tiene cuenta (se borró su usuario y su lugar quedó sin la app), cualquiera del
--     parche con la app lo puede cerrar, para que el parche no quede abierto para siempre.
--   - Cerrar sigue dejando 'parcheClosed' en la actividad (trigger parches_activity) y cerrar uno cerrado no hace nada.
-- Aditiva: no cambia filas de otras tablas ni la firma de ninguna función.

alter table public.parches add column created_by uuid;

-- Los que ya existen: quien hizo el aviso 'parcheCreated' o, si no lo hay, el primero del parche.
update public.parches p
   set created_by = coalesce(
     (select a.actor_id from public.parche_activity a
       where a.parche_id = p.id and a.kind = 'parcheCreated' and a.actor_id is not null
       order by a.created_at, a.id limit 1),
     (select pp.id from public.parche_participants pp
       where pp.parche_id = p.id order by pp.joined_at, pp.id limit 1));

-- El creador es un participante de ese mismo parche. create_parche inserta el parche sin created_by (null no se
-- revisa) y lo pone después de insertar a quien lo crea. Si se borrara ese participante, solo se borra created_by.
alter table public.parches
  add constraint created_by_in_parche foreign key (id, created_by)
    references public.parche_participants (parche_id, id)
    on delete set null (created_by);

-- parches: además de lo de antes, quien creó el parche no cambia una vez puesto.
create or replace function public.parches_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.code is distinct from old.code or new.created_at is distinct from old.created_at then
    raise exception 'No se puede cambiar el código ni la fecha de un parche' using hint = 'notAllowed';
  end if;
  if old.created_by is not null and new.created_by is distinct from old.created_by then
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

-- create_parche(p_name, p_display_name, p_id) → uuid del parche. Igual que antes y, además, guarda en created_by el
-- participante de quien lo crea.
create or replace function public.create_parche(p_name text, p_display_name text default null, p_id uuid default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_name    text := btrim(coalesce(p_name, ''));
  v_display text;
  v_id      uuid := coalesce(p_id, gen_random_uuid());
  v_creator uuid;
begin
  perform public.require_session();
  if exists (select 1 from public.parches where id = v_id) then
    if public.is_parche_member(v_id) then
      return v_id;
    end if;
    raise exception 'Ese parche ya existe' using hint = 'invalidData';
  end if;
  if char_length(v_name) not between 1 and 60 then
    raise exception 'El nombre del parche debe tener entre 1 y 60 caracteres' using hint = 'invalidData';
  end if;
  v_display := btrim(coalesce(nullif(btrim(p_display_name), ''),
                              (select display_name from public.profiles where id = auth.uid()), ''));
  if char_length(v_display) not between 1 and 40 then
    raise exception 'El nombre debe tener entre 1 y 40 caracteres' using hint = 'invalidData';
  end if;

  insert into public.parches (id, name, code) values (v_id, v_name, public.generate_parche_code('PCH-'));
  insert into public.parche_participants (parche_id, user_id, display_name, last_seen_at)
    values (v_id, auth.uid(), v_display, now())
    returning id into v_creator;
  update public.parches set created_by = v_creator where id = v_id;
  return v_id;
end $$;

-- close_parche(p_id) → nada. Solo quien creó el parche lo cierra; no se reabre. Cerrar uno cerrado no hace nada.
-- Si quien lo creó ya no tiene la app (o no se sabe quién fue), lo cierra cualquiera del parche con la app.
-- Errores: notFound, notAllowed ("Solo <nombre> puede cerrar el parche").
create or replace function public.close_parche(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_creator_user uuid;
  v_creator_name text;
begin
  perform public.require_session();
  if not public.is_parche_member(p_id) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  select pp.user_id, pp.display_name into v_creator_user, v_creator_name
    from public.parches p
    left join public.parche_participants pp on pp.id = p.created_by
   where p.id = p_id;
  if v_creator_user is not null and v_creator_user <> auth.uid() then
    raise exception 'Solo % puede cerrar el parche', v_creator_name using hint = 'notAllowed';
  end if;
  update public.parches set status = 'closed' where id = p_id and status = 'open';
end $$;
