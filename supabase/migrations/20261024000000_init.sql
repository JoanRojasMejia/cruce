-- Cruce · esquema inicial
-- Una cuenta compartida (ledger) entre exactamente dos personas.
-- Los montos son pesos colombianos enteros (bigint). El saldo nunca se guarda: se calcula.

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────
-- Tipos
-- ─────────────────────────────────────────────────────────────
create type public.tike_variant as enum ('rosa', 'verde');
create type public.avatar_color as enum ('yellow', 'violet');
create type public.movement_kind as enum ('expense', 'settlement');
create type public.split_type as enum ('equal', 'percentage', 'full_other');
create type public.movement_category as enum ('comida', 'mercado', 'transporte', 'hogar', 'ocio', 'prestamo', 'otro');

-- ─────────────────────────────────────────────────────────────
-- Tablas
-- ─────────────────────────────────────────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  created_at   timestamptz not null default now()
);

create table public.ledgers (
  id                    uuid primary key default gen_random_uuid(),
  created_by            uuid not null references public.profiles (id),
  currency              text not null default 'COP',
  default_other_percent smallint not null default 50 check (default_other_percent between 0 and 100),
  created_at            timestamptz not null default now()
);

create table public.ledger_members (
  ledger_id    uuid not null references public.ledgers (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  tike_variant public.tike_variant not null,
  avatar_color public.avatar_color not null,
  joined_at    timestamptz not null default now(),
  primary key (ledger_id, user_id),
  unique (ledger_id, tike_variant)
);

create table public.movements (
  id                  uuid primary key default gen_random_uuid(),
  ledger_id           uuid not null references public.ledgers (id) on delete cascade,
  kind                public.movement_kind not null default 'expense',
  payer_id            uuid not null references public.profiles (id),
  amount              bigint not null check (amount > 0),
  concept             text not null check (char_length(concept) between 1 and 80),
  category            public.movement_category not null default 'otro',
  split_type          public.split_type not null default 'equal',
  -- Porcentaje del monto que le toca a quien NO pagó.
  other_share_percent smallint not null default 50 check (other_share_percent between 0 and 100),
  -- Lo que quien no pagó le debe a quien pagó, redondeado al peso.
  owed_by_other       bigint generated always as ((amount * other_share_percent + 50) / 100) stored,
  payment_method      text,
  occurred_at         timestamptz not null default now(),
  created_by          uuid not null default auth.uid() references public.profiles (id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint split_matches_percent check (
    (split_type = 'equal' and other_share_percent = 50)
    or (split_type = 'full_other' and other_share_percent = 100)
    or split_type = 'percentage'
  ),
  constraint settlement_is_full_other check (kind = 'expense' or split_type = 'full_other')
);

create index movements_ledger_occurred_idx on public.movements (ledger_id, occurred_at desc) where deleted_at is null;

create table public.invites (
  code        text primary key,
  ledger_id   uuid not null references public.ledgers (id) on delete cascade,
  created_by  uuid not null references public.profiles (id),
  expires_at  timestamptz not null default now() + interval '24 hours',
  redeemed_by uuid references public.profiles (id),
  redeemed_at timestamptz
);

-- ─────────────────────────────────────────────────────────────
-- Reglas
-- ─────────────────────────────────────────────────────────────

-- Las reglas corren como dueño (security definer): deben ver todos los miembros,
-- no solo los que RLS deja ver a quien hace la petición.

-- Máximo dos personas por cuenta.
create function public.enforce_two_members() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.ledger_members where ledger_id = new.ledger_id) >= 2 then
    raise exception 'Esta cuenta ya tiene dos personas' using errcode = 'check_violation';
  end if;
  return new;
end $$;

create trigger ledger_members_max_two
  before insert on public.ledger_members
  for each row execute function public.enforce_two_members();

-- Quien paga tiene que ser miembro de la cuenta.
create function public.enforce_payer_is_member() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.ledger_members where ledger_id = new.ledger_id and user_id = new.payer_id
  ) then
    raise exception 'Quien pagó no pertenece a esta cuenta' using errcode = 'check_violation';
  end if;
  return new;
end $$;

create trigger movements_payer_is_member
  before insert or update of payer_id, ledger_id on public.movements
  for each row execute function public.enforce_payer_is_member();

create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger movements_touch_updated_at
  before update on public.movements
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- Saldo
-- ─────────────────────────────────────────────────────────────

