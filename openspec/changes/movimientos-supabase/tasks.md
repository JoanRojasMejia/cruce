# Tasks

## 1. Traducción del JSON (CruceCore)

- [x] 1.1 Escribir antes las pruebas de `MovementRemote` y verlas fallar:
  - filas de `movements` → `Movement`: gasto 50/50, porcentaje, "todo es del otro", pago para saldar con medio de pago, y uno eliminado con `deleted_at`;
  - `Movement` → fila: `split_type` y `other_share_percent` correctos, `occurred_at` con microsegundos, sin `owed_by_other`, `created_at` ni `updated_at`;
  - un `split_type` o `kind` desconocido no se acepta.
  
  Implementar `MovementRemote`. Verificar con `swift test` y `swift format lint --strict`.

## 2. Base de datos

- [x] 2.1 Agregar a pgTAP (archivo nuevo `08_movimientos.sql`), sin migraciones:
  - la otra persona del cruce puede editar y marcar `deleted_at` en un movimiento que anotó la otra;
  - un tercero no puede ver, editar ni crear movimientos en ese cruce;
  - crear a nombre de otro (`created_by` distinto) falla;
  - un `upsert` repetido con el mismo `id` deja una sola fila.
  
  Verificar con `supabase test db` sobre una base limpia.

## 3. Repositorio y app

- [x] 3.1 `ios/Cruce/Data/SupabaseLedgerRepository.swift`:
  - `loadMovements(in:)`: `select` por `ledger_id`;
  - `save(_:in:)`: `upsert` por `id`;
  - `delete(id:in:)`: `update deleted_at`.
  
  Los errores de red se traducen como en parches. Inyectarlo en `AppStores.live()`. Verificar compilando los tres esquemas.
- [x] 3.2 Recargar:
  - `.refreshable` en `HomeView` y en `CruceListView`;
  - `MainView` recarga al volver a `.active`;
  - limitar el concepto a 80 caracteres en `AddMovementView`.
  
  Verificar en el simulador que deslizar hacia abajo recarga.
- [x] 3.3 Cuadre en Debug con `ledger_balances` después de `load()`, con un aviso en la consola si no coinciden. Verificar en la consola del simulador que no aparece el aviso con los movimientos de la prueba de punta a punta.

## 4. Verificación y documentación

- [x] 4.1 De punta a punta contra Supabase local: Joan en el simulador y Jesús por la API, con un cruce entre los dos.
  - Joan anota una cena de $60.000 a medias y Jesús la ve por la API, con `owed_by_other` = 30.000.
  - Jesús anota un mercado de $100.000 por la API, Joan desliza para recargar y ve "Le debes $20.000 a Jesús".
  - Jesús elimina la cena por la API y, al recargar, el saldo cambia.
  - Joan cierra y abre la app: los movimientos siguen.
  - Un parche cerrado con "pasar al cruce" muestra "Parche …" en el historial del cruce.
- [x] 4.2 Actualizar:
  - CLAUDE.md §2 (movimientos en Supabase), §6 (`SupabaseLedgerRepository` y `MovementRemote`) y §8 (lo no sincronizado se pierde al recargar hasta el CP7);
  - ROADMAP: marcar el CP5;
  - `ios/README.md`.
  
  Verificar que las frases que decían "en memoria hasta el CP5" ya no quedan (`rg -n "hasta el CP5" CLAUDE.md ios/README.md`).
- [ ] 4.3 Suite completa: `swift test`, el lint, el backend, `supabase test db` y `xcodebuild` de los tres esquemas. Después, en testing (sin migraciones nuevas), Joan y Jesús anotan cada uno un gasto y, al recargar, los dos ven el mismo saldo.

## Workflow follow-up

- Archivar con `openspec archive movimientos-supabase` cuando se cumpla el "Hecho cuando" del CP5 y proponer el commit.
- El cambio `varios-cruces` sigue abierto hasta probarlo en testing con una tercera cuenta.
- Siguiente: CP6 (tiempo real).
