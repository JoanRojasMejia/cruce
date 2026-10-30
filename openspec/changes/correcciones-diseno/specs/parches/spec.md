## MODIFIED Requirements

### Requirement: Estados del parche
Un parche SHALL estar abierto o cerrado. Solo quien creó el parche SHALL poder cerrarlo, después de confirmar; a los demás la base MUST rechazarlo y la app MUST mostrarles "Pídele a <nombre> que lo cierre" en lugar del botón. Si quien lo creó ya no tiene la app, cualquier participante con la app SHALL poder cerrarlo. Cerrar MUST quedar en la actividad del parche. Un parche cerrado MUST NOT aceptar gastos nuevos ni ediciones de gastos y MUST NOT reabrirse. Un parche cerrado en el que todos los saldos son cero SHALL mostrarse "A paz y salvo".

#### Scenario: Cerrar
- **WHEN** Jesús creó el parche, lo cierra y confirma
- **THEN** ya no se pueden anotar gastos, se siguen pudiendo anotar pagos y los del parche ven "Jesús cerró el parche"

#### Scenario: Otra persona quiere cerrarlo
- **WHEN** Ana está en el parche que creó Jesús
- **THEN** en vez de "Cerrar el parche" ve "Pídele a Jesús que lo cierre", y si lo intenta igual la base responde "Solo Jesús puede cerrar el parche"

#### Scenario: Queda a paz y salvo
- **WHEN** en un parche cerrado se confirma el último pago pendiente y todos los saldos quedan en cero
- **THEN** el parche se muestra "A paz y salvo" en la lista de parches

### Requirement: Avisos dentro de la app
El parche SHALL mostrar su actividad (gastos anotados, editados o borrados; pagos anotados o confirmados; personas agregadas, que se unieron o que se quedaron con su lugar; parche cerrado) y un contador de lo que la persona no ha visto. La actividad SHALL estar en su propia pantalla, que se abre desde el encabezado del detalle del parche, y el encabezado MUST mostrar cuántos avisos hay sin ver. Al abrir la actividad el contador SHALL volver a cero y los avisos que eran nuevos SHALL verse resaltados. No hay notificaciones push.

#### Scenario: Contador
- **WHEN** Ana anota dos gastos y Jesús no ha abierto la actividad del parche desde entonces
- **THEN** Jesús ve 2 avisos sin ver en el encabezado del parche, y al abrir la actividad el contador vuelve a cero y esos dos gastos se ven como nuevos

## ADDED Requirements

### Requirement: Detalle del parche corto
El detalle de un parche SHALL mostrar arriba, en este orden: tu saldo, las acciones (anotar un gasto o un pago), los pagos por confirmar (junto con lo que puede pasar a un cruce), "Para saldar" y los saldos. Los gastos SHALL ir debajo, y al final cerrar el parche o a quién pedírselo. "Los del parche", el código del parche y la actividad MUST NOT estar en el detalle.

#### Scenario: Santa Marta
- **WHEN** Joan abre "Santa Marta"
- **THEN** ve su saldo, "Anotar un gasto" y "Anotar un pago", el pago de Carlos por confirmar, "Para saldar", los saldos y después los gastos, sin la lista de personas ni el código

### Requirement: Hoja de compartir el parche
El botón de compartir del encabezado del detalle SHALL abrir una hoja con el código del parche (compartir y copiar), "Compartir el ticket del parche" y "Los del parche", con el código `SOY-` de quien está sin la app y, mientras el parche esté abierto, el campo para agregar a alguien sin la app.

#### Scenario: Compartir desde el encabezado
- **WHEN** Joan toca el botón de compartir en "Santa Marta"
- **THEN** ve el código `PCH-SM4R7A`, "Compartir el ticket del parche" y a Joan, Jesús, Ana y Carlos (sin la app) con su código `SOY-K7QX2M`

#### Scenario: Ticket del parche desde la hoja
- **WHEN** Joan toca "Compartir el ticket del parche" en la hoja
- **THEN** la hoja se cierra y se abre el ticket del parche
