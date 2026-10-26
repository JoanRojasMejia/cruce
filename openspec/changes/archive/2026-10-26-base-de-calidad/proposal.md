# Proposal

## Why

Hoy nada se revisa solo: las pruebas de la lógica (`swift test`), del backend (`go test`) y de la base de datos (`supabase test db`) corren solo cuando alguien se acuerda de correrlas en su Mac. Además, el plan Free de Supabase no hace respaldos automáticos, así que hoy no hay ninguna copia de los datos de la nube. Antes del CP3, que conecta la app con Supabase, hace falta una red de seguridad barata para que cada cambio posterior se revise automáticamente.

Es un cambio de herramientas, fuera del orden de checkpoints de `docs/ROADMAP.md`, y es el primero de tres que van antes del CP3, en este orden:

1. `base-de-calidad` (este cambio): integración continua, formato, versiones alineadas y respaldos.
2. Endurecer las políticas RLS en una migración nueva.
3. Separar `AppState` y agregar borrado suave en la app de iOS.

Decisiones de los dueños que este cambio toma como restricciones:

- Se sigue en el plan Free de Supabase.
- El backend en Go se mantiene a propósito (quieren mostrar el manejo de Go).
- Durante la beta se trabaja directo en `main` (trunk-based); `git push` solo cuando el usuario lo pida.

## What Changes

- **Integración continua en GitHub Actions, solo Linux**: un flujo de trabajo con trabajos que corren solo cuando cambian sus carpetas:
  - backend (`backend/**`): `gofmt -l`, `go vet`, `staticcheck` y `go test ./...`;
  - base de datos (`supabase/**`): Supabase CLI con solo los servicios que necesitan las pruebas pgTAP y `supabase test db`;
  - lógica (`ios/Packages/CruceCore/**`): `swift format lint --strict` y `swift test` en la imagen oficial de Swift para Linux.
- **Compilación de la app de iOS bajo demanda**: `xcodebuild build` en macOS solo con `workflow_dispatch` (manual), porque un minuto de macOS cuesta unas 10 veces uno de Linux.
- **Formato y lint**: `swift format lint --strict` (viene con la herramienta de Swift 6) con una configuración `.swift-format` en el repo; una pasada única de `swift format --in-place` sobre `ios/` en su propio commit, sin cambios de comportamiento; `gofmt` y `staticcheck` para Go.
- **Versión de Go alineada**: `go.mod` dice `go 1.22` y `backend/Dockerfile` usa `golang:1.24-alpine`. Se alinean los dos (y la CI) a una sola versión.
- **`CruceCore` en modo de lenguaje Swift 6** (`swiftLanguageModes: [.v6]`), corrigiendo los errores de concurrencia estricta que aparezcan. La app sigue en Swift 5.
- **Respaldos para el plan Free**: `scripts/backup-db.sh` corre `supabase db dump` (esquema y datos) y deja archivos con fecha y hora en `backups/`, que queda fuera de git. Los secretos nunca entran al repo.
- **Documentación**: `CLAUDE.md` §4 y §7 (cómo corre la CI, comandos de formato y lint, respaldo), `backend/README.md` (`staticcheck`) e `ios/README.md` (formato).

## Capabilities

### New Capabilities
- `verificacion-automatica`: qué se revisa solo en cada cambio que llega al repositorio, cuándo corre cada revisión y qué revisiones son manuales.
- `respaldo-base-datos`: cómo se saca y se guarda una copia de la base de datos de la nube mientras el plan no tenga respaldos automáticos.

### Modified Capabilities
- `pruebas-logica`: se agrega que las pruebas de la lógica también corran y pasen en Linux, no solo en la Mac, y que la lógica compile sin errores con la revisión estricta de concurrencia.

## Impact

- Archivos nuevos: `.github/workflows/ci.yml` (y un flujo manual para iOS), `.swift-format`, `scripts/backup-db.sh`.
- Cambios: `backend/go.mod`, `backend/Dockerfile`, `ios/Packages/CruceCore/Package.swift` y, si hace falta, tipos de `CruceCore` (`Sendable`); formato de todos los `.swift` de `ios/`; `.gitignore` (`backups/`); `CLAUDE.md`, `backend/README.md`, `ios/README.md`.
- Herramientas: `staticcheck` (instalado con `go install`, no es dependencia del módulo); en la CI, acciones oficiales de Go y de Supabase y la imagen `swift` de Docker. No se agregan paquetes a la app ni al backend.
- Costo: el repositorio es público, así que los runners estándar de GitHub Actions no cobran minutos (se verifica antes de activar la CI). El flujo de macOS es manual.
- Sin cambios en el comportamiento de la app, el backend ni la base de datos.
