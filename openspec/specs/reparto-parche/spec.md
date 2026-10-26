# reparto-parche Specification

## Purpose
Repartir cada gasto de un parche en pesos enteros: partes iguales, por consumo, por partes o por porcentaje, con propina proporcional y varios pagadores.

## Requirements

### Requirement: Reparto en partes iguales
Un gasto SHALL poder repartirse en partes iguales entre todos los participantes o entre los que se elijan (al menos uno).

#### Scenario: Entre todos
- **WHEN** un gasto de $100.000 se reparte entre 4 personas
- **THEN** a cada una le tocan $25.000

#### Scenario: Entre algunos
- **WHEN** un taxi de $30.000 se reparte entre 3 de las 5 personas
- **THEN** a esas 3 les tocan $10.000 y a las otras 2 nada

### Requirement: Reparto por consumo
Un gasto SHALL poder repartirse por ítems: cada ítem tiene un monto y una o varias personas que lo consumieron, y se reparte en partes iguales entre ellas. Lo que le toca a cada persona es la suma de sus partes de los ítems.

#### Scenario: Cada uno su plato
- **WHEN** un almuerzo tiene ítems de $100.000 (Jesús), $50.000 (Ana), $20.000 (Carlos) y $30.000 (Joan)
- **THEN** les tocan $100.000, $50.000, $20.000 y $30.000

#### Scenario: Cuenta mixta
- **WHEN** una cuenta tiene una entrada de $40.000 para los 4 y platos de $30.000 (Jesús) y $20.000 (Ana)
- **THEN** a Jesús le tocan $40.000, a Ana $30.000, a Carlos $10.000 y a Joan $10.000

### Requirement: Reparto por partes y por porcentaje
Un gasto SHALL poder repartirse por partes (enteros ≥ 0, al menos uno > 0) o por porcentajes (enteros que suman 100).

#### Scenario: Una pareja cuenta doble
- **WHEN** un hospedaje de $300.000 se reparte por partes 2, 1 y 1
- **THEN** les tocan $150.000, $75.000 y $75.000

#### Scenario: Porcentajes
- **WHEN** un gasto de $200.000 se reparte 50 %, 30 % y 20 %
- **THEN** les tocan $100.000, $60.000 y $40.000

### Requirement: Propina proporcional
Un gasto SHALL poder llevar una propina de 0 a 100 %; el total es el monto base más la propina (en pesos enteros, redondeando hacia abajo) y la propina MUST repartirse en proporción a lo que le toca a cada uno.

#### Scenario: Propina del 10 %
- **WHEN** el almuerzo por consumo de $100.000, $50.000, $20.000 y $30.000 lleva 10 % de propina
- **THEN** el total es $220.000 y les tocan $110.000, $55.000, $22.000 y $33.000

### Requirement: Varios pagadores
Un gasto SHALL poder tener uno o varios pagadores con montos que sumen exactamente el total.

#### Scenario: Dos tarjetas
- **WHEN** Ana paga $120.000 y Jesús $100.000 de una cuenta de $220.000
- **THEN** el gasto se guarda con los dos pagadores y los saldos los tienen en cuenta

#### Scenario: No suman el total
- **WHEN** los pagadores suman $200.000 en una cuenta de $220.000
- **THEN** la app no deja guardar y explica cuánto falta

### Requirement: Redondeo en pesos enteros
Todo reparto MUST dar pesos enteros que sumen exactamente el total. Los pesos que sobran SHALL ir de a uno a quienes tienen el residuo más grande, y en empate a quien va primero en el orden del parche.

#### Scenario: $100.000 entre 3
- **WHEN** un gasto de $100.000 se reparte en partes iguales entre 3 personas
- **THEN** les tocan $33.334, $33.333 y $33.333, en el orden del parche
