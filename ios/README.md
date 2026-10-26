# Cruce · app iOS (SwiftUI)

iOS 17+, solo iPhone, modo claro. En Debug funciona con **datos de ejemplo** (`AppStores.sample`): todo el flujo se puede recorrer sin backend. Release arranca vacío, con miembros provisionales (`AppStores.live()`), hasta que el CP3/CP4 traigan la sesión real.

## Abrir el proyecto

```bash
brew install xcodegen      # una sola vez
cd ios
xcodegen                   # genera Cruce.xcodeproj desde project.yml
open Cruce.xcodeproj
```

En Xcode: **Signing & Capabilities → Team**, elige tu cuenta y corre en el simulador o en tu iPhone.
Las pruebas de la lógica y del estado de la app no necesitan Xcode ni simulador (corren también en Linux, en la CI):

```bash
cd ios/Packages/CruceCore
swift test                 # Swift Testing: saldo, pesos, fechas, repositorio, stores y navegación
```

## Formato

El formato de Swift lo define `.swift-format` en la raíz del repo (sangría de 4 espacios, líneas de hasta 120). Desde la raíz:

```bash
swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore     # revisa; no debe reportar nada
swift format --in-place --recursive ios/Cruce ios/Packages/CruceCore        # corrige el formato
```

Se nombran las dos carpetas en vez de `ios/` para no revisar el código que Xcode genera en `ios/build/` (por ejemplo `GeneratedAssetSymbols.swift`). La CI revisa con `--strict` solo `ios/Packages/CruceCore`.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `Cruce/DesignSystem` | Tokens de la guía de estilo: colores, tipografía Archivo, radios, bordes, sombras, espaciados, botones e ilustraciones. |
| `Cruce/Components` | Piezas reutilizables: tarjeta carpeta, fila de movimiento, chips, segmentado, teclado, avatar, logo. |
| `Cruce/App` | `CruceApp` (raíz de composición), `AppStores` y `.cruceStores(_:)`, `AppStores.sample` (solo Debug), `RootView`/`MainView` y `DebugScreen`. |
| `Cruce/Screens` | Las pantallas del canvas, cada una con su `#Preview`. |
| `Cruce/Resources` | Fuentes Archivo (licencia OFL), ilustraciones @2x/@3x, ícono de la app. |
| `Packages/CruceCore/Sources/CruceCore/Models` | `Member`, `Movement`, `SplitRule`, `MovementCategory`. |
| `Packages/CruceCore/Sources/CruceCore/Domain` | Lógica pura: saldo neto (`BalanceCalculator`), formato de pesos (`Money`), fechas en español. |
| `Packages/CruceCore/Sources/CruceCore/Data` | `LedgerRepository` (interfaz, `delete` es borrado suave) e `InMemoryLedgerRepository`. En el CP5 entra `SupabaseLedgerRepository`. |
| `Packages/CruceCore/Sources/CruceCore/State` | Estado de la app, `@MainActor @Observable`: `SessionStore` (sesión y etapa), `LedgerStore` (movimientos, saldo y acciones), `Router` (pila de navegación) y `Route`. |
| `Packages/CruceCore/Sources/CruceCore/Fixtures` | `MockData`: datos de ejemplo; en la app solo se usan en Debug y en las vistas previas. |
| `Packages/CruceCore/Tests/CruceCoreTests` | Pruebas de Swift Testing del saldo (con borrado suave), los pesos, las fechas, el repositorio en memoria, los stores y el `Router`. `FailingLedgerRepository` simula el almacenamiento sin conexión. |

## Pantallas del canvas → código

| Canvas | Vista |
|---|---|
| 01, 11, 12 Onboarding | `OnboardingView` |
| 13 Crear cuenta · 14 Invitar · 15 Unirse · 16 Conectados | `SignUpView`, `InviteView`, `JoinView`, `ConnectedView` |
| 02, 03, 04, 20 Inicio (vacío, te deben, debes, vista de Jesús) | `HomeView` (cambia según el saldo y quién usa la app) |
| 05 Agregar movimiento | `AddMovementView` (también edita) |
| 06 Gasto guardado | `MovementSavedSheet` |
| 07 Historial | `HistoryView` |
| 17 Detalle · 18 Eliminar | `MovementDetailView` + `DeleteConfirmation` |
| 08 Saldar · 09 A paz y salvo | `SettleView`, `SettleSuccessView` |
| 10 Sin conexión | `OfflineView` |
| 19 Ajustes | `SettingsView` |

## Reglas que el código respeta

- **Recibo rosa o verde:** sale de `Member.tikeVariant` (rosa para quien creó la cuenta, verde para quien se unió). Ver `Illustration.balance(_:variant:)`.
- **Estado:** cada vista lee solo el store que usa (`@Environment(SessionStore.self)`, `LedgerStore` o `Router`); los tres entran por `.cruceStores(_:)` en la app, `DebugScreen` y cada `#Preview`.
- **Eliminar es borrado suave:** el movimiento se marca con `deletedAt` y deja de contar y de verse.
- **Dinero:** `Int` en pesos, nunca `Double`. Formato `$30.000` con `Money.format`.
- **Saldo:** nunca se guarda; se calcula con `BalanceCalculator.net`.
- **Quién le debe a quién:** siempre con texto, signo y flecha, no solo color.

## Pendiente

- Botón oficial `SignInWithAppleButton` (requiere la membresía de Apple Developer) y sesión de Supabase.
- `SupabaseLedgerRepository` con tiempo real y cola para el modo sin conexión.
- "Cambiar monto" en Saldar (pago parcial), exportar CSV y desvincular.
