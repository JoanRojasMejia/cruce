# Proposal

## Why

Desde el CP5, si guardar un gasto falla por falta de red, el gasto queda solo en la memoria de la app: al recargar o al cerrarla se pierde. Antes de usar Cruce con plata real hay que poder anotar sin señal y que todo llegue a la base cuando vuelva la red, sin perder ni duplicar nada.

## What Changes

- **Lo del cruce se guarda en el teléfono.** Los movimientos de cada cruce y la cola de cambios pendientes se guardan en un archivo JSON (`Application Support/Cruce/movimientos.json`), con el mismo patrón que la cola de parches. Decisión de Joan: archivo JSON, no SwiftData.
- **Abrir sin red.** La app muestra lo último que tenía guardado y lo pendiente, aunque no haya red.
- **Cola de pendientes.**
  - Anotar, editar, eliminar o saldar sin red queda en la cola, en orden.
  - Al volver la red se envía sola, porque `NWPathMonitor` detecta la red. "Reintentar", en la pantalla sin conexión, también la envía.
  - Lo enviado no se duplica (`upsert` por `id`), y lo pendiente no desaparece al recargar.
- **La red de verdad.** `isOffline` refleja si hay red y si algo no se pudo enviar.
- **Conflictos.** Si el mismo movimiento se editó en los dos iPhone, gana el último cambio que llega a la base.
- **Cerrar sesión borra lo guardado en el teléfono**, para que quien entre después no vea los datos de otra persona.

## Capabilities

### New Capabilities
<!-- Ninguna. -->

### Modified Capabilities
- `movimientos`:
  - anotar sin conexión;
  - enviar lo pendiente al volver la red;
  - abrir la app sin red;
  - nada se pierde ni se duplica.

## Impact

- **CruceCore:**
  - `LedgerLocalStore` (protocolo), `FileLedgerLocalStore` e `InMemoryLedgerLocalStore`;
  - `LedgerPendingOperation`;
  - `LedgerStore`: `restore()`, cola, `flush()`, `networkChanged(isAvailable:)` y `reset()`;
  - pruebas.
- **App:**
  - `NetworkMonitor` (`NWPathMonitor`);
  - `AppStores.live()`;
  - `MainView`: restaurar al arrancar y enviar al volver la red;
  - "Cerrar sesión" limpia lo guardado.
- **Sin migraciones ni dependencias nuevas.** `Network` viene con iOS.
