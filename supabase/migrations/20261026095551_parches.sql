-- Cruce · parches
-- Grupos de varias personas con inicio y fin (un viaje, una cena), aparte del cruce de dos.
-- Todo se nombra por participante (parche_participants.id), no por cuenta: así quien no tiene la app
-- también paga, debe y aparece en la actividad. Dinero en pesos enteros (bigint); el saldo nunca se guarda.
--
-- La app lee las tablas con RLS (solo los del parche) y escribe solo con las funciones de abajo
-- (security definer): guardar un gasto toca varias tablas a la vez y tiene que ser una sola transacción.
--
-- Errores de las funciones: excepción con errcode P0001, mensaje en español y una pista (hint) que dice qué pasó,
-- igual que ParcheRepositoryError en CruceCore: notAuthenticated, invalidCode, alreadyParticipant, notFound,
-- notAllowed, parcheClosed, parcheOpen, invalidData, noSharedCruce, alreadyMoved, nothingToMove.
-- Los datos que no cumplen las reglas (checks y la validación de sumas) dan errcode 23514 (check_violation).

-- ─────────────────────────────────────────────────────────────
-- Tipos
-- ─────────────────────────────────────────────────────────────
create type public.parche_status as enum ('open', 'closed');
-- Igual que ParcheSplit.method.
create type public.parche_split_method as enum ('equal', 'items', 'shares', 'percentage');
-- Igual que ParcheActivityKind (rawValue).
create type public.parche_activity_kind as enum (
  'parcheCreated', 'expenseCreated', 'expenseEdited', 'expenseDeleted', 'paymentRecorded', 'paymentConfirmed',
  'participantAdded', 'participantJoined', 'placeClaimed', 'parcheClosed', 'debtMovedToCruce'
);

-- ─────────────────────────────────────────────────────────────
-- Tablas
-- ─────────────────────────────────────────────────────────────
create table public.parches (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 60),
  -- Para unirse: PCH- y 6 caracteres sin ambiguos (sin 0/O, 1/I/L).
  code       text not null unique check (code ~ '^PCH-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'),
  status     public.parche_status not null default 'open',
  created_at timestamptz not null default now(),
  closed_at  timestamptz,
  constraint closed_has_date check ((status = 'closed') = (closed_at is not null))
);

create table public.parche_participants (
  id           uuid primary key default gen_random_uuid(),
  parche_id    uuid not null references public.parches (id) on delete cascade,
  -- La cuenta de quien tiene la app; null si no la tiene.
  user_id      uuid references auth.users (id) on delete set null,
  display_name text not null check (char_length(display_name) between 1 and 40),
  -- Para quedarse con el lugar: SOY- y 6 caracteres. Solo mientras no tenga la app.
  claim_code   text unique check (claim_code ~ '^SOY-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'),
  -- Define el orden del parche (desempates del reparto y de las transferencias).
  joined_at    timestamptz not null default now(),
  last_seen_at timestamptz,
  unique (parche_id, user_id),
  -- Para que las demás tablas exijan que el participante sea de ese parche.
  unique (parche_id, id),
  constraint claim_code_without_app check (claim_code is null or user_id is null)
);
-- is_parche_member y "mis parches" filtran por user_id.
create index parche_participants_user_id_idx on public.parche_participants (user_id);

create table public.parche_expenses (
  -- Lo genera la app para que los reintentos sin conexión sean idempotentes.
  id           uuid primary key default gen_random_uuid(),
  parche_id    uuid not null references public.parches (id) on delete cascade,
  concept      text not null check (char_length(concept) between 1 and 80),
  -- Monto antes de la propina.
  base_amount  bigint not null check (base_amount > 0),
  tip_percent  smallint not null default 0 check (tip_percent between 0 and 100),
  -- Total con propina (redondeo hacia abajo); es lo que suman pagadores y partes.
  amount       bigint not null check (amount > 0),
  spent_on     timestamptz not null default now(),
  split_method public.parche_split_method not null,
  -- Participantes (no cuentas): quién lo anotó, lo editó por última vez y lo borró.
  recorded_by  uuid not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid,
  deleted_at   timestamptz,
  deleted_by   uuid,
  constraint amount_includes_tip check (amount = base_amount + base_amount * tip_percent / 100),
  constraint recorded_by_in_parche foreign key (parche_id, recorded_by)
    references public.parche_participants (parche_id, id) on delete cascade,
  constraint updated_by_in_parche foreign key (parche_id, updated_by)
    references public.parche_participants (parche_id, id) on delete cascade,
  constraint deleted_by_in_parche foreign key (parche_id, deleted_by)
    references public.parche_participants (parche_id, id) on delete cascade
);
create index parche_expenses_parche_idx on public.parche_expenses (parche_id);

-- Cuánto pagó cada pagador. Suman el total del gasto (validación diferida).
create table public.parche_expense_payers (
  expense_id     uuid not null references public.parche_expenses (id) on delete cascade,
  participant_id uuid not null references public.parche_participants (id) on delete cascade,
  amount         bigint not null check (amount > 0),
  primary key (expense_id, participant_id)
);
create index parche_expense_payers_participant_idx on public.parche_expense_payers (participant_id);

-- Lo que le toca a cada uno, ya resuelto en pesos, y el dato de entrada (1, sus partes o su porcentaje;
-- null en el reparto por consumo). Suman el total del gasto (validación diferida).
create table public.parche_expense_shares (
  expense_id     uuid not null references public.parche_expenses (id) on delete cascade,
  participant_id uuid not null references public.parche_participants (id) on delete cascade,
  amount         bigint not null check (amount >= 0),
  input          integer check (input >= 0),
  primary key (expense_id, participant_id)
);
create index parche_expense_shares_participant_idx on public.parche_expense_shares (participant_id);

