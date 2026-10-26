# Cruce · app iOS (SwiftUI)

iOS 17+, solo iPhone, modo claro. La app arranca con la sesión real (`AppStores.live()`): Debug habla con Supabase local y Release con la nube. Con `-screen <nombre>` (solo Debug) abre una pantalla con **datos de ejemplo** (`AppStores.sample`), sin backend. Los movimientos siguen en memoria hasta el CP5.

## Abrir el proyecto

```bash
brew install xcodegen      # una sola vez
cd ios
xcodegen                   # genera Cruce.xcodeproj desde project.yml
open Cruce.xcodeproj
```

Antes de compilar, crea la configuración de Supabase (una sola vez; `Config.xcconfig` está en `.gitignore`):

```bash
cd ios
cp Config.example.xcconfig Config.xcconfig
supabase status -o env | rg ANON_KEY          # con `supabase start`: clave anónima local → Debug
supabase projects api-keys --project-ref pqdjiecynyjnianslikp   # fila anon → Release
```

Pega cada clave en su línea de `Config.xcconfig`. La clave anónima es pública por diseño (la protege RLS); nunca pongas la `service_role`. Si falta la configuración, la app compila pero se detiene al arrancar con un mensaje que dice qué falta.

En Xcode: **Signing & Capabilities → Team**, elige tu cuenta y corre en el simulador o en tu iPhone.
Las pruebas de la lógica y del estado de la app no necesitan Xcode ni simulador (corren también en Linux, en la CI):

```bash
cd ios/Packages/CruceCore
swift test                 # Swift Testing: saldo, pesos, fechas, repositorio, stores y navegación
```

## Entrar en local (código por correo)

Se entra con un código de 6 dígitos que llega al correo, sin contraseña. En local el correo no sale: lo atrapa mailpit.

```bash
supabase start -x realtime,storage-api,imgproxy,postgres-meta,studio,edge-runtime,logflare,vector,supavisor   # sin excluir mailpit
```

1. En la app (Debug), escribe cualquier correo (por ejemplo `joan@example.com`) y toca **Enviarme el código**.
2. Abre `http://127.0.0.1:54324` o pide el último correo por la API:
   `curl -s http://127.0.0.1:54324/api/v1/messages | jq -r '.messages[0].ID'` y luego
   `curl -s http://127.0.0.1:54324/api/v1/message/<ID> | jq -r .Text`.
3. Escribe el código; la primera vez la app pide tu nombre y crea el perfil.

El correo usa `supabase/templates/codigo.html` (`config.toml` la asigna a enlace mágico y confirmación). En la nube hay que pegar la misma plantilla en el panel (Auth → Emails), y el SMTP de Supabase solo envía 2 correos por hora a miembros de la organización.

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
| `Cruce/App` | `CruceApp` (raíz de composición), `AppStores` y `.cruceStores(_:)`, `AppStores.sample` (solo Debug), `RootView`/`MainView`, `DebugScreen` y `SupabaseConfig` (lee la URL y la clave del `Info.plist`). |
| `Cruce/Data` | `SupabaseAuthService` y `SupabaseAccountDirectory`: la sesión y el perfil con supabase-swift, con un solo `SupabaseClient`. |
| `Cruce/Config` | `Cruce.xcconfig`, que incluye `ios/Config.xcconfig` si existe. |
| `Cruce/Screens` | Las pantallas del canvas, cada una con su `#Preview`. |
| `Cruce/Resources` | Fuentes Archivo (licencia OFL), ilustraciones @2x/@3x, ícono de la app. |
| `Packages/CruceCore/Sources/CruceCore/Models` | `Member`, `Movement`, `SplitRule`, `MovementCategory`. |
| `Packages/CruceCore/Sources/CruceCore/Domain` | Lógica pura: saldo neto (`BalanceCalculator`), formato de pesos (`Money`), fechas en español. |
| `Packages/CruceCore/Sources/CruceCore/Data` | `LedgerRepository` (interfaz, `delete` es borrado suave) e `InMemoryLedgerRepository`; `AuthService` y `AccountDirectory` (sesión y perfil) con sus dobles en memoria. En el CP5 entra `SupabaseLedgerRepository`. |
| `Packages/CruceCore/Sources/CruceCore/State` | Estado de la app, `@MainActor @Observable`: `SessionStore` (sesión y etapa), `LedgerStore` (movimientos, saldo y acciones), `Router` (pila de navegación) y `Route`. |
| `Packages/CruceCore/Sources/CruceCore/Fixtures` | `MockData`: datos de ejemplo; en la app solo se usan en Debug y en las vistas previas. |
| `Packages/CruceCore/Tests/CruceCoreTests` | Pruebas de Swift Testing del saldo (con borrado suave), los pesos, las fechas, el repositorio en memoria, los stores y el `Router`. `FailingLedgerRepository` simula el almacenamiento sin conexión. |

## Pantallas del canvas → código

| Canvas | Vista |
|---|---|
| 01, 11, 12 Onboarding | `OnboardingView` |
| 13 Entrar (correo, código y nombre) · 14 Invitar · 15 Unirse · 16 Conectados | `SignUpView`, `InviteView`, `JoinView`, `ConnectedView` |
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

- Sign in with Apple (función posterior: requiere la membresía de Apple Developer y su botón oficial `SignInWithAppleButton`).
- `SupabaseLedgerRepository` con tiempo real y cola para el modo sin conexión.
- "Cambiar monto" en Saldar (pago parcial), exportar CSV y desvincular.
