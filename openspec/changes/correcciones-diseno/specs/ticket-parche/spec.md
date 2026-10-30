## MODIFIED Requirements

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
