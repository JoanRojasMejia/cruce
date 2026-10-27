# CLAUDE.md — Contexto del proyecto Cruce

Este archivo es la especificación viva del proyecto. Léelo completo antes de tocar código.
Lo leen Claude Code (`CLAUDE.md`) y OpenCode (`AGENTS.md` apunta aquí).
El plan de trabajo, con los checkpoints, está en [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## 1. Qué es Cruce

Una app de iPhone para llevar las cuentas compartidas con tus amigos: con cada uno, un solo libro y un solo saldo. Empezó con **Joan y Jesús**, que son los primeros usuarios.

- **Problema:** hoy anotan las deudas por separado ("él me debe 30.000", "yo le debo 60.000") y no las pueden cruzar.
- **Solución:** cada gasto se compensa automáticamente contra lo que el otro debe, y la app muestra siempre **un único saldo neto**: quién le debe a quién y cuánto.
- **El cruce es entre dos personas.** La cuenta permanente (el "cruce") es siempre de dos; no se le agregan más personas.
- **Varios cruces por persona, uno por pareja** (decidido el 27 oct 2026). Cada quien puede tener un cruce con cada amigo (con Jesús, con Ana, con su hermano), pero nunca dos cruces con la misma persona. Con un solo cruce, el inicio es ese cruce, como en el diseño; con dos o más, el inicio muestra "Tus cruces" con el saldo de cada uno y al tocar uno se abre su inicio. "Invitar a alguien" crea un cruce nuevo con su código `CRZ-`. Implementado en el CP4 (la regla en la base y la vinculación) y el CP4b (la lista, el cruce abierto e invitar o unirse teniendo ya cruces).
- **Parches (implementados, cambio `parches`):** grupos de varias personas con inicio y fin (un viaje, una cena), donde también se cruzan cuentas y al final se salda todo. Son aparte del cruce y no lo cambian; al cerrar un parche, lo que dos personas se deben directamente puede pasar a su cruce como un movimiento. Quien no tiene la app participa igual ("sin la app") y luego puede quedarse con su lugar con un código `SOY-`; al parche se entra con un código `PCH-`.
- **Todo el texto en español (Colombia).** Moneda: pesos colombianos, formato `$30.000`.

### Vocabulario

Todas las pantallas usan estas palabras; no se mezclan sinónimos ("grupo", "viaje", "plan").

| Concepto | Palabra | Ejemplo |
|---|---|---|
| La app, la marca | **Cruce** | "Cruce · Parche Santa Marta" |
| La cuenta permanente de dos | **tu cruce con Joan** | "Pasar a tu cruce con Joan" |
| Todos los cruces de una persona | **tus cruces** | "Tus cruces", "Invitar a alguien" |
| El grupo con inicio y fin | **parche** | "Nuevo parche", "Parche Santa Marta", "Cerrar el parche", "Parche cerrado" |
| Las personas de un parche | **los del parche** | "4 personas en el parche" |
| Quien no tiene la app | **sin la app** | "Carlos (sin la app)". No se dice "invitado": "invitar" ya es mandar el código del cruce |
| Registrar un gasto o pago | **anotar** | "Anotar un gasto", "Anotado por Ana" |
| Terminar de pagar | **saldar**, **a paz y salvo** | "Ya están a paz y salvo" |

Se trata de **tú** en toda la app ("Le debes $87.500 a Jesús").

### Movimiento

Cada movimiento tiene: quién pagó, monto, concepto, fecha, categoría y reparto.

| Reparto | Qué significa | Lo que el otro le debe a quien pagó |
|---|---|---|
| `50/50` (por defecto) | Mitad y mitad | 50 % del monto |
| Porcentaje | El usuario elige cuánto le toca al otro | `otherShare` % del monto |
| Todo es del otro | Préstamos | 100 % del monto |

**Ejemplo canónico (está en las pruebas):** Joan paga una cena de $60.000 a medias, así que Jesús le debe $30.000. Jesús paga un mercado de $100.000 a medias, así que Joan le debe $50.000. **Saldo neto: Joan le debe $20.000 a Jesús.**

### Saldar cuentas

Es un movimiento más (`kind = settlement`, reparto "todo es del otro"): quien debe le paga el total al otro y el saldo queda en $0. Se elige el medio de pago (Efectivo, Nequi o Transferencia).

### Reglas de producto que no se negocian

1. **El saldo nunca se guarda: siempre se calcula** sumando los movimientos.
2. **Dinero en enteros.** `Int` en Swift, `bigint` en Postgres. Nunca `Double` ni `Decimal` con centavos.
3. **Redondeo:** al peso más cercano, .5 hacia arriba: `(monto * porcentaje + 50) / 100`. Es igual en Swift (`Money.share`) y en SQL (`owed_by_other`).
4. **Formato:** `$30.000`, `$1.800.000`, `+$18.000`, `−$50.000`. El signo menos es U+2212 (−), no un guion.
5. **Quién le debe a quién nunca depende solo del color.** Siempre va con la frase ("Jesús te debe"), el signo +/− y el texto "a tu favor" o "a favor de Jesús". La flecha va de quien debe a quien recibe.
6. **Regla del recibo rosa o verde ("Tike").** Las ilustraciones de "te deben" y "debes" tienen dos versiones. **Quien creó la cuenta (Joan) ve el recibo rosa; quien se unió con código (Jesús) ve el verde.** Se guarda por miembro (`Member.tikeVariant` en Swift, `ledger_members.tike_variant` en SQL).
7. **Colores de avatar:** quien crea la cuenta es amarillo y quien se une es violeta.
8. **Eliminar es borrado suave** (`deleted_at`): el otro recibe un aviso.

---

## 2. Estado actual (27 oct 2026)

| Parte | Estado | ¿Verificado? |
|---|---|---|
| Diseño (opción A, 20 pantallas y guía de estilo) | Cerrado | Sí. Capturas en `docs/design/screens/` |
| App iOS con todas las pantallas y datos de ejemplo | Compila, corre y se ve como el diseño (CP1) | Sí: capturas de las 20 pantallas en iPhone 16, SE y Pro Max, y con texto grande. Probada en un iPhone 17 Pro físico (cuenta gratuita de Apple) |
| Inicio de sesión (CP3) | Por correo con un código de 6 dígitos (supabase-swift 2.55.4), sesión persistente, perfil y etapa de entrada según la sesión real. Sign in with Apple queda para cuando se pague la membresía | En local sí: pasos de la tarea 4.2 de `inicio-sesion-correo`. En testing (27 oct 2026), con SMTP de Gmail y la plantilla: Joan y Jesús entraron en "Cruce Test" con el código que llegó por correo |
| Pruebas de Swift (saldo, pesos, fechas, repositorio, stores, sesión, navegación y parches) | 239 pruebas de Swift Testing en verde, en el paquete `CruceCore` | Sí: `swift test`, sin Xcode ni simulador, en la Mac y en Linux (`swift:6.4`) |
| Parches | Lógica en CruceCore (reparto, saldos, `ParcheStore` con cola sin conexión), pantallas nuevas (17 entradas `-screen` en Debug), tickets para compartir y `SupabaseParcheRepository` conectado en `AppStores.live()`. Migración `20261026095551_parches.sql` aplicada en local y en la nube (26 oct 2026) | Sí: pgTAP (`06_parches.sql`), `swift test` y, contra Supabase local, el repositorio real con tres cuentas (crear, unirse, sin la app, cuatro repartos, pagos, reclamar lugar, cerrar, pasar al cruce, avisos) y la app en el simulador mostrando "Tus parches" |
| Base de datos (Supabase) | `init.sql` aplicada en local y en la nube (proyecto `cruce`, Oregon, que es el ambiente de testing). `endurecer_rls.sql` (políticas solo para `authenticated`, `(select auth.uid())` e índices) y `parches.sql` aplicadas en local y en la nube (26 oct 2026). `vincular_cruces.sql` (un cruce por pareja, un cruce pendiente por persona, `preview_invite` y `my_cruces`) aplicada en local y en testing (27 oct 2026). `funciones_pendientes.sql` (cerrar un cruce, solo lectura y `my_cruces` con cerrado y reparto) aplicada en local y en testing (27 oct 2026) | Sí: 223 pruebas pgTAP en verde (saldo, reglas, vinculación, RLS y RLS endurecido, también sin sesión, parches, vincular cruces y cerrar cruces) y revisión de seguridad hecha |
| Vincular (CP4, cambio `vincular-cruces`) | Invitar muestra el código real y pasa sola a "Conectados" (revisa cada 3 s); unirse valida con la base y muestra "Cuenta de Joan"; nombres, colores y recibo salen de la base. La sesión guarda la lista de cruces; la app usa el más reciente hasta el CP4b | En local sí: Joan invita en el simulador y Jesús se une por la API; Ana se une en el simulador al código de Pedro (válido e inválido). En testing (27 oct 2026): Joan y Jesús se vincularon en "Cruce Test" desde sus iPhone |
| Varios cruces (CP4b, cambio `varios-cruces`) | Con dos o más cruces el inicio es "Tus cruces" (`CruceListView`) con el saldo de cada uno; el cruce abierto (`SessionStore.open`) decide la otra persona, el color y el recibo; los movimientos se guardan por cruce; "Invitar a alguien" (lista y Ajustes) y "Tengo un código" con `CRZ-` funcionan teniendo ya cruces | En local sí: Joan con tres cruces (Jesús, Ana y Pedro, por la API) desde el simulador, y un gasto en el cruce de Ana no aparece en el de Jesús. Falta probar en testing con una tercera cuenta |
| Movimientos en Supabase (CP5, cambio `movimientos-supabase`) | `SupabaseLedgerRepository` por cruce (`upsert` por `id`, borrado suave), `MovementRemote` para el JSON, deslizar para recargar en el inicio y en "Tus cruces", recarga al volver a la app y cuadre en Debug con `ledger_balances` | En local sí: Joan en el simulador y Jesús por la API (anotar, recargar, eliminar, cerrar y abrir la app, y la deuda de un parche en el cruce); el cuadre coincide. Falta probarlo en testing con Joan y Jesús |
| Tiempo real (CP6, cambio `tiempo-real`) | `MovementFeed` (CruceCore) y `SupabaseMovementFeed` (un canal de Realtime por cruce, filtrado por `ledger_id`); `LedgerStore.apply` reemplaza por `id` (sin duplicar el eco) y `follow()` aplica los cambios mientras `MainView` está activa | En local sí: Jesús anota, edita y borra por la API y el inicio de Joan cambia solo en menos de 2 s; lo propio no se duplica. Falta probarlo en testing |
| Sin conexión (CP7, cambio `sin-conexion`) | `LedgerStore` escribe primero en el teléfono (`FileLedgerLocalStore`, archivo JSON) y una cola (`pending`) que se envía en orden; `restore()` y `SessionStore.restore()` (`FileSessionCache`) abren la app sin red; `NetworkMonitor` (`NWPathMonitor`) envía al volver la red; lo que la base rechaza sale de la cola | En local sí: con Supabase apagado, Joan anota, cierra y abre la app (abre en el inicio con lo pendiente), y al volver la red el gasto llega una sola vez. Falta probarlo en testing con modo avión |
| Funciones pendientes (CP11, cambio `funciones-pendientes`) | Pago parcial con "Cambiar monto" (de $1 al total, "Pago anotado"); Ajustes: editar el nombre (`ProfileView`), reparto por defecto del cruce (`DefaultSplitView`, que usa "Nuevo movimiento"), exportar a CSV (`HistoryCSV` en CruceCore y `ShareLink` con el archivo) y desvincular (`UnlinkConfirmation`: el cruce se cierra para los dos y queda de solo lectura); historial con deslizar para eliminar (`List` + `swipeActions`) | En local sí: Joan en el simulador y Jesús por la API (pago parcial de $20.000, reparto 70 % que Jesús ve y "Nuevo movimiento" arranca en 70 %, nombre "Joan R." que Jesús ve, CSV guardado en Archivos, desvincular: los dos lo ven cerrado y la base rechaza gastos, y volver con un código nuevo crea un cruce abierto). Migración aplicada en testing (27 oct 2026); falta probar las pantallas en "Cruce Test" |
| Backend de Go (`/healthz` y webhook, CP8, cambio `backend-desplegado`) | Recibe los Database Webhooks de `movements` (insert y update) y deja una línea JSON por aviso, sin concepto ni nombres; un aviso rechazado deja una advertencia sin el secreto. Imagen de 15 MB, `fly.toml` (una máquina siempre prendida en San José) y `scripts/webhook-local.sh` para Supabase local | En local sí: anotar, editar y eliminar dejan `INSERT` y `UPDATE` en el log y un secreto incorrecto deja la advertencia. En testing (27 oct 2026): `cruce-api-testing` en Fly.io (`sjc`, una máquina), webhook creado en el panel (Integrations → Database Webhooks) y un gasto anotado en "Cruce Test" dejó `movimiento cambió` en `fly logs`. El de prod se despliega cuando exista su proyecto |
| Git | Iniciado (rama `main`) | — |
| Integración continua (GitHub Actions) | `ci.yml`: backend, base de datos y lógica, cada uno solo si cambió su carpeta; `ios.yml` compila la app a mano | Local: cada paso corre en la Mac (Linux con `swift:6.4` en Docker) y `actionlint` no reporta errores. En GitHub: corridas en verde desde el 26 oct 2026 |
| Ambientes (cambio `ambientes`) | Tres: local (Debug, esquema `Cruce`), testing (Staging, `Cruce Test`, el proyecto actual) y prod (Release, `Cruce Prod`; el proyecto se crea antes de TestFlight). Cada app tiene su identificador, nombre e ícono; `scripts/db-push.sh` sube migraciones por ambiente | Los tres esquemas compilan y conviven en el simulador; Ajustes dice "· local"; prod sin claves se detiene. Los scripts se corrieron contra testing (27 oct 2026). Joan entró en "Cruce Test" con el código del correo. "· testing" en Ajustes se verá cuando el inicio exista en testing (CP4) |
| Respaldos de la base de datos | `scripts/backup-db.sh testing`, `prod` o `--local`; quedan en `backups/<fecha>_<hora>_<ambiente>/`, fuera de git | `--local` sí; nube sí (primer respaldo el 26 oct 2026). Mientras la nube no tenga datos reales no se respalda antes de cada migración |

**CP0 a CP4 cerrados** (el CP3 por correo, sin Sign in with Apple). Joan y Jesús ya están vinculados en testing. CP4b, CP5, CP6 y CP7 hechos en local (falta probarlos en testing). El CP8 (backend en Fly.io) está hecho en testing. El CP11 (funciones pendientes) está hecho en local y su migración está en testing; falta probarlo en "Cruce Test". El CP9 (push) y el CP10 esperan: el CP9 necesita la membresía de Apple Developer.

---

## 3. Estructura del repositorio

```
cruce/
├── CLAUDE.md                 Este archivo
├── AGENTS.md → CLAUDE.md     Mismo contenido para OpenCode
├── README.md
├── docs/
│   ├── ROADMAP.md            Checkpoints, se toman uno a uno
│   ├── arquitectura.md       Decisiones de arquitectura
│   ├── diseno.md             Tokens e ilustraciones
│   └── design/screens/       Capturas PNG de las 20 pantallas y la guía (referencia visual)
├── ios/
│   ├── project.yml           Proyecto de XcodeGen (el .xcodeproj NO se sube al repo)
│   ├── Cruce/
│   │   ├── App/              CruceApp (raíz de composición), AppStores + .cruceStores, AppStores+Sample
│   │   │                     (solo Debug), RootView + MainView (navegación), DebugScreen
│   │   ├── Data/             SupabaseAuthService, SupabaseAccountDirectory, SupabaseParcheRepository y
│   │   │                     SupabaseLedgerRepository, SupabaseMovementFeed (tiempo real) y NetworkMonitor
│   │   │                     (supabase-swift)
│   │   ├── Config/           Cruce.xcconfig (incluye ios/Config.xcconfig, ignorado por git)
│   │   ├── DesignSystem/     Colors, Typography, Metrics, NeoSurface, NeoButtonStyle, Illustration
│   │   ├── Components/       FolderCard, MovementRow, Controls (IconButton, Chip, NeoSegmented,
│   │   │                     NeoTextField, NeoToggleStyle, PageDots, Badge, BeforeAfter),
│   │   │                     AmountKeypad, Avatar, CategoryIcon, CruceLogo
│   │   ├── Screens/          Onboarding, Auth, Home, AddMovement, History, Detail, Settle,
│   │   │                     Offline, Settings y Parches (lista, nuevo, código, detalle, gasto,
│   │   │                     pago, cerrar y tickets)
│   │   └── Resources/        Fuentes Archivo (OFL), Assets.xcassets (ilustraciones @2x/@3x,
│   │                         AppIcon, AccentColor, LaunchBackground)
│   └── Packages/CruceCore/   Paquete local con la lógica pura (la app lo usa con `import CruceCore`)
│       ├── Sources/CruceCore/
│       │   ├── Models/       Member, Movement, SplitRule, MovementCategory
│       │   ├── Domain/       BalanceCalculator, Money, DateText, AppVersion (versión con el ambiente)
│       │   ├── Config/       SupabaseConfig (lee la URL y la clave del Info.plist)
│       │   ├── Data/         LedgerRepository e InMemoryLedgerRepository (borrado suave); AuthService,
│       │   │                 AccountDirectory y sus dobles en memoria; Cruces (CruceLink, InviteCheck
│       │   │                 y CruceRemote, el JSON de la vinculación)
│       │   ├── State/        SessionStore, LedgerStore, Router y Route (estado de la app)
│       │   ├── Parches/      Allocation (reparto), modelos, ParcheCalculator, ParcheDetail, ParcheTicket,
│       │   │                 ParcheRepository (+ backend en memoria), ParcheRemote (JSON de Supabase),
│       │   │                 ParcheStore y PendingStore (cola sin conexión en disco)
│       │   └── Fixtures/     MockData (datos de ejemplo para Debug, previews y pruebas)
│       └── Tests/CruceCoreTests/  BalanceCalculator, DateText, Money, InMemoryLedgerRepository,
│                                  SessionStore, LedgerStore, Router y Parches/ (Swift Testing)
├── backend/                  Go 1.27, solo librería estándar; fly.toml (Fly.io) y Dockerfile
│   ├── cmd/api/main.go
│   └── internal/{config,httpapi,notify}
├── supabase/
│   ├── migrations/           20261024000000_init.sql, 20261026060520_endurecer_rls.sql,
│   │                         20261026095551_parches.sql, 20261027065544_vincular_cruces.sql y
│   │                         20261027180000_funciones_pendientes.sql
│   ├── ambientes.env         Identificador del proyecto de testing y de prod
│   └── tests/                Pruebas pgTAP (01_saldo a 09_funciones_pendientes)
├── openspec/                 Registro de specs y cambios (OpenSpec, ver §9)
│   ├── config.yaml           Esquema spec-driven, artefactos en español
│   ├── specs/                Cómo se comporta la app hoy (fuente de verdad)
│   └── changes/              Cambios en curso; archive/ guarda los cerrados
└── .claude/, .opencode/      Comandos /opsx (propose, apply, archive…) para cada agente
```

---

## 4. Cómo levantar y probar cada parte

### Requisitos en la Mac
- Xcode 15 o superior, con el simulador de iOS 17 o superior.
- `brew install xcodegen go supabase/tap/supabase` y Docker Desktop (para Supabase en local).

### Pruebas de la lógica (sin Xcode ni simulador)
```bash
cd ios/Packages/CruceCore && swift test   # Swift Testing: saldo, pesos, fechas, repositorio, stores y navegación
```
- La lógica pura (`Models`, `Domain` y los datos de ejemplo `MockData`), el repositorio (`Data`) y el estado de la app (`State`: `SessionStore`, `LedgerStore`, `Router`) viven en el paquete local `ios/Packages/CruceCore`; la app lo importa con `import CruceCore`. Por eso el estado se prueba con `swift test`, también en Linux.
- Basta con las Command Line Tools. No hace falta prender Colima, Supabase ni un simulador.

### App iOS
```bash
cd ios
xcodegen                                    # genera Cruce.xcodeproj desde project.yml
xcodebuild -project Cruce.xcodeproj -scheme Cruce \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
open Cruce.xcodeproj                        # para correr con ⌘R y ver las vistas previas
```
- Si el simulador "iPhone 16" no existe, lista los disponibles con `xcrun simctl list devices available` y usa otro.
- Si `xcodebuild` dice "Unable to find a device matching" aunque el simulador exista (pasa cuando hay varios iOS instalados), usa su identificador: `-destination 'id=<UDID>'`.
- Para instalarla en un iPhone físico: Xcode → Signing & Capabilities → Team.
- **Cada vez que agregues o muevas archivos, vuelve a correr `xcodegen`.**
- **Abrir una pantalla directo (solo Debug):** `xcrun simctl launch <udid> com.joanrojas.cruce.dev -screen <nombre>` y luego `xcrun simctl io <udid> screenshot captura.png`. Los nombres están en `App/DebugScreen.swift` (`homeTheyOwe`, `add`, `history`, `settle`…). Sirve para comparar contra `docs/design/screens/` sin tocar la pantalla.

### Backend
```bash
cd backend
go vet ./... && go test ./...
WEBHOOK_SECRET=dev go run ./cmd/api
curl localhost:8080/healthz
```
- **El webhook en local:** con el backend en `PORT=8088 WEBHOOK_SECRET=dev`, `scripts/webhook-local.sh` crea en Supabase local el trigger de `movements` (hay que repetirlo después de cada `supabase db reset`).
- **En la nube:** una app de Fly.io por ambiente (`fly deploy -a cruce-api-testing --ha=false`, `fly logs`); los secretos los pone Joan con `fly secrets import` y el webhook se crea en el panel de Supabase. Pasos en `backend/README.md`.

### Configuración de la app (Supabase)
- **Tres ambientes, uno por configuración de Xcode:** Debug (esquema `Cruce`) → local, Staging (`Cruce Test`) → testing (`pqdjiecynyjnianslikp`) y Release (`Cruce Prod`) → prod, que todavía no existe. Identificador, nombre, ícono y ambiente de cada uno están en `ios/Cruce/Config/Cruce.xcconfig`; la tabla está en `ios/README.md`. Staging se compila como Release (sin `DEBUG` ni `-screen`).
- `ios/Config.xcconfig` (ignorado por git) define `SUPABASE_URL` y `SUPABASE_ANON_KEY` por configuración: Debug (local, `http://127.0.0.1:54321`), Staging (testing) y Release (prod, con `pega-aqui…` hasta que exista: la app de prod se detiene en vez de usar otro ambiente). Se crea copiando `ios/Config.example.xcconfig`; los pasos están en `ios/README.md`. La clave anónima es pública por diseño; la `service_role` nunca va ahí.
- En Debug la app arranca con la sesión real contra Supabase local; con `-screen <nombre>` usa los datos de ejemplo.
- Para entrar en local, levanta Supabase **desde la raíz del repo** (si no, no carga `config.toml` y el correo llega con el enlace de Supabase en vez del código) y **sin excluir `mailpit`**, y lee el código en `http://127.0.0.1:54324` (o con su API, ver `ios/README.md`).

### Supabase (local)
```bash
supabase start         # levanta Postgres, Auth y Realtime en Docker (config.toml ya está en el repo)
supabase db reset      # aplica supabase/migrations
supabase test db       # 223 pruebas pgTAP de supabase/tests
```

### Respaldo de la base de datos
El plan Free de Supabase no hace respaldos automáticos. Desde la raíz del repo:
```bash
supabase login                      # una sola vez: tu sesión
scripts/backup-db.sh testing        # respalda testing en backups/<AAAA-MM-DD_HHMMSS>_testing/
scripts/backup-db.sh --local        # respalda la base local (con supabase start)
scripts/db-push.sh testing          # sube las migraciones a testing (prod pide confirmación y respalda antes)
```
- Los scripts vinculan el proyecto del ambiente que nombras (identificadores en `supabase/ambientes.env`); no uses `supabase link` ni `supabase db push` a mano. Detalle y pasos para crear prod en `supabase/README.md`.
- Deja `schema.sql` y `data.sql` en una carpeta nueva con fecha, hora y ambiente; si un volcado falla, no deja nada a medias.
- **Cuándo:** una vez por semana durante la beta y siempre antes de aplicar una migración en la nube.
- `backups/` está en `.gitignore` porque tiene datos personales: nunca se sube ni va a la CI. La contraseña de la base la pide el CLI (o la lee de la variable de entorno `SUPABASE_DB_PASSWORD`); nunca se escribe en el repo.

### Integración continua
- `.github/workflows/ci.yml` corre en GitHub Actions (solo Linux, sin secretos) en cada `push` a `main`, en cada pull request y a mano (`gh workflow run ci.yml`).
- Un trabajo `changes` mira qué carpetas cambiaron y solo corren los trabajos que tocan; los demás quedan en “skipped”. Un cambio en `ci.yml` vuelve a correr todo.
  - `backend` (`backend/**`): `gofmt -l`, `go vet`, `staticcheck` y `go test`, con la versión de Go de `backend/go.mod`.
  - `supabase` (`supabase/**`): `supabase start` solo con Postgres y Auth (excluye el resto, incluidos `postgrest` y `kong`) y `supabase test db` sobre una base vacía.
  - `core` (`ios/Packages/CruceCore/**` o `.swift-format`): en la imagen `swift:6.4`, `swift format lint --strict` y `swift test`.
- Para verla: `gh run list --workflow ci.yml` y `gh run view <id>` (o `gh run watch`). Un commit en verde muestra los trabajos que corrieron; uno de solo documentación los deja en “skipped”.
- La app de iOS se compila en la CI solo a mano: `gh workflow run ios.yml` (macOS, `xcodegen` y `xcodebuild … -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`). Es manual porque un minuto de macOS cuesta unas 10 veces uno de Linux (si el repo deja de ser público) y es lento, y la app ya se compila en la Mac antes de cada commit que la toca (§7).

---

## 5. Diseño

- **Fuente de verdad visual:** el canvas "Cruce — 3 propuestas" en Claude, página **"Opción A · flujo completo"**: https://claude.ai/code/artifact/5771f196-d1c4-4797-928a-4cd74aa50c18 (es privado del dueño; el agente no puede abrirlo).
- **Referencia para el agente:** `docs/design/screens/*.png` (a 390×844 @2x) y `docs/design/screens/00-Guia-Estilo.png`.
- **Estilo:** neobrutalista juguetón. Fondo crema, bordes negros gruesos, sombras sólidas desplazadas (sin blur), tarjetas tipo carpeta con pestaña de color y tipografía grotesca muy bold.
- **Los tokens viven en `ios/Cruce/DesignSystem/`.** No inventes colores ni tamaños: usa `CruceColor`, `TextStyleToken`, `Radius`, `BorderWidth`, `ShadowOffset` y `Spacing`. Si cambias el diseño, actualiza también `docs/diseno.md`.

### Pantallas → código

| # | Captura | Vista de SwiftUI |
|---|---|---|
| 01, 11, 12 | Onboarding 1/3, 2/3, 3/3 | `OnboardingView` |
| 13 | Entrar: correo, código y nombre | `SignUpView` (pasos `EmailStep`, `CodeStep` y `NameStep`) |
| 14 | Invitar (la ve quien crea) | `InviteView` |
| 15 | Unirse con código (la ve quien se une) | `JoinView` |
| 16 | Conectados | `ConnectedView` |
| 02 | Inicio vacío | `HomeView` → `EmptyHomeContent` |
| 03 / 04 | Inicio: te deben / debes (Joan, recibo rosa) | `HomeView` + `BalanceCard` |
| 20 | Inicio desde la vista de Jesús (recibo verde) | `HomeView` con `.cruceStores(.sample(viewer: MockData.jesus))` |
| 05 | Agregar movimiento (también editar) | `AddMovementView(editing:)` |
| 06 | Gasto guardado (hoja inferior) | `MovementSavedSheet` |
| 07 | Historial | `HistoryView` |
| 17 | Detalle | `MovementDetailView` |
| 18 | Eliminar | `DeleteConfirmation` |
| 08 | Saldar cuentas | `SettleView` |
| 09 | A paz y salvo | `SettleSuccessView` |
| 10 | Sin conexión | `OfflineView` |
| 19 | Ajustes | `SettingsView` |

Varios cruces (sin captura en `docs/design/screens/`; se abren en Debug con `-screen <nombre>`):

| Pantalla | Vista de SwiftUI | `-screen` |
|---|---|---|
| "Tus cruces" (el inicio con dos o más cruces) | `CruceListView`, `CruceRow`, `CruceEntryButtons` | `cruces` |
| Inicio de un cruce abierto desde la lista (volver y "Con Ana") | `HomeView(showsBack: true)` | `cruceAna` |
| Unirse con un código válido o inválido | `JoinView` | `join`, `joinInvalid` |

Parches (sin captura en `docs/design/screens/`; se abren en Debug con `-screen <nombre>`):

| Pantalla | Vista de SwiftUI | `-screen` |
|---|---|---|
| "Tus parches" (también la sección del inicio) | `ParcheListView`, `HomeParchesSection` | `parches`, `parchesEmpty` |
| Nuevo parche | `NewParcheView` | `parcheNew` |
| "Tengo un código" (`CRZ-`, `PCH-`, `SOY-`) | `EnterCodeView` | `parcheCode` |
| Detalle (saldos, gastos, pagos, actividad) | `ParcheDetailView` | `parcheDetail`, `parcheDetailEnd`, `parcheClosed` |
| Anotar o editar un gasto (y borrarlo) | `ParcheExpenseView` | `parcheExpense`, `parcheExpenseItems`, `parcheDelete` |
| Anotar un pago | `ParchePaymentView` | `parchePayment` |
| Cerrar el parche y "¿Lo pasas a tu cruce?" | `CloseParcheView`, `CruceQuestionCard` | `parcheClose`, `parcheCruce` |
| Sin conexión (cola pendiente) | `ParcheSyncBanner` | `parcheOffline` |
| Tickets para compartir | `ParcheTicketView` | `parcheTicket`, `parcheTicketSettled`, `parcheTicketGroup` |

Funciones del CP11 (sin captura en `docs/design/screens/`; se abren en Debug con `-screen <nombre>`):

| Pantalla | Vista de SwiftUI | `-screen` |
|---|---|---|
| "Cambiar monto" (pago parcial) | `ChangeAmountSheet` (en `SettleView`) | `settleAmount` |
| "Pago anotado" (después de un pago parcial) | `SettleSuccessView` | `successPartial` |
| Tu perfil (cambiar el nombre) | `ProfileView` | `profile` |
| Reparto por defecto | `DefaultSplitView` | `defaultSplit` |
| "¿Desvincular a Jesús?" | `UnlinkConfirmation` (en `SettingsView`) | `unlink` |
| "Tus cruces" con un cruce cerrado | `CruceListView`, `CruceRow` ("Cerrado") | `crucesClosed` |
| Inicio de un cruce cerrado | `HomeView` + `ClosedCruceBanner` | `cruceClosed` |

### Ilustraciones
`Assets.xcassets/Illustrations/il-0X-*.imageset`. El enum `Illustration` las mapea; `Illustration.balance(_:variant:)` aplica la regla rosa o verde. Los originales están en `~/Downloads/new-idea-proyect/ilustrations/`.

---

## 6. Arquitectura

```
iPhone de Joan ─┐                       ┌─ Database Webhook ─► Backend Go ─► APNs (push)
                ├─► Supabase ───────────┤
iPhone de Jesús ┘  (Auth · Postgres ·    └─ Realtime ─► los dos iPhones
                    RLS · Realtime)
```

- **La app habla directo con Supabase** (supabase-swift): auth, lectura y escritura de movimientos, tiempo real.
- **La lógica sensible vive en Postgres:** la vista `ledger_balances` y las funciones `create_ledger_with_invite()` y `redeem_invite(code)`. RLS en todas las tablas.
- **Go va al lado, no en medio** (en Fly.io, una máquina siempre prendida por ambiente): recibe los webhooks de `movements`, envía las notificaciones push, el recordatorio mensual y limpia las invitaciones.
- Detalle en `docs/arquitectura.md`.

### Modelo de datos: Swift ↔ SQL

| Swift | SQL |
|---|---|
| `Member` (id, name, avatarColor, tikeVariant) | `profiles` + `ledger_members` (tike_variant, avatar_color) |
| `Movement.kind` `.expense` / `.settlement` | `movements.kind` `expense` / `settlement` |
| `Movement.payerID`, `amount`, `concept`, `category`, `date`, `createdBy`, `paymentMethod` | `payer_id`, `amount`, `concept`, `category`, `occurred_at`, `created_by`, `payment_method` |
| `SplitRule.equal` | `split_type = 'equal'`, `other_share_percent = 50` |
| `SplitRule.percentage(otherShare:)` | `split_type = 'percentage'`, `other_share_percent = n` |
| `SplitRule.fullOther` | `split_type = 'full_other'`, `other_share_percent = 100` |
| `Movement.owedByOther` (calculado) | `owed_by_other` (columna generada) |
| `BalanceCalculator.net` | vista `ledger_balances.net` |
| `MovementCategory` | enum `movement_category` (comida, mercado, transporte, hogar, ocio, prestamo, otro) |

### Piezas clave de la app
- **Cuatro stores** (`@MainActor @Observable`, en `CruceCore/State/` y `CruceCore/Parches/`), sin ViewModels por pantalla ni coordinador:
  - **`SessionStore`**: `phase` (etapa del flujo de entrada), `me`, `partner` (la otra persona del cruce más reciente), `cruces` (los completos, del más reciente al más viejo), `inviteCode`, `invitePreview`, `pendingJoinCode`, `member(_:)`, la sesión (`userID`, `pendingEmail`, `error`, `isWorking`, `isReady`) y las acciones:
    - `refresh()` calcula la etapa: sin sesión → onboarding; sin perfil → pedir el nombre; sin un cruce completo → invitar (un cruce pendiente no cuenta); con cruce → inicio. Toma el color y el recibo de `me` del cruce más reciente; sin cruces, amarillo y rosa.
    - `sendCode(to:)`, `resendCode()`, `verify(code:)`, `createProfile(name:)` y `signOut()` (que también olvida `me`, los cruces y los códigos).
    - Vincular: `loadInviteCode()`, `checkCode(_:)` (vista previa), `join(code:)` (pasa a `.connected`) y `checkForPartner()` (la pantalla de invitar la llama cada 3 s).
    
    - Ajustes (CP11): `updateName(_:)`, `setDefaultSplit(_:)` (reparto por defecto del cruce abierto) y `closeOpenCruce()` (desvincular). `isOpenCruceClosed` lo leen las vistas para esconder anotar, saldar, editar y eliminar; `showsCruceList` decide la raíz de `MainView` (un cruce y abierto → su inicio; si no, "Tus cruces").
    
    Recibe un `AuthService` y un `AccountDirectory`.
  - **`LedgerStore`**: los movimientos de cada cruce (`movementsByCruce`, también los eliminados); las lecturas y las acciones son del cruce abierto, y `net(of:)` y `phrase(forNet:partner:)` dan el saldo y la frase de cualquier cruce (para "Tus cruces"). Además, todos los movimientos del cruce abierto (también los eliminados) y las lecturas de los vigentes (`visibleMovements`, `movement(_:)`, `isEmpty`, `net`, `balance`, `phrase(forNet:)`…), `lastSaved` (abre la hoja "Gasto guardado"), `lastSettlement` (abre "A paz y salvo"), `isOffline`, `pendingSyncCount` y las acciones `load`, `save`, `delete`, `settle` y `retrySync`. Lee `me`/`partner` del `SessionStore` en el momento.
  - **`Router`**: `path: [Route]`, `push`, `pop` y `popToRoot`. `Route` incluye `.cruce(id)` (abre ese cruce desde la lista), `.invite` y `.join` (invitar y unirse teniendo ya cruces).
  - **El cruce abierto** vive en `SessionStore` (`openCruceID`, `openCruce`, `open(_:)`): al abrir un cruce, `partner`, el color y el recibo de `me` pasan a ser los de ese cruce, así las vistas leen `session.partner` sin saber de cruces. `lastLinked` abre "Conectados" encima del inicio cuando alguien se une o quien usa la app se une a otro cruce. La raíz de `MainView` es `CruceListView` con dos o más cruces y `HomeView` con uno.
  - **`ParcheStore`**: los parches de quien entró (`parches`, `unseenTotal`, saldos y frases), y las acciones crear, unirse, reclamar lugar, agregar sin la app, anotar/editar/borrar gasto, anotar/confirmar pago, cerrar y pasar al cruce. Los gastos y pagos sin conexión quedan en una cola (`pending`) guardada en disco con `FilePendingStore` y se reintentan (idempotentes por `id`). Recibe un `ParcheRepository` y un `PendingStore`; se carga al arrancar y cada vez que cambia `session.userID`.
  - Las acciones que cruzan stores quedan explícitas en la vista: "Cerrar sesión" (`router.popToRoot()` y `session.signOut()`), guardar un movimiento (`router.pop()` y `ledger.save`) y "Volver al inicio" en "A paz y salvo" (`router.popToRoot()`).
- **`AppStores`** y **`.cruceStores(_:)`** (`App/AppStores.swift`): agrupa los cuatro stores y los inyecta en el `Environment` con un solo modificador; lo usan `CruceApp` (la raíz de composición), `DebugScreen` y cada `#Preview`. `AppStores.live()` es el arranque real (Release, y Debug sin `-screen`): sesión, vinculación, parches y movimientos con Supabase.
- **`AppStores.sample(phase:viewer:movements:)`** (`App/AppStores+Sample.swift`, solo Debug): datos de ejemplo para la app en Debug, `DebugScreen` y las vistas previas, con `inviteCode = "CRZ-4821"`. `MockData` reproduce el canvas: desde la vista de Joan, "Jesús te debe $20.000".
- **`AuthService`** y **`AccountDirectory`** (`CruceCore/Data/AuthService.swift`): la frontera con Supabase Auth, con `profiles` y con la vinculación. `AccountDirectory` da el perfil, `cruces(for:)` (`my_cruces()`), `inviteCode(for:)` (`create_ledger_with_invite()`), `previewInvite` (`preview_invite`), `redeemInvite` (`redeem_invite`), `updateDisplayName`, `setDefaultOtherPercent` y `closeCruce` (`close_cruce`); el JSON se traduce en `CruceRemote`, probado con `swift test`. En la app los implementan `SupabaseAuthService` y `SupabaseAccountDirectory` (`ios/Cruce/Data/`), con un solo `SupabaseClient` creado en `AppStores.live()`; en pruebas y vistas previas, `InMemoryAuthService` (código `123456`) e `InMemoryAccountDirectory`. CruceCore no depende de supabase-swift.
- **`ParcheRepository`** (`CruceCore/Parches/`): la frontera de parches. En la app la implementa `SupabaseParcheRepository` (`ios/Cruce/Data/`): lee con una sola consulta de `parches` con todo embebido (RLS solo deja ver los parches propios) y escribe solo con las funciones de la base (`create_parche`, `save_parche_expense`…). La traducción del JSON, los parámetros y los errores (`hint` → `ParcheRepositoryError`, sin red → `.offline`) viven en `ParcheRemote`, probado con `swift test`. En pruebas y Debug, `InMemoryParcheRepository`.
- **`LedgerRepository`** (`CruceCore/Data/`): es la frontera con el backend. Es por cruce (`loadMovements(in:)`, `save(_:in:)`, `delete(id:in:)`): lo que se guarda en un cruce no aparece en otro. En la app la implementa `SupabaseLedgerRepository` (`ios/Cruce/Data/`, CP5): lee `movements` por `ledger_id`, guarda con `upsert` por `id` (un reintento no duplica) y elimina marcando `deleted_at`; el JSON se traduce en `MovementRemote` (CruceCore), probado con `swift test`. En Debug, después de cargar compara el saldo con `ledger_balances` y escribe en la consola (`Logger`, categoría `cuadre`). En pruebas y vistas previas, `InMemoryLedgerRepository` (un actor). `delete(id:in:)` es **borrado suave**: marca `Movement.deletedAt` (igual a `movements.deleted_at`) y conserva el movimiento; `BalanceCalculator` y las lecturas del `LedgerStore` ignoran los eliminados.

---

## 7. Convenciones

- **iOS 17+, solo iPhone, modo claro forzado**, orientación vertical.
- **Swift 5 en la app, Swift 6 en `CruceCore`:** la app sigue en `SWIFT_VERSION 5.0` (project.yml); el paquete `CruceCore` usa `swiftLanguageModes: [.v6]` (concurrencia estricta), así que sus tipos públicos de valor declaran `Sendable`. El modo de lenguaje es por módulo. SwiftUI con `@Observable` y `@Environment(SessionStore.self)`, `@Environment(LedgerStore.self)` o `@Environment(Router.self)`: cada vista lee solo lo que usa. Sin Combine ni UIKit, salvo cuando no haya alternativa (por ejemplo `UIPasteboard`).
- **Vistas con parámetros y propiedades `private` necesitan un `init` explícito:** si no, el init memberwise queda privado.
- **Cada pantalla tiene su `#Preview`**, con `.cruceStores(.sample(...))` y dentro de `#if DEBUG` (para que Release compile). Si agregas una pantalla, agrega su preview y su fila en la tabla de la sección 5.
- **`MockData` solo en Debug, vistas previas y pruebas.** Ninguna vista de producción lee `MockData` ni datos fijos como el código de invitación: `rg -n "MockData" ios/Cruce` solo debe encontrar líneas dentro de `#if DEBUG` o de un `#Preview`.
- **Textos de la interfaz en español**, con tuteo y tono cercano, sin jerga bancaria. Los comentarios del código también van en español.
- **Accesibilidad:** área táctil mínima de 44 pt, `accessibilityLabel` en los botones de solo ícono, las ilustraciones con su label y la dirección de la deuda siempre en texto.
- **Dependencias:** no agregues paquetes sin preguntar. Las previstas son `supabase-swift` (CP3) y, como opción, `swift-snapshot-testing` (CP12). El backend usa solo la librería estándar mientras se pueda.
- **Migraciones:** nunca edites una migración que ya se aplicó en la nube; crea una nueva en `supabase/migrations/`.
- **Secretos:** nunca en el repo. `.env` está en `.gitignore`. La llave `service_role` vive solo en el backend.
- **Commits:** pequeños, en español, uno por tarea del checkpoint. Antes de cada commit, en verde:
  - `cd ios/Packages/CruceCore && swift test`;
  - `cd backend && test -z "$(gofmt -l .)" && go vet ./... && staticcheck ./... && go test ./...` (`staticcheck` se instala con `go install honnef.co/go/tools/cmd/staticcheck@2026.2.2` y necesita `$(go env GOPATH)/bin` en el `PATH`);
  - `swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore` desde la raíz;
  - si el commit toca la app, también `xcodebuild … build`.

---

## 8. Riesgos conocidos y cosas sin verificar

- **La app de Swift nunca se ha compilado.** Errores probables:
  - inits memberwise privados;
  - inferencia de tipos en ternarios con `.white`;
  - `#Preview` que usan `let` y `return`.
  Corrígelos sin cambiar el comportamiento ni el diseño.
- **Fuentes:** los `.ttf` se convirtieron desde los `woff2` de Fontsource y se les renombró la tabla de nombres. Los nombres PostScript esperados son `Archivo-Medium`, `Archivo-SemiBold`, `Archivo-Bold`, `Archivo-ExtraBold` y `Archivo-Black`. Verifica que carguen; si se ve la fuente del sistema, revisa `UIAppFonts` en `project.yml`.
- **Sign in with Apple** requiere la membresía de Apple Developer (de pago), igual que las notificaciones push y TestFlight. Con una cuenta gratuita la app solo se puede instalar desde Xcode y deja de abrir a los 7 días. Por eso se entra por correo con un código; Sign in with Apple, con el botón oficial `SignInWithAppleButton`, es una función posterior.
- **Cuenta gratuita y tres apps:** las tres apps (Cruce Dev, Cruce Test y Cruce) cuentan para el límite de apps instaladas desde Xcode y de identificadores nuevos por semana. En el iPhone basta con Cruce Test.
- **Testing se pausa:** en el plan gratis, Supabase pausa un proyecto tras una semana sin uso; se reactiva desde el panel.
- **Correo en la nube:** El plan gratis de Supabase no deja editar la plantilla con su correo por defecto (que además trae un enlace, no el código), así que cada proyecto necesita SMTP propio. Testing usa SMTP de Gmail con una cuenta solo para Cruce (contraseña de aplicación, unos 500 correos al día; Gmail avisa que puede caer en spam); prod necesitará un proveedor transaccional con dominio propio. La plantilla (`supabase/templates/codigo.html`) se pega a mano en el panel de cada proyecto; no se usa `supabase config push`. Pasos en `supabase/README.md`.
- **La migración ya está en la nube:** desde ahora no se edita `20261024000000_init.sql`; cualquier cambio va en una migración nueva.
- **`redeem_invite` devuelve `jsonb`** (`ok`, `error`, `message`) en vez de lanzar errores, por el límite de 5 intentos fallidos por hora. La app debe mostrar `message`.
- **Sin conexión (CP7):** los movimientos de cada cruce y la cola de pendientes se guardan en `Application Support/Cruce/movimientos.json`, y la sesión en `sesion.json` (para abrir sin red); al volver la red (`NetworkMonitor`) o con "Reintentar" se envía la cola en orden. Si los dos editan el mismo movimiento, gana el último cambio que llega a la base (no se comparan `updated_at`). Cerrar sesión borra lo guardado, también lo pendiente sin enviar. Tiempo real (CP6): `SupabaseMovementFeed` abre un canal de Realtime por cruce mientras la app está activa; si el canal falla, deslizar y volver a la app siguen recargando. La app abre el cruce guardado o el más reciente.
- **Cruce cerrado (CP11):** desvincular pone `ledgers.closed_at` con `close_cruce()`; un trigger en `movements` rechaza anotar, editar o eliminar en un cruce cerrado (`hint = 'cruceClosed'`), también desde la cola sin conexión (sale de la cola) y desde "pasar a tu cruce" de un parche. La regla de un cruce por pareja cuenta solo los abiertos. No hay forma de reabrir un cruce: se vuelve con un código nuevo.
- **Exportar CSV:** Ajustes escribe el archivo en `tmp/Exportar/` y lo comparte con `ShareLink` y su URL. Con un `Transferable` (`FileRepresentation`), "Guardar en Archivos" fallaba en el simulador.
- **No implementado todavía:** el switch de notificaciones (CP9), "Recordarme saldar" (CP10), borrar la cuenta y el deslizar para volver con la barra de navegación oculta.

---

## 9. Cómo trabajar en este repo

1. Abre `docs/ROADMAP.md` y toma **el primer checkpoint sin marcar**. No avances al siguiente sin terminar el actual.
2. Cada checkpoint es un cambio de OpenSpec en `openspec/changes/<nombre>/` (propuesta, delta de specs y `tasks.md`). Si no existe, créalo con `/opsx:propose` (OpenCode: `/opsx-propose`) a partir del checkpoint.
3. Antes de escribir código, explica en pocas líneas el plan del checkpoint y espera el visto bueno.
4. Al terminar, verifica los criterios de "Hecho cuando", corre las pruebas, marca las casillas en `tasks.md` y en `ROADMAP.md`, actualiza la sección 2 de este archivo, archiva el cambio (`openspec archive <nombre>`, que actualiza `openspec/specs/`) y propón el commit.
5. Si una decisión es del dueño del producto (Joan), pregunta en vez de asumir. Hay una lista de decisiones abiertas en `ROADMAP.md`.

### OpenSpec
- CLI: `npx @fission-ai/openspec@1.15.0 <comando>` (o instálalo con `npm i -g @fission-ai/openspec`). Usa `OPENSPEC_TELEMETRY=0` para no enviar estadísticas de uso.
- Comandos útiles: `openspec list` (cambios), `openspec list --specs`, `openspec show <nombre>`, `openspec validate --all --strict`.
- Las specs describen comportamiento observable, no clases ni librerías. Los encabezados y las palabras SHALL/MUST van en inglés; el resto, en español.
- Historial: el CP0, el CP1 y el CP2 están archivados en `openspec/changes/archive/` (`2026-10-23-cerrar-cp0`, `2026-10-23-fidelidad-visual` y `2026-10-23-base-de-datos`). La migración de las pruebas a Swift Testing, fuera del orden del roadmap, está en `2026-10-25-migrar-pruebas-swift-testing`, y la base de calidad (CI, formato y respaldos) en `2026-10-26-base-de-calidad`. El segundo cambio de herramientas, `endurecer-rls` (políticas RLS solo para `authenticated`, `(select auth.uid())` e índices), está aplicado en la nube y archivado en `2026-10-26-endurecer-rls`. El tercero, `ordenar-app-ios` (tres stores en lugar de `AppState`, borrado suave y datos de ejemplo solo en Debug), está en `2026-10-26-ordenar-app-ios`. Con esos tres cambios terminó la preparación previa al CP3. El CP3 se hizo en el cambio `inicio-sesion-correo` (entrar con un código por correo), archivado en `2026-10-26-inicio-sesion-correo`. Los parches (grupos con inicio y fin, fuera del orden del roadmap) están en `2026-10-26-parches`. Los ambientes local, testing y prod (configuraciones de Xcode, scripts por ambiente y SMTP propio en testing) están en `2026-10-27-ambientes`. El CP4 (vincular cruces con Supabase: uno por pareja, vista previa del código y la lista de cruces en la sesión) está en `2026-10-27-vincular-cruces`. El CP8 (backend en Fly.io, logs sin datos personales y el webhook de `movements`) está en `2026-10-27-backend-desplegado`. El CP11 (pago parcial, CSV, desvincular, perfil, reparto por defecto y deslizar para eliminar) está en `2026-10-27-funciones-pendientes`.
