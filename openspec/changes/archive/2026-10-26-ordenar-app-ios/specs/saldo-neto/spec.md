# Spec Delta

## MODIFIED Requirements

### Requirement: El saldo se calcula, nunca se guarda
El saldo neto SHALL calcularse siempre sumando el efecto de los movimientos vigentes de la cuenta. El sistema MUST NOT almacenar el saldo como un valor propio. Un movimiento eliminado no es vigente: MUST NOT contar en el saldo ni en el monto del pago para saldar.

#### Scenario: El saldo refleja un movimiento nuevo
- **WHEN** se agrega, edita o elimina un movimiento
- **THEN** el saldo mostrado se recalcula a partir de la lista de movimientos resultante

#### Scenario: Movimiento eliminado en la lista
- **WHEN** la lista tiene el ejemplo canónico y además un gasto eliminado de $40.000 pagado por Joan a medias
- **THEN** el saldo sigue indicando que Joan le debe $20.000 a Jesús, y saldar registra un pago de $20.000
