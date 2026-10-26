-- Cruce · endurecer RLS
-- Sigue la guía de Supabase sin cambiar quién ve o escribe qué:
--   1. Las políticas aplican solo a authenticated: sin sesión (anon) no se evalúa ninguna y no se ve nada.
--   2. (select auth.uid()) se evalúa una vez por consulta en vez de una vez por fila.
--   3. Índices en las columnas que filtran las políticas y no tenían uno.
-- Las expresiones son las de 20261024000000_init.sql; solo cambia auth.uid() por (select auth.uid()).
-- alter policy conserva el nombre y el comando de cada política.

-- ─────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────
alter policy "perfil propio o de mi pareja de cuenta" on public.profiles
  to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.ledger_members mine
      join public.ledger_members theirs on theirs.ledger_id = mine.ledger_id
      where mine.user_id = (select auth.uid()) and theirs.user_id = profiles.id
    )
  );
alter policy "crear mi perfil" on public.profiles
  to authenticated
  with check (id = (select auth.uid()));
alter policy "editar mi perfil" on public.profiles
  to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ─────────────────────────────────────────────────────────────
-- ledgers y ledger_members (is_ledger_member depende de la fila: no se envuelve)
-- ─────────────────────────────────────────────────────────────
alter policy "ver mis cuentas" on public.ledgers to authenticated;
alter policy "editar mis cuentas" on public.ledgers to authenticated;
alter policy "ver miembros de mis cuentas" on public.ledger_members to authenticated;

-- ─────────────────────────────────────────────────────────────
-- movements
-- ─────────────────────────────────────────────────────────────
alter policy "ver movimientos de mis cuentas" on public.movements to authenticated;
alter policy "crear movimientos en mis cuentas" on public.movements
  to authenticated
  with check (public.is_ledger_member(ledger_id) and created_by = (select auth.uid()));
alter policy "editar movimientos de mis cuentas" on public.movements to authenticated;

-- ─────────────────────────────────────────────────────────────
-- invites
-- ─────────────────────────────────────────────────────────────
alter policy "ver mis invitaciones" on public.invites
  to authenticated
  using (created_by = (select auth.uid()));

-- ─────────────────────────────────────────────────────────────
-- Índices para los filtros de las políticas
-- ─────────────────────────────────────────────────────────────

-- La llave primaria de ledger_members empieza por ledger_id; la política de profiles filtra por user_id.
create index ledger_members_user_id_idx on public.ledger_members (user_id);
-- invites solo tenía índice en code; la política de ver invitaciones filtra por created_by.
create index invites_created_by_idx on public.invites (created_by);
