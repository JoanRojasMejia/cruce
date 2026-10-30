## MODIFIED Requirements

### Requirement: Varios pagadores
Un gasto SHALL poder tener uno o varios pagadores con montos que sumen exactamente el total, y MUST guardar cuánto puso cada uno. Con más de un pagador, la app SHALL mostrar "¿Cuánto puso cada uno?" con un campo por pagador. Por defecto el total SHALL repartirse en partes iguales entre los pagadores (pesos enteros, con el mismo redondeo del reparto) y volver a repartirse al agregar o quitar pagadores o al cambiar el total, hasta que alguien escriba un monto a mano. Mientras la suma no dé el total, la app MUST mostrar "Faltan $X" o "Sobran $X" y MUST NOT dejar guardar.

#### Scenario: Dos tarjetas
- **WHEN** Ana paga $120.000 y Jesús $100.000 de una cuenta de $220.000
- **THEN** el gasto se guarda con los dos pagadores y los saldos los tienen en cuenta

#### Scenario: No suman el total
- **WHEN** los pagadores suman $200.000 en una cuenta de $220.000
- **THEN** la app no deja guardar y explica cuánto falta

#### Scenario: Partes iguales por defecto
- **WHEN** en un gasto de $600.000 que pagó Jesús se agrega a Joan como pagador
- **THEN** aparece "¿Cuánto puso cada uno?" con $300.000 para cada uno, y con un tercer pagador quedan $200.000 cada uno

#### Scenario: Faltan o sobran
- **WHEN** en ese gasto de $600.000 se escribe que Jesús puso $400.000 y Joan sigue con $300.000
- **THEN** la app muestra "Sobran $100.000" y no deja guardar hasta que la suma dé $600.000

#### Scenario: El Hospedaje de Santa Marta
- **WHEN** el Hospedaje de $600.000, repartido por partes 1/1/1/1, lo pagan Jesús con $400.000 y Joan con $200.000, junto con el resto de los gastos de Santa Marta
- **THEN** los saldos son +$47.000 (Joan), +$125.000 (Jesús), $0 (Ana) y −$172.000 (Carlos)
