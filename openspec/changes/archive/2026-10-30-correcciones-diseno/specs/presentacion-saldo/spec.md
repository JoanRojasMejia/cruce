## ADDED Requirements

### Requirement: Ilustraciones neutrales en parches y tickets
Los parches y los tickets SHALL usar ilustraciones neutrales, sin la regla del recibo rosa o verde, que MUST quedar solo para los cruces entre dos personas. La tarjeta del saldo del parche SHALL mostrar il-19a cuando a quien mira le deben, il-19b cuando debe e il-18 cuando todos quedan en $0. La esquina de un ticket pendiente, individual o de grupo, SHALL mostrar il-15 y la de un ticket a paz y salvo, il-07.

#### Scenario: Jesús mira su saldo en el parche
- **WHEN** Jesús, que se unió con código a su cruce con Joan, tiene +$125.000 en "Santa Marta"
- **THEN** la tarjeta de su saldo en el parche muestra la ilustración del grupo que le debe, la misma que vería Joan, sin recibo verde

#### Scenario: Ticket pendiente de Carlos
- **WHEN** Joan abre el ticket de Carlos, que debe en el parche
- **THEN** la esquina del ticket muestra la ilustración del ticket pendiente

### Requirement: Ilustración que todavía no está
Cada ilustración nueva (de il-09 a il-21) SHALL tener su espacio con nombre fijo en el catálogo de la app. Mientras ese espacio no tenga imagen, la pantalla MUST mostrar la ilustración que usaba antes o, si no usaba ninguna, no mostrar nada, sin espacio vacío ni error.

#### Scenario: Nuevo parche sin il-10
- **WHEN** el espacio `il-10-nuevo-parche` todavía no tiene imagen y Joan abre "Nuevo parche"
- **THEN** ve la ilustración de bienvenida, como antes

#### Scenario: Código del correo sin il-09
- **WHEN** el espacio `il-09-revisa-correo` todavía no tiene imagen y Joan está en "Escribe el código"
- **THEN** entre las casillas y "Entrar" no aparece ninguna ilustración
