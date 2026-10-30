## ADDED Requirements

### Requirement: Una sola pantalla de código
La app SHALL tener una sola pantalla para entrar con un código, "Tengo un código", que se abre desde invitar, "Tus cruces", Ajustes y los parches. SHALL detectar el tipo por el prefijo mientras se escribe (`CRZ-`, `PCH-` o `SOY-`), sin importar mayúsculas, espacios ni el guion; cuatro dígitos solos son un `CRZ-`. Los formatos MUST NOT cambiar. La lista de prefijos MUST NOT mostrarse hasta que lo escrito no sea un código.

#### Scenario: Un código de cruce sin cruces
- **WHEN** Jesús, que todavía no tiene cruces, toca "Tengo un código" en invitar y escribe "crz4821", el código vigente de Joan
- **THEN** la pantalla marca el código como de un cruce, muestra "CÓDIGO VÁLIDO" con "Cuenta de Joan" y, al tocar "Unirme a la cuenta de Joan", Jesús llega a "Conectados"

#### Scenario: Un código de parche
- **WHEN** Ana escribe "PCH-SM4R7A", el código de "Santa Marta"
- **THEN** la pantalla muestra "Santa Marta" antes de entrar y Ana todavía no es participante

#### Scenario: Algo que no es un código
- **WHEN** alguien escribe "HOLA-1234"
- **THEN** la pantalla dice "Eso no es un código de Cruce" y muestra los prefijos `CRZ-`, `PCH-` y `SOY-` con lo que hace cada uno

### Requirement: Errores de código separados
Un código que no sirve SHALL decir por qué, con su propio título y mensaje: no existe, venció (solo `CRZ-`), ya se usó (un `CRZ-` canjeado o un lugar `SOY-` que alguien ya tomó) o es tuyo (tu propio `CRZ-`, o un lugar `SOY-` que ya es tuyo). La base MUST devolverlos como errores distintos (`invalid`, `expired`, `used`, `own`) con la misma forma de respuesta, y MUST seguir contando cada uno como intento fallido.

#### Scenario: CRZ- vencido
- **WHEN** Ana escribe un código `CRZ-` que venció
- **THEN** la app muestra "Ese código venció" y "Ese código ya venció. Pídele uno nuevo a quien te lo mandó."

#### Scenario: SOY- ya usado
- **WHEN** Carlos ya se quedó con su lugar y Pedro escribe el mismo código `SOY-`
- **THEN** la app muestra "Ese código ya se usó", no "Ese código no existe"

#### Scenario: El lugar ya es tuyo
- **WHEN** Carlos vuelve a escribir su código `SOY-` después de quedarse con el lugar
- **THEN** la app muestra "Ese código es tuyo" con "Ese lugar ya es tuyo."

### Requirement: Ver a dónde lleva un código de parche
Antes de entrar, la app SHALL mostrar a qué parche lleva un código `PCH-` (y si ya se está en él) y de quién es el lugar de un código `SOY-` y en qué parche. Ver un código MUST NOT unir a nadie ni tomar el lugar. Los códigos `PCH-` y `SOY-` que no sirven MUST contar como intentos fallidos junto con los `CRZ-`: con 5 en la última hora, el sistema MUST rechazar cualquier código, incluso uno válido, con "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."

#### Scenario: El lugar de Carlos
- **WHEN** Ana escribe el código `SOY-` de Carlos en "Santa Marta"
- **THEN** la pantalla muestra "Eres Carlos en Santa Marta" y el botón "Quedarme con el lugar"

#### Scenario: Ya estaba en el parche
- **WHEN** Joan escribe el código `PCH-` de un parche donde ya está
- **THEN** la pantalla dice "Ya estás en este parche" y el botón "Ver el parche" abre el parche

#### Scenario: Adivinar códigos
- **WHEN** alguien escribe 5 códigos `PCH-` o `SOY-` que no existen en menos de una hora
- **THEN** el siguiente código, aunque exista, se rechaza con "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."

### Requirement: Enlace con el código
Abrir un enlace `cruce://codigo/<CÓDIGO>` SHALL abrir "Tengo un código" con el campo lleno. Sin sesión, el código MUST quedar guardado y la pantalla SHALL abrirse al entrar (en invitar o en el inicio). Cada ambiente MUST tener su propio esquema (`cruce-dev` en local, `cruce-test` en testing y `cruce` en prod): cada app SHALL abrir solo los enlaces de su esquema y los enlaces que crea (el ticket) SHALL usar el suyo.

#### Scenario: Enlace con la app abierta
- **WHEN** Joan está en el inicio y abre `cruce://codigo/pch-sm4r7a`
- **THEN** se abre "Tengo un código" con "PCH-SM4R7A" y lo que muestra ese código

#### Scenario: Enlace sin sesión
- **WHEN** alguien sin sesión abre `cruce://codigo/CRZ-4821` y después entra con su correo
- **THEN** al llegar a invitar se abre "Tengo un código" con "CRZ-4821"

#### Scenario: Varias apps instaladas
- **WHEN** Joan tiene Cruce Test y Cruce Dev en el mismo iPhone y abre `cruce-test://codigo/SOY-K7QX2M`
- **THEN** se abre Cruce Test, no Cruce Dev, con "SOY-K7QX2M" en "Tengo un código"
