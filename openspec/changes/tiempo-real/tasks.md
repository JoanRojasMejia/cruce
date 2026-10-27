# Tasks

## 1. CruceCore

- [x] 1.1 Escribir antes las pruebas y verlas fallar:
  - `apply` agrega un gasto nuevo de la otra persona y el saldo cambia;
  - el eco del mismo `id` no duplica;
  - una edición con `deleted_at` lo saca del saldo;
  - un cambio de otro cruce no toca el cruce abierto;
  - `follow` aplica lo que llega de un `InMemoryMovementFeed`;
  - `parseTimestamp` acepta el formato con espacio y zona `+00`.
  
  Implementar `MovementFeed`, `MovementChange`, `InMemoryMovementFeed`, `LedgerStore.apply` y `follow`. Verificar con `swift test` y el lint.

## 2. App

- [x] 2.1 `SupabaseMovementFeed` (un canal por cruce, `AnyAction` con filtro `ledger_id`, traducción con `MovementRemote`, cierre al terminar). Inyectarlo en `AppStores.live()`, y que `MainView` siga los cambios en la `.task` de carga, con reconexión al volver a `.active`. Verificar compilando los tres esquemas.
- [x] 2.2 Supabase local con Realtime (sin `-x realtime`) y comando actualizado en `ios/README.md`. De punta a punta: Joan mira su inicio en el simulador y Jesús anota, edita y elimina por la API. Los cambios aparecen sin tocar nada en menos de 10 segundos, y lo que anota Joan no se duplica.

## 3. Documentación y cierre

- [x] 3.1 Actualizar CLAUDE.md §2, §6 y §8, el ROADMAP (marcar el CP6) e `ios/README.md`. Verificar con `swift test`, el lint, el backend, `supabase test db` y los tres esquemas.

## Workflow follow-up

- Archivar cuando se pruebe en testing con Joan y Jesús, y proponer el commit.
