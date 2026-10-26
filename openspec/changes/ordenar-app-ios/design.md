# Design

## Context

Ver `proposal.md` (Why). Estado actual comprobado en el código:

- `ios/Cruce/App/AppState.swift`: una clase `@MainActor @Observable` con la sesión (`phase`, `me`, `partner`), `movements` (`private(set)`), `path: [Route]`, `lastSaved`, `lastSettlement`, `isOffline`, `pendingSyncCount`, lecturas (`net`, `balance`, `sortedMovements`, `phrase(forNet:)`, `impact(of:)`, `member(_:)`, `movement(_:)`, `movementsSinceLastSettlement`, `lastSettlementDate`, `balanceIllustration`) y acciones (`load`, `save`, `delete`, `settle`, `retrySync`, `signOut`). `Route` está en el mismo archivo. `AppState.preview(phase:viewer:movements:)` arma el estado con `MockData` y un `InMemoryLedgerRepository`.
- `CruceApp` arranca **siempre** (también en Release) con `AppState.preview(phase: .onboarding)`, es decir, con los datos de ejemplo. En Debug, `DebugScreen.current?.makeState()` lo reemplaza.
- Todas las pantallas leen `@Environment(AppState.self)`. Las que más lo usan: `HomeView` (saldo, ruta, últimos 3), `HistoryView`, `MovementDetailView`/`DeleteConfirmation`, `AddMovementView`, `SettleView`, `SettleSuccessView`, `OfflineView`, `SettingsView` (`signOut`) y `AuthViews` (`phase`, `me`).
- `ios/Cruce/Data/LedgerRepository.swift`: protocolo `Sendable` (`loadMovements`, `save`, `delete(id:)`) e `InMemoryLedgerRepository` (actor); `delete` hace `storage[id] = nil` (borrado real).
- `Movement` (CruceCore) no tiene `deletedAt`. `BalanceCalculator.net`, `settlement` y `movementsSinceLastSettlement` suman toda la lista que reciben. `HomeView` decide el estado vacío con `app.movements.isEmpty`.
- SQL: `movements.deleted_at timestamptz`, índice parcial `where deleted_at is null` y la vista `ledger_balances` filtra `m.deleted_at is null`. La política de lectura de `movements` **no** filtra eliminados: la app los recibe y debe ignorarlos.
- Datos de ejemplo en vistas de producción: `InviteView` tiene `private let code = "CRZ-4821"`; `JoinView` muestra `MockData.joan` como quien invita; `OnboardingView` (página 1) dibuja una tarjeta ilustrativa con `MockData.joan` y `MockData.jesus`.
- `CruceCore` está en Swift 6 (concurrencia estricta), se prueba con `swift test` en la Mac y en Linux (`swift:6.4` en la CI). La app está en Swift 5 y no tiene target de pruebas en `project.yml`.
- `SettingsView` guarda el interruptor de notificaciones en `@State` local; se queda así (lo resuelve el CP9).

## Goals / Non-Goals

**Goals:**
- Que cada pantalla dependa solo de lo que usa (sesión, movimientos o navegación) y que ese estado se pueda probar con `swift test`, sin simulador, también en la CI de Linux.
- Borrado suave igual al de la base de datos, para que `SupabaseLedgerRepository` (CP5) solo tenga que mapear `deleted_at`.
- Que ninguna vista de producción lea `MockData` ni datos fijos; los datos de ejemplo entran por un solo lugar.
- Cero cambios visuales.

**Non-Goals:**
- Swift 6 en la app, ViewModels por pantalla, TCA, coordinadores o un framework de inyección.
- Supabase, red, inicio de sesión real, invitaciones reales (CP3–CP5), tiempo real y el aviso al otro (CP6/CP9), deshacer un borrado.
- Un target de pruebas de UI o de snapshots en Xcode (snapshot es opcional en el CP12).

## Decisions

### 1. Tres stores por dominio, no un store único ni ViewModels por pantalla

`SessionStore`, `LedgerStore` y `Router`, cada uno `@MainActor @Observable final class`, inyectados con `.environment(_:)` y leídos con `@Environment(X.self)`.