-- Ítems del reparto por consumo, en el orden en que se anotaron. Suman el monto base.
create table public.parche_expense_items (
  id              uuid primary key default gen_random_uuid(),
  expense_id      uuid not null references public.parche_expenses (id) on delete cascade,
  position        smallint not null check (position >= 0),
  amount          bigint not null check (amount > 0),
  -- Quienes lo consumieron (ordenados y sin repetir); la validación revisa que sean del parche.
  participant_ids uuid[] not null check (cardinality(participant_ids) >= 1),
  unique (expense_id, position)
);

-- Pagos entre dos del parche. Solo cuentan en el saldo cuando confirmed_at no es null.
create table public.parche_payments (
  -- Lo genera la app para que los reintentos sin conexión sean idempotentes.
  id           uuid primary key default gen_random_uuid(),
  parche_id    uuid not null references public.parches (id) on delete cascade,
  from_id      uuid not null,
  to_id        uuid not null,
  amount       bigint not null check (amount > 0),
  recorded_by  uuid not null,
  created_at   timestamptz not null default now(),
  confirmed_at timestamptz,
  constraint payment_between_two check (from_id <> to_id),
  constraint payment_from_in_parche foreign key (parche_id, from_id)
    references public.parche_participants (parche_id, id) on delete cascade,
  constraint payment_to_in_parche foreign key (parche_id, to_id)
    references public.parche_participants (parche_id, id) on delete cascade,
  constraint payment_recorded_by_in_parche foreign key (parche_id, recorded_by)
    references public.parche_participants (parche_id, id) on delete cascade
);
create index parche_payments_parche_idx on public.parche_payments (parche_id);

-- Deudas entre dos que pasaron a su cruce. En el parche cuentan como un pago confirmado de from_id a to_id.
create table public.parche_cruce_transfers (
  id          uuid primary key default gen_random_uuid(),
  parche_id   uuid not null references public.parches (id) on delete cascade,
  from_id     uuid not null,
  to_id       uuid not null,
  amount      bigint not null check (amount > 0),
  movement_id uuid references public.movements (id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint transfer_between_two check (from_id <> to_id),
  constraint transfer_from_in_parche foreign key (parche_id, from_id)
    references public.parche_participants (parche_id, id) on delete cascade,
  constraint transfer_to_in_parche foreign key (parche_id, to_id)
    references public.parche_participants (parche_id, id) on delete cascade
);
-- Una sola vez por par, sin importar quién le debía a quién.
create unique index parche_cruce_transfers_pair_idx
  on public.parche_cruce_transfers (parche_id, least(from_id, to_id), greatest(from_id, to_id));
create index parche_cruce_transfers_movement_idx on public.parche_cruce_transfers (movement_id);

-- Avisos dentro de la app. La escriben solo los triggers.
create table public.parche_activity (
  id                   uuid primary key default gen_random_uuid(),
  parche_id            uuid not null references public.parches (id) on delete cascade,
  kind                 public.parche_activity_kind not null,
  -- Participante que hizo la acción (null si la hizo la base sin sesión).
  actor_id             uuid references public.parche_participants (id) on delete cascade,
  -- La persona de la que se trata: la agregada, la que se unió o reclamó su lugar; quien pagó o quien debía.
  participant_id       uuid references public.parche_participants (id) on delete cascade,
  -- La otra persona: quien recibió el pago o a quien le debían.
  other_participant_id uuid references public.parche_participants (id) on delete cascade,
  -- Quien anotó el gasto o el pago (para "editó un gasto que anotaste").
  recorded_by_id       uuid references public.parche_participants (id) on delete cascade,
  expense_id           uuid references public.parche_expenses (id) on delete cascade,
  payment_id           uuid references public.parche_payments (id) on delete cascade,
  amount               bigint,
  concept              text,
  created_at           timestamptz not null default now()
);
create index parche_activity_parche_created_idx on public.parche_activity (parche_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- Quién soy en un parche
-- ─────────────────────────────────────────────────────────────

-- El participante de quien hace la petición en ese parche, o null si no es del parche.
create function public.my_parche_participant_id(p_parche uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select id from public.parche_participants where parche_id = p_parche and user_id = auth.uid();
$$;

-- La usan las políticas de RLS; security definer evita la recursión con parche_participants.
create function public.is_parche_member(p_parche uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.parche_participants where parche_id = p_parche and user_id = auth.uid()
  );
$$;

-- ─────────────────────────────────────────────────────────────
-- Ayudas internas
-- ─────────────────────────────────────────────────────────────

-- Un código nuevo (PCH- o SOY-) que no usa ningún parche ni ningún lugar.
-- Los caracteres salen de gen_random_uuid() (aleatorio criptográfico): 31^6 ≈ 887 millones de códigos.
create function public.generate_parche_code(p_prefix text) returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes    bytea;
  v_code     text;
  v_attempts int := 0;
begin
  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 50 then
      raise exception 'No se pudo generar un código, intenta de nuevo';
    end if;
    v_bytes := uuid_send(gen_random_uuid());
    v_code := p_prefix;
    for i in 0..5 loop
      v_code := v_code || substr(v_alphabet, get_byte(v_bytes, i) % 31 + 1, 1);
    end loop;
    exit when not exists (select 1 from public.parches where code = v_code)
      and not exists (select 1 from public.parche_participants where claim_code = v_code);
  end loop;
  return v_code;
end $$;

create function public.require_session() returns void
language plpgsql stable set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión' using hint = 'notAuthenticated';
  end if;
end $$;

-- Lanza parcheClosed si el parche no está abierto.
create function public.require_open_parche(p_parche uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.parches where id = p_parche and status = 'open') then
    raise exception 'El parche está cerrado' using hint = 'parcheClosed';
  end if;
end $$;

-- Lo esencial de un gasto como jsonb (para saber si un reenvío trae cambios): campos, pagadores y partes
-- ordenados por participante, e ítems en orden. Si el gasto no existe, null.
create function public.parche_expense_snapshot(p_expense uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'concept', e.concept, 'base_amount', e.base_amount, 'tip_percent', e.tip_percent, 'amount', e.amount,
    'spent_on', e.spent_on, 'split_method', e.split_method::text,
    'payers', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', p.participant_id, 'amount', p.amount)
                 order by p.participant_id), '[]'::jsonb)
               from public.parche_expense_payers p where p.expense_id = e.id),
    'shares', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', s.participant_id, 'amount', s.amount,
                 'input', s.input) order by s.participant_id), '[]'::jsonb)
               from public.parche_expense_shares s where s.expense_id = e.id),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('amount', i.amount, 'participant_ids', to_jsonb(i.participant_ids))
                order by i.position), '[]'::jsonb)
              from public.parche_expense_items i where i.expense_id = e.id))
  from public.parche_expenses e where e.id = p_expense;
