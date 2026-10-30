-- Una cuenta borrada no vuelve a entrar a cruces ni parches.
--
-- Al borrar la cuenta, el perfil queda como lápida con el mismo id (borrar_cuenta.sql). Pero su sesión (el JWT) sigue
-- viva hasta una hora, y las llaves de ledger_members, ledgers e invites apuntan a profiles, que la lápida satisface:
-- con esa sesión se podía crear un cruce o canjear un código y quedar en un cruce abierto con "Cuenta borrada".
--
-- 1. require_session() también exige que la cuenta exista en auth.users (security definer para poder leerla).
-- 2. Nadie con el perfil borrado puede ser miembro de un cruce (trigger en ledger_members), venga de donde venga.
-- 3. forget_account firma el rechazo automático de "pasar al cruce" con el lugar de quien borró su cuenta: borrada
--    desde el panel no hay sesión, y la actividad quedaba sin autor ("Alguien no aceptó…").

create or replace function public.require_session() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión' using hint = 'notAuthenticated';
  end if;
  if not exists (select 1 from auth.users where id = auth.uid()) then
    raise exception 'Tu cuenta ya no existe' using hint = 'accountDeleted';
  end if;
end $$;

create function public.ledger_members_account_alive() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from auth.users where id = new.user_id)
     or exists (select 1 from public.profiles where id = new.user_id and deleted_at is not null) then
    raise exception 'Tu cuenta ya no existe' using hint = 'accountDeleted';
  end if;
  return new;
end $$;

-- El nombre empieza por "a_" para que corra antes que las otras reglas de ledger_members (van en orden alfabético).
create trigger a_ledger_members_account_alive
  before insert on public.ledger_members
  for each row execute function public.ledger_members_account_alive();

-- Igual que en borrar_cuenta.sql, salvo el paso 2b.
create or replace function public.forget_account() returns trigger
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

  -- 2b. Ese aviso lo firma su lugar en el parche (sin sesión, desde el panel, quedaba sin autor).
  update public.parche_activity a set actor_id = pp.id
    from public.parche_participants pp
   where a.kind = 'debtRejectedForCruce' and a.actor_id is null and a.created_at = now()
     and pp.parche_id = a.parche_id and pp.user_id = old.id
     and pp.id in (a.participant_id, a.other_participant_id);

  -- 3. Sus lugares en los parches: "Cuenta borrada", con sus gastos y pagos. Después la llave pone user_id en null.
  update public.parche_participants set display_name = 'Cuenta borrada', account_deleted_at = now()
   where user_id = old.id;

  -- 4. El perfil queda como lápida: el @usuario queda libre de inmediato.
  update public.profiles
     set display_name = 'Cuenta borrada', username = null, avatar_color = null, deleted_at = now()
   where id = old.id and deleted_at is null;
  return old;
end $$;

revoke all on function public.require_session() from public, anon, authenticated;
revoke all on function public.ledger_members_account_alive() from public, anon, authenticated;
revoke all on function public.forget_account() from public, anon, authenticated;
