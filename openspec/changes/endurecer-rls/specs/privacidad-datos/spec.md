# Spec Delta

## ADDED Requirements

### Requirement: Sin sesión no hay acceso
Una petición sin sesión iniciada MUST NOT ver ni escribir ningún dato de cuentas, miembros, movimientos, saldos, perfiles ni invitaciones, aunque conozca los identificadores de esos registros.

#### Scenario: Consulta sin sesión
- **WHEN** alguien sin sesión iniciada consulta cuentas, miembros, movimientos, saldos, perfiles o invitaciones
- **THEN** no recibe ningún registro

#### Scenario: Escritura sin sesión
- **WHEN** alguien sin sesión iniciada intenta crear un movimiento en la cuenta de Joan y Jesús
- **THEN** la operación se rechaza y la cuenta queda igual

#### Scenario: Las personas con sesión no notan el cambio
- **WHEN** Joan, con su sesión iniciada, consulta su cuenta, anota un movimiento o ve el perfil de Jesús
- **THEN** obtiene exactamente lo mismo que antes de este cambio