-- net > 0: el otro le debe a este usuario. net < 0: este usuario le debe al otro.
create view public.ledger_balances with (security_invoker = true) as
select
  lm.ledger_id,
  lm.user_id,
  coalesce(sum(
    case when m.payer_id = lm.user_id then m.owed_by_other else -m.owed_by_other end
  ), 0)::bigint as net
from public.ledger_members lm
left join public.movements m
  on m.ledger_id = lm.ledger_id and m.deleted_at is null
group by lm.ledger_id, lm.user_id;

-- ─────────────────────────────────────────────────────────────
-- Seguridad (RLS)
-- ─────────────────────────────────────────────────────────────

-- Evita recursión en las políticas de ledger_members.
create function public.is_ledger_member(p_ledger uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ledger_members where ledger_id = p_ledger and user_id = auth.uid()
  );
$$;

alter table public.profiles enable row level security;
alter table public.ledgers enable row level security;
alter table public.ledger_members enable row level security;
alter table public.movements enable row level security;
alter table public.invites enable row level security;

create policy "perfil propio o de mi pareja de cuenta" on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.ledger_members mine
      join public.ledger_members theirs on theirs.ledger_id = mine.ledger_id
      where mine.user_id = auth.uid() and theirs.user_id = profiles.id
    )
  );
create policy "crear mi perfil" on public.profiles
  for insert with check (id = auth.uid());
create policy "editar mi perfil" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy "ver mis cuentas" on public.ledgers
  for select using (public.is_ledger_member(id));
create policy "editar mis cuentas" on public.ledgers
  for update using (public.is_ledger_member(id));

create policy "ver miembros de mis cuentas" on public.ledger_members
  for select using (public.is_ledger_member(ledger_id));

create policy "ver movimientos de mis cuentas" on public.movements
  for select using (public.is_ledger_member(ledger_id));
create policy "crear movimientos en mis cuentas" on public.movements
  for insert with check (public.is_ledger_member(ledger_id) and created_by = auth.uid());
-- Eliminar es un borrado suave: se actualiza deleted_at.
create policy "editar movimientos de mis cuentas" on public.movements
  for update using (public.is_ledger_member(ledger_id)) with check (public.is_ledger_member(ledger_id));

create policy "ver mis invitaciones" on public.invites
  for select using (created_by = auth.uid());

-- ─────────────────────────────────────────────────────────────
-- Funciones que llama la app
-- ─────────────────────────────────────────────────────────────

-- Crea la cuenta compartida, agrega a quien la crea (recibo rosa, avatar amarillo)
-- y devuelve un código de invitación tipo CRZ-4821.
create function public.create_ledger_with_invite() returns text
language plpgsql security definer set search_path = public as $$
declare
  v_ledger   uuid;
  v_code     text;
  v_attempts int := 0;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  insert into ledgers (created_by) values (auth.uid()) returning id into v_ledger;
  insert into ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    values (v_ledger, auth.uid(), 'rosa', 'yellow');

  -- Un código se puede reusar solo si su invitación venció sin canjearse;
  -- las canjeadas se conservan como registro de quién se unió.
  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 200 then
      raise exception 'No se pudo generar un código, intenta de nuevo';
    end if;
    v_code := 'CRZ-' || lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from invites where code = v_code and (redeemed_at is not null or expires_at > now())
    );
  end loop;

  delete from invites where code = v_code;
  insert into invites (code, ledger_id, created_by) values (v_code, v_ledger, auth.uid());
  return v_code;
end $$;

-- Canjea un código: agrega a quien lo usa (recibo verde, avatar violeta) y devuelve el ledger.
create function public.redeem_invite(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_invite invites%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión';
  end if;

  select * into v_invite from invites where code = upper(trim(p_code)) for update;

  if not found or v_invite.redeemed_at is not null or v_invite.expires_at <= now() then
    raise exception 'El código no es válido o ya venció';
  end if;
  if v_invite.created_by = auth.uid() then
    raise exception 'No puedes usar tu propio código';
  end if;

  insert into ledger_members (ledger_id, user_id, tike_variant, avatar_color)
    values (v_invite.ledger_id, auth.uid(), 'verde', 'violet');

  update invites set redeemed_by = auth.uid(), redeemed_at = now() where code = v_invite.code;
  return v_invite.ledger_id;
end $$;

revoke all on function public.create_ledger_with_invite() from public, anon;
revoke all on function public.redeem_invite(text) from public, anon;
grant execute on function public.create_ledger_with_invite() to authenticated;
grant execute on function public.redeem_invite(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Tiempo real: los dos celulares ven los cambios al instante.
-- ─────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.movements;
