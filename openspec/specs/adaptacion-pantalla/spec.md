# adaptacion-pantalla Specification

## Purpose
Asegurar que cada pantalla se pueda usar completa en los tamaños de iPhone soportados y con texto más grande.

## Requirements

### Requirement: Nada cortado en pantallas pequeñas y grandes
En iPhone SE y en iPhone Pro Max, ninguna pantalla SHALL cortar texto ni dejar controles fuera de alcance; donde el contenido no quepa, la pantalla MUST permitir hacer scroll.

#### Scenario: Agregar movimiento en iPhone SE
- **WHEN** se abre "Nuevo movimiento" en un iPhone SE
- **THEN** se puede llegar a todos los campos y al botón "Guardar movimiento"

### Requirement: Texto dinámico hasta un límite definido
La app SHALL respetar el tamaño de texto del sistema hasta un límite máximo acordado; por encima de ese límite el texto MUST dejar de crecer sin romper el diseño.

#### Scenario: Texto grande en el inicio
- **WHEN** la persona usa el tamaño de texto máximo permitido
- **THEN** el saldo, la frase de quién le debe a quién y los botones del inicio se leen completos
