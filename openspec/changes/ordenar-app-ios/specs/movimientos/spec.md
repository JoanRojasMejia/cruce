# Spec Delta

## MODIFIED Requirements

### Requirement: Eliminar un movimiento
Eliminar un movimiento SHALL pedir confirmación, mostrando cómo queda el saldo si se elimina. Un movimiento eliminado MUST dejar de contar en el saldo. Eliminar SHALL ser un borrado suave: el movimiento se conserva marcado con el momento en que se eliminó y MUST NOT volver a aparecer en el inicio, el historial ni el detalle, ni poder editarse.

#### Scenario: Confirmar la eliminación
- **WHEN** se elimina un gasto de $6.000 a medias pagado por Joan
- **THEN** el saldo de Joan baja $3.000 y el movimiento desaparece del historial

#### Scenario: El movimiento eliminado se conserva marcado
- **WHEN** se elimina un movimiento y luego se vuelven a cargar los movimientos de la cuenta
- **THEN** el movimiento sigue registrado con la fecha y hora en que se eliminó, y no aparece en el inicio ni en el historial

#### Scenario: Eliminar el único movimiento
- **WHEN** la cuenta tiene un solo movimiento y se elimina
- **THEN** el inicio muestra el estado vacío, igual que una cuenta sin movimientos
