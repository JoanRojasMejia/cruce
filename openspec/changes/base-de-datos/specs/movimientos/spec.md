# Spec Delta

## ADDED Requirements

### Requirement: Quien paga pertenece a la cuenta
El pagador de un movimiento MUST ser uno de los dos miembros de la cuenta.

#### Scenario: Pagador ajeno
- **WHEN** se intenta registrar un movimiento cuyo pagador no es miembro de la cuenta
- **THEN** la operación falla con "Quien pagó no pertenece a esta cuenta"

### Requirement: Un movimiento no cambia de cuenta ni de autor
Al editar un movimiento, su cuenta, quién lo anotó y cuándo se anotó MUST NOT cambiar. Sacar un gasto de la vista del otro solo es posible con el borrado suave, que deja aviso.

#### Scenario: Mover un gasto a otra cuenta
- **WHEN** Joan intenta pasar un gasto de su cuenta con Jesús a otra cuenta
- **THEN** la operación falla y el gasto sigue visible para Jesús
