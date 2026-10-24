# Spec Delta

## ADDED Requirements

### Requirement: Quien paga pertenece a la cuenta
El pagador de un movimiento MUST ser uno de los dos miembros de la cuenta.

#### Scenario: Pagador ajeno
- **WHEN** se intenta registrar un movimiento cuyo pagador no es miembro de la cuenta
- **THEN** la operación falla con "Quien pagó no pertenece a esta cuenta"
