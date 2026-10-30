## MODIFIED Requirements

### Requirement: Entrar con un código por correo
La app SHALL permitir entrar con un correo y un código de 6 dígitos enviado a ese correo. El mismo flujo MUST servir para crear la cuenta y para volver a entrar. La app MUST NOT pedir contraseña ni depender de un enlace que abra la app. El campo del código SHALL poder llenarse solo desde Mail (`oneTimeCode`). "Pedir otro código" MUST quedar desactivado durante 30 segundos después de cada envío, con la cuenta regresiva en el botón ("Pedir otro código en 0:27").

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

#### Scenario: Pedir otro código muy pronto
- **WHEN** la persona acaba de recibir el código y mira "Pedir otro código"
- **THEN** el botón dice "Pedir otro código en 0:30", baja cada segundo y solo se puede tocar al llegar a cero; entonces envía otro código y la cuenta vuelve a empezar
