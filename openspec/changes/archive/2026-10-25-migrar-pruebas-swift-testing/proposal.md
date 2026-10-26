# Proposal

## Why

Hoy las 16 pruebas de la lógica pura (saldo neto, formato de pesos y fechas) usan XCTest dentro del proyecto de Xcode, así que solo corren con Xcode y un simulador. La Mac de desarrollo tiene 8 GB de RAM: con solo las Command Line Tools, Swift Testing corre bien pero XCTest no (verificado), y sin Xcode no hay SDK de iOS. Mover esa lógica a un paquete local permite correr las pruebas con `swift test` en segundos, sin Xcode ni simulador.

Es un cambio de herramientas, fuera del orden de checkpoints de `docs/ROADMAP.md`. Joan y Jesús lo acordaron y va antes del CP3, para que el trabajo con Supabase ya tenga pruebas rápidas.

## What Changes

- Nuevo paquete local `ios/Packages/CruceCore` con la lógica pura de la app: modelos (`Member`, `Movement` y sus tipos), dominio (`BalanceCalculator`, `Money`, `DateText`) y los datos de ejemplo que usan las pruebas. Los archivos se mueven con `git mv` para conservar el historial.
- La app importa el paquete (`import CruceCore`) en los archivos que usan esos tipos; la API que la app usa pasa a ser `public`. El comportamiento de la app no cambia.
- Las 16 pruebas pasan de XCTest a Swift Testing, una a una y con las mismas aserciones; los casos en forma de tabla (formato y redondeo) pasan a pruebas parametrizadas. No se pierde ninguna prueba.
- Las pruebas de fechas dejan explícitos el idioma, el calendario y la zona horaria, para que el resultado no dependa de la configuración de la máquina.
- `project.yml`: el target de la app depende del paquete local y se elimina el target `CruceTests` de XCTest. **BREAKING** para el flujo de trabajo: `⌘U` y `xcodebuild … test` dejan de correr estas pruebas; el comando pasa a ser `cd ios/Packages/CruceCore && swift test`.
- Documentación: `CLAUDE.md` (§3 estructura, §4 cómo probar, §7 regla de commits) e `ios/README.md`.

## Capabilities

### New Capabilities
- `pruebas-logica`: cómo se verifica la lógica pura de la app (dónde y con qué corre, qué cubre y de qué no depende).

### Modified Capabilities

## Impact

- Código: `ios/Cruce/Models/`, `ios/Cruce/Domain/` y `ios/Cruce/Data/MockData.swift` se mueven al paquete; unos 20 archivos de `Screens/`, `Components/`, `App/` y `Data/` agregan `import CruceCore`.
- Pruebas: `ios/CruceTests/` se mueve a `ios/Packages/CruceCore/Tests/CruceCoreTests/` y se reescribe con Swift Testing.
- Proyecto: `ios/project.yml` (paquete local, sin `CruceTests`). Comprobar que la app compila requiere Xcode, que se está instalando.
- Sin cambios en el backend, la base de datos ni las dependencias externas: el paquete es local y Swift Testing viene con la herramienta de Swift.
