# reparto-parche Specification

## Purpose
Repartir cada gasto de un parche en pesos enteros: partes iguales, por consumo, por partes o por porcentaje, con propina proporcional y varios pagadores.

## Requirements

### Requirement: Reparto en partes iguales
Un gasto SHALL poder repartirse en partes iguales entre todos los participantes o entre los que se elijan (al menos uno).

#### Scenario: Entre todos
- **WHEN** un gasto de $100.000 se reparte entre 4 personas
- **THEN** a cada una le tocan $25.000

#### Scenario: Entre algunos
- **WHEN** un taxi de $30.000 se reparte entre 3 de las 5 personas
- **THEN** a esas 3 les tocan $10.000 y a las otras 2 nada

### Requirement: Reparto por consumo
Un gasto SHALL poder repartirse por ítems: cada ítem tiene un monto, una o varias personas que lo consumieron y un nombre opcional de hasta 40 caracteres ("Mojarra"), y se reparte en partes iguales entre ellas. Lo que le toca a cada persona es la suma de sus partes de los ítems.

#### Scenario: Cada uno su plato
- **WHEN** un almuerzo tiene ítems de $100.000 (Jesús), $50.000 (Ana), $20.000 (Carlos) y $30.000 (Joan)
- **THEN** les tocan $100.000, $50.000, $20.000 y $30.000

#### Scenario: Cuenta mixta
- **WHEN** una cuenta tiene una entrada de $40.000 para los 4 y platos de $30.000 (Jesús) y $20.000 (Ana)
- **THEN** a Jesús le tocan $40.000, a Ana $30.000, a Carlos $10.000 y a Joan $10.000

#### Scenario: Ítems con nombre
- **WHEN** Joan le pone "Mojarra" al ítem de $20.000 de Carlos y guarda
- **THEN** el ítem queda con su nombre, y un ítem sin nombre se guarda igual

### Requirement: Ítems que no suman el monto
Mientras los ítems no sumen el monto sin propina, la pantalla MUST mostrar "Faltan $X por repartir" (o "Sobran $X: los ítems suman más que el monto") y el gasto MUST NOT guardarse.

#### Scenario: Faltan pesos por repartir
- **WHEN** el monto es $50.000 y solo hay un ítem de $20.000
- **THEN** la pantalla dice "Faltan $30.000 por repartir"

### Requirement: Vista previa y borrar al editar
La vista previa del reparto SHALL titularse "Lo que le toca a cada quien". Al editar un gasto, "Borrar el gasto" SHALL ser un botón de texto debajo de "Guardar cambios".

#### Scenario: Editar el almuerzo
- **WHEN** Joan abre para editar el almuerzo repartido por consumo
- **THEN** la vista previa se titula "Lo que le toca a cada quien" y "Borrar el gasto" es un botón de texto debajo de "Guardar cambios"

### Requirement: Reparto por partes y por porcentaje
Un gasto SHALL poder repartirse por partes (enteros ≥ 0, al menos uno > 0) o por porcentajes (enteros que suman 100).

#### Scenario: Una pareja cuenta doble
- **WHEN** un hospedaje de $300.000 se reparte por partes 2, 1 y 1
- **THEN** les tocan $150.000, $75.000 y $75.000

#### Scenario: Porcentajes
- **WHEN** un gasto de $200.000 se reparte 50 %, 30 % y 20 %
- **THEN** les tocan $100.000, $60.000 y $40.000

### Requirement: Propina proporcional
Un gasto SHALL poder llevar una propina de 0 a 100 %; el total es el monto base más la propina (en pesos enteros, redondeando hacia abajo) y la propina MUST repartirse en proporción a lo que le toca a cada uno.

#### Scenario: Propina del 10 %
- **WHEN** el almuerzo por consumo de $100.000, $50.000, $20.000 y $30.000 lleva 10 % de propina
- **THEN** el total es $220.000 y les tocan $110.000, $55.000, $22.000 y $33.000

### Requirement: Varios pagadores
Un gasto SHALL poder tener uno o varios pagadores con montos que sumen exactamente el total, y MUST guardar cuánto puso cada uno.

#### Scenario: Dos tarjetas
- **WHEN** Ana paga $120.000 y Jesús $100.000 de una cuenta de $220.000
- **THEN** el gasto se guarda con los dos pagadores y los saldos los tienen en cuenta

#### Scenario: El Hospedaje de Santa Marta
- **WHEN** el Hospedaje de $600.000, repartido por partes 1/1/1/1, lo pagan Jesús con $400.000 y Joan con $200.000, junto con el resto de los gastos de Santa Marta
- **THEN** los saldos son +$47.000 (Joan), +$125.000 (Jesús), $0 (Ana) y −$172.000 (Carlos)

### Requirement: Cuánto puso cada pagador
Con más de un pagador, la app SHALL mostrar "¿Cuánto puso cada uno?" con un campo por pagador. Por defecto el total SHALL repartirse en partes iguales entre los pagadores (pesos enteros, con el mismo redondeo del reparto) y volver a repartirse al agregar o quitar pagadores o al cambiar el total, hasta que alguien escriba un monto a mano.

#### Scenario: Partes iguales por defecto
- **WHEN** en un gasto de $600.000 que pagó Jesús se agrega a Joan como pagador
- **THEN** aparece "¿Cuánto puso cada uno?" con $300.000 para cada uno, y con un tercer pagador quedan $200.000 cada uno

### Requirement: Pagadores que no suman el total
Mientras la suma de los pagadores no dé el total, la app MUST mostrar "Faltan $X" o "Sobran $X" y MUST NOT dejar guardar.

#### Scenario: No suman el total
- **WHEN** los pagadores suman $200.000 en una cuenta de $220.000
- **THEN** la app no deja guardar y explica cuánto falta

#### Scenario: Faltan o sobran
- **WHEN** en ese gasto de $600.000 se escribe que Jesús puso $400.000 y Joan sigue con $300.000
- **THEN** la app muestra "Sobran $100.000" y no deja guardar hasta que la suma dé $600.000

### Requirement: Redondeo en pesos enteros
Todo reparto MUST dar pesos enteros que sumen exactamente el total. Los pesos que sobran SHALL ir de a uno a quienes tienen el residuo más grande, y en empate a quien va primero en el orden del parche.

#### Scenario: $100.000 entre 3
- **WHEN** un gasto de $100.000 se reparte en partes iguales entre 3 personas
- **THEN** les tocan $33.334, $33.333 y $33.333, en el orden del parche

### Requirement: Formas de reparto con un ejemplo
Al anotar un gasto, la pantalla SHALL mostrar a la vista "Iguales entre todos" y "Otra forma de repartir". "Otra forma de repartir" MUST abrir las demás formas ("Iguales entre algunos", "Por consumo", "Por partes" y "Por porcentaje"), cada una con un ejemplo de una línea. Al editar un gasto que usa otra forma, las opciones SHALL verse abiertas con esa forma elegida.

#### Scenario: Por partes con su ejemplo
- **WHEN** Joan toca "Otra forma de repartir"
- **THEN** ve "Por partes" con "Si Ana va con su pareja, ella cuenta 2 y los demás 1."

#### Scenario: Editar un gasto por consumo
- **WHEN** Joan abre el almuerzo repartido por consumo
- **THEN** "Otra forma de repartir" está abierta y "Por consumo" está elegida
