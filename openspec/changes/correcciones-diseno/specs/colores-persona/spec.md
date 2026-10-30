## ADDED Requirements

### Requirement: Color fijo por persona
Cada persona SHALL tener un color fijo guardado en su perfil, de una paleta de 6: amarillo, violeta, verde, durazno, rosado y lima. Un perfil nuevo MUST recibir uno de la paleta al azar. Los perfiles que ya existían SHALL quedar con el color que tenían en su cruce más reciente (primero los abiertos; un cruce pendiente no cuenta), o amarillo si no tenían cruces. El color MUST NOT depender del papel de la persona en cada cruce (quien lo creó o quien se unió).

#### Scenario: Joan en dos cruces
- **WHEN** Joan creó su cruce con Jesús y se unió con código al cruce de Ana, y su color es verde
- **THEN** Joan se ve verde en "Tus cruces", en su cruce con Jesús, en su cruce con Ana y en lo que ven Jesús y Ana

#### Scenario: Un perfil nuevo
- **WHEN** alguien entra por primera vez y escribe su nombre
- **THEN** su perfil queda con un color de la paleta, elegido al azar

### Requirement: Cambiar el color en Tu perfil
En "Tu perfil" la app SHALL mostrar "Tu color" con las 6 muestras de la paleta y la elegida marcada. Al guardar, el color nuevo MUST verse en todos los cruces y parches de la persona. Cada quien MUST poder cambiar solo su propio color. Sin conexión, el color SHALL seguir siendo el anterior y la app SHALL avisar del problema.

#### Scenario: Jesús cambia su color
- **WHEN** Jesús elige rosado en "Tu perfil" y guarda
- **THEN** Joan lo ve rosado en su cruce y Jesús sale rosado en los parches donde está

#### Scenario: El color de otra persona
- **WHEN** Jesús intenta cambiar el color de Joan
- **THEN** la base no lo cambia

### Requirement: Color en los parches
En un parche, quien tiene la app SHALL verse con el color de su perfil. Cuando alguien se queda con un lugar con su código `SOY-`, el lugar SHALL tomar el color de su perfil. El ticket personal SHALL mostrar a la persona con el mismo color que en el parche.

#### Scenario: Ana se queda con el lugar de Carlos
- **WHEN** Ana, que es rosada, entra con el código `SOY-` de Carlos
- **THEN** ese lugar pasa a verse rosado

### Requirement: Color de quien está sin la app
Quien está sin la app MUST recibir, al entrar al parche, el primer color de la paleta que nadie del parche usa (si ya se usaron los 6, vuelve a empezar), y lo MUST conservar aunque los demás cambien el suyo. Su avatar SHALL llevar ese color con el borde punteado, además del texto "(sin la app)".

#### Scenario: Carlos sin la app
- **WHEN** Joan (verde) crea "Santa Marta", Jesús (amarillo) se une y Joan agrega a Carlos y a Diego sin la app
- **THEN** Carlos queda violeta y Diego durazno, y siguen así aunque Jesús cambie su color

### Requirement: El recibo sigue siendo por cruce
La regla del recibo rosa o verde ("Tike") MUST seguir siendo por cruce y no depender del color: quien creó el cruce SHALL ver el recibo rosa y quien se unió con código, el verde. Abrir otro cruce MUST cambiar solo el recibo de quien usa la app, no su color.

#### Scenario: Joan abre sus dos cruces
- **WHEN** Joan, que creó su cruce con Jesús y se unió al de Ana, abre uno y luego el otro
- **THEN** ve el recibo rosa con Jesús y el verde con Ana, y en los dos su avatar es del mismo color
