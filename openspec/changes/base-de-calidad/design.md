# Design

## Context

Ver `proposal.md` (Why). Estado actual comprobado:

- No existe `.github/`: hoy no hay ninguna integración continua. El remoto es `github.com/cruce-app/cruce` y `gh repo view` lo reporta `PUBLIC` (se vuelve a verificar antes de activar la CI, porque de eso depende que los minutos sean gratis).
- `backend/go.mod` declara `go 1.22`; `backend/Dockerfile` compila con `golang:1.24-alpine`. La Mac tiene `go1.27.3`. El backend solo usa la librería estándar (sin `go.sum`).
- `ios/Packages/CruceCore/Package.swift`: `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]`. La Mac tiene Swift 6.4 (Command Line Tools), que trae `swift format`.
- `DateText` guarda tres `DateFormatter` en `private static let` y formatea con `es_CO` y patrones fijos (`d MMM`, `EEE d MMM`, `h:mm a` con `amSymbol`/`pmSymbol` propios). `Money` y los modelos son `enum`/`struct` de valor; `MockData` expone `public static let` de `Member`.
- `supabase/tests/*.sql` (54 pruebas pgTAP) insertan en `auth.users` y fijan `request.jwt.claims`; no llaman a la API HTTP. `CLAUDE.local.md` ya define un “Supabase mínimo” (db, auth, rest, kong).
- No hay `staticcheck` ni `actionlint` instalados en la Mac; sí `colima`, `docker` y `supabase`.
- La Mac tiene 8 GB de RAM: Colima y el simulador no se prenden a la vez (`CLAUDE.local.md`).

## Goals / Non-Goals

**Goals:**
- Que la CI arranque en verde desde su primer commit: primero se alinean Go y Swift 6, después se agrega la CI.
- Revisiones baratas: todo en runners de Linux, cada trabajo solo cuando cambia su carpeta, macOS solo a mano.
- Un respaldo de la base de datos que se pueda correr hoy, sin pagar un plan.

**Non-Goals:**
- Pasar la app (`ios/Cruce`) a Swift 6 o a concurrencia estricta: sigue en `SWIFT_VERSION 5.0`.
- Proteger la rama `main` con revisiones obligatorias o pull requests: durante la beta se trabaja directo en `main`.
- Desplegar el backend o aplicar migraciones desde la CI.
- Respaldos programados o automáticos en la nube (se reconsidera si se cambia de plan).
- Endurecer RLS o separar `AppState`: son los dos cambios siguientes.

## Decisions

### 1. Un flujo `ci.yml` con trabajos filtrados por carpeta

- Disparadores: `push` a `main` y `pull_request` (por si más adelante se usan), más `workflow_dispatch` para correrlo a mano.
- Un primer trabajo `changes` decide qué partes cambiaron con `dorny/paths-filter` (versión fijada), y los trabajos `backend`, `supabase` y `core` corren con `if:` según su salida. El flujo de trabajo también se incluye en cada filtro, para que un cambio en `ci.yml` vuelva a correr todo.
- `concurrency` por rama con `cancel-in-progress: true`, para no gastar minutos en commits ya superados.
- `permissions: contents: read`; ningún trabajo usa secretos.
- Las acciones de terceros se fijan por versión mayor conocida (`actions/checkout@v4`, `actions/setup-go@v5`, `supabase/setup-cli@v1`); fijarlas por SHA queda como mejora posterior.

**Por qué un solo flujo con `paths-filter` y no `on.push.paths` en tres flujos:** con `paths` a nivel de flujo, un commit que no toca nada no deja ningún resultado y no se puede tener un único estado agregado. Con un trabajo `changes`, los trabajos omitidos aparecen como “skipped”, que GitHub cuenta como éxito, y el flujo siempre informa algo.

**Alternativas:**
- *Tres flujos con `on.push.paths`* (rechazada): más archivos y sin vista única; sirve igual para el costo.
- *Correr todo en cada commit* (rechazada): la revisión de Supabase tarda varios minutos en bajar imágenes aunque el cambio sea de documentación.

### 2. Trabajo `backend`

- `actions/setup-go` con `go-version-file: backend/go.mod`, así la CI usa siempre la versión del módulo.
- Pasos: `test -z "$(gofmt -l .)"` (imprime los archivos sin formato antes de fallar), `go vet ./...`, `staticcheck ./...` y `go test ./...`.
- `staticcheck` con `dominikh/staticcheck-action` fijado a una versión que soporte la versión de Go elegida; en la Mac, `go install honnef.co/go/tools/cmd/staticcheck@<versión>`. No entra a `go.mod` (no es dependencia del módulo).

### 3. Versión de Go: 1.27 en `go.mod`, Dockerfile y CI

