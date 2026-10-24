# privacidad-datos Specification

## Purpose
Garantizar que la información de una cuenta compartida solo la vean y la modifiquen sus dos miembros.

## Requirements

### Requirement: Solo los miembros ven la cuenta
Una persona SHALL ver únicamente las cuentas, miembros, movimientos y saldos de las cuentas a las que pertenece. Una persona que no es miembro MUST NOT ver ningún dato de esa cuenta.

#### Scenario: Una tercera persona consulta
- **WHEN** una persona que no pertenece a la cuenta de Joan y Jesús consulta cuentas, miembros, movimientos o saldos
- **THEN** no recibe ningún registro de esa cuenta

#### Scenario: Cada miembro ve su cuenta
- **WHEN** Joan consulta sus movimientos
- **THEN** ve los movimientos de su cuenta con Jesús y de ninguna otra

### Requirement: Perfiles visibles solo para la pareja de cuenta
Una persona SHALL ver su propio perfil y el de quien comparte cuenta con ella, y MUST NOT ver otros perfiles.

#### Scenario: Perfil ajeno
- **WHEN** Joan consulta perfiles
- **THEN** ve el suyo y el de Jesús, pero no el de una tercera persona

### Requirement: Solo los miembros escriben en la cuenta
Solo un miembro SHALL poder crear o editar movimientos de su cuenta, y el movimiento MUST quedar registrado como anotado por quien lo crea.

#### Scenario: Escritura ajena
- **WHEN** una persona que no es miembro intenta crear o editar un movimiento de la cuenta
- **THEN** la operación se rechaza

#### Scenario: Anotar a nombre de otro
- **WHEN** Joan intenta crear un movimiento marcado como anotado por Jesús
- **THEN** la operación se rechaza

### Requirement: Invitaciones privadas
Una persona SHALL ver solo las invitaciones que ella creó.

#### Scenario: Invitación ajena
- **WHEN** Jesús consulta la tabla de invitaciones
- **THEN** no ve las invitaciones creadas por Joan
