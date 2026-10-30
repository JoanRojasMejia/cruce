## MODIFIED Requirements

### Requirement: Unirse con un código
Canjear un código válido SHALL agregar a quien lo usa como segundo miembro, con recibo verde y avatar violeta, y devolver el nombre de quien invitó. El código MUST quedar marcado como usado. El sistema MUST rechazar códigos inexistentes, vencidos, ya usados o propios, cada uno con su propio error (`invalid`, `expired`, `used` u `own`).

#### Scenario: Jesús se une
- **WHEN** Jesús canjea el código vigente de Joan
- **THEN** queda como miembro de la cuenta de Joan con recibo verde y avatar violeta, y la respuesta trae el nombre "Joan"

#### Scenario: Código vencido, usado o propio
- **WHEN** alguien canjea un código vencido, ya usado o creado por sí mismo
- **THEN** la operación se rechaza con un mensaje en español para cada caso ("Ese código ya venció. Pídele uno nuevo a quien te lo mandó.", "Ese código ya se usó. Pídele uno nuevo a quien te lo mandó." o "Ese código es tuyo. Mándaselo a la otra persona para que lo use.") y no se agrega a nadie

#### Scenario: Código que no existe
- **WHEN** alguien canjea un código que no existe
- **THEN** la operación se rechaza con "Ese código no existe. Revisa que esté bien escrito." y no se agrega a nadie

### Requirement: Ver de quién es un código antes de unirse
Antes de unirse, la app SHALL mostrar el nombre de quien creó un código vigente. Para códigos inexistentes, vencidos, usados, propios o de alguien con quien ya se tiene cruce, SHALL mostrar el mismo mensaje que daría canjearlo. Ver un código MUST NOT agregar a nadie ni marcar el código como usado.

#### Scenario: Código válido
- **WHEN** Jesús escribe los 4 dígitos del código vigente de Joan
- **THEN** la app muestra "CÓDIGO VÁLIDO" con "Cuenta de Joan" y Jesús todavía no es miembro

#### Scenario: Código inválido
- **WHEN** Jesús escribe 4 dígitos que no son de ningún código
- **THEN** la app muestra "Ese código no existe" y no muestra ningún nombre
