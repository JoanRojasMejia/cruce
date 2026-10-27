# Proposal

## Why

Desde el CP4b la app trabaja con varios cruces, pero los movimientos todavía viven solo en la memoria del iPhone:
- lo que anota Joan no le llega a Jesús;
- al cerrar la app se pierde;
- cada cruce real arranca en $0;
- la deuda que un parche pasa al cruce ya se guarda en `movements`, pero nadie la ve.

El CP5 conecta los movimientos con Supabase, por cruce, para que los dos vean lo mismo.

## What Changes

- **`SupabaseLedgerRepository`:** implementa `LedgerRepository` contra la tabla `movements` (con RLS), por cruce (`ledger_id`). Carga todos los movimientos del cruce, también los eliminados. Guardar crea o edita por `id`: el `id` lo genera la app, así un reintento no duplica. Eliminar marca `deleted_at` (borrado suave).
- **Traducción del JSON en CruceCore (`MovementRemote`):**
  - `kind`;
  - `split_type` y `other_share_percent` ↔ `SplitRule`;
  - `occurred_at` ↔ `date`;
  - `payment_method` y `deleted_at`.
  
  Se prueba con JSON de ejemplo y `swift test`, como `ParcheRemote`.
- **`AppStores.live()`** usa el repositorio real. Los datos de ejemplo siguen solo en Debug con `-screen` y en las vistas previas.
- **Recargar:**
  - deslizar hacia abajo en el inicio y en "Tus cruces" vuelve a cargar los movimientos;
  - también se recargan al volver a la app desde el fondo.
  
  El tiempo real es el CP6.
- **Cuadre con la base (solo en Debug):** después de cargar, se compara el saldo que calcula la app con `ledger_balances` y, si no coinciden, se avisa en la consola.
- **La deuda que viene de un parche** aparece en el cruce como un movimiento más ("Parche Santa Marta").

**Fuera de alcance:**
- tiempo real (CP6);
- cola sin conexión guardada en el teléfono (CP7). Hoy, si falla guardar, el movimiento queda en pantalla y se marca "sin conexión", como ya pasa.

## Capabilities

### New Capabilities
<!-- Ninguna. -->

### Modified Capabilities
- `movimientos`:
  - los movimientos se guardan en la nube y los dos los ven;
  - recargar;
  - guardar dos veces el mismo movimiento no lo duplica;
  - la deuda de un parche se ve en el cruce.
  
  El cuadre con `ledger_balances` es una verificación de Debug, no un comportamiento de la app: va en el diseño.

## Impact

- **CruceCore:** `MovementRemote` (JSON ↔ `Movement`) con sus pruebas.
- **App:**
  - `ios/Cruce/Data/SupabaseLedgerRepository.swift` (nuevo);
  - `AppStores.live()`;
  - `.refreshable` en `HomeView` y `CruceListView`;
  - recarga al volver a la app (`scenePhase`);
  - el cuadre en Debug.
- **Base de datos:** sin migraciones; se usan la tabla `movements`, sus reglas y la vista `ledger_balances`. Se agrega una prueba pgTAP de que la otra persona del cruce puede editar y eliminar (borrado suave) un movimiento, y un tercero no.
- **Documentación:** CLAUDE.md §2, §6 y §8, ROADMAP e `ios/README.md`.
- **Sin dependencias nuevas.**