- `go.mod`: `go 1.27.0`. Sin línea `toolchain`: con la librería estándar y la misma versión en todos lados no aporta, y `setup-go` lee la directiva `go`.
- `backend/Dockerfile`: `golang:1.27-alpine` (se verifica que la etiqueta existe con `docker pull` antes del commit).
- §3 de `CLAUDE.md` pasa de “Go 1.22+” a “Go 1.27”.

**Por qué 1.27 y no 1.24:** Go da soporte a las dos últimas versiones mayores. A octubre de 2026 son 1.27 y 1.26; 1.24 ya no recibe parches de seguridad, y la Mac ya tiene 1.27.3. Alinear a 1.24 dejaría al backend en una versión sin soporte desde el primer día.

**Alternativas:**
- *`go 1.24` + `toolchain go1.24.x`* (rechazada): coincide con el Dockerfile actual, pero es una versión sin soporte.
- *`go 1.26`* (rechazada): también tiene soporte, pero obliga a instalar otra versión en la Mac sin ninguna ventaja.

### 4. Trabajo `supabase`

- `supabase/setup-cli@v1` con una versión fijada (la misma que tiene la Mac, `supabase --version`).
- `supabase start` con exclusiones: `-x realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor,postgrest,kong`, y luego `supabase test db`. Las pruebas solo hablan SQL, así que no necesitan `postgrest` ni `kong`.
- Si `supabase test db` falla sin `gotrue` o sin `kong` (por ejemplo, porque `auth.users` lo crean las migraciones de GoTrue o porque el CLI espera la API), se agregan de vuelta solo los servicios necesarios. La lista final se decide en la Mac, en la tarea 4.1, antes de escribirla en la CI.
- `supabase start` ya aplica `supabase/migrations` sobre una base vacía; no hace falta `db reset`.

### 5. Trabajo `core`: Swift en Linux con la imagen oficial

- `container: swift:6.4` (misma versión menor que la Mac; se verifica la etiqueta en Docker Hub). Pasos: `swift format lint --strict --recursive Sources Tests` y `swift test`, dentro de `ios/Packages/CruceCore`.
- La plataforma `.macOS(.v14)` del paquete no impide compilar en Linux; `platforms` solo restringe las plataformas de Apple.
- `swift format` viene en la imagen de Swift 6; no se instala nada más.

### 6. Compilación de iOS a mano

