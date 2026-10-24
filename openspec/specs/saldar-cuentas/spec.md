# saldar-cuentas Specification

## Purpose
Permitir que quien debe le pague el total al otro y que el saldo quede en $0, dejando registro del pago.

## Requirements

### Requirement: Saldar es un movimiento más
Saldar SHALL registrar un movimiento de tipo pago, con reparto "todo es del otro", en el que quien debe le paga al otro el total del saldo. Después del pago el saldo MUST quedar en $0.

#### Scenario: Jesús salda lo que debe
- **WHEN** el saldo dice "Jesús te debe $20.000" y se confirma el pago
- **THEN** se registra que Jesús pagó $20.000 y se muestra "¡A paz y salvo!" con el saldo en $0

#### Scenario: Ya están a paz y salvo
- **WHEN** el saldo es $0
- **THEN** no hay pago que registrar

### Requirement: Medio de pago
Al saldar SHALL elegirse el medio de pago entre Efectivo, Nequi o Transferencia, y el mensaje de éxito MUST nombrarlo.

#### Scenario: Pago por Nequi
- **WHEN** se salda eligiendo Nequi
- **THEN** el mensaje dice "Jesús te pagó $20.000 por Nequi. El saldo quedó en $0."

### Requirement: Movimientos desde el último pago
El sistema SHALL poder identificar los movimientos registrados después del último pago para saldar.

#### Scenario: Movimientos posteriores a saldar
- **WHEN** hay un pago para saldar y luego dos gastos nuevos
- **THEN** solo esos dos gastos cuentan como movimientos desde el último pago
