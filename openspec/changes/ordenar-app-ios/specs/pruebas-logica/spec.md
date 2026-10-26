# Spec Delta

## MODIFIED Requirements

### Requirement: Cobertura mínima de la lógica
Las pruebas SHALL cubrir al menos los casos que ya existían: el ejemplo canónico del saldo, la simetría entre miembros, préstamos, reparto por porcentaje, redondeo, saldar cuentas, movimientos desde el último saldo, formato y lectura de pesos, y los textos de fecha. También SHALL cubrir que los movimientos eliminados no cuentan en el saldo, en el pago para saldar ni en los movimientos desde el último saldo. MUST NOT bajar de 16 casos.

#### Scenario: Corrida completa
- **WHEN** se corre el comando de pruebas de la lógica
- **THEN** pasan 16 casos o más, con las mismas aserciones que tenían antes de este cambio

#### Scenario: Movimientos eliminados
- **WHEN** se corren las pruebas del saldo con una lista que incluye movimientos eliminados
- **THEN** el saldo, el pago para saldar y los movimientos desde el último saldo son los mismos que sin esos movimientos

## ADDED Requirements

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