- Flujo aparte `ios.yml` solo con `workflow_dispatch`, en `macos-latest` (o la versión más nueva con Xcode compatible): `brew install xcodegen`, `cd ios && xcodegen`, `xcodebuild -project Cruce.xcodeproj -scheme Cruce -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- `generic/platform=iOS Simulator` evita depender del nombre de un simulador instalado en el runner.
- **Por qué manual:** en repos privados un minuto de macOS cuenta 10 veces uno de Linux; aunque el repo público no paga minutos estándar, el flujo de macOS es lento y la app se compila en la Mac antes de cada commit que la toca (§7). Si el repo pasa a privado, esta decisión ya protege el costo.

### 7. Formato de Swift

- `.swift-format` en la raíz del repo (lo encuentran tanto `ios/Cruce` como el paquete). Se parte de `swift format dump-configuration` y se ajusta a lo que ya usa el código: sangría de 4 espacios y largo de línea de 120. Las reglas se dejan por defecto salvo las que choquen con el estilo de SwiftUI ya escrito (por ejemplo, `NoLeadingUnderscores` o la documentación obligatoria de símbolos públicos), que se desactivan con una línea de motivo en la tarea.
- `swift format --in-place --recursive ios/` va en un commit propio que solo cambia formato. Se verifica con `swift test` y `xcodebuild build`.
- La CI revisa con `--strict` solo `ios/Packages/CruceCore` (lo que corre en Linux). La app se revisa en la Mac (`swift format lint --strict --recursive ios/Cruce`) y en el flujo manual de iOS.

### 8. `CruceCore` en Swift 6

- `swiftLanguageModes: [.v6]` en `Package.swift`. Primero se cambia solo eso y se observa el error (RED); después se corrige (GREEN).
- Corrección esperada: `Sendable` explícito en los tipos públicos de valor que se guardan en `static let` o cruzan actores (`Member`, `Movement`, `SplitRule`, `MovementCategory`, `TikeVariant`, `AvatarColor`, `BalanceState`). Para tipos públicos el compilador no infiere `Sendable` fuera del módulo, así que se declara.
- `DateText`: si `DateFormatter` no es `Sendable` en alguna plataforma, se reemplazan los `static let` por formateadores creados en cada llamada o por `Date.FormatStyle` con el mismo patrón fijo, sin cambiar el texto. Se prefiere crear el formateador en la función: es lo más simple y el costo no importa a este volumen.
- La app (Swift 5) consume el paquete en modo 6 sin problema: el modo de lenguaje es por módulo.

### 9. Respaldo con `scripts/backup-db.sh`

- `set -euo pipefail`. Comprueba que existe `supabase` y que el proyecto está vinculado (`supabase/.temp/project-ref`, que ya está en `.gitignore`); si no, sale con un mensaje que dice qué hacer (`supabase login` y `supabase link`).
- Corre `supabase db dump -f <tmp>/schema.sql` y `supabase db dump --data-only -f <tmp>/data.sql` en una carpeta temporal y, solo si los dos terminan bien, la mueve a `backups/<AAAA-MM-DD_HHMMSS>/`. Así un fallo no deja archivos a medias.
- Opción `--local` para respaldar la base local (`supabase db dump --local`): es lo que verifica el agente. La corrida contra la nube la hace el usuario, porque necesita su sesión y su proyecto vinculado.
- La contraseña de la base nunca va en el script: la pide el CLI o se pasa por la variable `SUPABASE_DB_PASSWORD`, que no se guarda en el repo.
- `.gitignore` agrega `backups/`. El plan Free no hace respaldos, así que §4 de `CLAUDE.md` recomienda correrlo antes de cada migración que vaya a la nube y al menos una vez por semana durante la beta.
- **Alternativa rechazada:** un flujo programado en la CI que haga el respaldo. Necesitaría la contraseña de la base como secreto del repo y guardar los datos personales en artefactos de un repo público.

## Risks / Trade-offs

- [`DateText` en Linux: swift-corelibs-foundation puede dar otros textos para `es_CO` (abreviaturas de mes y día, puntos, mayúsculas)] → Antes de confiar en la CI se corre la suite en Linux en la Mac con Colima: `docker run --rm -v "$PWD/ios/Packages/CruceCore:/pkg" -w /pkg swift:6.4 swift test`. Si hay diferencias, la opción preferida es **(a) fijar los textos con patrones y símbolos explícitos** en `DateText` (como ya se hace con `amSymbol`/`pmSymbol`: `shortMonthSymbols` y `shortWeekdaySymbols` propios), porque mantiene una sola verdad y la prueba sigue corriendo en las dos plataformas. Se descartan (b) correr esa suite solo en macOS, que deja la CI sin revisar fechas, y (c) aceptar diferencias por plataforma, que contradice la spec de `pruebas-logica`.
- [Memoria de la Mac: la imagen de Swift y Supabase en Docker] → Modo “Base de datos / backend” de `CLAUDE.local.md`: Colima prendido y ningún simulador. La corrida de Linux y la de Supabase no se hacen a la vez con el simulador; al terminar, `supabase stop && colima stop`.
- [El primer `swift format --in-place` cambia muchos archivos y esconde cambios reales] → Va solo en su propio commit, sin ningún otro cambio, y se verifica con `swift test` y `xcodebuild build`.
- [Una exclusión de servicios de Supabase de más rompe `supabase test db`] → Se prueba la lista en la Mac antes de escribirla en la CI (decisión 4).
- [La CI depende de servicios externos (Docker Hub, GitHub)] → Es solo una revisión: si falla por la red, se vuelve a correr; nunca bloquea un commit local.
- [`staticcheck` aún no soporta Go 1.27] → Se fija la versión más nueva que lo soporte; si no existe, `staticcheck` queda fuera de la CI con una nota y el resto sigue.
- [El repo deja de ser público y los minutos se cobran] → Linux es barato y macOS ya es manual; se revisa la facturación si cambia la visibilidad.
- [Un respaldo de la nube contiene datos personales] → Queda solo en la Mac, en `backups/` ignorado por git; nunca en la CI ni en el repo.

## Migration Plan

1. Alinear Go a 1.27 (go.mod, Dockerfile) y agregar `staticcheck`, corrigiendo lo que reporte.
2. Pasar `CruceCore` a Swift 6 (RED → GREEN) y comprobar la suite en Linux con Docker.
3. Agregar `.swift-format`, formatear `ios/` en un commit propio.
4. Decidir en la Mac la lista mínima de servicios de Supabase.
5. Agregar `ci.yml` e `ios.yml` (la CI arranca en verde porque los pasos 1 a 4 ya están).
6. Agregar el script de respaldo y la documentación.

El push a `main` (que activa la CI por primera vez) lo decide el usuario. Rollback: revertir el commit del flujo apaga la CI; los demás commits son independientes.

## Open Questions

- Cada cuánto correr el respaldo de la nube en la práctica (semanal o antes de cada migración): se puede ajustar en `CLAUDE.md` sin cambiar el script.