$$;

-- ─────────────────────────────────────────────────────────────
-- Validación de sumas (constraint triggers diferidos: se revisa al final de la transacción,
-- cuando el gasto ya tiene sus pagadores, partes e ítems)
-- ─────────────────────────────────────────────────────────────
create function public.validate_parche_expense() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  -- La misma función sirve para las cuatro tablas: en parche_expenses el gasto es id; en las demás, expense_id.
  v_row     jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_id      uuid := (v_row ->> case when tg_table_name = 'parche_expenses' then 'id' else 'expense_id' end)::uuid;
  v_expense public.parche_expenses%rowtype;
begin
  select * into v_expense from public.parche_expenses where id = v_id;
  -- Si el gasto ya no existe (se borró el parche), no hay nada que revisar.
  if not found then
    return null;
  end if;

  if not exists (select 1 from public.parche_expense_payers where expense_id = v_id) then
    raise exception 'El gasto necesita al menos un pagador'
      using errcode = 'check_violation', hint = 'invalidData';
  end if;
  if exists (
    select 1 from public.parche_expense_payers p
    where p.expense_id = v_id
      and not exists (select 1 from public.parche_participants pp where pp.id = p.participant_id and pp.parche_id = v_expense.parche_id)
    union all
    select 1 from public.parche_expense_shares s
    where s.expense_id = v_id
      and not exists (select 1 from public.parche_participants pp where pp.id = s.participant_id and pp.parche_id = v_expense.parche_id)
    union all
    select 1 from public.parche_expense_items i, unnest(i.participant_ids) as item_participant
    where i.expense_id = v_id
      and not exists (select 1 from public.parche_participants pp where pp.id = item_participant and pp.parche_id = v_expense.parche_id)
  ) then
    raise exception 'Alguien del gasto no está en el parche'
      using errcode = 'check_violation', hint = 'invalidData';
  end if;
  if (select coalesce(sum(amount), 0) from public.parche_expense_payers where expense_id = v_id) <> v_expense.amount then
    raise exception 'Los pagos no suman el total del gasto'
      using errcode = 'check_violation', hint = 'invalidData';
  end if;
  if (select coalesce(sum(amount), 0) from public.parche_expense_shares where expense_id = v_id) <> v_expense.amount then
    raise exception 'Las partes no suman el total del gasto'
      using errcode = 'check_violation', hint = 'invalidData';
  end if;
  if v_expense.split_method = 'items'
     and (select coalesce(sum(amount), 0) from public.parche_expense_items where expense_id = v_id) <> v_expense.base_amount then
    raise exception 'Los ítems no suman el monto del gasto'
      using errcode = 'check_violation', hint = 'invalidData';
  end if;
  return null;
end $$;

create constraint trigger parche_expenses_valid
  after insert or update on public.parche_expenses
  deferrable initially deferred
  for each row execute function public.validate_parche_expense();
create constraint trigger parche_expense_payers_valid
  after insert or update or delete on public.parche_expense_payers
  deferrable initially deferred
  for each row execute function public.validate_parche_expense();
create constraint trigger parche_expense_shares_valid
  after insert or update or delete on public.parche_expense_shares
  deferrable initially deferred
  for each row execute function public.validate_parche_expense();
create constraint trigger parche_expense_items_valid
  after insert or update or delete on public.parche_expense_items
  deferrable initially deferred
  for each row execute function public.validate_parche_expense();

-- ─────────────────────────────────────────────────────────────
-- Reglas de cada tabla y actividad (triggers)
-- ─────────────────────────────────────────────────────────────

-- parches: el código y la fecha de creación no cambian, y un parche cerrado no se reabre.
create function public.parches_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.code is distinct from old.code or new.created_at is distinct from old.created_at then
    raise exception 'No se puede cambiar el código ni la fecha de un parche' using hint = 'notAllowed';
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

create trigger parches_before_update
  before update on public.parches
  for each row execute function public.parches_before_update();

create function public.parches_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'open' and new.status = 'closed' then
    insert into public.parche_activity (parche_id, kind, actor_id)
      values (new.id, 'parcheClosed', public.my_parche_participant_id(new.id));
  end if;
  return null;
end $$;

create trigger parches_activity
  after update on public.parches
  for each row execute function public.parches_activity();

-- parche_participants: el lugar es de una sola cuenta; al reclamarlo se borra su código.
create function public.parche_participants_before_update() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.parche_id is distinct from old.parche_id or new.joined_at is distinct from old.joined_at then
    raise exception 'No se puede cambiar el parche ni el orden de una persona' using hint = 'notAllowed';
  end if;
  if old.user_id is not null and new.user_id is distinct from old.user_id then
    raise exception 'Ese lugar ya es de alguien' using hint = 'notAllowed';
  end if;
  if new.user_id is not null then
    new.claim_code := null;
  end if;
  return new;
end $$;

create trigger parche_participants_before_update
  before update on public.parche_participants
  for each row execute function public.parche_participants_before_update();

