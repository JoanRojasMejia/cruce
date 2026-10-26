# Tasks

Cada tarea termina en un commit (Conventional Commits, descripción en español, por ejemplo `test(ios): …`). Requisito de cada commit: `cd ios/Packages/CruceCore && swift test` en verde, salvo la tarea 1.1, que deja la prueba en rojo a propósito y se confirma junto con la 2.1.

## 1. Paquete

- [x] 1.1 Crear `ios/Packages/CruceCore/Package.swift` (tools 6.0, `swiftLanguageModes: [.v5]`, iOS 17 y macOS 14, librería `CruceCore` y target de pruebas `CruceCoreTests`) con una prueba de Swift Testing que use `Money.format(30_000)` (verificado: `swift test` falla en RED porque `Money` todavía no está en el paquete)

## 2. Mover la lógica

- [x] 2.1 Mover con `git mv` `ios/Cruce/Models/`, `ios/Cruce/Domain/` y `ios/Cruce/Data/MockData.swift` a `Sources/CruceCore/{Models,Domain,Fixtures}`, agregar `public` (con `public init` en los `struct`) a la API que usa la app y `import CruceCore` en los archivos de la app que la usan. En el mismo commit, en `ios/project.yml`, agregar el paquete local `CruceCore` como dependencia del target `Cruce` y eliminar el target `CruceTests` y su entrada en el esquema, para que ningún commit deje la app sin poder compilar (los archivos de `ios/CruceTests/` se migran en el grupo 3) (verificado: la prueba de 1.1 pasa en GREEN con `swift test`; `git log --follow` muestra el historial de los archivos movidos; `rg` no encuentra en `ios/Cruce/` un archivo que use esos tipos sin `import CruceCore`; `rg CruceTests ios/project.yml` no encuentra nada y `xcodegen` genera el proyecto sin errores). Commit: `refactor(ios): mover modelos y dominio al paquete CruceCore`

## 3. Migrar las pruebas a Swift Testing

- [x] 3.1 Mover `MoneyTests.swift` con `git mv` a `Tests/CruceCoreTests/` y reescribirlo con `@Suite`, `@Test` y `#expect`; formato y lectura como pruebas parametrizadas; quitar la prueba provisional de 1.1 (verificado: `swift test --filter MoneyTests` pasa y cubre los 10 pares de valores de las 3 pruebas originales). Commit: `test(ios): migrar MoneyTests a Swift Testing`
- [x] 3.2 Mover y reescribir `DateTextTests.swift` con el calendario y la zona horaria explícitos (verificado: `TZ=America/Bogota swift test --filter DateTextTests` y `TZ=Asia/Tokyo swift test --filter DateTextTests` pasan con las 4 pruebas y sus 7 aserciones). Commit: `test(ios): migrar DateTextTests a Swift Testing`
- [x] 3.3 Mover y reescribir `BalanceCalculatorTests.swift`, con el redondeo de montos impares parametrizado y `try #require` donde antes había `throws` (verificado: `swift test --filter BalanceCalculatorTests` pasa con los 9 casos originales y sus 16 aserciones más el `XCTUnwrap`). Commit: `test(ios): migrar BalanceCalculatorTests a Swift Testing`
- [x] 3.4 Documentar el nuevo comando de pruebas en `ios/README.md` y en `CLAUDE.md` §4 (verificado: el comando escrito, `cd ios/Packages/CruceCore && swift test`, corre tal cual y pasa). Commit: `docs(ios): explicar cómo correr las pruebas con swift test`

## 4. Proyecto de Xcode

- [x] 4.1 Compilar la app con Xcode: `cd ios && xcodegen && xcodebuild -project Cruce.xcodeproj -scheme Cruce -destination 'platform=iOS Simulator,name=iPhone 16' build` (verificado: `BUILD SUCCEEDED`; requiere Xcode instalado. Si falta un `public` o un `import`, se corrige aquí con su propio commit `fix(ios): …`)
- [x] 4.2 Actualizar `CLAUDE.md` §2 (fila de pruebas de Swift), §3 (estructura con `ios/Packages/CruceCore`, sin `CruceTests`) y §7 (antes de cada commit: `swift test` en el paquete y `go test ./...`; `xcodebuild build` cuando se toque la app), y la tabla de estructura de `ios/README.md` (verificado: `rg -n "CruceTests|⌘U" CLAUDE.md ios/README.md` no encuentra referencias viejas). Commit: `docs: actualizar estructura y reglas de pruebas`

## 5. Verificación final

- [ ] 5.1 Correr `cd ios/Packages/CruceCore && swift test` en una Mac sin abrir Xcode ni simulador (verificado: pasan 16 casos o más, sin fallos, y la lista de pruebas cubre todos los casos de las pruebas originales)

## Workflow follow-up

- Archivar el cambio con `OPENSPEC_TELEMETRY=0 npx -y @fission-ai/openspec@1.15.0 archive migrar-pruebas-swift-testing` solo cuando la 4.1 esté verificada con Xcode.
- Verificar que `openspec/specs/pruebas-logica/spec.md` quedó creado y que `openspec validate --all --strict` pasa.
