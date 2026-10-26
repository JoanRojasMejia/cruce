# Design

## Context

Ver `proposal.md` (Why). Estado actual comprobado:

- `ios/Cruce/Domain/{BalanceCalculator,Money,DateText}.swift` y `ios/Cruce/Models/{Movement,Member}.swift` solo importan `Foundation`. `BalanceCalculator` depende de `Movement`, así que los modelos se mueven con el dominio.
- `BalanceCalculatorTests` usa `MockData` (`ios/Cruce/Data/MockData.swift`, 48 líneas, solo `Foundation`, depende de `Member` y `Movement`) en tres casos (`joan`/`jesus` y `testNetIsSymmetricBetweenBothMembers`, `testMockDataMatchesDesign`). La app también lo usa en unos 9 archivos (previews, `AppState`, `DebugScreen`).
- Pruebas: `BalanceCalculatorTests` (9), `DateTextTests` (4) y `MoneyTests` (3), 16 casos con XCTest y `@testable import Cruce`.
- `DateText` fija el idioma `es_CO` en sus formateadores, pero estos usan la zona horaria del sistema; las pruebas construyen la fecha con un calendario gregoriano que también usa la zona del sistema.
- `ios/project.yml` (XcodeGen) define `Cruce` y `CruceTests`; `SWIFT_VERSION 5.0`, iOS 17. El esquema `Cruce` corre `CruceTests` en `test`.
- Herramienta en la Mac: Swift 6.4 de las Command Line Tools (`xcode-select -p` → `/Library/Developer/CommandLineTools`). Swift Testing corre; XCTest no.

## Goals / Non-Goals

**Goals:**
- Un módulo real (`CruceCore`) que la app importa y que se prueba con `swift test` sin Xcode.
- Migrar las 16 pruebas sin perder ninguna aserción.
- Conservar el historial de git de los archivos movidos.

**Non-Goals:**
- Cambiar el comportamiento de la lógica o de la app.
- Pasar el proyecto a Swift 6 o a concurrencia estricta.
- Probar vistas, `AppState` o `LedgerRepository` (siguen en la app; quedan para checkpoints posteriores).

## Decisions

### 1. Paquete local `ios/Packages/CruceCore`

- `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]` (mismo modo que la app), `platforms: [.iOS(.v17), .macOS(.v14)]`. macOS hace falta para que `swift test` corra en la Mac.
- Un producto de librería `CruceCore` con un target `CruceCore` (`Sources/CruceCore/{Models,Domain,Fixtures}`) y un target de pruebas `CruceCoreTests`.
- Se mueve con `git mv`: `Models/`, `Domain/` y `Data/MockData.swift` (a `Fixtures/`). `LedgerRepository` e `InMemoryLedgerRepository` se quedan en la app.
- Sin dependencias externas: Swift Testing viene con la herramienta.

**Por qué `MockData` va al paquete:** las pruebas lo usan y la app también; dejarlo en la app obligaría a copiarlo en las pruebas, con el riesgo de que dejen de coincidir con el canvas.

**Alternativas:**
- *Compilar los mismos archivos en la app y en el paquete* (rechazada): evita el `public`, pero no hay frontera real de módulo y la app podría depender de detalles internos sin que nadie lo note.
- *Seguir con XCTest* (rechazada): cada corrida necesita Xcode y un simulador, algo que la Mac de 8 GB no aguanta junto con Supabase.
- *Copiar `MockData` en las pruebas* (rechazada): duplica datos que deben coincidir con el diseño.

### 2. API pública mínima

- `public` en los tipos, casos, propiedades y funciones que la app usa: `Member`, `TikeVariant`, `AvatarColor`, `Movement` (y `Movement.Kind`), `SplitRule`, `MovementCategory`, `BalanceCalculator`, `Money`, `DateText` y `MockData`.
- Los `struct` necesitan un `public init` explícito: el init memberwise no es público.
- Las conformidades (`Identifiable`, `Codable`, `Hashable`, `CaseIterable`) se mantienen; al ser públicos los tipos, sus requisitos (`id`, etc.) también quedan `public`.
- Lo que solo usan las pruebas queda `internal` y se alcanza con `@testable import CruceCore`.
- La app agrega `import CruceCore` en los archivos que usan esos tipos (unos 20, ubicados con `rg`).

### 3. Pruebas con Swift Testing

- Un `@Suite` por archivo actual (`BalanceCalculatorTests`, `MoneyTests`, `DateTextTests`), movidos con `git mv` a `Tests/CruceCoreTests/` y reescritos: `func testX()` → `@Test("descripción en español") func x()`, `XCTAssertEqual(a, b)` → `#expect(a == b)`, `XCTUnwrap`/`throws` → `try #require`.
- Pruebas parametrizadas solo donde el caso ya es una tabla: `Money.format` (pares monto → texto, con y sin signo), `Money.parse` y redondeo de montos impares. Cada fila de la tabla conserva el par de valores de la aserción original.
- Conteo: Swift Testing cuenta cada fila de una prueba parametrizada como caso. El criterio es “16 o más casos y ninguna aserción perdida”, que se revisa contra la lista de las pruebas actuales.

### 4. Fechas independientes de la máquina

- El idioma ya está fijo en `DateText` (`es_CO`). Las pruebas fijan el calendario (gregoriano) y construyen las fechas en la misma zona horaria que usan los formateadores, de forma explícita.
- Se comprueba corriendo la suite con dos zonas: `TZ=America/Bogota swift test` y `TZ=Asia/Tokyo swift test`.
- *Alternativa rechazada:* agregar a `DateText` un parámetro de zona horaria. Cambia la API sin necesidad de producto; se reconsidera si la comprobación con dos zonas falla.

### 5. `project.yml`

- `packages: CruceCore: path: Packages/CruceCore` y `dependencies: - package: CruceCore` en el target `Cruce`.
- Se elimina el target `CruceTests` y su entrada en el esquema (`build` y `test`): no queda ninguna prueba de XCTest que lo justifique. Si más adelante hay pruebas de UI o de la app, se agrega un target nuevo.

## Risks / Trade-offs

- [Comprobar que la app compila necesita Xcode, que se está instalando] → La parte de `swift test` se verifica ya; la tarea de `xcodegen` + `xcodebuild build` queda marcada como pendiente hasta tener Xcode, y el cambio no se archiva sin ella.
- [Falta un `public` o un `import CruceCore` y la app no compila] → Se busca con `rg` cada tipo movido en `ios/Cruce/` antes del commit; `xcodebuild build` lo confirma.
- [`swift-tools-version 6.0` con modo de lenguaje 5 se comporta distinto de la app] → El paquete usa `.v5`, igual que `SWIFT_VERSION 5.0`.
- [Se pierde una aserción al reescribir] → Cada tarea de migración compara la lista de aserciones antes y después.
- [Romper la regla de commits de §7 (`xcodebuild … test` en verde)] → Mientras no haya Xcode, el requisito para cada commit es `swift test` en verde; §7 se actualiza en este cambio.

## Migration Plan

1. Crear el paquete con una prueba que falle (RED).
2. Mover modelos, dominio y datos de ejemplo; agregar `public` e `import CruceCore` (GREEN).
3. Migrar las pruebas archivo por archivo.
4. Actualizar `project.yml`, regenerar y compilar con Xcode.
5. Actualizar la documentación.

Rollback: revertir los commits del cambio; los `git mv` hacen que el historial de los archivos vuelva intacto.
