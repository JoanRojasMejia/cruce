# Proposal

## Why

Desde el CP5, los movimientos de cada cruce están en Supabase, pero lo que anota la otra persona solo se ve al deslizar para recargar o al volver a la app. El CP6 hace que el inicio de Joan cambie solo cuando Jesús anota, edita o elimina un gasto.

## What Changes

- **Escuchar los cambios.** La app se suscribe a los cambios de `movements` (Supabase Realtime) de cada cruce de quien entró: un canal por cruce, filtrado por `ledger_id`. La tabla ya está en la publicación `supabase_realtime` desde `init.sql`, y RLS decide qué cambios recibe cada quien.
- **Aplicar sin recargar todo.** `LedgerStore` aplica cada cambio sobre los movimientos de ese cruce, reemplazando por `id`: un gasto nuevo se agrega, una edición o un borrado suave reemplazan el que había, y el eco de lo que uno mismo guardó no duplica nada.
- **Reconectar.** La suscripción se vuelve a abrir cuando cambian los cruces y cuando la app vuelve al primer plano, después de recargar.
- **Fuera de alcance:** notificaciones push (CP9) y cola sin conexión (CP7).

## Capabilities

### New Capabilities
<!-- Ninguna. -->

### Modified Capabilities
- `movimientos`: los cambios de la otra persona aparecen solos, en segundos y sin duplicados.

## Impact

- **CruceCore:**
  - `MovementFeed` (protocolo) y `MovementChange`;
  - `LedgerStore.apply(_:)` y `follow(_:)`;
  - un doble en memoria;
  - pruebas.
- **App:**
  - `SupabaseMovementFeed` (Realtime) en `ios/Cruce/Data`;
  - `AppStores.live()`;
  - `MainView`, que sigue los cambios mientras está en pantalla.
- **Supabase:** sin migraciones. En local hay que levantar Supabase sin excluir `realtime`; se actualiza el comando de `ios/README.md`.
- **Sin dependencias nuevas:** Realtime ya viene en supabase-swift.
