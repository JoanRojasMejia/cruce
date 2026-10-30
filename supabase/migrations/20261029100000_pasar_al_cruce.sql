-- Cruce · pasar al cruce (corrección 1 de la revisión de diseño)
-- Antes: al cerrar un parche, cualquiera de los dos pasaba a su cruce la deuda directa entre ellos, de una vez.
-- Ahora:
--   - La oferta sale solo del plan "Para saldar" (parche_settlement_plan, igual que ParcheCalculator.minimumTransfers):
--     una transferencia del plan entre dos personas con la app que comparten un cruce abierto. Monto y dirección son
--     los de esa transferencia.
--   - Uno propone (propose_parche_debt_to_cruce) y queda "por confirmar" para los dos; la otra persona acepta
--     (accept_parche_cruce_transfer: crea el movimiento en el cruce y salda la transferencia en el parche, en una sola
--     transacción) o rechaza (reject_parche_cruce_transfer: la deuda sigue en el parche).
--   - En el saldo del parche y en la deuda directa solo cuentan las transferencias aceptadas.
-- Aditiva: no borra datos. Las transferencias que ya existían quedan aceptadas.
-- Errores nuevos con las pistas de siempre: notFound, notAllowed, parcheOpen, noSharedCruce, alreadyMoved, nothingToMove.

-- ─────────────────────────────────────────────────────────────
-- Tipos y columnas
-- ─────────────────────────────────────────────────────────────

-- Igual que ParcheActivityKind (rawValue). Aceptar sigue dejando 'debtMovedToCruce'.
-- (Los valores nuevos solo se usan dentro de funciones plpgsql, que se resuelven al ejecutarse.)
alter type public.parche_activity_kind add value if not exists 'debtProposedToCruce';
alter type public.parche_activity_kind add value if not exists 'debtRejectedForCruce';

-- status: pending (por confirmar), accepted (pasó al cruce) o rejected (la deuda sigue en el parche).
-- Las filas que ya existían pasaron al cruce de una vez: quedan aceptadas. Las nuevas nacen por confirmar.
alter table public.parche_cruce_transfers
  add column status       text not null default 'accepted'
    constraint transfer_status_valid check (status in ('pending', 'accepted', 'rejected')),
  -- Participante que la propuso (null en las que ya existían).
  add column proposed_by  uuid,
  -- Cuándo la otra persona la aceptó o la rechazó.
  add column responded_at timestamptz,
  add constraint transfer_proposed_by_in_parche foreign key (parche_id, proposed_by)
    references public.parche_participants (parche_id, id) on delete cascade;
alter table public.parche_cruce_transfers alter column status set default 'pending';

-- Una sola transferencia viva por par (por confirmar o aceptada), sin importar quién le debía a quién.
-- Las rechazadas no cuentan: después de un rechazo se puede volver a proponer.
drop index public.parche_cruce_transfers_pair_idx;
create unique index parche_cruce_transfers_pair_idx
  on public.parche_cruce_transfers (parche_id, least(from_id, to_id), greatest(from_id, to_id))
  where status <> 'rejected';

-- ─────────────────────────────────────────────────────────────
-- Saldos y plan para saldar (iguales que ParcheCalculator)
-- ─────────────────────────────────────────────────────────────

