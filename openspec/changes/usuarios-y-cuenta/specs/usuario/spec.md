# Spec Delta

## Purpose
Darle a cada persona un @usuario único para distinguirla de otras con el mismo nombre, sin cambiar que la app la identifica por su `id`.

## ADDED Requirements

### Requirement: Formato del @usuario
Cada perfil SHALL tener un @usuario de 3 a 20 caracteres: letras minúsculas sin tilde, números, punto (`.`) y guion bajo (`_`). Lo escrito MUST guardarse en minúsculas, sin espacios a los lados y sin la `@` inicial. Dos perfiles MUST NOT tener el mismo @usuario, sin importar mayúsculas. La app MUST seguir identificando a las personas por su `id`, nunca por el nombre ni por el @usuario.

#### Scenario: Mayúsculas y arroba
- **WHEN** Joan escribe "@Joan.R"
- **THEN** se guarda "joan.r"

#### Scenario: Formato inválido
- **WHEN** Joan escribe "jo" o "joan rojas"
- **THEN** la app dice "Tu @usuario debe tener de 3 a 20 caracteres: minúsculas, números, punto o guion bajo." y no lo guarda

#### Scenario: Ocupado sin importar mayúsculas
- **WHEN** Jesús ya es "jesus" y Ana escribe "JESUS"
- **THEN** la app dice "Ese @usuario ya está ocupado. Prueba con otro."

### Requirement: Elegir el @usuario al registrarse
Al crear la cuenta, después del nombre, la app SHALL mostrar el paso "Elige tu @usuario" con una sugerencia basada en ese nombre (en minúsculas, sin tildes, con un número al final si ya está ocupada). Mientras se escribe, SHALL decir si está disponible o por qué no sirve. "Seguir" MUST guardar el @usuario elegido y pasar a invitar. Si la app se cierra en ese paso, la persona MUST quedar con la sugerencia.

#### Scenario: Sugerencia del nombre
- **WHEN** Jesús crea su cuenta con el nombre "Jesús" y nadie más es "jesus"
- **THEN** el paso siguiente sugiere "jesus" y dice que está disponible

#### Scenario: Sugerencia ocupada
- **WHEN** Ana crea su cuenta con el nombre "Joan" y "joan" ya es de otra persona
- **THEN** la sugerencia es "joan2"

### Requirement: Cambiar el @usuario
Tu perfil SHALL mostrar el @usuario y dejar cambiarlo, con la misma revisión de formato y disponibilidad. Con uno inválido, ocupado o igual al actual, "Guardar" MUST estar desactivado. Sin conexión, la app MUST mostrar un error y conservar el anterior.

#### Scenario: Joan cambia su @usuario
- **WHEN** Joan cambia "joan" por "joan.r" y guarda
- **THEN** Tu perfil dice "@joan.r" y "joan" queda libre para otra persona

### Requirement: Dónde se ve el @usuario
El @usuario SHALL verse junto al nombre en la vista previa de un código `CRZ-` ("Cuenta de Joan · @joan"), en cada fila de "Tus cruces" y en la lista de los del parche para quien tiene la app. Quien está sin la app y una cuenta borrada MUST NOT mostrar un @usuario.

#### Scenario: Dos Juan
- **WHEN** Ana tiene un cruce con dos personas llamadas "Juan", "juan" y "juan.p"
- **THEN** "Tus cruces" muestra "@juan" y "@juan.p" debajo de cada nombre

### Requirement: Usuarios que ya existían
Al aplicar la migración, cada perfil que ya existía SHALL recibir un @usuario a partir de su nombre, con la misma regla de la sugerencia (un sufijo numérico si choca), en el orden en que se crearon los perfiles. Después cada uno MAY cambiarlo en Tu perfil.

#### Scenario: Dos perfiles con el mismo nombre
- **WHEN** la migración encuentra a "Juan" (el más viejo) y a otro "Juan"
- **THEN** quedan "juan" y "juan2"
