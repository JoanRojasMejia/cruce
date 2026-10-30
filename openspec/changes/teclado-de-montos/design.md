# Design

## Context

Ver proposal.md (Why). Hoy `AmountKeypad` recibe los dígitos como texto y corta en 9; solo lo usan "Nuevo movimiento" (dentro del `ScrollView`) y "Cambiar monto". `ParcheExpenseView` usa un `TextField` con `.numberPad` en la tarjeta amarilla y `ParchePaymentView` un `MoneyField` blanco. "Nuevo movimiento" ya baja el teclado del sistema al tocar el espacio vacío con un fondo que ocupa al menos el alto visible (`GeometryReader` + `minHeight`).

## Goals / Non-Goals

**Goals:**
- Un solo mecanismo para las tres pantallas: el contenedor con desplazamiento, la tarjeta amarilla y el teclado acoplado.
- La regla de las teclas y de qué teclado está abierto en CruceCore, probada con `swift test`.

**Non-Goals:**
- Cambiar los montos secundarios (`MoneyField`, `NumberField`) o "Cambiar monto" (sigue en una hoja).
- Sonidos o vibraciones nuevos: solo siguen los seis momentos de `Feedback`.

## Decisions

- **Las teclas trabajan sobre el monto (`Int`), no sobre texto.** `AmountEntry.press(_:on:)` en CruceCore: un dígito agrega a la derecha, `000` multiplica por mil, borrar divide por diez, los ceros a la izquierda no cuentan y una tecla que pasaría de 12 dígitos no hace nada. Con `Int` el `base` del gasto del parche y el `amount` del pago se enlazan sin traducir. Alternativa descartada: seguir con un `String` de dígitos, que obliga a convertir en cada pantalla.
- **12 dígitos, como `Money.parse`.** El teclado cortaba en 9; el gasto del parche ya aceptaba 12 con el teclado del sistema. Se usa un solo límite (`AmountEntry.maxDigits`).
- **Qué teclado está abierto es un valor: `AmountEntryFocus` (`amount`, `field`, `none`).** `initial(isEditing:)` da `amount` al anotar y `none` al editar. La pantalla lo guarda en `@State`; tocar la tarjeta pasa a `amount` y baja el teclado del sistema, el espacio vacío pasa a `none` y lo baja también, "Listo" pasa a `none`.
- **El teclado del sistema se detecta con los avisos de edición de los campos (`UITextField`/`UITextView.textDidBeginEditingNotification` y `textDidEndEditingNotification`), no con un `FocusState` por campo.** Así cualquier campo (concepto, nombre de ítem, `MoneyField`, `NumberField`) cierra el teclado de Cruce sin enlazar cada uno, también con un teclado físico (que no muestra el teclado en pantalla ni manda `keyboardWillShow`). Se leen con `NotificationCenter.notifications(named:)` en un `.task`, sin Combine. Cuando el campo deja de editarse estando en `field`, queda `none`.
- **El teclado acoplado va en el `safeAreaInset` de abajo, debajo del botón principal.** Así el botón queda encima del teclado (igual que con el del sistema, que empuja el `safeAreaInset`) y el `ScrollView` reduce su área visible: todo el contenido se alcanza desplazando. El teclado entra y sale con `.move(edge: .bottom)`.
- **Componentes compartidos en `Components/AmountEntry.swift`:** `AmountEntryScreen` (contenedor, fondo para el espacio vacío, botones y teclado), `MainAmountCard` (tarjeta amarilla con el cursor cuando está activa) y `AmountKeypadDock` ("Listo" + `AmountKeypad`).
- **VoiceOver:** las etiquetas y el texto hablado viven en CruceCore (`AmountKey.accessibilityLabel`, `AmountEntry.spokenValue` y `AmountEntry.announcement`). El monto hablado usa los dígitos sin puntos ("60000 pesos"), que VoiceOver en español lee como "sesenta mil pesos"; `$60.000` se puede leer como dólares o con "punto". La tarjeta es un solo elemento con etiqueta, valor y la acción por defecto; cada tecla anuncia el monto nuevo con `AccessibilityNotification.Announcement`.

## Risks / Trade-offs

- [Un campo nuevo que no sea `UITextField` ni `UITextView` no avisaría al empezar a editarse] → todos los campos de la app son `TextField` de SwiftUI, que usan esas dos clases.
- [El teclado acoplado más el botón ocupan unos 300 pt en un iPhone SE] → el contenido se desplaza encima; se revisa con capturas en el SE.
- [Pasar de 9 a 12 dígitos en "Nuevo movimiento"] → la tarjeta ya achica el texto (`minimumScaleFactor`); la base guarda `bigint`.