-- Persona agregada sin la app (actor: quien la agregó), quien crea el parche (primer participante)
-- o quien se une con el código; y quien se queda con su lugar.
create function public.parche_participants_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.user_id is null then
      insert into public.parche_activity (parche_id, kind, actor_id, participant_id)
        values (new.parche_id, 'participantAdded', public.my_parche_participant_id(new.parche_id), new.id);
    elsif not exists (select 1 from public.parche_participants where parche_id = new.parche_id and id <> new.id) then
      insert into public.parche_activity (parche_id, kind, actor_id)
        values (new.parche_id, 'parcheCreated', new.id);
    else
      insert into public.parche_activity (parche_id, kind, actor_id, participant_id)
        values (new.parche_id, 'participantJoined', new.id, new.id);
    end if;
  elsif old.user_id is null and new.user_id is not null then
    insert into public.parche_activity (parche_id, kind, actor_id, participant_id)
      values (new.parche_id, 'placeClaimed', new.id, new.id);
  end if;
  return null;
end $$;

create trigger parche_participants_activity
  after insert or update on public.parche_participants
  for each row execute function public.parche_participants_activity();

-- parche_expenses: solo con el parche abierto. Quién anotó, editó y borró lo pone la base
-- (el participante de quien hace la petición); el parche, el autor y la fecha de anotación no cambian.
-- Un gasto borrado ya no se edita.
create function public.parche_expenses_before_write() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := public.my_parche_participant_id(new.parche_id);
begin
  if tg_op = 'UPDATE' and old.deleted_at is not null then
    raise exception 'Ese gasto ya se borró' using hint = 'notFound';
  end if;
  perform public.require_open_parche(new.parche_id);

  if tg_op = 'INSERT' then
    new.recorded_by := coalesce(v_me, new.recorded_by);
    new.created_at := now();
    new.updated_at := new.created_at;
    new.updated_by := null;
    new.deleted_at := null;
    new.deleted_by := null;
    return new;
  end if;

  if new.parche_id is distinct from old.parche_id
     or new.recorded_by is distinct from old.recorded_by
     or new.created_at is distinct from old.created_at then
    raise exception 'No se puede cambiar el parche, quién anotó ni cuándo se anotó un gasto' using hint = 'notAllowed';
  end if;
  new.updated_at := now();
  if new.deleted_at is not null then
    new.deleted_by := coalesce(v_me, new.deleted_by);
    new.updated_by := old.updated_by;
  else
    new.updated_by := coalesce(v_me, new.updated_by);
  end if;
  return new;
end $$;

create trigger parche_expenses_before_write
  before insert or update on public.parche_expenses
  for each row execute function public.parche_expenses_before_write();

create function public.parche_expenses_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_kind public.parche_activity_kind;
begin
  if tg_op = 'INSERT' then
    v_kind := 'expenseCreated';
  elsif old.deleted_at is null and new.deleted_at is not null then
    v_kind := 'expenseDeleted';
  else
    v_kind := 'expenseEdited';
  end if;
  insert into public.parche_activity (parche_id, kind, actor_id, recorded_by_id, expense_id, amount, concept)
    values (new.parche_id, v_kind, public.my_parche_participant_id(new.parche_id), new.recorded_by, new.id,
            new.amount, new.concept);
  return null;
end $$;

create trigger parche_expenses_activity
  after insert or update on public.parche_expenses
  for each row execute function public.parche_expenses_activity();

-- parche_payments: con el parche abierto o cerrado. Cuenta de una vez (confirmed_at) si lo anota quien recibe
-- o si quien recibe no tiene la app; si no, queda pendiente. Después solo cambia confirmed_at (de null a una fecha).
create function public.parche_payments_before_write() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.recorded_by := coalesce(public.my_parche_participant_id(new.parche_id), new.recorded_by);
    new.created_at := now();
    new.confirmed_at := case
      when new.recorded_by = new.to_id
        or exists (select 1 from public.parche_participants where id = new.to_id and user_id is null)
      then now() end;
    return new;
  end if;

  if new.parche_id is distinct from old.parche_id or new.from_id is distinct from old.from_id
     or new.to_id is distinct from old.to_id or new.amount is distinct from old.amount
     or new.recorded_by is distinct from old.recorded_by or new.created_at is distinct from old.created_at
     or (old.confirmed_at is not null and new.confirmed_at is distinct from old.confirmed_at) then
    raise exception 'Un pago anotado solo se puede confirmar' using hint = 'notAllowed';
  end if;
  return new;
end $$;

create trigger parche_payments_before_write
  before insert or update on public.parche_payments
  for each row execute function public.parche_payments_before_write();

create function public.parche_payments_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.parche_activity
      (parche_id, kind, actor_id, participant_id, other_participant_id, recorded_by_id, payment_id, amount)
      values (new.parche_id, 'paymentRecorded', new.recorded_by, new.from_id, new.to_id, new.recorded_by, new.id,
              new.amount);
  elsif old.confirmed_at is null and new.confirmed_at is not null then
    insert into public.parche_activity
      (parche_id, kind, actor_id, participant_id, other_participant_id, recorded_by_id, payment_id, amount)
      values (new.parche_id, 'paymentConfirmed', public.my_parche_participant_id(new.parche_id), new.from_id,
              new.to_id, new.recorded_by, new.id, new.amount);
  end if;
  return null;
end $$;

create trigger parche_payments_activity
  after insert or update on public.parche_payments
  for each row execute function public.parche_payments_activity();

create function public.parche_cruce_transfers_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.parche_activity (parche_id, kind, actor_id, participant_id, other_participant_id, amount)
    values (new.parche_id, 'debtMovedToCruce', public.my_parche_participant_id(new.parche_id), new.from_id,
            new.to_id, new.amount);
  return null;
end $$;

create trigger parche_cruce_transfers_activity
  after insert on public.parche_cruce_transfers
  for each row execute function public.parche_cruce_transfers_activity();

-- ─────────────────────────────────────────────────────────────
-- Deuda directa entre dos (design.md §5)
-- ─────────────────────────────────────────────────────────────

