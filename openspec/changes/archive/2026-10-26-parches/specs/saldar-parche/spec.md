# Spec Delta

## ADDED Requirements

### Requirement: Saldo de cada persona
El saldo de cada persona SHALL calcularse (nunca guardarse) como lo que pagó en gastos vigentes, menos lo que le toca en ellos, más los pagos confirmados que hizo, menos los confirmados que recibió, contando como pagos las deudas que pasaron al cruce. La suma de todos los saldos MUST ser cero. Un saldo positivo SHALL mostrarse "Le deben" y uno negativo "Debe", nunca solo con color.

#### Scenario: Un almuerzo
- **WHEN** Ana paga $220.000 repartidos en $110.000, $55.000, $22.000 y $33.000 (Ana es la de $55.000)
- **THEN** a Ana le deben $165.000 y los demás deben $110.000, $22.000 y $33.000

### Requirement: Pagos con confirmación
Un pago anotado por quien lo recibió, o cuyo receptor no tiene la app, SHALL contar de una vez. Si lo anota otra persona y el receptor tiene la app, MUST quedar pendiente y no contar hasta que el receptor lo confirme.

#### Scenario: Carlos le pagó a Jesús
- **WHEN** Ana anota que Carlos le pagó $87.500 a Jesús
- **THEN** el pago queda pendiente, Jesús ve "Carlos te pagó $87.500, ¿confirmas?" y el saldo cambia solo cuando confirma

#### Scenario: Lo anota quien recibió
- **WHEN** Jesús anota que Carlos le pagó $87.500
- **THEN** el pago cuenta de una vez

### Requirement: Mínimo de transferencias
La app SHALL mostrar cómo saldar con el menor número de transferencias, a lo sumo una menos que las personas con saldo distinto de cero, de forma determinista.

#### Scenario: Cuatro personas
- **WHEN** los saldos son +165.000 (Ana), −110.000 (Jesús), −22.000 (Carlos) y −33.000 (Joan)
- **THEN** la app muestra tres transferencias: Jesús le paga $110.000 a Ana, Joan le paga $33.000 a Ana y Carlos le paga $22.000 a Ana

### Requirement: Pasar la deuda al cruce
Con el parche cerrado, si dos de sus participantes con la app comparten un cruce, la app SHALL preguntar a cada uno si lo que se deben directamente entre ellos pasa a su cruce. Si cualquiera de los dos acepta, se MUST crear un movimiento en el cruce por ese monto (paga quien recibe, todo le corresponde a quien debe, concepto "Parche <nombre>"), y en el parche esa deuda MUST contar como un pago entre ellos. Cada par SHALL poder pasar la deuda una sola vez.

#### Scenario: Joan y Jesús
- **WHEN** al cerrar el parche Joan le debe directamente $64.000 a Jesús y Jesús acepta pasarlo a su cruce
- **THEN** su cruce tiene un movimiento de $64.000 "Parche Santa Marta" a favor de Jesús, y en el parche ya no aparece una transferencia entre ellos por esa deuda

#### Scenario: No quieren pasarla
- **WHEN** responden "No, se salda en el parche"
- **THEN** la deuda se salda dentro del parche como cualquier otra
