# ticket-parche Specification

## Purpose
Generar en el teléfono los tickets del parche y de cada persona como imagen para compartir.

## Requirements

### Requirement: Ticket personal
La app SHALL generar en el teléfono una imagen para compartir con lo que debe o le deben a una persona: la frase, sus transferencias, el detalle de sus gastos, la fecha y hora del corte y el sello "Pendiente" o "A paz y salvo". En un gasto por consumo, el detalle MUST incluir los nombres de los ítems que la persona consumió, cuando los tienen.

#### Scenario: Ticket de Carlos
- **WHEN** Jesús comparte el ticket personal de Carlos
- **THEN** se abre el menú de compartir de iOS con una imagen que dice cuánto debe Carlos, a quién, por qué gastos, la fecha del corte, "Pendiente" y su código `SOY-`

#### Scenario: Ya está a paz y salvo
- **WHEN** el saldo de Carlos es cero
- **THEN** el ticket dice que está a paz y salvo y lleva el sello "A paz y salvo"

#### Scenario: Lo que consumió
- **WHEN** en el almuerzo por consumo el ítem "Mojarra" es de Carlos
- **THEN** su ticket muestra "Mojarra" debajo de "Almuerzo en Taganga"

### Requirement: Código en el ticket de quien no tiene la app
Si la persona no tiene la app, su ticket personal MUST incluir su código `SOY-` con la frase "¿Ya tienes Cruce? Entra con el código … y tus cuentas te siguen" y el enlace `cruce://codigo/SOY-…` (con el esquema de la app que lo comparte: `cruce-test` en testing, `cruce-dev` en local). El texto que acompaña la imagen al compartir SHALL llevar ese mismo enlace, que abre "Tengo un código" con el campo lleno.

#### Scenario: Persona con la app
- **WHEN** se comparte el ticket personal de Ana, que tiene la app
- **THEN** el ticket no lleva código `SOY-`

#### Scenario: Ticket de Carlos con su enlace
- **WHEN** Jesús comparte el ticket personal de Carlos desde la app de prod
- **THEN** la imagen y el texto llevan `cruce://codigo/SOY-K7QX2M`, y el texto termina con "Ábrelo en Cruce: cruce://codigo/SOY-K7QX2M"

### Requirement: Ticket del parche
La app SHALL generar una imagen con el nombre del parche, el total gastado, las transferencias para saldar, la fecha y hora del corte y el sello del parche, sin los saldos individuales de cada persona.

#### Scenario: Compartir con el grupo
- **WHEN** alguien comparte el ticket del parche
- **THEN** la imagen muestra el total gastado y la lista de transferencias "X le paga $… a Y"
