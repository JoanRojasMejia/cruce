# Spec Delta

## ADDED Requirements

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
