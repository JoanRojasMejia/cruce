# Spec Delta

## ADDED Requirements

### Requirement: Los cambios de la otra persona aparecen solos
Mientras la app está abierta, un movimiento que la otra persona anota, edita o elimina en un cruce SHALL aparecer en el historial y el saldo de ese cruce en pocos segundos, sin deslizar para recargar. Aplicar un cambio MUST NOT duplicar un movimiento que ya estaba.

#### Scenario: Jesús anota mientras Joan mira
- **WHEN** Joan tiene abierto el inicio de su cruce con Jesús y Jesús anota un mercado de $100.000 a medias
- **THEN** en menos de 10 segundos el inicio de Joan muestra el mercado y el saldo cambia en $50.000, sin tocar nada

#### Scenario: Eco de lo propio
- **WHEN** Joan anota un gasto y le llega el cambio de ese mismo gasto
- **THEN** el gasto aparece una sola vez

#### Scenario: Borrado de la otra persona
- **WHEN** Jesús elimina un gasto mientras Joan mira su inicio
- **THEN** el gasto deja de contar en el saldo de Joan sin recargar

### Requirement: Reconectar al volver
Al volver la app al primer plano, la app SHALL recargar los movimientos y volver a escuchar los cambios de cada cruce.

#### Scenario: Volver a la app
- **WHEN** Joan deja la app en segundo plano, Jesús anota un gasto y Joan vuelve a la app
- **THEN** Joan ve el gasto y los cambios siguientes aparecen solos
