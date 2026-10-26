# Spec Delta

## Purpose

Define cómo se verifica la lógica pura de la app (saldo neto, formato de pesos y fechas): dónde corren sus pruebas, qué deben cubrir y de qué no pueden depender.

## ADDED Requirements

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
Las pruebas SHALL cubrir al menos los casos que ya existían: el ejemplo canónico del saldo, la simetría entre miembros, préstamos, reparto por porcentaje, redondeo, saldar cuentas, movimientos desde el último saldo, formato y lectura de pesos, y los textos de fecha. MUST NOT bajar de 16 casos.

#### Scenario: Corrida completa
- **WHEN** se corre el comando de pruebas de la lógica
- **THEN** pasan 16 casos o más, con las mismas aserciones que tenían antes de este cambio

### Requirement: Resultados independientes de la máquina
Los resultados de las pruebas SHALL ser los mismos en cualquier máquina. MUST NOT depender del idioma, la región ni la zona horaria configurados en el sistema.

#### Scenario: Otra zona horaria
- **WHEN** se corren las pruebas con la zona horaria del sistema en Bogotá y luego en una zona muy distinta, como Tokio
- **THEN** pasan las mismas pruebas en las dos corridas
