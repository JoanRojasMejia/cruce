## ADDED Requirements

### Requirement: Eliminar deslizando en el historial
En el historial, deslizar una fila hacia la izquierda SHALL mostrar "Eliminar". Tocarlo SHALL abrir la misma confirmación que eliminar desde el detalle, con cómo queda el saldo, y solo al confirmar se elimina (borrado suave). En un cruce cerrado el historial MUST NOT ofrecer eliminar.

#### Scenario: Eliminar un gasto desde el historial
- **WHEN** Joan desliza la fila de un gasto de $6.000 a medias que pagó él, toca "Eliminar" y confirma
- **THEN** el gasto desaparece del historial y el saldo de Joan baja $3.000

#### Scenario: Cancelar
- **WHEN** Joan desliza una fila, toca "Eliminar" y luego cancela
- **THEN** el movimiento sigue en el historial
