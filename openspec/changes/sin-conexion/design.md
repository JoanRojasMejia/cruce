# Design

## Context

- **`LedgerStore` (CP5 y CP6):** tiene `movementsByCruce` en memoria. Si `save`, `delete` o `settle` fallan, suben `pendingSyncCount` y `isOffline`, pero no guardan nada. `retrySync()` limpia y recarga, y ahí se pierde lo pendiente. `load()` reemplaza todo con lo de la base.
- **Parches:** ya tienen una cola sin conexión en un archivo JSON (`FilePendingStore`, `Application Support/Cruce/parches.json`), con operaciones `Codable` idempotentes por `id`.
- **La base:** `movements` guarda con `upsert` por `id` y tiene un trigger que pone `updated_at` en cada edición.
- **Decisión de Joan (27 oct 2026):** archivo JSON, no SwiftData.

## Goals / Non-Goals

**Goals:**
- No perder ni duplicar nada sin red, y que todo se pruebe con `swift test` (también en Linux).
- Mantener la API que usan las vistas (`isOffline`, `pendingSyncCount`, `retrySync()`).

**Non-Goals:**
- Resolver conflictos campo por campo.
- Sincronizar entre varios teléfonos de la misma persona más allá de lo que da la base.

## Decisions

### D1. `LedgerLocalState` en un archivo JSON
- **Qué guarda:** `userID`, `movementsByCruce: [UUID: [Movement]]` y `pending: [LedgerPendingOperation]`.
- **Las operaciones:** `.save(Movement, cruce:)` y `.delete(id:, cruce:, at:)`. Saldar es un `.save`.
- **Dónde:** `FileLedgerLocalStore` escribe `Application Support/Cruce/movimientos.json` de forma atómica. `InMemoryLedgerLocalStore` sirve para pruebas.
- **De quién es:** el `userID` evita mostrarle a alguien lo guardado de otra persona. Si no coincide con la sesión, se ignora y se borra.

### D2. Escribir primero en el teléfono, después en la base
- **Al anotar, editar, eliminar o saldar:** se cambia el cruce en memoria, se agrega la operación a la cola, se guarda el archivo y se intenta enviar la cola (`flush()`).
- **`flush()`:** envía en orden. Cada operación que llega a la base sale de la cola. La primera que falla detiene el envío y deja `isOffline = true`.
- **`pendingSyncCount`:** es el largo de la cola.
- **Por qué siempre por la cola:** es un solo camino para con red y sin red, y el orden se conserva (por ejemplo, anotar y después eliminar).

### D3. Cargar sin perder lo pendiente
- **Orden:** `load()` primero intenta `flush()`. Después trae los cruces de la base y vuelve a aplicar encima lo que siga en la cola, para que no desaparezca.
- **Si cargar falla:** se queda lo que había (lo guardado en el archivo) y `isOffline = true`.
- **Al terminar:** guarda el archivo.
- **`restore()`:** al arrancar, lee el archivo antes de la primera carga, así la app abre con datos aunque no haya red.

### D4. La red
- **En la app:** `NetworkMonitor` (`NWPathMonitor`) llama a `ledger.networkChanged(isAvailable:)`.
- **Sin red:** `isOffline = true`.
- **Al volver la red:** `flush()` y después `load()`.
- **En CruceCore:** la lógica no depende de `Network`, así se prueba en Linux.

### D5. Conflictos: gana el último cambio que llega a la base
- **Cómo funciona:** el `upsert` reemplaza la fila y el trigger pone `updated_at`. Si los dos editan el mismo movimiento, queda el último que llega a la base. Para dos personas que casi nunca editan lo mismo, alcanza.
- **El caso raro:** una edición hecha sin red y enviada tarde le gana a una más nueva del otro.
- **Alternativa descartada:** comparar `updated_at` antes de enviar. Exige leer cada fila y otro tipo de error en la cola, para un caso que casi no pasa. El ROADMAP decía "gana el último `updated_at`"; se cambia a esta regla y queda anotado.

### D6. Cerrar sesión
- **Qué hace:** "Cerrar sesión" llama `ledger.reset()`, que vacía la memoria, la cola y el archivo.
- **Lo que se pierde:** lo que estaba en la cola sin enviar. Se acepta y se documenta: "Cerrar sesión" ya es una acción explícita.

### D7. La sesión también abre sin red
- **El problema que apareció al probar:** sin red, `SessionStore.refresh()` no puede leer el perfil ni los cruces, y la app se quedaba en la etapa inicial (el onboarding).
- **Qué se agregó:** `SessionCache` guarda un `SessionSnapshot` (quién entró, `me`, sus cruces y el abierto) en `Application Support/Cruce/sesion.json` cada vez que `refresh()` sale bien.
- **Al arrancar:** `restore()` abre el inicio al instante con eso, y `refresh()` después lo confirma o lo corrige.
- **Al cerrar sesión:** se borra.

## Risks / Trade-offs

- **[Archivo grande]** Con años de movimientos el JSON crece → Con dos personas son unos cientos de KB, que alcanzan. Si algún día pesa, se cambia el almacenamiento detrás del mismo protocolo.
- **[Una operación que la base rechaza siempre]** Por ejemplo, un concepto inválido trabaría la cola para siempre → Se distingue "sin red" (`URLError`) de "la base dijo que no". Lo rechazado sale de la cola y se recarga desde la base. Se prueba con un repositorio que rechaza.
- **[Eco de Realtime con la cola]** Un cambio de la base que llega mientras hay pendientes del mismo `id` → `apply` reemplaza, y el próximo `load` vuelve a aplicar lo pendiente encima.
