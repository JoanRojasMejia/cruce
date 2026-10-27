# Spec Delta

## ADDED Requirements

### Requirement: Invitar teniendo ya un cruce
Quien ya tiene al menos un cruce SHALL poder abrir "Invitar a alguien" desde "Tus cruces" y desde Ajustes, y ver el código de su cruce pendiente. Cuando la otra persona se una, la app SHALL mostrar "Conectados" con esa persona y después abrir el cruce nuevo.

#### Scenario: Joan invita a Ana
- **WHEN** Joan, que ya tiene un cruce con Jesús, abre "Invitar a alguien" y Ana se une con ese código
- **THEN** la app de Joan muestra "Conectados" con Ana y después Joan tiene dos cruces, con Jesús y con Ana

#### Scenario: Salir sin que nadie se una
- **WHEN** Joan abre "Invitar a alguien" y vuelve atrás sin que nadie se una
- **THEN** sigue con los mismos cruces y, al volver a invitar, ve el mismo código

### Requirement: Unirse con un código teniendo ya un cruce
"Tengo un código" con un código `CRZ-` SHALL abrir la pantalla de unirse con el código ya escrito, también para quien ya tiene cruces, con la vista previa del nombre y las mismas reglas: un cruce por pareja y el límite de intentos.

#### Scenario: Jesús se une al cruce de Ana
- **WHEN** Jesús, que ya tiene un cruce con Joan, escribe el código de Ana en "Tengo un código" y se une
- **THEN** ve "Cuenta de Ana", después "Conectados" con Ana, y queda con dos cruces

#### Scenario: Código de alguien con quien ya hay cruce
- **WHEN** Jesús escribe un código de Joan, con quien ya tiene un cruce
- **THEN** la pantalla de unirse muestra "Ya tienes un cruce con Joan" y no se crea otro cruce
