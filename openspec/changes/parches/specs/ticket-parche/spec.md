# Spec Delta

## ADDED Requirements

### Requirement: Ticket personal
La app SHALL generar en el teléfono una imagen para compartir con lo que debe o le deben a una persona: la frase, sus transferencias, el detalle de sus gastos, la fecha y hora del corte y el sello "Pendiente" o "A paz y salvo".

#### Scenario: Ticket de Carlos
- **WHEN** Jesús comparte el ticket personal de Carlos
- **THEN** se abre el menú de compartir de iOS con una imagen que dice cuánto debe Carlos, a quién, por qué gastos, la fecha del corte, "Pendiente" y su código `SOY-`

#### Scenario: Ya está a paz y salvo
- **WHEN** el saldo de Carlos es cero
- **THEN** el ticket dice que está a paz y salvo y lleva el sello "A paz y salvo"

### Requirement: Código en el ticket de quien no tiene la app
Si la persona no tiene la app, su ticket personal MUST incluir su código `SOY-` con la frase "¿Ya tienes Cruce? Entra con el código … y tus cuentas te siguen".

#### Scenario: Persona con la app
- **WHEN** se comparte el ticket personal de Ana, que tiene la app
- **THEN** el ticket no lleva código `SOY-`

### Requirement: Ticket del parche
La app SHALL generar una imagen con el nombre del parche, el total gastado, las transferencias para saldar, la fecha y hora del corte y el sello del parche, sin los saldos individuales de cada persona.

#### Scenario: Compartir con el grupo
- **WHEN** alguien comparte el ticket del parche
- **THEN** la imagen muestra el total gastado y la lista de transferencias "X le paga $… a Y"