-- Saldo de cada participante, en el orden del parche (joined_at y, si empatan, id): lo que pagó en gastos vigentes −
-- lo que le toca en ellos + pagos confirmados que hizo − los que recibió + transferencias al cruce ACEPTADAS como
-- quien debía − como a quien le debían. Siempre suma cero.
create function public.parche_balances(p_parche uuid)
returns table (participant_id uuid, net bigint, "position" integer)
language sql stable security definer set search_path = '' as $$
  with moves (pid, amount) as (
    select p.participant_id, p.amount
      from public.parche_expense_payers p join public.parche_expenses e on e.id = p.expense_id
      where e.parche_id = p_parche and e.deleted_at is null
    union all
    select s.participant_id, -s.amount
      from public.parche_expense_shares s join public.parche_expenses e on e.id = s.expense_id
      where e.parche_id = p_parche and e.deleted_at is null
    union all
    select pay.from_id, pay.amount from public.parche_payments pay
      where pay.parche_id = p_parche and pay.confirmed_at is not null
    union all
    select pay.to_id, -pay.amount from public.parche_payments pay
      where pay.parche_id = p_parche and pay.confirmed_at is not null
    union all
    select t.from_id, t.amount from public.parche_cruce_transfers t
      where t.parche_id = p_parche and t.status = 'accepted'
    union all
    select t.to_id, -t.amount from public.parche_cruce_transfers t
      where t.parche_id = p_parche and t.status = 'accepted'
  )
  select pp.id,
         coalesce((select sum(m.amount) from moves m where m.pid = pp.id), 0)::bigint,
         (row_number() over (order by pp.joined_at, pp.id))::integer
  from public.parche_participants pp
  where pp.parche_id = p_parche
  order by pp.joined_at, pp.id;
$$;

-- "Para saldar": voraz, el que más debe le paga al que más le deben el menor de los dos montos, y se repite.
-- Los empates los gana quien va primero en el orden del parche. Igual que ParcheCalculator.minimumTransfers.
-- Un mismo par aparece a lo sumo una vez (después de cada pago, uno de los dos queda en cero).
create function public.parche_settlement_plan(p_parche uuid)
returns table (from_id uuid, to_id uuid, amount bigint)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_ids      uuid[];
  v_net      bigint[];
  v_debtor   integer;
  v_creditor integer;
  v_amount   bigint;
begin
  select array_agg(b.participant_id order by b."position"), array_agg(b.net order by b."position")
    into v_ids, v_net
    from public.parche_balances(p_parche) as b;
  if v_ids is null then
    return;
  end if;
  loop
    v_debtor := null;
    v_creditor := null;
    -- Con comparaciones estrictas, en empate se queda el índice más bajo.
    for i in 1 .. array_length(v_ids, 1) loop
      if v_net[i] < 0 and (v_debtor is null or v_net[i] < v_net[v_debtor]) then
        v_debtor := i;
      end if;
      if v_net[i] > 0 and (v_creditor is null or v_net[i] > v_net[v_creditor]) then
        v_creditor := i;
      end if;
    end loop;
    exit when v_debtor is null or v_creditor is null;
    v_amount := least(-v_net[v_debtor], v_net[v_creditor]);
    v_net[v_debtor] := v_net[v_debtor] + v_amount;
    v_net[v_creditor] := v_net[v_creditor] - v_amount;
    from_id := v_ids[v_debtor];
    to_id := v_ids[v_creditor];
    amount := v_amount;
    return next;
  end loop;
end $$;

