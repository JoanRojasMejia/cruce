# pruebas-logica Specification

## Purpose
Define cómo se verifica la lógica pura de la app (saldo neto, formato de pesos y fechas): dónde corren sus pruebas, qué deben cubrir y de qué no pueden depender.

## Requirements

### Requirement: Pruebas de la lógica sin Xcode ni simulador
Las pruebas de la lógica pura SHALL correr con un solo comando de terminal usando solo las herramientas de línea de comandos de Swift. MUST NOT requerir Xcode, un SDK de iOS ni un simulador.

#### Scenario: Mac solo con las herramientas de línea de comandos
- **WHEN** alguien corre el comando de pruebas de la lógica en una Mac sin Xcode instalado
- **THEN** las pruebas compilan, corren y reportan su resultado sin abrir ni bootear un simulador

### Requirement: La app usa la misma lógica que se prueba
La app SHALL usar exactamente el código de lógica que verifican las pruebas. MUST NOT existir una segunda copia de esa lógica dentro de la app.

#### Scenario: Un cambio en la lógica llega a la app
- **WHEN** se cambia una regla de la lógica pura, por ejemplo el redondeo del reparto
- **THEN** las pruebas y la app ven el mismo cambio sin editar dos lugares

### Requirement: Cobertura mínima de la lógica
Las pruebas SHALL cubrir al menos los casos que ya existían: el ejemplo canónico del saldo, la simetría entre miembros, préstamos, reparto por porcentaje, redondeo, saldar cuentas, movimientos desde el último saldo, formato y lectura de pesos, y los textos de fecha. También SHALL cubrir que los movimientos eliminados no cuentan en el saldo, en el pago para saldar ni en los movimientos desde el último saldo. MUST NOT bajar de 16 casos.

#### Scenario: Corrida completa
- **WHEN** se corre el comando de pruebas de la lógica
- **THEN** pasan 16 casos o más, con las mismas aserciones que tenían antes de este cambio

#### Scenario: Movimientos eliminados
- **WHEN** se corren las pruebas del saldo con una lista que incluye movimientos eliminados
- **THEN** el saldo, el pago para saldar y los movimientos desde el último saldo son los mismos que sin esos movimientos

### Requirement: Resultados independientes de la máquina
Los resultados de las pruebas SHALL ser los mismos en cualquier máquina. MUST NOT depender del idioma, la región ni la zona horaria configurados en el sistema.

#### Scenario: Otra zona horaria
- **WHEN** se corren las pruebas con la zona horaria del sistema en Bogotá y luego en una zona muy distinta, como Tokio
- **THEN** pasan las mismas pruebas en las dos corridas

### Requirement: Pruebas de la lógica también en Linux
Las pruebas de la lógica pura SHALL correr y pasar en Linux con la herramienta oficial de Swift, con los mismos resultados que en la Mac. MUST NOT depender de bibliotecas que solo existen en las plataformas de Apple.

#### Scenario: Corrida en Linux
- **WHEN** se corren las pruebas de la lógica en Linux con la herramienta oficial de Swift
- **THEN** pasan las mismas pruebas que en la Mac, incluidos los textos de fecha en español de Colombia

### Requirement: Lógica libre de errores de concurrencia
La lógica pura SHALL compilar con la revisión estricta de concurrencia de Swift sin errores. Sus valores MUST poder compartirse entre tareas concurrentes sin riesgo de carreras de datos.

#### Scenario: Compilación estricta
- **WHEN** se compila el paquete de la lógica con la revisión estricta de concurrencia
- **THEN** compila sin errores y las pruebas pasan

### Requirement: Pruebas del estado de la app sin simulador
El comportamiento del estado de la app SHALL tener pruebas que corren con el mismo comando de terminal que la lógica, en la Mac y en Linux, sin Xcode ni simulador. Deben cubrir guardar, editar, eliminar, saldar, la falla de sincronización, reintentar, cerrar sesión y la navegación.

#### Scenario: Guardar sin conexión
- **WHEN** se guarda un gasto y el almacenamiento de la cuenta falla
- **THEN** el gasto queda en la lista, hay un cambio pendiente de sincronizar y la app queda sin conexión

#### Scenario: Eliminar marca el movimiento
- **WHEN** se elimina un movimiento en las pruebas del estado
- **THEN** el saldo cambia, el movimiento ya no está entre los visibles y el almacenamiento lo conserva marcado como eliminado

#### Scenario: Corrida en Linux
- **WHEN** se corren estas pruebas en Linux con la herramienta oficial de Swift
- **THEN** pasan las mismas pruebas que en la Mac
