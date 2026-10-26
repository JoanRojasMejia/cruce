# Spec Delta

## ADDED Requirements

### Requirement: Crear un parche
Una persona con sesión SHALL poder crear un parche con un nombre de 1 a 60 caracteres. Quien lo crea MUST quedar como participante, y el parche MUST nacer abierto y con un código `PCH-` de 6 caracteres.

#### Scenario: Crear
- **WHEN** Jesús crea el parche "Santa Marta"
- **THEN** el parche queda abierto, Jesús es su único participante y la app muestra el código `PCH-` para compartir

### Requirement: Unirse con código
Una persona con sesión SHALL poder unirse a un parche abierto o cerrado escribiendo su código `PCH-`. Si ya es participante, MUST NOT agregarse dos veces.

#### Scenario: Unirse
- **WHEN** Ana escribe el código del parche "Santa Marta"
- **THEN** Ana queda como participante y ve los gastos del parche

#### Scenario: Código inválido
- **WHEN** alguien escribe un código que no existe
- **THEN** la app muestra "Ese código no existe" y no cambia nada

### Requirement: Personas sin la app
Cualquier participante con la app SHALL poder agregar a una persona sin la app con un nombre de 1 a 40 caracteres. Esa persona MUST recibir un código personal `SOY-` de 6 caracteres y MUST mostrarse como "<nombre> (sin la app)".

#### Scenario: Agregar a Carlos
- **WHEN** Jesús agrega a "Carlos" al parche
- **THEN** Carlos aparece como "Carlos (sin la app)" y tiene un código `SOY-`

### Requirement: Quedarse con el lugar
Una persona con sesión SHALL poder escribir un código `SOY-` para quedarse con ese lugar: el participante pasa a ser suyo con todo su historial, el código deja de servir y los demás ven el aviso "<nombre> ahora tiene la app". MUST NOT servir si esa persona ya es participante de ese parche.

#### Scenario: Carlos instala la app
- **WHEN** Carlos inicia sesión y escribe su código `SOY-`
- **THEN** entra al parche como Carlos, con sus gastos y lo que debe, sin crear una persona nueva

#### Scenario: Ya estaba en el parche
- **WHEN** Ana, que ya es participante, escribe el código `SOY-` de Carlos
- **THEN** la app muestra que ya está en el parche y Carlos sigue sin la app

### Requirement: Cualquiera con la app anota
Todo participante con la app SHALL poder anotar, editar y borrar gastos mientras el parche esté abierto, y anotar pagos mientras esté abierto o cerrado. Cada gasto y pago MUST mostrar quién lo anotó. Borrar MUST ser un borrado suave.

#### Scenario: Ana edita un gasto de Jesús
- **WHEN** Ana edita el monto de un gasto que anotó Jesús
- **THEN** el gasto cambia, los saldos se recalculan y Jesús ve el aviso "Ana editó un gasto que anotaste"

### Requirement: Estados del parche
Un parche SHALL estar abierto o cerrado. Cualquier participante con la app SHALL poder cerrarlo después de confirmar. Un parche cerrado MUST NOT aceptar gastos nuevos ni ediciones de gastos y MUST NOT reabrirse. Un parche cerrado en el que todos los saldos son cero SHALL mostrarse "A paz y salvo".

#### Scenario: Cerrar
- **WHEN** Jesús cierra el parche y confirma
- **THEN** ya no se pueden anotar gastos y se siguen pudiendo anotar pagos

#### Scenario: Queda a paz y salvo
- **WHEN** en un parche cerrado se confirma el último pago pendiente y todos los saldos quedan en cero
- **THEN** el parche se muestra "A paz y salvo" en la lista de parches

### Requirement: Anotar sin conexión
Los gastos y pagos SHALL poder anotarse sin conexión; MUST guardarse en el teléfono y enviarse al volver la conexión, sin duplicarse por reintentos.

#### Scenario: Sin señal
- **WHEN** Ana anota un gasto sin conexión y cierra la app
- **THEN** al abrirla con conexión el gasto se envía una sola vez y los demás lo ven

### Requirement: Aviso de posible duplicado
Antes de guardar un gasto, si hay un gasto vigente con el mismo monto y el mismo pagador anotado en las últimas 3 horas, la app SHALL avisar "Parece que <nombre> ya anotó este gasto" y MUST dejar guardarlo igual.

#### Scenario: Ana y Jesús anotan el mismo almuerzo
- **WHEN** Jesús anota $220.000 pagados por Ana una hora después de que Ana anotó $220.000 pagados por ella
- **THEN** la app avisa del posible duplicado antes de guardar

### Requirement: Avisos dentro de la app
El parche SHALL mostrar su actividad (gastos anotados, editados o borrados; pagos anotados o confirmados; personas agregadas, que se unieron o que se quedaron con su lugar; parche cerrado) y un contador de lo que la persona no ha visto. No hay notificaciones push.

#### Scenario: Contador
- **WHEN** Ana anota dos gastos y Jesús no ha abierto el parche desde entonces
- **THEN** Jesús ve 2 avisos sin ver en el parche, y al abrirlo el contador vuelve a cero
