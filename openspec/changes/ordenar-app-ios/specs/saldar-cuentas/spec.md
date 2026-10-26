# Spec Delta

## MODIFIED Requirements

### Requirement: Movimientos desde el último pago
El sistema SHALL poder identificar los movimientos registrados después del último pago para saldar. Los movimientos eliminados MUST NOT contar, y un pago para saldar eliminado MUST NOT tomarse como el último pago.

#### Scenario: Movimientos posteriores a saldar
- **WHEN** hay un pago para saldar y luego dos gastos nuevos
- **THEN** solo esos dos gastos cuentan como movimientos desde el último pago

#### Scenario: Gasto eliminado después de saldar
- **WHEN** hay un pago para saldar y luego dos gastos nuevos, y uno de ellos se elimina
- **THEN** solo el gasto que sigue vigente cuenta como movimiento desde el último pago

#### Scenario: Pago para saldar eliminado
- **WHEN** el único pago para saldar se elimina
- **THEN** todos los movimientos vigentes cuentan como movimientos desde el último pago
