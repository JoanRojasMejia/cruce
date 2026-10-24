# Spec Delta

## Purpose

Registrar los gastos y pagos entre las dos personas, con los datos necesarios para calcular el saldo y mostrar el historial.

## ADDED Requirements

### Requirement: Datos de un movimiento
Cada movimiento SHALL registrar quién pagó, el monto, el concepto, la fecha, la categoría, el reparto y quién lo anotó. Un movimiento es un gasto o un pago para saldar.

#### Scenario: Guardar un gasto
- **WHEN** Joan anota "Prueba" por $6.000, pagado por él, a medias, en Comida
- **THEN** se confirma "¡Gasto guardado!" con `+$3.000 a tu favor` y el saldo antes y después del gasto

### Requirement: Categorías
La categoría de un movimiento SHALL ser una de: Comida, Mercado, Transporte, Hogar, Ocio, Préstamo u Otro.

#### Scenario: Filtrar el historial por categoría
- **WHEN** se elige una categoría en el historial
- **THEN** solo se listan los movimientos de esa categoría

### Requirement: Historial agrupado por día
El historial SHALL listar los movimientos del más reciente al más antiguo, agrupados por día, y permitir filtrar por quién pagó y por categoría.

#### Scenario: Movimientos de hoy y de ayer
- **WHEN** hay movimientos de hoy y de ayer
- **THEN** aparecen bajo los encabezados "HOY · …" y "AYER · …"

### Requirement: Eliminar un movimiento
Eliminar un movimiento SHALL pedir confirmación, mostrando cómo queda el saldo si se elimina. Un movimiento eliminado MUST dejar de contar en el saldo.

#### Scenario: Confirmar la eliminación
- **WHEN** se elimina un gasto de $6.000 a medias pagado por Joan
- **THEN** el saldo de Joan baja $3.000 y el movimiento desaparece del historial
