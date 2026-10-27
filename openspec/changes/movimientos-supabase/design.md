# Design

## Context

- **`movements` en la base** (`init.sql`):
  - columnas: `id` (uuid), `ledger_id`, `kind`, `payer_id`, `amount > 0`, `concept` de 1 a 80 caracteres, `category`, `split_type`, `other_share_percent`, `owed_by_other` (generada), `payment_method`, `occurred_at`, `created_by` (por defecto `auth.uid()`), `created_at`, `updated_at` y `deleted_at`;
  - reglas: `split_matches_percent` y `settlement_is_full_other`;
  - triggers: quien paga es miembro, y `protect_movement_identity` impide cambiar `ledger_id`, `created_by` y `created_at`;
  - RLS (`endurecer_rls.sql`): ver y editar si eres miembro; crear solo con `created_by = auth.uid()`.
- **El saldo en la base:** `ledger_balances` calcula el saldo por cruce y persona.
- **La app:**
  - `LedgerRepository` ya es por cruce (CP4b) y hoy lo implementa `InMemoryLedgerRepository`;
  - `Movement` tiene `id`, `kind`, `payerID`, `amount`, `concept`, `category`, `split`, `date`, `createdBy`, `paymentMethod` y `deletedAt`;
  - `AddMovementView` ya usa la categoría como concepto cuando viene vacío;
  - `LedgerStore.load()` carga todos los cruces de la sesión y `MainView` lo llama cuando cambian los cruces.
- **El patrón a seguir:** `SupabaseParcheRepository` hace las peticiones y `ParcheRemote` (CruceCore) traduce el JSON, con sus pruebas.

## Goals / Non-Goals

**Goals:**
- Que el repositorio real sea un reemplazo directo del de memoria: `LedgerStore` y las vistas no cambian.
- Que la traducción se pruebe sin red.

**Non-Goals:**
- Tiempo real (CP6).
- Cola sin conexión guardada en disco (CP7).
- Paginar el historial: con dos personas, todos los movimientos de un cruce caben en una consulta.

## Decisions

### D1. `MovementRemote` traduce el JSON en CruceCore
- **Qué hace:**
  - `movements(from: Data) -> [Movement]` (decodifica las filas);
  - `row(for: Movement, cruce: UUID) -> Encodable` (arma la fila para `upsert`).
- **Mapeo:**
  - `split_type` + `other_share_percent` → `SplitRule`: `equal` → `.equal`, `full_other` → `.fullOther`, `percentage` → `.percentage(otherShare:)`, y al revés con `otherSharePercent`;
  - `occurred_at` ↔ `date`, con `ParcheRemote.parseTimestamp` y `timestamp`, que conservan los microsegundos.
- **Lo que no se envía:** `owed_by_other` (es generada), `created_at` ni `updated_at` (los pone la base).
- **Alternativa descartada:** hacer `Movement` `Codable` con las llaves de la base. Mezcla el modelo de dominio con el formato de PostgREST, y `SplitRule` ya tiene su propio `Codable`.

### D2. Guardar es `upsert` por `id`
- **Qué:** `save(_:in:)` hace `upsert` en `movements`, con `onConflict: id`. Sirve para crear y para editar.
- **Por qué:** el `id` lo genera la app, así que reintentar después de un error no duplica (spec "Guardar no duplica"). Editar reenvía el mismo `ledger_id` y `created_by`, que el trigger de identidad acepta.
- **Eliminar:** `delete(id:in:)` hace `update deleted_at` con la fecha del teléfono (la misma que `LedgerStore` ya puso en el movimiento), filtrando por `id` y `ledger_id`. PostgREST no deja mandar `now()` como valor.
- **Alternativa descartada:** separar `insert` y `update`. Obliga a la app a saber si el movimiento ya llegó a la base, que con errores de red no es seguro.

### D3. Cargar trae todo el cruce, también lo eliminado
- **Qué:** `loadMovements(in:)` hace `select` de las columnas que usa `Movement`, con `ledger_id = cruce` y orden por `occurred_at`.
- **Por qué los eliminados:** `LedgerStore` y `BalanceCalculator` ya ignoran lo eliminado, y el borrado suave necesita conservarlo para poder avisarle al otro.

### D4. Recargar: deslizar hacia abajo y al volver a la app
- **Deslizar:** `.refreshable { await ledger.load() }` en `HomeView` y en `CruceListView`.
- **Volver a la app:** `MainView` observa `scenePhase` y llama `ledger.load()` al pasar a `.active`.
- **Por qué no consultar cada pocos segundos, como en invitar:** el tiempo real llega en el CP6, y cargar cada 3 segundos todos los cruces gastaría batería sin necesidad.

### D5. Cuadre con `ledger_balances`, solo en Debug
- **Qué:** después de `load()`, una función de Debug lee `ledger_balances` del cruce y compara con `BalanceCalculator.net`. Si no coinciden, escribe un aviso en la consola (`Logger`).
- **Por qué no `assert`:** no debe detener la app de quien prueba.
- **En Release no corre.**

### D6. Errores
- **Lo que no cambia:** los errores de red siguen el camino de hoy (`isOffline`, `pendingSyncCount`), y `retrySync()` recarga.
- **El límite conocido:** un movimiento que no llegó a la base se pierde al recargar. Lo resuelve el CP7 con la cola en disco; mientras tanto se documenta.

## Risks / Trade-offs

- **[Concepto vacío o largo]** La base exige de 1 a 80 caracteres → La app ya pone la categoría si viene vacío. El campo se limita a 80 caracteres al escribir (se revisa en `AddMovementView`).
- **[Perder lo no sincronizado al recargar]** Si guardar falla y después se recarga, el movimiento local desaparece → Pasa poco (dos personas, casi siempre con red). Lo arregla el CP7 y va en CLAUDE.md §8.
- **[Fechas]** Un `occurred_at` con microsegundos que vuelve redondeado cambiaría el orden o la identidad → Se usa la misma traducción de fechas que en parches, probada.
- **[Pruebas en local]** Probar entre "dos iPhone" necesita dos sesiones → En local, una sesión en el simulador y la otra por la API, como en el CP4. En testing lo prueban Joan y Jesús.
