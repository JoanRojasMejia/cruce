# Spec Delta

## MODIFIED Requirements

### Requirement: Crear la cuenta con un código de invitación
Al crear la cuenta compartida, el sistema SHALL agregar a quien la crea como primer miembro, con recibo rosa y avatar amarillo, y devolver un código con el formato `CRZ-` seguido de cuatro dígitos. El código MUST vencer a las 24 horas. Una persona MUST tener como máximo una cuenta pendiente (sin segunda persona): si ya la tiene, el sistema SHALL devolver su código vigente o, si venció, uno nuevo para esa misma cuenta.

#### Scenario: Joan crea la cuenta
- **WHEN** Joan, con sesión iniciada, crea la cuenta
- **THEN** recibe un código como `CRZ-4821` y queda como miembro con recibo rosa y avatar amarillo

#### Scenario: Sin sesión
- **WHEN** alguien sin sesión intenta crear una cuenta
- **THEN** la operación falla y no se crea nada

#### Scenario: Volver a la pantalla de invitar
- **WHEN** Joan pide el código dos veces mientras nadie se ha unido
- **THEN** recibe el mismo código y sigue teniendo una sola cuenta pendiente

#### Scenario: Código pendiente vencido
- **WHEN** Joan pide el código y el de su cuenta pendiente ya venció
- **THEN** recibe un código nuevo para esa misma cuenta, sin crear otra

### Requirement: Unirse con un código
Canjear un código válido SHALL agregar a quien lo usa como segundo miembro, con recibo verde y avatar violeta, y devolver el nombre de quien invitó. El código MUST quedar marcado como usado. El sistema MUST rechazar códigos inexistentes, vencidos, ya usados o propios.

#### Scenario: Jesús se une
- **WHEN** Jesús canjea el código vigente de Joan
- **THEN** queda como miembro de la cuenta de Joan con recibo verde y avatar violeta, y la respuesta trae el nombre "Joan"

#### Scenario: Código vencido, usado o propio
- **WHEN** alguien canjea un código vencido, ya usado o creado por sí mismo
- **THEN** la operación se rechaza con un mensaje en español ("El código no es válido o ya venció" o "No puedes usar tu propio código") y no se agrega a nadie

### Requirement: Límite de intentos para unirse
Una persona SHALL tener como máximo 5 intentos fallidos por hora entre canjear un código y ver de quién es. Al llegar al límite, el sistema MUST rechazar cualquier código, incluso uno válido, con el mensaje "Hiciste demasiados intentos. Espera una hora e intenta de nuevo." Los intentos fallidos MUST quedar registrados aunque la operación no se complete.

#### Scenario: Adivinar códigos
- **WHEN** alguien prueba códigos al azar y falla 5 veces en una hora
- **THEN** el sexto intento se rechaza aunque el código sea de una cuenta real, y no queda en ninguna cuenta

#### Scenario: Pasada la hora
- **WHEN** pasó más de una hora desde esos 5 intentos fallidos
- **THEN** la persona puede volver a canjear un código válido

#### Scenario: Adivinar con la vista previa
- **WHEN** alguien consulta 5 códigos inexistentes en una hora para ver de quién son
- **THEN** la siguiente consulta o canje se rechaza con el mensaje del límite y no revela ningún nombre

## ADDED Requirements

### Requirement: Un cruce por pareja
Dos personas MUST tener como máximo una cuenta compartida entre ellas. Una persona SHALL poder tener cuentas con personas distintas. Canjear el código de alguien con quien ya se comparte una cuenta MUST rechazarse con el mensaje "Ya tienes un cruce con Joan", sin agregar a nadie y sin contar como intento fallido.

#### Scenario: Segundo cruce con la misma persona
- **WHEN** Jesús, que ya tiene un cruce con Joan, canjea un código nuevo de Joan
- **THEN** la operación se rechaza con "Ya tienes un cruce con Joan" y Jesús sigue con un solo cruce con Joan

#### Scenario: Cruces con personas distintas
- **WHEN** Jesús, que ya tiene un cruce con Joan, canjea el código de Ana
- **THEN** Jesús queda con dos cruces: uno con Joan y otro con Ana

#### Scenario: Agregar el miembro directo a la base
- **WHEN** se intenta, por fuera de las funciones, dejar a las mismas dos personas en una segunda cuenta
- **THEN** la base lo rechaza con "Ya tienen un cruce entre los dos"

### Requirement: Ver de quién es un código antes de unirse
Antes de unirse, la app SHALL mostrar el nombre de quien creó un código vigente. Para códigos inexistentes, vencidos, usados, propios o de alguien con quien ya se tiene cruce, SHALL mostrar el mismo mensaje que daría canjearlo. Ver un código MUST NOT agregar a nadie ni marcar el código como usado.

#### Scenario: Código válido
- **WHEN** Jesús escribe los 4 dígitos del código vigente de Joan
- **THEN** la app muestra "CÓDIGO VÁLIDO" con "Cuenta de Joan" y Jesús todavía no es miembro

#### Scenario: Código inválido
- **WHEN** Jesús escribe 4 dígitos que no son de ningún código vigente
- **THEN** la app muestra "El código no es válido o ya venció" y no muestra ningún nombre

### Requirement: Quien invita se entera de la unión
Mientras la pantalla de invitar está abierta, la app de quien invitó SHALL notar en pocos segundos que la otra persona se unió y pasar sola a "Conectados", con el nombre real de esa persona.

#### Scenario: Jesús se une mientras Joan espera
- **WHEN** Joan tiene abierta la pantalla de invitar y Jesús canjea su código
- **THEN** en menos de 10 segundos la app de Joan muestra "Conectados" con Jesús

### Requirement: Colores y recibo de la base
La app SHALL mostrar, para cada persona del cruce, el color de avatar y la versión del recibo que guarda la base para ese cruce, no valores fijos.

#### Scenario: Quien se une ve el recibo verde
- **WHEN** Jesús se une al cruce de Joan y llega al inicio
- **THEN** Jesús ve su avatar violeta, el de Joan amarillo y las ilustraciones con el recibo verde