- **`SessionStore`**: `phase`, `me`, `partner`, `inviteCode: String?`, `member(_ id:)`, `signOut()` (vuelve a `.onboarding`).
- **`LedgerStore`**: recibe `session: SessionStore` y `repository: LedgerRepository` en su `init`. Guarda **todos** los movimientos (incluidos los eliminados) en `private(set) var movements` y expone `visibleMovements` (vigentes, del más reciente al más antiguo), `movement(_ id:)` (solo vigentes), `isEmpty`, `net`, `balance`, `impact(of:)`, `phrase(forNet:)`, `movementsSinceLastSettlement`, `lastSettlementDate`, `lastSaved`, `lastSettlement`, `isOffline`, `pendingSyncCount` y las acciones `load`, `save`, `delete`, `settle`, `retrySync`. Lee `session.me`/`session.partner` en el momento, así un cambio de nombre o de sesión se refleja sin copiar datos.
- **`Router`**: `path: [Route]`, `push(_:)`, `pop()` (no falla con la pila vacía) y `popToRoot()`.
- **Acciones que cruzan stores**: son dos y quedan explícitas en la vista que las dispara, sin un coordinador: "Cerrar sesión" (`SettingsView`) llama `router.popToRoot()` y luego `session.signOut()`; guardar en `AddMovementView` llama `router.pop()` y luego `ledger.save(_:)` (mismo orden que hoy). "A paz y salvo" (`SettleSuccessView`) llama `router.popToRoot()`.
- **`AppState` desaparece.** Mantenerlo como fachada que reexporta los tres stores conservaría el acoplamiento que se quiere quitar (cualquier vista vuelve a ver todo) y agrega una capa más que mantener. La raíz de composición es `CruceApp`.

**Alternativas:**
- *Un solo store con extensiones por archivo* (rechazada): ordena el código pero no las dependencias; cada vista sigue observando todo y las pruebas siguen arrastrando sesión y navegación.
- *ViewModel por pantalla* (rechazada): unas 15 clases nuevas, duplicación de lecturas (saldo, frase) y va contra el enfoque MV ya elegido con `@Observable`.
- *`LedgerStore` sin depender de `SessionStore`, recibiendo el `memberID` en cada lectura* (rechazada): cada vista tendría que pasar `session.me.id` en cada llamada; más ruido y más lugares para equivocarse de miembro.

### 2. Los stores viven en `CruceCore`, no en la app ni en un paquete nuevo

Se mudan a `CruceCore`: `Route` (`State/Route.swift`), `LedgerRepository` e `InMemoryLedgerRepository` (`Data/`), `SessionStore`, `LedgerStore` y `Router` (`State/`). Son `public` con `init` públicos.

**Por qué:** la app no tiene target de pruebas y agregarlo exige Xcode y un simulador, que no corren en la CI de Linux. `CruceCore` ya se prueba con `swift test` en la Mac y en `swift:6.4`. `Observation` (`@Observable`) viene con la herramienta de Swift desde 5.9, también en Linux, y `@MainActor` no depende de SwiftUI. Nada de esto importa SwiftUI: `Route` es un `enum` `Hashable` con `UUID`, y el repositorio solo usa Foundation. El modo Swift 6 del paquete obliga a que el repositorio sea `Sendable` (ya lo es) y a que los stores queden aislados en `@MainActor`, que es lo que se quiere.

**Lo que se queda en la app:** todo lo visual. La regla del recibo rosa o verde (`balanceIllustration`) pasa a una función de `Illustration` en `DesignSystem/Illustration.swift`: `Illustration.balance(_ state: BalanceState, variant: TikeVariant)`, porque `Illustration` mapea imágenes del catálogo de la app. Es una función pura de tres casos y la cubren las capturas de `homeTheyOwe`, `homeYouOwe` y `homeJesus`.

**Alternativas:**
- *Stores en la app con un target de pruebas de Xcode* (rechazada): solo prueba en la Mac con simulador, no en la CI de Linux, y choca con el modo de recursos (8 GB).
- *Paquete local nuevo (`CruceState`) o un segundo target dentro de `CruceCore`* (rechazada por ahora): separa mejor "lógica pura" de "estado", pero agrega un producto más que enlazar en `project.yml` y en la CI sin que hoy aporte; si el paquete crece, se separa en un cambio aparte. Se usan carpetas (`Data/`, `State/`) para que la frontera se vea.

### 3. Borrado suave con `deletedAt: Date?`, no con un enum de estado

`Movement` gana `public var deletedAt: Date?` (en el `init` con valor por defecto `nil`, al final) y `public var isDeleted: Bool { deletedAt != nil }`. Refleja `movements.deleted_at timestamptz` uno a uno, así el mapeo del CP5 es directo, y `Codable` sigue leyendo JSON viejo sin la clave.

