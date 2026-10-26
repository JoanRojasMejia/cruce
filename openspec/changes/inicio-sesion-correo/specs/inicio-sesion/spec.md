# Spec Delta

## ADDED Requirements

### Requirement: Entrar con un código por correo
La app SHALL permitir entrar con un correo y un código de 6 dígitos enviado a ese correo. El mismo flujo MUST servir para crear la cuenta y para volver a entrar. La app MUST NOT pedir contraseña ni depender de un enlace que abra la app.

#### Scenario: Pedir el código
- **WHEN** la persona escribe un correo válido y continúa
- **THEN** la app pide el código a Supabase Auth y muestra la pantalla para escribirlo

#### Scenario: Correo inválido
- **WHEN** la persona escribe un texto que no es un correo
- **THEN** la app no pide el código y explica que el correo no es válido

#### Scenario: Código correcto
- **WHEN** la persona escribe el código de 6 dígitos que recibió
- **THEN** la app abre la sesión y pasa a la etapa que corresponde

#### Scenario: Código incorrecto o vencido
- **WHEN** la persona escribe un código equivocado o vencido
- **THEN** la sesión no se abre y la app muestra un mensaje en español con la opción de pedir otro código

### Requirement: Sesión persistente
La sesión SHALL sobrevivir a cerrar y volver a abrir la app, hasta que la persona cierre sesión.

#### Scenario: Volver a abrir la app
- **WHEN** la persona entró, cierra la app y la vuelve a abrir
- **THEN** la app arranca con la sesión abierta, sin pedir el correo otra vez

### Requirement: Crear el perfil
Después del primer código, si la persona no tiene perfil, la app SHALL pedir su nombre y crear su fila en `profiles` con `id` igual al de su usuario. El nombre MUST tener entre 1 y 40 caracteres.

#### Scenario: Primera vez
- **WHEN** una persona sin perfil escribe el código correcto
- **THEN** la app pide su nombre y, al guardarlo, crea el perfil y pasa a invitar

#### Scenario: Ya tiene perfil
- **WHEN** una persona con perfil vuelve a entrar
- **THEN** la app no pide el nombre otra vez

### Requirement: Etapa de entrada según la sesión
`RootView` SHALL decidir la etapa a partir de la sesión real: sin sesión, onboarding; con sesión y sin perfil, pedir el nombre; con perfil y sin cuenta compartida, invitar; con cuenta compartida, inicio.

#### Scenario: Sin sesión
- **WHEN** la app arranca sin sesión
- **THEN** muestra el onboarding

#### Scenario: Con perfil y sin cuenta compartida
- **WHEN** la app arranca con sesión, con perfil y sin fila en `ledger_members`
- **THEN** muestra la pantalla de invitar

#### Scenario: Con cuenta compartida
- **WHEN** la app arranca con sesión y la persona pertenece a una cuenta
- **THEN** muestra el inicio

### Requirement: Cerrar sesión
Cerrar sesión desde ajustes SHALL terminar la sesión en Supabase Auth, borrar la sesión guardada y volver al onboarding.

#### Scenario: Cerrar sesión
- **WHEN** la persona cierra sesión y vuelve a abrir la app
- **THEN** la app muestra el onboarding y pide el correo para entrar