-- Lo que p_from le debe directamente a p_to (negativo si p_to le debe a p_from), igual que
-- ParcheCalculator.directDebt: por cada gasto vigente, share_from × paid_to / total (entero, hacia abajo)
-- menos lo recíproco; luego los pagos confirmados y las deudas pasadas al cruce entre los dos.
create function public.parche_direct_debt(p_parche uuid, p_from uuid, p_to uuid) returns bigint
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
                where parche_id = p_parche and from_id = p_from and to_id = p_to), 0)
    + coalesce((select sum(amount) from public.parche_cruce_transfers
                where parche_id = p_parche and from_id = p_to and to_id = p_from), 0)
  )::bigint;
$$;

-- ─────────────────────────────────────────────────────────────
-- Seguridad (RLS): los del parche ven todo su parche; nadie más ve nada
-- ─────────────────────────────────────────────────────────────
alter table public.parches enable row level security;
alter table public.parche_participants enable row level security;
alter table public.parche_expenses enable row level security;
alter table public.parche_expense_payers enable row level security;
alter table public.parche_expense_shares enable row level security;
alter table public.parche_expense_items enable row level security;
alter table public.parche_payments enable row level security;
alter table public.parche_cruce_transfers enable row level security;
alter table public.parche_activity enable row level security;

create policy "ver mis parches" on public.parches
  for select to authenticated using (public.is_parche_member(id));
create policy "ver los del parche" on public.parche_participants
  for select to authenticated using (public.is_parche_member(parche_id));
create policy "ver gastos de mis parches" on public.parche_expenses
  for select to authenticated using (public.is_parche_member(parche_id));
create policy "ver pagadores de mis parches" on public.parche_expense_payers
  for select to authenticated using (
    exists (select 1 from public.parche_expenses e where e.id = expense_id and public.is_parche_member(e.parche_id)));
create policy "ver partes de mis parches" on public.parche_expense_shares
  for select to authenticated using (
    exists (select 1 from public.parche_expenses e where e.id = expense_id and public.is_parche_member(e.parche_id)));
create policy "ver ítems de mis parches" on public.parche_expense_items
  for select to authenticated using (
    exists (select 1 from public.parche_expenses e where e.id = expense_id and public.is_parche_member(e.parche_id)));
create policy "ver pagos de mis parches" on public.parche_payments
  for select to authenticated using (public.is_parche_member(parche_id));
create policy "ver deudas pasadas al cruce de mis parches" on public.parche_cruce_transfers
  for select to authenticated using (public.is_parche_member(parche_id));
create policy "ver actividad de mis parches" on public.parche_activity
  for select to authenticated using (public.is_parche_member(parche_id));

-- ─────────────────────────────────────────────────────────────
-- Funciones que llama la app
-- ─────────────────────────────────────────────────────────────

