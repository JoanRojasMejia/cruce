# reparto-por-defecto Specification

## Purpose
Que cada cruce tenga un reparto con el que arranca cada gasto nuevo, para no elegirlo cada vez.

## Requirements

### Requirement: Reparto por defecto de un cruce
Cada cruce SHALL tener un reparto por defecto (lo que le toca a quien no pagó, de 0 % a 100 %), que empieza en 50 %. "Reparto por defecto" en Ajustes SHALL mostrar el actual ("50/50", "70 %" o "Todo es del otro") y abrir una pantalla para cambiarlo, con las opciones de "Nuevo movimiento". Lo comparten las dos personas del cruce y MUST NOT cambiar el de otro cruce. Sin conexión, la app MUST mostrar un error y conservar el anterior.

#### Scenario: Cambiar a 70 %
- **WHEN** Joan elige "Porcentaje" con 70 % para el otro y guarda
- **THEN** Ajustes dice "70 %" en su cruce con Jesús, y Jesús ve lo mismo al recargar

#### Scenario: Otro cruce
- **WHEN** Joan cambia el reparto de su cruce con Jesús a 70 %
- **THEN** su cruce con Ana sigue en 50/50

### Requirement: Nuevo movimiento arranca con el reparto por defecto
Al anotar un movimiento nuevo, el reparto SHALL arrancar con el reparto por defecto del cruce abierto: 50 % como "Mitad y mitad", 100 % como "Todo es del otro" y cualquier otro valor como "Porcentaje" con ese valor. Se MUST poder cambiar para ese movimiento sin tocar el reparto por defecto. Editar un movimiento existente MUST conservar su propio reparto.

#### Scenario: Reparto de 70 %
- **WHEN** el reparto por defecto del cruce es 70 % y Joan abre "Nuevo movimiento"
- **THEN** el reparto aparece en "Porcentaje" con 70 % para Jesús

#### Scenario: Editar un gasto viejo
- **WHEN** el reparto por defecto es 70 % y Joan edita un gasto que se anotó a medias
- **THEN** el reparto del gasto sigue en "Mitad y mitad"
