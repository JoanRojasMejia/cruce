# Spec Delta

## Purpose

Define qué teclado se usa para escribir cada monto en la app, dónde aparece el teclado de Cruce y cómo se pasa de un teclado a otro, también con VoiceOver.

## ADDED Requirements

### Requirement: Monto principal con el teclado de Cruce
El monto principal (la tarjeta amarilla de "Nuevo movimiento", "Editar movimiento", "Anotar un gasto", "Editar el gasto" y "Anotar un pago" del parche) SHALL escribirse con el teclado de Cruce: 1 a 9, `000`, `0` y borrar. Los montos secundarios (lo que puso cada pagador, el monto de un ítem y la propina) MUST seguir con el teclado del sistema. "Cambiar monto" en Saldar SHALL seguir en una hoja con el teclado de Cruce.

#### Scenario: Gasto del parche
- **WHEN** Joan abre "Anotar un gasto" en un parche
- **THEN** el monto se escribe con el teclado de Cruce y no aparece el teclado del sistema

#### Scenario: Monto de un pagador
- **WHEN** Joan elige dos pagadores y toca lo que puso Jesús
- **THEN** se abre el teclado numérico del sistema

### Requirement: Teclado acoplado abajo
El teclado de Cruce SHALL ir acoplado abajo de la pantalla, como un teclado, con un botón "Listo" que lo cierra. El botón principal de la pantalla MUST quedar a la vista encima del teclado y el contenido MUST poder desplazarse por encima de él, sin quedar nada escondido, también en un iPhone SE.

#### Scenario: Guardar con el teclado abierto
- **WHEN** Joan escribe $60.000 en "Nuevo movimiento"
- **THEN** "Guardar movimiento" se ve encima del teclado y se puede tocar sin cerrarlo

#### Scenario: Cerrar el teclado
- **WHEN** Joan toca "Listo" en el teclado de Cruce
- **THEN** el teclado se cierra y el monto escrito se conserva

### Requirement: Anotar un pago con la tarjeta amarilla
En "Anotar un pago" del parche el monto SHALL ir en la tarjeta amarilla arriba, como en el cruce. Tocar una sugerencia de "Para saldar" MUST seguir llenando quién pagó, a quién y el monto de la tarjeta.

#### Scenario: Llenar desde "Para saldar"
- **WHEN** Joan toca la sugerencia en que Carlos le paga $47.000 a Joan
- **THEN** la tarjeta amarilla muestra `$47.000` y quedan elegidos Carlos y Joan

### Requirement: Qué arranca activo
Al anotar algo nuevo, el monto SHALL arrancar activo, con el teclado de Cruce abierto. Al editar, nada MUST arrancar activo: no se ve ningún teclado hasta que se toca la tarjeta amarilla u otro campo.

#### Scenario: Nuevo movimiento
- **WHEN** Joan abre "Nuevo movimiento"
- **THEN** el teclado de Cruce está abierto

#### Scenario: Editar un gasto
- **WHEN** Joan abre "Editar el gasto" del almuerzo y luego toca la tarjeta amarilla
- **THEN** al abrir no hay teclado, y al tocar la tarjeta se abre el de Cruce

### Requirement: Cambio entre teclados
Tocar la tarjeta amarilla SHALL abrir el teclado de Cruce y cerrar el del sistema. Tocar otro campo (el concepto, un nombre o un monto secundario) SHALL abrir el del sistema y cerrar el de Cruce. Tocar el espacio vacío MUST cerrar los dos. Nunca MUST verse los dos teclados a la vez.

#### Scenario: Del monto al concepto
- **WHEN** con el teclado de Cruce abierto Joan toca "Concepto"
- **THEN** se cierra el teclado de Cruce y se abre el del sistema

#### Scenario: Espacio vacío
- **WHEN** con cualquiera de los dos teclados abierto Joan toca el espacio vacío de la pantalla
- **THEN** no queda ningún teclado abierto

### Requirement: Teclas y lectura del monto
El teclado SHALL ignorar los ceros a la izquierda, aceptar como máximo 12 dígitos (como la lectura de montos) y no hacer nada si una tecla los superaría. Con VoiceOver, cada tecla MUST tener su etiqueta ("Borrar", "Tres ceros" o el dígito), la tarjeta MUST decir su monto y abrirse con la acción por defecto, y al tocar una tecla se MUST anunciar el monto nuevo, por ejemplo "Monto: 60000 pesos".

#### Scenario: Seis y tres ceros
- **WHEN** se toca "6" y luego "000"
- **THEN** la tarjeta muestra `$6.000` y VoiceOver anuncia "Monto: 6000 pesos"

#### Scenario: Límite de dígitos
- **WHEN** ya hay 12 dígitos escritos y se toca "5"
- **THEN** el monto no cambia
