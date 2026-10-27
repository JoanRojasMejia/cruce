# Spec Delta

## ADDED Requirements

### Requirement: Anotar sin conexión
Sin red, anotar, editar, eliminar y saldar SHALL cambiar el cruce en el teléfono y quedar en una cola de pendientes guardada en el teléfono. La app SHALL mostrar que está sin conexión y cuántos movimientos faltan por enviar.

#### Scenario: Modo avión
- **WHEN** Joan, en modo avión, anota una cena de $60.000 a medias
- **THEN** la cena aparece en su inicio con "Jesús te debe $30.000", la app dice "Sin conexión" y hay 1 movimiento pendiente por sincronizar

### Requirement: Enviar lo pendiente al volver la red
Al volver la red, la app SHALL enviar sola la cola de pendientes, en el orden en que se hicieron. "Reintentar" SHALL enviarla también. Lo enviado MUST NOT duplicarse en la base, y lo pendiente MUST NOT desaparecer de la pantalla mientras no se haya enviado.

#### Scenario: Vuelve la red
- **WHEN** Joan anotó dos gastos en modo avión y vuelve la red
- **THEN** los dos gastos llegan a la base una sola vez, el contador de pendientes vuelve a 0 y Jesús los ve

#### Scenario: Recargar sin red
- **WHEN** Joan desliza para recargar mientras sigue sin red
- **THEN** los gastos pendientes siguen en su inicio

### Requirement: Abrir la app sin red
La app SHALL guardar en el teléfono los movimientos de cada cruce y la cola de pendientes. Al abrir la app sin red, SHALL mostrar lo último guardado; los pendientes MUST seguir en la cola para enviarse después.

#### Scenario: Cerrar y abrir sin red
- **WHEN** Joan anota un gasto sin red, cierra la app y la vuelve a abrir todavía sin red
- **THEN** ve sus movimientos y el gasto pendiente, y cuando vuelve la red el gasto se envía

### Requirement: Lo guardado en el teléfono es de quien entró
Cerrar sesión SHALL borrar del teléfono los movimientos y la cola guardados. La app MUST NOT mostrarle a una persona lo guardado de otra.

#### Scenario: Otra persona entra en el mismo iPhone
- **WHEN** Joan cierra sesión y Jesús entra en ese iPhone
- **THEN** Jesús no ve los movimientos que Joan tenía guardados en el teléfono
