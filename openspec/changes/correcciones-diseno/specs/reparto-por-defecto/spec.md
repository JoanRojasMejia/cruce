## MODIFIED Requirements

### Requirement: Reparto por defecto de un cruce
Cada cruce SHALL tener un reparto por defecto (lo que le toca a quien no pagó, de 0 % a 100 %), que empieza en 50 %. "Reparto por defecto" en Ajustes del cruce SHALL mostrar el actual ("50/50", "70 %" o "Todo es del otro") y abrir una pantalla para cambiarlo, con las opciones de "Nuevo movimiento". Lo comparten las dos personas del cruce y MUST NOT cambiar el de otro cruce. Sin conexión, la app MUST mostrar un error y conservar el anterior.

#### Scenario: Cambiar a 70 %
- **WHEN** Joan elige "Porcentaje" con 70 % para el otro y guarda
- **THEN** Ajustes del cruce dice "70 %" en su cruce con Jesús, y Jesús ve lo mismo al recargar

#### Scenario: Otro cruce
- **WHEN** Joan cambia el reparto de su cruce con Jesús a 70 %
- **THEN** su cruce con Ana sigue en 50/50
