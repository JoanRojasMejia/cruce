# saldo-neto Specification

## Purpose
Calcular un único saldo neto entre las dos personas de una cuenta compartida, compensando cada gasto contra lo que el otro debe.

## Requirements

### Requirement: El saldo se calcula, nunca se guarda
El saldo neto SHALL calcularse siempre sumando el efecto de los movimientos vigentes de la cuenta. El sistema MUST NOT almacenar el saldo como un valor propio.

#### Scenario: El saldo refleja un movimiento nuevo
- **WHEN** se agrega, edita o elimina un movimiento
- **THEN** el saldo mostrado se recalcula a partir de la lista de movimientos resultante

### Requirement: Efecto de un movimiento según quién pagó
Cada movimiento SHALL sumar lo que el otro le debe a quien pagó: a favor de quien pagó y en contra del otro, por el mismo monto. El saldo de una persona MUST ser el opuesto exacto del saldo de la otra.

#### Scenario: Ejemplo canónico
- **WHEN** Joan paga una cena de $60.000 a medias y Jesús paga un mercado de $100.000 a medias
- **THEN** el saldo indica que Joan le debe $20.000 a Jesús (−20.000 para Joan y +20.000 para Jesús)

#### Scenario: Simetría entre los dos miembros
- **WHEN** se calcula el saldo de la misma lista de movimientos para cada miembro
- **THEN** la suma de los dos saldos es 0

### Requirement: Reparto del movimiento
Cada movimiento SHALL tener uno de tres repartos, que definen qué porcentaje del monto le toca al otro:
- `50/50` (por defecto): 50 %.
- Porcentaje: el porcentaje elegido para el otro, limitado entre 0 y 100.
- Todo es del otro (préstamos): 100 %.

#### Scenario: Préstamo
- **WHEN** alguien registra un préstamo de $40.000 con reparto "todo es del otro"
- **THEN** el otro le debe los $40.000 completos

#### Scenario: Reparto por porcentaje
- **WHEN** alguien paga $100.000 y al otro le toca el 30 %
- **THEN** el otro le debe $30.000

### Requirement: Redondeo al peso más cercano
La parte que le toca al otro SHALL redondearse al peso entero más cercano, con .5 hacia arriba, usando `(monto × porcentaje + 50) / 100` en división entera. La app y la base de datos MUST usar la misma fórmula.

#### Scenario: Monto impar a medias
- **WHEN** alguien paga $1.001 a medias
- **THEN** el otro le debe $501
