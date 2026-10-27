# Tasks

## 1. CruceCore

- [x] 1.1 Escribir antes las pruebas y verlas fallar (repositorio que falla y se recupera, más un almacenamiento local en memoria):
  - sin red, guardar deja el gasto en pantalla, 1 pendiente y la cola en el almacenamiento;
  - al recuperarse y reintentar, el gasto llega al repositorio una vez y la cola queda vacía (cambia la prueba vieja, que aseguraba que se perdía);
  - recargar sin red no borra lo pendiente;
  - anotar y luego eliminar sin red llegan en orden;
  - `restore()` trae lo guardado de la misma persona e ignora lo de otra;
  - `networkChanged(false)` marca sin conexión y `networkChanged(true)` envía;
  - una operación que la base rechaza sale de la cola;
  - `reset()` vacía todo;
  - `FileLedgerLocalStore` guarda y lee un archivo temporal.
  
  Implementar `LedgerLocalStore`, `LedgerPendingOperation`, `FileLedgerLocalStore`, `InMemoryLedgerLocalStore` y los cambios en `LedgerStore`. Verificar con `swift test` y el lint.

## 2. App

- [x] 2.1 `NetworkMonitor` con `NWPathMonitor`, que llama `ledger.networkChanged`. `AppStores.live()` con `FileLedgerLocalStore.standard()`. `MainView` hace `restore()` antes de la primera carga. "Cerrar sesión" (Ajustes e Invitar) llama `ledger.reset()`. `SupabaseLedgerRepository` distingue "sin red" de "la base lo rechazó". Verificar compilando los tres esquemas.
- [x] 2.2 De punta a punta en el simulador contra Supabase local:
  - sin red (con `supabase stop` como corte), Joan anota un gasto: ve "Sin conexión" y 1 pendiente;
  - cierra y abre la app: el gasto sigue;
  - vuelve la red (`supabase start`) y "Reintentar" o volver a la app lo envía: el gasto aparece una sola vez en la base.

## 3. Documentación y cierre

- [x] 3.1 Actualizar:
  - CLAUDE.md §2, §6 y §8;
  - ROADMAP: marcar el CP7, resolver la decisión "persistencia local: archivo JSON" y cambiar la regla de conflictos;
  - `ios/README.md`.
  
  Verificar con la suite completa: `swift test`, el lint, el backend, `supabase test db` y los tres esquemas.

## Workflow follow-up

- Archivar cuando se pruebe en testing (modo avión en "Cruce Test") y proponer el commit.