- **`BalanceCalculator`** ignora los eliminados dentro de `net(of:for:)`, `settlement(...)` y `movementsSinceLastSettlement(_:)`. Filtrar en el dominio (y no en cada vista) cumple "movimientos vigentes" de `saldo-neto` en un solo lugar y es lo que verifica el delta de `pruebas-logica`. `impact(of:for:)` no filtra: es el efecto de un movimiento y la confirmación de borrado lo usa para mostrar "cómo queda".
- **`InMemoryLedgerRepository.delete(id:)`** marca `deletedAt = .now` (o una fecha inyectada para las pruebas) y conserva el movimiento; `loadMovements()` los devuelve todos, igual que hará Supabase con su política de lectura. El protocolo no cambia: `delete(id:)` significa "borrado suave" en todas las implementaciones (se documenta en el comentario del protocolo).
- **`LedgerStore.delete(_:)`** marca el movimiento en su lista (no lo quita) y llama al repositorio. Las lecturas visibles (`visibleMovements`, `movement(_:)`, `isEmpty`, `lastSettlementDate`) filtran `isDeleted`. `HomeView` pasa de `movements.isEmpty` a `ledger.isEmpty` para que eliminar el único movimiento muestre el inicio vacío.
- Editar un movimiento eliminado no es posible: `movement(_:)` devuelve `nil` y `AddMovementView(editing: nil)` abriría uno nuevo; como un eliminado no aparece en ninguna lista, no hay forma de llegar a esa ruta.

**Alternativas:**
- *`enum Status { active, deleted(Date) }`* (rechazada): más expresivo, pero no coincide con la columna, complica `Codable` y no hay un tercer estado previsto.
- *Seguir quitando de la lista local y marcar solo en el repositorio* (rechazada): la lista local y la persistida dirían cosas distintas, y el tiempo real (CP6) recibe el `update` de `deleted_at`, no un `delete`.

### 4. Raíz de composición y datos de ejemplo

- `CruceApp` crea `SessionStore`, `LedgerStore` y `Router` en `@State` y los inyecta con un solo modificador de la app, `.cruceStores(_:)` (en `App/`), que aplica los tres `.environment(...)`. Así ninguna raíz (la app, `DebugScreen`, las vistas previas) puede olvidar uno.
- Los tres stores se agrupan en un `struct AppStores` (valor, no observable) solo para transportarlos; no tiene lógica.
- **Release:** `AppStores.live()` arranca en `.onboarding` con un `InMemoryLedgerRepository` vacío y miembros provisionales neutros ("Tú" y "Tu amigo", con sus colores y variantes por rol) y `inviteCode = nil`, hasta que el CP3/CP4 traigan la sesión y el código reales. Release no se distribuye todavía (no hay TestFlight), así que esto no cambia lo que ve nadie hoy.
- **Debug:** `AppStores.sample(phase:viewer:movements:)`, dentro de `#if DEBUG` en `App/AppStores+Sample.swift`, siembra el repositorio con `MockData.movements()`, la sesión con `MockData.joan`/`MockData.jesus` y `inviteCode = "CRZ-4821"`. `CruceApp` lo usa en Debug, `DebugScreen.makeStores()` lo usa con cada pantalla y las vistas previas con `.cruceStores(.sample(...))`. Reemplaza a `AppState.preview`. La carga inicial sigue siendo `.task { await ledger.load() }`; para que las vistas previas y `DebugScreen` no dependan de esa tarea, `sample` también fija la lista del store al construirlo (como hace hoy `AppState.preview`).
- **Vistas que hoy leen datos de ejemplo:**
  - `InviteView` muestra `session.inviteCode`; si es `nil` muestra `CRZ-····` con el mismo estilo (solo pasa en Release).
  - `JoinView` muestra a `session.partner` como quien invita. En la etapa `.join`, desde la vista de Jesús, el otro es Joan: la captura no cambia. Al CP4 le toca mostrar el nombre que devuelva `redeem_invite`.
  - `OnboardingView` página 1: la tarjeta "Joan le debe a Jesús $20.000" es una ilustración fija del producto, no datos de la cuenta. Usa dos `Member` decorativos privados de la vista (mismos nombres, colores y variantes) en vez de `MockData`, para que el texto fijo y los avatares sigan iguales.
- **Regla verificable:** `rg -n "MockData" ios/Cruce` solo encuentra líneas dentro de `#if DEBUG` (incluidos `DebugScreen.swift` y `AppStores+Sample.swift`) o de bloques `#Preview`. Si los `#Preview` no compilan en Release por depender de `AppStores.sample`, se envuelven en `#if DEBUG`; se comprueba con `xcodebuild -configuration Release build`.

