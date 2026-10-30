# Proposal

## Why

Hoy el monto principal se escribe de tres formas distintas: en "Nuevo movimiento" el teclado de Cruce va dentro del contenido (hay que bajar para verlo en pantallas chicas), en "Anotar un gasto" del parche se usa el teclado del sistema dentro de la tarjeta amarilla y en "Anotar un pago" del parche es un campo blanco abajo. Joan aprobó una sola regla: "el monto principal se escribe con el teclado de Cruce; los montos secundarios, con el del sistema".

## What Changes

- El teclado de Cruce (1 a 9, `000`, `0` y borrar) va acoplado abajo, como un teclado, en "Nuevo movimiento" (y "Editar movimiento"), "Anotar un gasto" y "Editar el gasto" del parche y "Anotar un pago" del parche. Lleva "Listo" para cerrarlo y el botón principal de la pantalla sigue a la vista encima.
- "Anotar un pago" del parche pasa el monto a la tarjeta amarilla arriba, como en el cruce; tocar una sugerencia de "Para saldar" la sigue llenando.
- Nuevo: el monto arranca activo (el teclado abierto). Editar: nada arranca activo y tocar la tarjeta abre el teclado.
- Cambio entre teclados: tocar la tarjeta abre el de Cruce y cierra el del sistema; tocar otro campo hace lo contrario; tocar el espacio vacío cierra los dos.
- Los montos secundarios (lo que puso cada pagador, el monto de un ítem, la propina) siguen con el teclado del sistema. "Cambiar monto" en Saldar sigue en una hoja con el teclado de Cruce.
- VoiceOver: cada tecla tiene su etiqueta ("Borrar", "Tres ceros", el dígito); la tarjeta dice el monto y se abre con la acción por defecto, y al tocar una tecla se anuncia el monto nuevo ("Monto: 60000 pesos", que se oye "sesenta mil pesos").
- El teclado de Cruce acepta hasta 12 dígitos, el mismo límite que ya tiene la lectura de montos (`formato-pesos`); antes cortaba en 9.
- Se vuelve a probar "Deshacer" después de borrar un gasto del parche y se corrige si falla.

## Capabilities

### New Capabilities
- `teclado-de-montos`: qué teclado se usa para cada monto, dónde va el teclado de Cruce, qué arranca activo, cómo se pasa de un teclado al otro y cómo lo lee VoiceOver.

### Modified Capabilities

Ninguna: "Deshacer al borrar un gasto" (`parches`) y "Captura de montos desde el teclado" (`formato-pesos`) no cambian de requisito.

## Impact

- App iOS: `Components/AmountKeypad.swift` y un componente compartido para el teclado acoplado y la tarjeta amarilla; `AddMovementView`, `ParcheExpenseView`, `ParchePaymentView` y `ChangeAmountSheet` (solo el tipo del monto); `DebugScreen` con pantallas nuevas para revisar los estados.
- CruceCore: la regla de las teclas, las etiquetas de VoiceOver, el texto hablado del monto y qué teclado está abierto, con pruebas de Swift Testing.
- Sin cambios en la base, el backend ni las dependencias.