-- create_parche(p_name, p_display_name, p_id) → uuid del parche.
-- Crea el parche abierto con su código PCH- y a quien lo crea como único participante (con p_display_name
-- o el nombre de su perfil). p_id lo puede generar la app: repetir la llamada con el mismo id devuelve el mismo parche.
create function public.create_parche(p_name text, p_display_name text default null, p_id uuid default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_name    text := btrim(coalesce(p_name, ''));
  v_display text;
  v_id      uuid := coalesce(p_id, gen_random_uuid());
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
    values (v_id, auth.uid(), v_display, now());
  return v_id;
end $$;

-- join_parche(p_code, p_display_name) → uuid del parche.
-- Se une con el código PCH- (sin importar mayúsculas ni espacios), abierto o cerrado. Si ya es participante
-- no cambia nada. Errores: invalidCode ("Ese código no existe"), invalidData (nombre).
create function public.join_parche(p_code text, p_display_name text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_parche  uuid;
  v_display text;
begin
  perform public.require_session();
  select id into v_parche from public.parches where code = upper(btrim(coalesce(p_code, '')));
  if v_parche is null then
    raise exception 'Ese código no existe' using hint = 'invalidCode';
  end if;
  if public.is_parche_member(v_parche) then
    return v_parche;
  end if;
  v_display := btrim(coalesce(nullif(btrim(p_display_name), ''),
                              (select display_name from public.profiles where id = auth.uid()), ''));
  if char_length(v_display) not between 1 and 40 then
    raise exception 'El nombre debe tener entre 1 y 40 caracteres' using hint = 'invalidData';
  end if;
  insert into public.parche_participants (parche_id, user_id, display_name, last_seen_at)
    values (v_parche, auth.uid(), v_display, now());
  return v_parche;
end $$;

-- add_parche_participant(p_parche, p_display_name, p_id) → la fila de parche_participants (con claim_code).
-- Cualquiera del parche agrega a alguien sin la app, con el parche abierto; la base le genera su código SOY-.
-- Repetir con el mismo p_id devuelve la misma persona. Errores: notFound, parcheClosed, invalidData.
create function public.add_parche_participant(p_parche uuid, p_display_name text, p_id uuid default null)
returns public.parche_participants
language plpgsql security definer set search_path = '' as $$
declare
  v_display     text := btrim(coalesce(p_display_name, ''));
  v_participant public.parche_participants%rowtype;
begin
  perform public.require_session();
  if not public.is_parche_member(p_parche) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  if p_id is not null then
    select * into v_participant from public.parche_participants where id = p_id;
    if found then
      if v_participant.parche_id <> p_parche then
        raise exception 'Esa persona ya existe' using hint = 'invalidData';
      end if;
      return v_participant;
    end if;
  end if;
  perform public.require_open_parche(p_parche);
  if char_length(v_display) not between 1 and 40 then
    raise exception 'El nombre debe tener entre 1 y 40 caracteres' using hint = 'invalidData';
  end if;
  insert into public.parche_participants (id, parche_id, display_name, claim_code)
    values (coalesce(p_id, gen_random_uuid()), p_parche, v_display, public.generate_parche_code('SOY-'))
    returning * into v_participant;
  return v_participant;
end $$;

-- claim_parche_place(p_code) → uuid del parche.
-- Se queda con el lugar del código SOY-: el participante pasa a ser suyo con todo su historial y el código
-- deja de servir. Errores: invalidCode ("Ese código no existe"), alreadyParticipant ("Ya estás en este parche").
create function public.claim_parche_place(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_participant public.parche_participants%rowtype;
begin
  perform public.require_session();
  select * into v_participant from public.parche_participants
    where claim_code = upper(btrim(coalesce(p_code, ''))) for update;
  if not found then
    raise exception 'Ese código no existe' using hint = 'invalidCode';
  end if;
  if public.is_parche_member(v_participant.parche_id) then
    raise exception 'Ya estás en este parche' using hint = 'alreadyParticipant';
  end if;
  update public.parche_participants
    set user_id = auth.uid(), claim_code = null, last_seen_at = now()
    where id = v_participant.id;
  return v_participant.parche_id;
end $$;

-- save_parche_expense(...) → uuid del gasto.
-- Crea o reemplaza (upsert por p_id) el gasto con sus pagadores, partes e ítems, en una sola transacción.
--   p_payers: [{"participant_id": uuid, "amount": int}]                  (suman p_amount)
--   p_shares: [{"participant_id": uuid, "amount": int, "input": int|null}] (suman p_amount)
--   p_items:  [{"amount": int, "participant_ids": [uuid, …]}]            (solo 'items'; suman p_base_amount)
-- p_split_method: 'equal' | 'items' | 'shares' | 'percentage'. p_amount = p_base_amount + p_base_amount × p_tip_percent / 100.
-- Reenviar el mismo contenido no cambia nada ni deja aviso; un gasto borrado no se edita (se ignora).
-- Solo con el parche abierto. Errores: notFound, parcheClosed, invalidData (concepto) y 23514 (sumas, checks).
create function public.save_parche_expense(
  p_id uuid, p_parche_id uuid, p_concept text, p_base_amount bigint, p_tip_percent integer, p_amount bigint,
  p_spent_on timestamptz, p_split_method text, p_payers jsonb, p_shares jsonb, p_items jsonb default '[]'::jsonb
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_concept  text := btrim(coalesce(p_concept, ''));
  v_existing public.parche_expenses%rowtype;
  v_incoming jsonb;
begin
  perform public.require_session();
  if not public.is_parche_member(p_parche_id) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  perform public.require_open_parche(p_parche_id);

  select * into v_existing from public.parche_expenses where id = p_id for update;
  if found then
    if v_existing.parche_id <> p_parche_id then
      raise exception 'Ese gasto no existe' using hint = 'notFound';
    end if;
    if v_existing.deleted_at is not null then
      return p_id;
    end if;
  end if;
  if char_length(v_concept) not between 1 and 80 then
    raise exception 'El concepto debe tener entre 1 y 80 caracteres' using hint = 'invalidData';
  end if;

  -- Lo que llega, con la misma forma que parche_expense_snapshot.
  v_incoming := jsonb_build_object(
    'concept', v_concept, 'base_amount', p_base_amount, 'tip_percent', p_tip_percent, 'amount', p_amount,
    'spent_on', coalesce(p_spent_on, v_existing.spent_on, now()), 'split_method', p_split_method,
    'payers', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', x.participant_id, 'amount', x.amount)
                 order by x.participant_id), '[]'::jsonb)
               from jsonb_to_recordset(coalesce(p_payers, '[]'::jsonb)) as x(participant_id uuid, amount bigint)),
    'shares', (select coalesce(jsonb_agg(jsonb_build_object('participant_id', x.participant_id, 'amount', x.amount,
                 'input', x.input) order by x.participant_id), '[]'::jsonb)
               from jsonb_to_recordset(coalesce(p_shares, '[]'::jsonb)) as x(participant_id uuid, amount bigint, input integer)),
    'items', (select coalesce(jsonb_agg(jsonb_build_object('amount', (x.item ->> 'amount')::bigint,
                'participant_ids', to_jsonb(array(
                  select distinct v::uuid from jsonb_array_elements_text(x.item -> 'participant_ids') as v order by 1)))
                order by x.n), '[]'::jsonb)
              from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as x(item, n)));

  if v_existing.id is not null then
    if public.parche_expense_snapshot(p_id) = v_incoming then
      return p_id;
    end if;
    update public.parche_expenses
      set concept = v_concept, base_amount = p_base_amount, tip_percent = p_tip_percent, amount = p_amount,
          spent_on = coalesce(p_spent_on, spent_on), split_method = p_split_method::public.parche_split_method
      where id = p_id;
    delete from public.parche_expense_payers where expense_id = p_id;
    delete from public.parche_expense_shares where expense_id = p_id;
    delete from public.parche_expense_items where expense_id = p_id;
  else
    insert into public.parche_expenses
      (id, parche_id, concept, base_amount, tip_percent, amount, spent_on, split_method, recorded_by)
      values (p_id, p_parche_id, v_concept, p_base_amount, p_tip_percent, p_amount, coalesce(p_spent_on, now()),
              p_split_method::public.parche_split_method, public.my_parche_participant_id(p_parche_id));
  end if;

  insert into public.parche_expense_payers (expense_id, participant_id, amount)
    select p_id, x.participant_id, x.amount
    from jsonb_to_recordset(coalesce(p_payers, '[]'::jsonb)) as x(participant_id uuid, amount bigint);
  insert into public.parche_expense_shares (expense_id, participant_id, amount, input)
    select p_id, x.participant_id, x.amount, x.input
    from jsonb_to_recordset(coalesce(p_shares, '[]'::jsonb)) as x(participant_id uuid, amount bigint, input integer);
  insert into public.parche_expense_items (expense_id, position, amount, participant_ids)
    select p_id, (x.n - 1)::smallint, (x.item ->> 'amount')::bigint,
           array(select distinct v::uuid from jsonb_array_elements_text(x.item -> 'participant_ids') as v order by 1)
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as x(item, n);

  -- Revisa las sumas ya (y no al final de la transacción) para que el error salga de esta llamada.
  set constraints public.parche_expenses_valid, public.parche_expense_payers_valid,
    public.parche_expense_shares_valid, public.parche_expense_items_valid immediate;
  set constraints public.parche_expenses_valid, public.parche_expense_payers_valid,
    public.parche_expense_shares_valid, public.parche_expense_items_valid deferred;
  return p_id;
end $$;

-- delete_parche_expense(p_id) → nada. Borrado suave (deleted_at, deleted_by), solo con el parche abierto.
-- Borrar uno ya borrado no hace nada. Errores: notFound, parcheClosed.
create function public.delete_parche_expense(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_expense public.parche_expenses%rowtype;
begin
  perform public.require_session();
  select * into v_expense from public.parche_expenses where id = p_id for update;
  if not found or not public.is_parche_member(v_expense.parche_id) then
    raise exception 'Ese gasto no existe' using hint = 'notFound';
  end if;
  if v_expense.deleted_at is not null then
    return;
  end if;
  perform public.require_open_parche(v_expense.parche_id);
  update public.parche_expenses set deleted_at = now() where id = p_id;
end $$;

-- record_parche_payment(p_id, p_parche_id, p_from_id, p_to_id, p_amount) → la fila de parche_payments.
-- Anota que p_from_id le pagó p_amount a p_to_id, con el parche abierto o cerrado. La base decide si cuenta de
-- una vez (confirmed_at) o queda pendiente (design.md §6). Repetir con el mismo p_id devuelve el pago guardado.
-- Errores: notFound, invalidData ("El pago no es válido").
create function public.record_parche_payment(
  p_id uuid, p_parche_id uuid, p_from_id uuid, p_to_id uuid, p_amount bigint
) returns public.parche_payments
language plpgsql security definer set search_path = '' as $$
declare
  v_payment public.parche_payments%rowtype;
begin
  perform public.require_session();
  if not public.is_parche_member(p_parche_id) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  select * into v_payment from public.parche_payments where id = p_id;
  if found then
    if v_payment.parche_id <> p_parche_id then
      raise exception 'Ese pago no existe' using hint = 'notFound';
    end if;
    return v_payment;
  end if;
  if p_amount is null or p_amount <= 0 or p_from_id is not distinct from p_to_id
     or (select count(*) from public.parche_participants where parche_id = p_parche_id and id in (p_from_id, p_to_id)) <> 2 then
    raise exception 'El pago no es válido' using hint = 'invalidData';
  end if;
  insert into public.parche_payments (id, parche_id, from_id, to_id, amount, recorded_by)
    values (coalesce(p_id, gen_random_uuid()), p_parche_id, p_from_id, p_to_id, p_amount,
            public.my_parche_participant_id(p_parche_id))
    returning * into v_payment;
  return v_payment;
end $$;

-- confirm_parche_payment(p_id) → la fila de parche_payments.
-- Solo quien recibió el pago lo confirma; confirmar uno ya confirmado no hace nada.
-- Errores: notFound, notAllowed ("Solo quien recibió el pago puede confirmarlo").
create function public.confirm_parche_payment(p_id uuid) returns public.parche_payments
language plpgsql security definer set search_path = '' as $$
declare
  v_payment public.parche_payments%rowtype;
begin
  perform public.require_session();
  select * into v_payment from public.parche_payments where id = p_id for update;
  if not found or not public.is_parche_member(v_payment.parche_id) then
    raise exception 'Ese pago no existe' using hint = 'notFound';
  end if;
  if v_payment.confirmed_at is not null then
    return v_payment;
  end if;
  if v_payment.to_id is distinct from public.my_parche_participant_id(v_payment.parche_id) then
    raise exception 'Solo quien recibió el pago puede confirmarlo' using hint = 'notAllowed';
  end if;
  update public.parche_payments set confirmed_at = now() where id = p_id returning * into v_payment;
  return v_payment;
end $$;

-- close_parche(p_id) → nada. Cualquiera del parche lo cierra; no se reabre. Cerrar uno cerrado no hace nada.
-- Errores: notFound.
create function public.close_parche(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_session();
  if not public.is_parche_member(p_id) then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
  update public.parches set status = 'closed' where id = p_id and status = 'open';
end $$;

-- move_parche_debt_to_cruce(p_parche, p_other) → la fila de parche_cruce_transfers (con movement_id).
-- Pasa al cruce lo que quien llama y p_other (participante) se deben directamente (parche_direct_debt):
-- inserta en movements del cruce que comparten (si comparten varios, el más reciente) un gasto 'full_other'
-- pagado por quien recibe, con el concepto "Parche <nombre>", y guarda la transferencia (cuenta como pago).
-- Solo con el parche cerrado y una vez por par; cualquiera de los dos la acepta.
-- Errores: notFound, parcheOpen, notAllowed (consigo mismo o sin la app), noSharedCruce, alreadyMoved, nothingToMove.
create function public.move_parche_debt_to_cruce(p_parche uuid, p_other uuid)
returns public.parche_cruce_transfers
language plpgsql security definer set search_path = '' as $$
declare
  v_parche   public.parches%rowtype;
  v_me       uuid;
  v_other    public.parche_participants%rowtype;
  v_ledger   uuid;
  v_debt     bigint;
  v_movement uuid;
  v_transfer public.parche_cruce_transfers%rowtype;
begin
  perform public.require_session();
  -- Bloquea el parche: dos aceptaciones al tiempo no crean dos movimientos.
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

  select mine.ledger_id into v_ledger
    from public.ledger_members mine
    join public.ledger_members theirs on theirs.ledger_id = mine.ledger_id and theirs.user_id = v_other.user_id
    join public.ledgers l on l.id = mine.ledger_id
    where mine.user_id = auth.uid()
    order by l.created_at desc
    limit 1;
  if v_ledger is null then
    raise exception 'No comparten un cruce' using hint = 'noSharedCruce';
  end if;
  if exists (select 1 from public.parche_cruce_transfers
             where parche_id = p_parche and least(from_id, to_id) = least(v_me, v_other.id)
               and greatest(from_id, to_id) = greatest(v_me, v_other.id)) then
    raise exception 'La deuda entre ustedes ya pasó al cruce' using hint = 'alreadyMoved';
  end if;

  v_debt := public.parche_direct_debt(p_parche, v_me, v_other.id);
  if v_debt = 0 then
    raise exception 'No se deben nada entre ustedes' using hint = 'nothingToMove';
  end if;

  -- Paga quien recibe; todo le corresponde a quien debe.
  insert into public.movements (ledger_id, kind, payer_id, amount, concept, split_type, other_share_percent, created_by)
    values (v_ledger, 'expense', case when v_debt > 0 then v_other.user_id else auth.uid() end, abs(v_debt),
            'Parche ' || v_parche.name, 'full_other', 100, auth.uid())
    returning id into v_movement;
  insert into public.parche_cruce_transfers (parche_id, from_id, to_id, amount, movement_id)
    values (p_parche, case when v_debt > 0 then v_me else v_other.id end,
            case when v_debt > 0 then v_other.id else v_me end, abs(v_debt), v_movement)
    returning * into v_transfer;
  return v_transfer;
end $$;

-- mark_parche_seen(p_id) → nada. Guarda en last_seen_at cuándo quien llama abrió el parche;
-- los avisos sin ver son la actividad con created_at posterior. Errores: notFound.
create function public.mark_parche_seen(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_session();
  update public.parche_participants set last_seen_at = now() where parche_id = p_id and user_id = auth.uid();
  if not found then
    raise exception 'Ese parche no existe' using hint = 'notFound';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Permisos
-- ─────────────────────────────────────────────────────────────

-- Supabase da por defecto todos los permisos de tabla a anon y authenticated: aquí authenticated solo lee
-- (con RLS) y anon no tiene nada. Las escrituras van por las funciones.
revoke all on public.parches, public.parche_participants, public.parche_expenses, public.parche_expense_payers,
  public.parche_expense_shares, public.parche_expense_items, public.parche_payments, public.parche_cruce_transfers,
  public.parche_activity from anon, authenticated;
grant select on public.parches, public.parche_participants, public.parche_expenses, public.parche_expense_payers,
  public.parche_expense_shares, public.parche_expense_items, public.parche_payments, public.parche_cruce_transfers,
  public.parche_activity to authenticated;

-- Las funciones que llama la app y las que usan las políticas: solo authenticated.
revoke all on function public.create_parche(text, text, uuid) from public, anon;
revoke all on function public.join_parche(text, text) from public, anon;
revoke all on function public.add_parche_participant(uuid, text, uuid) from public, anon;
revoke all on function public.claim_parche_place(text) from public, anon;
revoke all on function public.save_parche_expense(uuid, uuid, text, bigint, integer, bigint, timestamptz, text, jsonb, jsonb, jsonb) from public, anon;
revoke all on function public.delete_parche_expense(uuid) from public, anon;
revoke all on function public.record_parche_payment(uuid, uuid, uuid, uuid, bigint) from public, anon;
revoke all on function public.confirm_parche_payment(uuid) from public, anon;
revoke all on function public.close_parche(uuid) from public, anon;
revoke all on function public.move_parche_debt_to_cruce(uuid, uuid) from public, anon;
revoke all on function public.mark_parche_seen(uuid) from public, anon;
revoke all on function public.is_parche_member(uuid) from public, anon;
revoke all on function public.my_parche_participant_id(uuid) from public, anon;
grant execute on function public.create_parche(text, text, uuid) to authenticated;
grant execute on function public.join_parche(text, text) to authenticated;
grant execute on function public.add_parche_participant(uuid, text, uuid) to authenticated;
grant execute on function public.claim_parche_place(text) to authenticated;
grant execute on function public.save_parche_expense(uuid, uuid, text, bigint, integer, bigint, timestamptz, text, jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.delete_parche_expense(uuid) to authenticated;
grant execute on function public.record_parche_payment(uuid, uuid, uuid, uuid, bigint) to authenticated;
grant execute on function public.confirm_parche_payment(uuid) to authenticated;
grant execute on function public.close_parche(uuid) to authenticated;
grant execute on function public.move_parche_debt_to_cruce(uuid, uuid) to authenticated;
grant execute on function public.mark_parche_seen(uuid) to authenticated;
grant execute on function public.is_parche_member(uuid) to authenticated;
grant execute on function public.my_parche_participant_id(uuid) to authenticated;

-- Ayudas internas y funciones de triggers: no se llaman desde la app.
revoke all on function public.generate_parche_code(text) from public, anon, authenticated;
revoke all on function public.require_session() from public, anon, authenticated;
revoke all on function public.require_open_parche(uuid) from public, anon, authenticated;
revoke all on function public.parche_expense_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.parche_direct_debt(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.validate_parche_expense() from public, anon, authenticated;
revoke all on function public.parches_before_update() from public, anon, authenticated;
revoke all on function public.parches_activity() from public, anon, authenticated;
revoke all on function public.parche_participants_before_update() from public, anon, authenticated;
revoke all on function public.parche_participants_activity() from public, anon, authenticated;
revoke all on function public.parche_expenses_before_write() from public, anon, authenticated;
revoke all on function public.parche_expenses_activity() from public, anon, authenticated;
revoke all on function public.parche_payments_before_write() from public, anon, authenticated;
revoke all on function public.parche_payments_activity() from public, anon, authenticated;
revoke all on function public.parche_cruce_transfers_activity() from public, anon, authenticated;
