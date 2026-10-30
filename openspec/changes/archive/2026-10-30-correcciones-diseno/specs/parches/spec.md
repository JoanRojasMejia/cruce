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

### Requirement: Anotar sin conexión
Los gastos y pagos SHALL poder anotarse sin conexión; MUST guardarse en el teléfono y enviarse al volver la conexión, sin duplicarse por reintentos. Mientras haya algo sin enviar, el parche SHALL mostrar un solo aviso ("Sin conexión" o "Enviando…", con "Reintentar"), sin repetir el error de conexión en otro aviso. Cada gasto o pago sin enviar MUST llevar el ícono de reloj y el texto "Sin enviar". Un pago "Por confirmar" SHALL tener su propio estilo (etiqueta "Por confirmar" y fondo gris), distinto del de lo que no se ha enviado.

#### Scenario: Sin señal
- **WHEN** Ana anota un gasto sin conexión y cierra la app
- **THEN** al abrirla con conexión el gasto se envía una sola vez y los demás lo ven

#### Scenario: Un aviso y las filas sin enviar
- **WHEN** Joan, sin señal, anota el gasto "Hielo" y que Carlos le pagó $20.000 a Jesús, y desliza para recargar
- **THEN** ve un solo aviso "Sin conexión" con "2 cambios guardados en el teléfono, sin enviar.", la fila de "Hielo" y la del pago llevan el reloj y "Sin enviar", y el pago además dice "Por confirmar"
- **AND** al volver la señal y enviarse, las marcas "Sin enviar" desaparecen

## ADDED Requirements

### Requirement: Deshacer al borrar un gasto
Después de borrar un gasto del parche, la app SHALL esconderlo de una vez y mostrar el aviso "Borraste “<concepto>”" con "Deshacer" durante 5 segundos. El borrado MUST enviarse solo cuando pasan los 5 segundos sin "Deshacer" (sin función nueva en la base); salir del parche no lo pierde. Se SHALL enviar antes si se borra otro gasto, si se cierra el parche o si la app se va a segundo plano. "Deshacer" MUST devolver el gasto sin enviar nada ni dejar aviso de borrado.

#### Scenario: Deshacer
- **WHEN** Joan borra "Taxi" y toca "Deshacer" antes de 5 segundos
- **THEN** "Taxi" vuelve a verse y los demás nunca lo vieron borrado

#### Scenario: Sin deshacer
- **WHEN** Joan borra "Taxi" y pasan 5 segundos
- **THEN** el aviso se va, el borrado se envía y los demás ven "Taxi" borrado

#### Scenario: La app se va a segundo plano
- **WHEN** Joan borra "Taxi" y sale de la app antes de 5 segundos
- **THEN** el borrado se envía de una vez


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

### Requirement: Llegada con un código PCH
Después de entrar a un parche con un código `PCH-` desde "Tengo un código", la app SHALL mostrar "Entraste a <parche>" con las personas del parche, tu saldo en el parche (con la frase y el signo) y un botón "Ver el parche" que abre su detalle.

#### Scenario: Ana entra a Santa Marta
- **WHEN** Ana escribe `PCH-SM4R7A` en "Tengo un código" y toca "Entrar"
- **THEN** ve "Entraste a Santa Marta", a Joan, Jesús y Carlos (sin la app), "Estás a paz y salvo" con $0 y "Ver el parche"

### Requirement: Llegada con un código SOY
Después de quedarse con un lugar con un código `SOY-`, la app SHALL mostrar "Ahora eres <nombre> en <parche>", con el avatar del lugar pasando de punteado (sin la app) a sólido, y un texto que diga que sus gastos y pagos en el parche lo siguen. Con "Reducir movimiento" activado, el avatar MUST aparecer sólido sin animación.

#### Scenario: Carlos se queda con su lugar
- **WHEN** Carlos instala la app y escribe `SOY-K7QX2M` en "Tengo un código"
- **THEN** ve "Ahora eres Carlos en Santa Marta", su avatar pasa de punteado a sólido, "Debes $172.000" con −$172.000 y "Ver el parche"
