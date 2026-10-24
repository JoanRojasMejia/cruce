# Spec Delta

## Purpose

Unir a exactamente dos personas en una cuenta compartida mediante un código de invitación de un solo uso.

## ADDED Requirements

### Requirement: Crear la cuenta con un código de invitación
Al crear la cuenta compartida, el sistema SHALL agregar a quien la crea como primer miembro, con recibo rosa y avatar amarillo, y devolver un código con el formato `CRZ-` seguido de cuatro dígitos. El código MUST vencer a las 24 horas.

#### Scenario: Joan crea la cuenta
- **WHEN** Joan, con sesión iniciada, crea la cuenta
- **THEN** recibe un código como `CRZ-4821` y queda como miembro con recibo rosa y avatar amarillo

#### Scenario: Sin sesión
- **WHEN** alguien sin sesión intenta crear una cuenta
- **THEN** la operación falla y no se crea nada

### Requirement: Unirse con un código
Canjear un código válido SHALL agregar a quien lo usa como segundo miembro, con recibo verde y avatar violeta. El código MUST quedar marcado como usado. El sistema MUST rechazar códigos inexistentes, vencidos, ya usados o propios.

#### Scenario: Jesús se une
- **WHEN** Jesús canjea el código vigente de Joan
- **THEN** queda como miembro de la cuenta de Joan con recibo verde y avatar violeta

#### Scenario: Código vencido, usado o propio
- **WHEN** alguien canjea un código vencido, ya usado o creado por sí mismo
- **THEN** la operación se rechaza con un mensaje en español ("El código no es válido o ya venció" o "No puedes usar tu propio código") y no se agrega a nadie

### Requirement: Límite de intentos para unirse
Una persona SHALL tener como máximo 5 intentos fallidos de canjear un código por hora. Al llegar al límite, el sistema MUST rechazar cualquier código, incluso uno válido, con el mensaje "Hiciste demasiados intentos. Espera una hora e intenta de nuevo." Los intentos fallidos MUST quedar registrados aunque la operación no se complete.

#### Scenario: Adivinar códigos
- **WHEN** alguien prueba códigos al azar y falla 5 veces en una hora
- **THEN** el sexto intento se rechaza aunque el código sea de una cuenta real, y no queda en ninguna cuenta

#### Scenario: Pasada la hora
- **WHEN** pasó más de una hora desde esos 5 intentos fallidos
- **THEN** la persona puede volver a canjear un código válido

### Requirement: Máximo dos personas por cuenta
Una cuenta compartida MUST tener como máximo dos miembros.

#### Scenario: Tercera persona
- **WHEN** se intenta agregar una tercera persona a una cuenta que ya tiene dos
- **THEN** la operación falla con "Esta cuenta ya tiene dos personas"

### Requirement: Los códigos usados se conservan
Generar un código nuevo MUST NOT borrar ni reemplazar invitaciones ya canjeadas, para conservar quién se unió y cuándo.

#### Scenario: Código repetido
- **WHEN** el código generado coincide con el de una invitación ya canjeada
- **THEN** se genera otro código y la invitación anterior se conserva
