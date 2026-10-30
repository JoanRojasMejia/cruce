## ADDED Requirements

### Requirement: Ajustes de la cuenta
**Ajustes** SHALL tener solo lo de la cuenta: el perfil, las notificaciones, los recordatorios, "Invitar a alguien", "Cerrar sesión" y la versión. Sus textos MUST NOT nombrar a una sola persona (por ejemplo, "Cuando alguien anote un gasto"). El engrane de "Tus cruces" SHALL abrir Ajustes.

#### Scenario: Engrane en Tus cruces
- **WHEN** Joan tiene cruces con Jesús y con Ana y toca el engrane de "Tus cruces"
- **THEN** ve Ajustes con su perfil, "Cuando alguien anote un gasto", "Recordarme saldar", "Invitar a alguien", "Cerrar sesión" y la versión, sin nada del cruce con Jesús ni del de Ana

### Requirement: Ajustes del cruce
**Ajustes del cruce** SHALL tener con quién es el cruce y desde cuándo, la moneda, el reparto por defecto, "Exportar historial (CSV)" y "Desvincular a <nombre>". El engrane de un cruce SHALL abrir Ajustes del cruce.

#### Scenario: Engrane dentro de un cruce
- **WHEN** Joan abre su cruce con Ana desde "Tus cruces" y toca el engrane
- **THEN** ve Ajustes del cruce con "Con Ana", la moneda, el reparto por defecto, exportar y "Desvincular a Ana", sin la fila "Tu cuenta"

### Requirement: La cuenta desde el único cruce
Cuando el cruce es el inicio (un solo cruce abierto), Ajustes del cruce SHALL terminar con una fila "Tu cuenta" que abre Ajustes.

#### Scenario: Un solo cruce
- **WHEN** Joan solo tiene su cruce con Jesús, que es su inicio, y toca el engrane
- **THEN** ve Ajustes del cruce, que termina con "Tu cuenta"; al tocarla se abre Ajustes y al volver regresa a Ajustes del cruce

### Requirement: Tus parches solo en el inicio
La sección "Tus parches" SHALL aparecer en "Tus cruces" y en el inicio cuando ese inicio es el único cruce abierto. Un cruce abierto desde "Tus cruces" MUST NOT repetir "Tus parches".

#### Scenario: Un solo cruce
- **WHEN** Joan solo tiene su cruce con Jesús, que es su inicio
- **THEN** el inicio muestra el saldo con Jesús y, debajo, "Tus parches"

#### Scenario: Cruce abierto desde la lista
- **WHEN** Joan tiene cruces con Jesús y con Ana y abre el de Ana desde "Tus cruces"
- **THEN** ve el saldo y los movimientos con Ana, sin la sección "Tus parches"
