# Proposal

## Why

La migración de Supabase se escribió pero nunca se ha aplicado. Antes de conectar la app (CP3 a CP5) hay que probar en una base real que el saldo, la vinculación de las dos personas y la privacidad de los datos funcionan como dicen las reglas de producto.

## What Changes

- Supabase en local con Docker (`supabase init`, `start`, `db reset`) aplicando `supabase/migrations/`.
- Pruebas SQL con pgTAP en `supabase/tests/`, que corren con `supabase test db`.
- Correcciones a la migración inicial si las pruebas encuentran errores. Se puede editar porque nunca se ha aplicado en la nube.
- Proyecto de Supabase en la nube con la migración aplicada (`supabase db push`).

## Capabilities

### New Capabilities
- `vinculacion`: crear la cuenta compartida, invitar con un código y unirse; máximo dos personas.
- `privacidad-datos`: cada persona solo ve y modifica los datos de sus propias cuentas.

### Modified Capabilities
- `movimientos`: quien paga un movimiento tiene que pertenecer a la cuenta.

## Impact

- Nuevo: `supabase/config.toml`, `supabase/tests/*.sql`.
- Posible cambio: `supabase/migrations/20261024000000_init.sql`.
- Documentación: `supabase/README.md`, `docs/ROADMAP.md`, `CLAUDE.md`.
- Dependencia de desarrollo: la CLI de Supabase (Homebrew) y Docker Desktop. La app iOS y el backend de Go no cambian.
