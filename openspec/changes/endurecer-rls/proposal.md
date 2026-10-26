# Proposal

## Why

Las políticas RLS de `20261024000000_init.sql` protegen bien los datos (las 23 pruebas de `04_rls.sql` lo comprueban), pero no siguen la guía oficial de Supabase (https://supabase.com/docs/guides/database/postgres/row-level-security): llaman a `auth.uid()` fila por fila, se aplican a todos los roles (también a peticiones sin sesión) y filtran por `ledger_members.user_id` sin un índice que empiece por esa columna. Con unas 1.000 personas esto es higiene y no una emergencia de rendimiento, pero conviene dejarlo bien antes del CP3, que conecta la app con Supabase y empieza a generar tráfico real.

Es el segundo de tres cambios de herramientas antes del CP3, fuera del orden de checkpoints de `docs/ROADMAP.md`:

1. `base-de-calidad` (archivado): integración continua, formato, versiones alineadas y respaldos.
2. `endurecer-rls` (este cambio).
3. Separar `AppState` y agregar borrado suave en la app de iOS.

## What Changes

- **Una migración nueva** en `supabase/migrations/` (creada con `supabase migration new endurecer_rls`). `20261024000000_init.sql` ya está aplicada en la nube y no se toca.
- **`auth.uid()` evaluado una vez por consulta**: en las expresiones de las políticas, `auth.uid()` pasa a `(select auth.uid())`.
- **Políticas solo para `authenticated`**: las 10 políticas de `profiles`, `ledgers`, `ledger_members`, `movements` e `invites` pasan de aplicarse a todos los roles a aplicarse solo a `authenticated`; una petición sin sesión no evalúa ninguna y no ve ni escribe nada.
- **Índices para los filtros de las políticas**: `ledger_members (user_id)` e `invites (created_by)`.
- **Pruebas pgTAP nuevas** que fallan con el esquema actual y pasan con la migración: roles de cada política, forma de las expresiones, índices nuevos y acceso sin sesión.
- **Sin cambios** en permisos (`grant`/`revoke`), en el comportamiento de las funciones (`is_ledger_member`, `create_ledger_with_invite`, `redeem_invite`, triggers), en la vista `ledger_balances` ni en los contratos de las funciones que llama la app.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `privacidad-datos`: se agrega como requisito explícito que una petición sin sesión iniciada no ve ni escribe ningún dato de cuentas, miembros, movimientos, saldos, perfiles ni invitaciones. Hoy ya pasa de forma implícita (`auth.uid()` es nulo y las políticas dan falso); con este cambio queda garantizado por el rol de las políticas y cubierto por pruebas. Los requisitos existentes no cambian.

## Impact

- Archivos nuevos: `supabase/migrations/<timestamp>_endurecer_rls.sql` y `supabase/tests/05_rls_endurecido.sql`.
- Documentación: `CLAUDE.md` §2 (estado) y §9 (historial de cambios).
- Base de datos en la nube: se aplica con `supabase db push` solo cuando el usuario lo apruebe, después de un respaldo con `scripts/backup-db.sh`.
- Sin cambios en la app de iOS, en el backend en Go ni en la CI. El trabajo `supabase` de `ci.yml` corre solo porque cambia `supabase/**`.
- Sin cambios de comportamiento para quien usa la app: las mismas personas ven y escriben exactamente los mismos datos.
