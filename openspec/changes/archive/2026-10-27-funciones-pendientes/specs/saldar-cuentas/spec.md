## MODIFIED Requirements

### Requirement: Saldar es un movimiento más
Saldar SHALL registrar un movimiento de tipo pago, con reparto "todo es del otro", en el que quien debe le paga al otro. Por defecto el pago es el total del saldo y, después del pago, el saldo MUST quedar en $0. Con "Cambiar monto" el pago SHALL poder ser menor (ver "Pago parcial").

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

#### Scenario: Pago parcial por Nequi
- **WHEN** Jesús debe $20.000 y se registra un pago de $5.000 por Nequi
- **THEN** el mensaje dice "Jesús te pagó $5.000 por Nequi. Todavía te debe $15.000."

## ADDED Requirements

### Requirement: Pago parcial
"Cambiar monto" en Saldar SHALL dejar escribir el monto del pago, en pesos enteros, entre $1 y el total que se debe; un monto fuera de ese rango MUST NOT poderse confirmar. La tarjeta del pago, el botón y el "después" SHALL mostrar el monto elegido y cómo queda el saldo. El pago parcial se registra igual que saldar, pero el saldo baja sin llegar a $0 y la pantalla de éxito MUST decir "Pago anotado".

#### Scenario: Joan paga una parte
- **WHEN** Joan le debe $50.000 a Jesús, toca "Cambiar monto", escribe $20.000 y confirma
- **THEN** se registra que Joan pagó $20.000, el saldo queda "Le debes $30.000 a Jesús" y la pantalla dice "Pago anotado"

#### Scenario: Monto mayor al saldo
- **WHEN** Joan le debe $50.000 a Jesús y escribe $60.000
- **THEN** no puede confirmar el pago

#### Scenario: Monto igual al total
- **WHEN** Joan escribe exactamente $50.000
- **THEN** el pago salda las cuentas y la pantalla dice "¡A paz y salvo!"
