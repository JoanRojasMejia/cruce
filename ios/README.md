# Cruce · app iOS (SwiftUI)

iOS 17+, solo iPhone, modo claro. La app arranca con la sesión real (`AppStores.live()`) contra el Supabase de su ambiente (ver [Ambientes](#ambientes)). Con `-screen <nombre>` (solo Debug) abre una pantalla con **datos de ejemplo** (`AppStores.sample`), sin backend. Los movimientos siguen en memoria hasta el CP5.

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
supabase projects api-keys --project-ref pqdjiecynyjnianslikp   # fila anon de testing → Staging
```

Pega cada clave en su línea de `Config.xcconfig`. `Release` (prod) se queda con `pega-aqui…` hasta que exista el proyecto de prod: así la app de prod se detiene en vez de usar otro ambiente. La clave anónima es pública por diseño (la protege RLS); nunca pongas la `service_role`. Si falta la configuración, la app compila pero se detiene al arrancar con un mensaje que dice qué falta.

En Xcode: **Signing & Capabilities → Team**, elige tu cuenta y corre en el simulador o en tu iPhone.
Las pruebas de la lógica y del estado de la app no necesitan Xcode ni simulador (corren también en Linux, en la CI):

```bash
cd ios/Packages/CruceCore
swift test                 # Swift Testing: saldo, pesos, fechas, repositorio, stores y navegación
```

## Ambientes

Cada ambiente es una configuración de Xcode con su esquema. Elegir el ambiente es elegir el esquema en la barra de Xcode.

| Esquema | Configuración | Ambiente | Supabase | Identificador | Nombre en el iPhone |
|---|---|---|---|---|---|
| `Cruce` | Debug | local | Docker (`supabase start`) | `com.joanrojas.cruce.dev` | Cruce Dev |
| `Cruce Test` | Staging | testing | `pqdjiecynyjnianslikp` | `com.joanrojas.cruce.staging` | Cruce Test |
| `Cruce Prod` | Release | prod | todavía no existe | `com.joanrojas.cruce` | Cruce |

- El identificador, el nombre, el ícono y el ambiente de cada configuración están en `Cruce/Config/Cruce.xcconfig` (versionado). Las claves de Supabase, en `ios/Config.xcconfig` (ignorado).
- Staging se compila como Release: sin `DEBUG`, sin `-screen` ni datos de ejemplo. Es la misma app que irá a prod, contra testing.
- Fuera de prod, Ajustes dice el ambiente junto a la versión: "Cruce 1.0 (1) · testing".
- Las tres apps se pueden instalar a la vez. **Con la cuenta gratuita de Apple** hay un límite de apps instaladas desde Xcode y de identificadores nuevos por semana. En el iPhone basta con "Cruce Test"; "Cruce Dev" vive en el simulador.
- Desde la terminal: `xcodebuild -project Cruce.xcodeproj -scheme "Cruce Test" -destination 'platform=iOS Simulator,name=iPhone 16' build`.

Los íconos de local y testing (`AppIconDev`, `AppIconTest`) salen del ícono de prod con una franja en tinta. Para regenerarlos, desde `ios/Cruce/Resources/Assets.xcassets`:

```bash
for pair in Dev:DEV Test:TEST; do name=${pair%%:*}; label=${pair##*:}; magick -size 1024x1024 xc:'#FFD12E' \( AppIcon.appiconset/AppIcon-1024.png -resize 760x760 \) -gravity north -geometry +0+20 -composite -gravity northwest -fill '#111111' -draw 'rectangle 0,800 1024,1024' -font ../Fonts/Archivo-Black.ttf -pointsize 150 -kerning 12 -fill '#FFD12E' -gravity south -annotate +0+30 "$label" -alpha off -define png:exclude-chunks=date,time AppIcon$name.appiconset/AppIcon$name-1024.png; done
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

Levanta Supabase desde la raíz del repo: si no, no carga `config.toml` y el correo llega con el enlace de Supabase en vez del código.

Para probar invitar y unirse con una sola app, la otra persona puede actuar por la API (`/auth/v1/otp`, `/auth/v1/verify` con el código de mailpit y `/rest/v1/rpc/redeem_invite`). En Debug, `-screen join` y `-screen joinInvalid` abren la pantalla de unirse con un código válido o inválido, sin backend.

El correo usa `supabase/templates/codigo.html` (`config.toml` la asigna a enlace mágico y confirmación). En la nube, cada proyecto necesita SMTP propio para poder editar la plantilla y pegarla en el panel; los pasos están en `supabase/README.md`.

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
| `Cruce/App` | `CruceApp` (raíz de composición), `AppStores` y `.cruceStores(_:)`, `AppStores.sample` (solo Debug), `RootView`/`MainView`, `DebugScreen` y `SupabaseConfig.load()` (detiene la app si faltan la URL o la clave). |
| `Cruce/Data` | `SupabaseAuthService`, `SupabaseAccountDirectory` y `SupabaseParcheRepository`: la sesión, el perfil y los parches con supabase-swift, con un solo `SupabaseClient`. Los parches se leen con una sola consulta (RLS) y se escriben solo con las funciones de la base. |
| `Cruce/Config` | `Cruce.xcconfig`: identificador, nombre, ícono y ambiente de cada configuración; incluye `ios/Config.xcconfig` si existe. |
| `Cruce/Screens` | Las pantallas del canvas, cada una con su `#Preview`; `Screens/Parches` tiene las de parches (lista, nuevo, código, detalle, gasto, pago, cerrar y tickets). |
| `Cruce/Resources` | Fuentes Archivo (licencia OFL), ilustraciones @2x/@3x, ícono de la app. |
| `Packages/CruceCore/Sources/CruceCore/Models` | `Member`, `Movement`, `SplitRule`, `MovementCategory`. |
| `Packages/CruceCore/Sources/CruceCore/Domain` | Lógica pura: saldo neto (`BalanceCalculator`), formato de pesos (`Money`), fechas en español y la línea de la versión con el ambiente (`AppVersion`). |
| `Packages/CruceCore/Sources/CruceCore/Config` | `SupabaseConfig`: lee la URL y la clave del `Info.plist`; un valor vacío o de plantilla cuenta como faltante. |
| `Packages/CruceCore/Sources/CruceCore/Data` | `LedgerRepository` (interfaz, `delete` es borrado suave) e `InMemoryLedgerRepository`; `AuthService` y `AccountDirectory` (sesión, perfil y vinculación) con sus dobles en memoria; `CruceLink`, `InviteCheck` y `CruceRemote` (el JSON de `my_cruces`, `preview_invite` y `redeem_invite`). En el CP5 entra `SupabaseLedgerRepository`. |
| `Packages/CruceCore/Sources/CruceCore/State` | Estado de la app, `@MainActor @Observable`: `SessionStore` (sesión y etapa), `LedgerStore` (movimientos, saldo y acciones), `Router` (pila de navegación) y `Route`. |
| `Packages/CruceCore/Sources/CruceCore/Parches` | Parches: reparto (`Allocation`), modelos, `ParcheCalculator`, `ParcheDetail`, tickets, `ParcheRepository` con su backend en memoria, `ParcheRemote` (JSON de Supabase, parámetros y errores), `ParcheStore` y `PendingStore` (`FilePendingStore` guarda la cola sin conexión en `Application Support/Cruce/parches.json`). |
| `Packages/CruceCore/Sources/CruceCore/Fixtures` | `MockData`: datos de ejemplo; en la app solo se usan en Debug y en las vistas previas. |
| `Packages/CruceCore/Tests/CruceCoreTests` | Pruebas de Swift Testing del saldo (con borrado suave), los pesos, las fechas, el repositorio en memoria, los stores, el `Router` y los parches (`Tests/CruceCoreTests/Parches`). `FailingLedgerRepository` simula el almacenamiento sin conexión. |

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
| Parches (sin captura en el canvas) | `ParcheListView`, `NewParcheView`, `EnterCodeView`, `ParcheDetailView`, `ParcheExpenseView`, `ParchePaymentView`, `CloseParcheView`, `ParcheTicketView`; en Debug con `-screen parches`, `parcheDetail`, `parcheExpense`… (lista completa en `CLAUDE.md` §5) |

## Reglas que el código respeta

- **Recibo rosa o verde:** sale de `Member.tikeVariant` (rosa para quien creó la cuenta, verde para quien se unió). Ver `Illustration.balance(_:variant:)`.
- **Estado:** cada vista lee solo el store que usa (`@Environment(SessionStore.self)`, `LedgerStore`, `Router` o `ParcheStore`); los cuatro entran por `.cruceStores(_:)` en la app, `DebugScreen` y cada `#Preview`.
- **Eliminar es borrado suave:** el movimiento se marca con `deletedAt` y deja de contar y de verse.
- **Dinero:** `Int` en pesos, nunca `Double`. Formato `$30.000` con `Money.format`.
- **Saldo:** nunca se guarda; se calcula con `BalanceCalculator.net`.
- **Quién le debe a quién:** siempre con texto, signo y flecha, no solo color.

## Pendiente

- Sign in with Apple (función posterior: requiere la membresía de Apple Developer y su botón oficial `SignInWithAppleButton`).
- `SupabaseLedgerRepository` con tiempo real y cola para el modo sin conexión.
- "Cambiar monto" en Saldar (pago parcial), exportar CSV y desvincular.
- Parches: sin tiempo real (se ve lo nuevo al abrir o deslizar para recargar), sin notificaciones push, y el movimiento que crea "pasar al cruce" solo se ve en el inicio cuando entre `SupabaseLedgerRepository` (CP5). La cola sin conexión es una por teléfono, no por cuenta.