**Alternativas:**
- *Sacar `MockData` de `CruceCore` a un target solo de Debug* (rechazada): las pruebas del paquete lo usan, y XcodeGen no enlaza un producto por configuración sin trucos; la regla con `rg` y la compilación en Release bastan.
- *Inyectar los stores con un contenedor o un `EnvironmentKey` con valor por defecto* (rechazada): un valor por defecto escondería un olvido mostrando datos falsos; preferimos que falle en Debug y que el modificador único lo evite.

### 5. Pruebas

Swift Testing en `ios/Packages/CruceCore/Tests/CruceCoreTests/`, con `@MainActor` en las suites de stores:

- `BalanceCalculatorTests` (RED primero): eliminados fuera de `net`, de `settlement` y de `movementsSinceLastSettlement` (incluido un pago eliminado).
- `InMemoryLedgerRepositoryTests`: `delete` conserva el movimiento con `deletedAt`, `save` reemplaza por `id`.
- `LedgerStoreTests`: guardar uno nuevo fija `lastSaved` y editar no; eliminar marca, baja el saldo y lo saca de `visibleMovements`; eliminar el único deja `isEmpty`; `settle` agrega el pago y fija `lastSettlement`, y no hace nada en $0; un repositorio de prueba que falla (`FailingLedgerRepository`, en el target de pruebas) sube `pendingSyncCount` y `isOffline`; `retrySync` los limpia y recarga.
- `SessionStoreTests`: `signOut` vuelve a `.onboarding`; `member(_:)` devuelve al otro por `id`.
- `RouterTests`: `push`, `pop` con pila vacía sin fallar, `popToRoot`.

Todas corren en la CI existente (trabajo `core`, `swift:6.4`) sin tocar `ci.yml`.

## Risks / Trade-offs

- [Una vista lee un store que no se inyectó y la app se cae en tiempo de ejecución] → un solo modificador `.cruceStores(_:)` en todas las raíces; cada `#Preview` usa ese modificador; antes del último commit se abren las 20 pantallas de `DebugScreen` en el simulador y se revisa que ninguna se caiga.
- [Regresión de navegación (volver, hoja "Gasto guardado", "A paz y salvo", cerrar sesión)] → `RouterTests` y `LedgerStoreTests`; prueba a mano en el simulador de agregar, editar, eliminar, saldar y cerrar sesión; las capturas de `add`, `saved`, `history`, `detail`, `delete`, `settle` y `success`.
- [Cambio visual involuntario] → capturas de `DebugScreen` antes y después (`homeTheyOwe`, `homeYouOwe`, `homeJesus`, `homeEmpty`, `add`, `saved`, `history`, `detail`, `delete`, `settle`, `success`, `invite`, `join`, `onboarding1`) en el mismo simulador y se comparan píxel a píxel con `cmp`; si una difiere, se mira lado a lado antes de seguir.
- [`@Observable` público en un paquete Swift 6 que la app usa en Swift 5] → el modo de lenguaje es por módulo (ya pasa con los modelos); se compila la app en cada tarea que mueve código.
- [`Observation` en Linux] → se verifica en la tarea de los stores corriendo la suite en `swift:6.4` con Docker antes de confiar en la CI.
- [`CruceCore` deja de ser "solo lógica pura"] → carpetas `Data/` y `State/` separadas de `Models/` y `Domain/`, y `CLAUDE.md` lo dice; si crece, se separa en un target propio.
- [Release arranca con miembros provisionales y sin código] → no se distribuye hasta el CP3/CP4, que reemplazan `AppStores.live()`; queda anotado en el comentario.

## Migration Plan

1. Borrado suave en el dominio con pruebas (RED → GREEN), sin tocar la app (sigue compilando: el campo nuevo tiene valor por defecto).
2. Mover repositorio y `Route` al paquete y crear los stores con sus pruebas, sin que la app los use todavía.
3. Cambiar la app a los stores en un solo paso (raíz de composición, `DebugScreen`, pantallas y vistas previas), borrar `AppState.swift` y `Data/LedgerRepository.swift`, correr `xcodegen` y comparar capturas.
4. Quitar los datos de ejemplo de las vistas de producción y comparar capturas otra vez.
5. Documentación.

No hay datos ni migraciones que revertir: cada paso es un commit y se revierte con `git revert`. La base de datos no cambia.