-- Igual que antes, salvo que solo cuentan las transferencias al cruce aceptadas.
create or replace function public.parche_direct_debt(p_parche uuid, p_from uuid, p_to uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select (
    coalesce((
      select sum(div(coalesce(share_from.amount, 0)::numeric * coalesce(paid_to.amount, 0), e.amount)
               - div(coalesce(share_to.amount, 0)::numeric * coalesce(paid_from.amount, 0), e.amount))
      from public.parche_expenses e
      left join public.parche_expense_shares share_from on share_from.expense_id = e.id and share_from.participant_id = p_from
      left join public.parche_expense_shares share_to on share_to.expense_id = e.id and share_to.participant_id = p_to
      left join public.parche_expense_payers paid_from on paid_from.expense_id = e.id and paid_from.participant_id = p_from
      left join public.parche_expense_payers paid_to on paid_to.expense_id = e.id and paid_to.participant_id = p_to
      where e.parche_id = p_parche and e.deleted_at is null and e.amount > 0), 0)
    - coalesce((select sum(amount) from public.parche_payments
                where parche_id = p_parche and confirmed_at is not null and from_id = p_from and to_id = p_to), 0)
    + coalesce((select sum(amount) from public.parche_payments
                where parche_id = p_parche and confirmed_at is not null and from_id = p_to and to_id = p_from), 0)
    - coalesce((select sum(amount) from public.parche_cruce_transfers
                where parche_id = p_parche and status = 'accepted' and from_id = p_from and to_id = p_to), 0)
    + coalesce((select sum(amount) from public.parche_cruce_transfers
                where parche_id = p_parche and status = 'accepted' and from_id = p_to and to_id = p_from), 0)
  )::bigint;
$$;

-- El cruce abierto más reciente que comparten dos cuentas, o null.
create function public.shared_open_ledger(p_user uuid, p_other uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select mine.ledger_id
  from public.ledger_members mine
  join public.ledger_members theirs on theirs.ledger_id = mine.ledger_id and theirs.user_id = p_other
  join public.ledgers l on l.id = mine.ledger_id
  where mine.user_id = p_user and l.closed_at is null
  order by l.created_at desc
  limit 1;
$$;

-- ─────────────────────────────────────────────────────────────
-- Actividad: proponer, aceptar y rechazar
-- ─────────────────────────────────────────────────────────────
create or replace function public.parche_cruce_transfers_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_kind public.parche_activity_kind;
begin
  if tg_op = 'INSERT' then
    v_kind := case when new.status = 'accepted' then 'debtMovedToCruce'::public.parche_activity_kind
                   else 'debtProposedToCruce'::public.parche_activity_kind end;
  elsif old.status = 'pending' and new.status = 'accepted' then
    v_kind := 'debtMovedToCruce'::public.parche_activity_kind;
  elsif old.status = 'pending' and new.status = 'rejected' then
    v_kind := 'debtRejectedForCruce'::public.parche_activity_kind;
  else
    return null;
  end if;
  insert into public.parche_activity (parche_id, kind, actor_id, participant_id, other_participant_id, amount)
    values (new.parche_id, v_kind, public.my_parche_participant_id(new.parche_id), new.from_id, new.to_id,
            new.amount);
  return null;
end $$;

drop trigger parche_cruce_transfers_activity on public.parche_cruce_transfers;
create trigger parche_cruce_transfers_activity
  after insert or update on public.parche_cruce_transfers
  for each row execute function public.parche_cruce_transfers_activity();

-- ─────────────────────────────────────────────────────────────
-- Funciones que llama la app
-- ─────────────────────────────────────────────────────────────

-- propose_parche_debt_to_cruce(p_parche, p_other) → la fila de parche_cruce_transfers (por confirmar).
-- Quien llama le propone a p_other (participante) pasar a su cruce la transferencia del plan "Para saldar" entre
-- los dos: mismo monto y misma dirección. Todavía no crea el movimiento; eso pasa cuando p_other la acepta.
-- Necesita el parche cerrado, que los dos tengan la app y compartan un cruce abierto. Si ya hay una por confirmar
-- para el par, la devuelve (proponer otra vez no crea otra).
-- Errores: notFound, parcheOpen, notAllowed (consigo mismo o sin la app), noSharedCruce, alreadyMoved, nothingToMove.
create function public.propose_parche_debt_to_cruce(p_parche uuid, p_other uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
declare
  v_parche   public.parches%rowtype;
  v_me       uuid;
  v_other    public.parche_participants%rowtype;
  v_existing public.parche_cruce_transfers%rowtype;
  v_from     uuid;
  v_to       uuid;
  v_amount   bigint;
  v_transfer public.parche_cruce_transfers%rowtype;
begin
  perform public.require_session();
  -- Bloquea el parche: dos propuestas al tiempo no crean dos filas.
  select * into v_parche from public.parches where id = p_parche for update;
  v_me := public.my_parche_participant_id(p_parche);
  if v_parche.id is null or v_me is null then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  if v_parche.status = 'open' then
    raise exception 'El parche sigue abierto' using hint = 'parcheOpen';
  end if;
  select * into v_other from public.parche_participants where id = p_other and parche_id = p_parche;
  if not found then
    raise exception 'Esa persona no está en el parche' using hint = 'notFound';
  end if;
  if v_other.id = v_me then
    raise exception 'No puedes pasarte una deuda a ti mismo' using hint = 'notAllowed';
  end if;
  if v_other.user_id is null then
    raise exception 'Esa persona no tiene la app' using hint = 'notAllowed';
  end if;
  if public.shared_open_ledger(auth.uid(), v_other.user_id) is null then
    raise exception 'No comparten un cruce' using hint = 'noSharedCruce';
  end if;

  select * into v_existing from public.parche_cruce_transfers
    where parche_id = p_parche and status <> 'rejected'
      and least(from_id, to_id) = least(v_me, v_other.id) and greatest(from_id, to_id) = greatest(v_me, v_other.id);
  if found then
    if v_existing.status = 'pending' then
      return v_existing;
    end if;
    raise exception 'La deuda entre ustedes ya pasó al cruce' using hint = 'alreadyMoved';
  end if;

  select p.from_id, p.to_id, p.amount into v_from, v_to, v_amount
    from public.parche_settlement_plan(p_parche) as p
    where (p.from_id = v_me and p.to_id = v_other.id) or (p.from_id = v_other.id and p.to_id = v_me);
  if v_amount is null then
    raise exception 'Para saldar no hay un pago entre ustedes' using hint = 'nothingToMove';
  end if;

  insert into public.parche_cruce_transfers (parche_id, from_id, to_id, amount, status, proposed_by)
    values (p_parche, v_from, v_to, v_amount, 'pending', v_me)
    returning * into v_transfer;
  return v_transfer;
end $$;

-- accept_parche_cruce_transfer(p_id) → la fila de parche_cruce_transfers (aceptada, con movement_id).
-- Solo la otra persona del par (no quien la propuso). En una sola transacción: inserta en el cruce abierto que
-- comparten un gasto 'full_other' pagado por quien recibe, con el concepto "Parche <nombre>", y marca la
-- transferencia como aceptada (desde ahí cuenta en el parche como un pago). Aceptar una ya aceptada no hace nada.
-- Si las cuentas del parche cambiaron y el plan ya no tiene esa misma transferencia, no se acepta.
-- Errores: notFound, notAllowed (no es la otra persona o ya se rechazó), noSharedCruce, nothingToMove.
create function public.accept_parche_cruce_transfer(p_id uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
declare
  v_parche_id uuid;
  v_parche    public.parches%rowtype;
  v_transfer  public.parche_cruce_transfers%rowtype;
  v_me        uuid;
  v_other     uuid;
  v_ledger    uuid;
  v_creditor  uuid;
  v_movement  uuid;
begin
  perform public.require_session();
  select parche_id into v_parche_id from public.parche_cruce_transfers where id = p_id;
  if v_parche_id is null or not public.is_parche_member(v_parche_id) then
    raise exception 'Esa propuesta no existe' using hint = 'notFound';
  end if;
  -- Primero el parche y luego la transferencia, en el mismo orden que al proponer: dos aceptaciones al tiempo
  -- no crean dos movimientos.
  select * into v_parche from public.parches where id = v_parche_id for update;
  select * into v_transfer from public.parche_cruce_transfers where id = p_id for update;
  if v_transfer.status = 'accepted' then
    return v_transfer;
  end if;
  v_me := public.my_parche_participant_id(v_parche_id);
  if v_me is distinct from v_transfer.from_id and v_me is distinct from v_transfer.to_id
     or v_me is not distinct from v_transfer.proposed_by then
    raise exception 'Solo la otra persona puede responder' using hint = 'notAllowed';
  end if;
  if v_transfer.status = 'rejected' then
    raise exception 'Esa propuesta ya se rechazó' using hint = 'notAllowed';
  end if;

  v_other := case when v_me = v_transfer.from_id then v_transfer.to_id else v_transfer.from_id end;
  v_ledger := public.shared_open_ledger(auth.uid(),
    (select user_id from public.parche_participants where id = v_other));
  if v_ledger is null then
    raise exception 'No comparten un cruce' using hint = 'noSharedCruce';
  end if;
  if not exists (select 1 from public.parche_settlement_plan(v_parche_id) as p
                 where p.from_id = v_transfer.from_id and p.to_id = v_transfer.to_id
                   and p.amount = v_transfer.amount) then
    raise exception 'Las cuentas del parche cambiaron: rechaza la propuesta y vuelvan a proponerla'
      using hint = 'nothingToMove';
  end if;

  -- Paga quien recibe; todo le corresponde a quien debe.
  select user_id into v_creditor from public.parche_participants where id = v_transfer.to_id;
  insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values (v_ledger, 'expense', v_creditor, v_transfer.amount, 'Parche ' || v_parche.name, 'full_other', 100,
            auth.uid())
    returning id into v_movement;
  update public.parche_cruce_transfers
    set status = 'accepted', movement_id = v_movement, responded_at = now()
    where id = p_id
    returning * into v_transfer;
  return v_transfer;
end $$;

-- reject_parche_cruce_transfer(p_id) → la fila de parche_cruce_transfers (rechazada).
-- Solo la otra persona del par. La deuda sigue en el parche y el par puede volver a proponerla.
-- Rechazar una ya rechazada no hace nada. Errores: notFound, notAllowed, alreadyMoved (ya se aceptó).
create function public.reject_parche_cruce_transfer(p_id uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
declare
  v_transfer public.parche_cruce_transfers%rowtype;
  v_me       uuid;
begin
  perform public.require_session();
  select * into v_transfer from public.parche_cruce_transfers where id = p_id for update;
  if not found or not public.is_parche_member(v_transfer.parche_id) then
    raise exception 'Esa propuesta no existe' using hint = 'notFound';
  end if;
  v_me := public.my_parche_participant_id(v_transfer.parche_id);
  if v_me is distinct from v_transfer.from_id and v_me is distinct from v_transfer.to_id
     or v_me is not distinct from v_transfer.proposed_by then
    raise exception 'Solo la otra persona puede responder' using hint = 'notAllowed';
  end if;
  if v_transfer.status = 'rejected' then
    return v_transfer;
  end if;
  if v_transfer.status = 'accepted' then
    raise exception 'La deuda entre ustedes ya pasó al cruce' using hint = 'alreadyMoved';
  end if;
  update public.parche_cruce_transfers set status = 'rejected', responded_at = now()
    where id = p_id
    returning * into v_transfer;
  return v_transfer;
end $$;

-- La función de antes, para las apps que todavía la llaman: ahora solo propone (no crea el movimiento).
create or replace function public.move_parche_debt_to_cruce(p_parche uuid, p_other uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
begin
  return public.propose_parche_debt_to_cruce(p_parche, p_other);
end $$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────
revoke all on function public.propose_parche_debt_to_cruce(uuid, uuid) from public, anon;
revoke all on function public.accept_parche_cruce_transfer(uuid) from public, anon;
revoke all on function public.reject_parche_cruce_transfer(uuid) from public, anon;
grant execute on function public.propose_parche_debt_to_cruce(uuid, uuid) to authenticated;
grant execute on function public.accept_parche_cruce_transfer(uuid) to authenticated;
grant execute on function public.reject_parche_cruce_transfer(uuid) to authenticated;

-- Ayudas internas: no se llaman desde la app.
revoke all on function public.parche_balances(uuid) from public, anon, authenticated;
revoke all on function public.parche_settlement_plan(uuid) from public, anon, authenticated;
revoke all on function public.shared_open_ledger(uuid, uuid) from public, anon, authenticated;
