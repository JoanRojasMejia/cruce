# Spec Delta

## Purpose

Permite que cada persona lleve varios cruces, uno con cada amigo: verlos todos con su saldo, abrir uno y que todo lo que se anota, se ve y se salda sea de ese cruce.

## ADDED Requirements

### Requirement: Inicio según la cantidad de cruces
Con un solo cruce, el inicio SHALL ser ese cruce, con su saldo y sus movimientos. Con dos o más cruces, el inicio SHALL mostrar "Tus cruces": una fila por cruce, con la otra persona y su saldo. Al tocar una fila, la app SHALL abrir el inicio de ese cruce, con un botón para volver a la lista.

#### Scenario: Un solo cruce
- **WHEN** Joan solo tiene un cruce, con Jesús
- **THEN** el inicio muestra su saldo con Jesús, como en el diseño, sin lista de cruces

#### Scenario: Dos cruces
- **WHEN** Joan tiene un cruce con Jesús y otro con Ana
- **THEN** el inicio muestra "Tus cruces" con una fila para Jesús y otra para Ana

#### Scenario: Abrir un cruce
- **WHEN** Joan toca la fila de Ana en "Tus cruces"
- **THEN** se abre el inicio de su cruce con Ana, y el botón de volver lo lleva otra vez a la lista

### Requirement: Saldo de cada cruce en la lista
Cada fila de "Tus cruces" SHALL mostrar el saldo neto de ese cruce con la frase de quién le debe a quién, el signo y el monto, con las mismas reglas del inicio. Un cruce sin movimientos o saldado SHALL decir que están a paz y salvo.

#### Scenario: Saldos distintos por cruce
- **WHEN** Jesús le debe $20.000 a Joan y Joan le debe $15.000 a Ana
- **THEN** la fila de Jesús dice "Jesús te debe $20.000" con +$20.000 y la de Ana dice "Le debes $15.000 a Ana" con −$15.000

#### Scenario: Cruce nuevo
- **WHEN** un cruce no tiene movimientos
- **THEN** su fila dice "Están a paz y salvo", con $0

### Requirement: Los movimientos son de un cruce
Cada movimiento SHALL pertenecer a un solo cruce. Anotar, editar, eliminar y saldar MUST afectar solo al cruce abierto. El historial, el detalle y el saldo del inicio MUST mostrar solo los movimientos de ese cruce.

#### Scenario: Anotar en un cruce
- **WHEN** Joan, con el cruce de Ana abierto, anota una cena de $40.000 a medias
- **THEN** el gasto aparece en el historial y el saldo de su cruce con Ana, y no en su cruce con Jesús

#### Scenario: Saldar un cruce
- **WHEN** Joan salda su cruce con Jesús
- **THEN** ese cruce queda en $0 y el saldo con Ana no cambia

### Requirement: Las pantallas del cruce nombran a su otra persona
Las pantallas del cruce abierto (inicio, anotar, historial, detalle, saldar, "A paz y salvo", Ajustes y sin conexión) SHALL nombrar y mostrar a la otra persona de ese cruce, no a la de otro.

#### Scenario: Saldar con Ana
- **WHEN** Joan abre su cruce con Ana y entra a saldar
- **THEN** la pantalla dice que le paga a Ana o que Ana le paga, nunca Jesús
