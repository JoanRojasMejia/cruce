# Spec Delta

## MODIFIED Requirements

### Requirement: Etapa de entrada según la sesión
`RootView` SHALL decidir la etapa a partir de la sesión real:
- sin sesión, onboarding;
- con sesión y sin perfil, pedir el nombre;
- con perfil y sin un cruce completo (de dos personas), invitar;
- con al menos un cruce completo, inicio.

Un cruce pendiente, que solo tiene a quien invitó, MUST NOT llevar al inicio.

#### Scenario: Sin sesión
- **WHEN** la app arranca sin sesión
- **THEN** muestra el onboarding

#### Scenario: Con perfil y sin cuenta compartida
- **WHEN** la app arranca con sesión, con perfil y sin fila en `ledger_members`
- **THEN** muestra la pantalla de invitar

#### Scenario: Con un cruce pendiente
- **WHEN** la app arranca con sesión y la persona solo tiene un cruce donde nadie se ha unido
- **THEN** muestra la pantalla de invitar con el código de ese cruce

#### Scenario: Con cuenta compartida
- **WHEN** la app arranca con sesión y la persona tiene al menos un cruce de dos personas
- **THEN** muestra el inicio con el nombre real de la otra persona del cruce más reciente
