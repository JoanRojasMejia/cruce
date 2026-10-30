# Tasks

## 1. Regla de las teclas en CruceCore

- [x] 1.1 Pruebas primero (`AmountEntryTests`): teclas, ceros a la izquierda, `000`, borrar, límite de 12 dígitos, etiquetas de VoiceOver, monto hablado y qué teclado arranca activo y cómo cambia; verlas fallar con `swift test`
- [x] 1.2 `AmountKey`, `AmountEntry` y `AmountEntryFocus` en CruceCore hasta que `swift test` quede en verde (incluidas las pruebas de `Money` que ya existían)

## 2. Teclado acoplado compartido

- [x] 2.1 `AmountKeypad` con `AmountEntry` (monto `Int`, 12 dígitos, etiquetas y anuncio del monto); "Cambiar monto" sigue funcionando (`-screen settleAmount`)
- [x] 2.2 `AmountEntryScreen`, `MainAmountCard` y `AmountKeypadDock` en `Components/AmountEntry.swift`; compila con `xcodebuild`

## 3. Pantallas

- [x] 3.1 "Nuevo movimiento" y "Editar movimiento" con el teclado acoplado; el espacio vacío sigue cerrando el teclado del sistema (capturas `-screen add` y `-screen editMovement` en iPhone 17 Pro y SE)
- [x] 3.2 "Anotar un gasto" y "Editar el gasto" del parche con la tarjeta amarilla y el teclado acoplado; los montos de pagador, ítem y propina siguen con el teclado del sistema (capturas `-screen parcheExpense` y `-screen parcheExpenseItems`)
- [x] 3.3 "Anotar un pago" del parche con la tarjeta amarilla arriba y las sugerencias de "Para saldar" llenándola (captura `-screen parchePayment`)

## 4. Deshacer

- [x] 4.1 Probar "Deshacer" con calma en el simulador (`-screen parcheUndo` y borrar desde `-screen parcheDetail`) y corregirlo si falla

## 5. Verificación

- [x] 5.1 `swift test`, `swift format lint --strict` y `xcodebuild` en verde; recorrido en el simulador cambiando entre teclados (tarjeta, concepto, espacio vacío, "Listo") en iPhone 17 Pro y capturas de las cuatro pantallas en el SE
- [x] 5.2 `openspec validate teclado-de-montos --strict`

## Workflow follow-up

- Actualizar CLAUDE.md (§2, §5 y §6) y `docs/diseno.md` con la regla del teclado (lo hace la rama principal).
- Archivar el cambio cuando se pruebe en "Cruce Test".
