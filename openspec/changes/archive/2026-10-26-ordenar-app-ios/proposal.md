# Proposal

## Why

`AppState` es hoy un solo objeto que guarda la sesión, los movimientos, la navegación y las hojas que se abren; cualquier pantalla puede tocarlo todo y nada de eso tiene pruebas, porque vive en la app (Swift 5, solo compila con Xcode). Además, eliminar un movimiento lo borra de verdad (`InMemoryLedgerRepository.delete` hace `storage[id] = nil`), lo que contradice la regla 8 de `CLAUDE.md` y la base de datos (`movements.deleted_at`), y algunas pantallas leen `MockData` o un código fijo (`"CRZ-4821"`) directamente. El CP3 (inicio de sesión) y el CP5 (`SupabaseLedgerRepository`) van a apoyarse en estas piezas, así que conviene ordenarlas antes.

Es el tercero y último de los cambios de herramientas que van antes del CP3 (después de `base-de-calidad` y `endurecer-rls`).

## What Changes

- **Separar `AppState`** en tres objetos pequeños `@Observable @MainActor`, inyectados por el `Environment` de SwiftUI, sin ViewModels por pantalla, sin TCA, sin coordinador y sin framework de inyección:
  - `SessionStore`: quién usa la app y con quién comparte (`me`, `partner`), la etapa del flujo de entrada (`phase`), el código de invitación y `signOut`.
  - `LedgerStore`: los movimientos, `save`, `delete`, `settle`, `retrySync`, el estado de sincronización y `lastSaved`/`lastSettlement`; recibe el `LedgerRepository` en su `init`.
  - `Router`: la pila de navegación (`path: [Route]`) y sus ayudas (abrir, volver, volver al inicio).
  - `AppState` desaparece. `CruceApp` queda como raíz de composición: arma los tres objetos y los inyecta.
- **Borrado suave**: `Movement` gana `deletedAt: Date?`; eliminar marca el movimiento en vez de quitarlo. El saldo, el inicio, el historial, el detalle y "movimientos desde el último pago" ignoran los eliminados. El aviso al otro miembro queda para el tiempo real (CP6) y las notificaciones (CP9).
- **Sin datos de ejemplo en las pantallas**: `MockData` solo se usa en vistas previas, pruebas y la configuración Debug. Se quitan `"CRZ-4821"` y las lecturas directas de `MockData` de `InviteView`, `JoinView` y `OnboardingView`. En Debug la app sigue arrancando con los datos de ejemplo, sembrados desde la raíz de composición y no desde las vistas.
- **Pruebas del estado** con Swift Testing para `LedgerStore`, `SessionStore`, `Router` y el repositorio en memoria, que corren con `swift test` (también en Linux, en la CI existente).
- **Sin cambios visuales**: todas las pantallas se ven igual; se comparan capturas de `DebugScreen` antes y después.
- **Documentación**: `CLAUDE.md` (§5 ilustraciones, §6 piezas clave, §3 estructura), `ios/README.md` y la línea de `AppState` en el CP6 de `docs/ROADMAP.md`.

No es parte de este cambio: pasar la app a Swift 6, red o Supabase (CP5), inicio de sesión (CP3), deshacer un borrado ni cambios de diseño.

## Capabilities

### New Capabilities
<!-- Ninguna. -->

### Modified Capabilities
- `movimientos`: eliminar un movimiento pasa a ser un borrado suave; el movimiento se conserva marcado y deja de verse y de contar.
- `saldo-neto`: se precisa que los movimientos eliminados no son "vigentes" y no cuentan en el saldo ni en el pago para saldar.
- `saldar-cuentas`: los movimientos eliminados no cuentan como "movimientos desde el último pago", y un pago eliminado no es el último pago.
- `pruebas-logica`: se agregan pruebas del estado de la app (guardar, eliminar, saldar, falla de sincronización y navegación) que corren sin Xcode ni simulador, y la cobertura mínima incluye el borrado suave.

## Impact

- **CruceCore** (`ios/Packages/CruceCore`): `Movement.deletedAt`; `BalanceCalculator` filtra los eliminados; se mudan al paquete `Route`, `LedgerRepository`, `InMemoryLedgerRepository` y los tres stores (carpetas nuevas `Data/` y `State/`); pruebas nuevas en `Tests/CruceCoreTests/`.
- **App** (`ios/Cruce`): se borra `App/AppState.swift` y `Data/LedgerRepository.swift`; cambian `CruceApp`, `RootView`/`MainView`, `DebugScreen` y todas las pantallas que hoy leen `@Environment(AppState.self)` (lectura de los nuevos objetos, sin cambios de diseño); las vistas previas usan un ayudante de datos de ejemplo solo de Debug. Hay que volver a correr `xcodegen`.
- **Base de datos**: ninguna; `deleted_at` y el índice parcial `where deleted_at is null` ya existen.
- **Dependencias**: ninguna nueva. Se usa `Observation`, que viene con la herramienta de Swift en Mac y Linux.
- **Riesgo**: regresiones de navegación y vistas previas o pantallas que fallen en tiempo de ejecución por un objeto que falta en el `Environment`.
