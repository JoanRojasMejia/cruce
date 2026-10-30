## MODIFIED Requirements

### Requirement: Saldo de cada persona
El saldo de cada persona SHALL calcularse (nunca guardarse) como lo que pagó en gastos vigentes, menos lo que le toca en ellos, más los pagos confirmados que hizo, menos los confirmados que recibió, contando como pagos las transferencias que pasaron al cruce y la otra persona aceptó. Las que están por confirmar o se rechazaron MUST NOT contar. La suma de todos los saldos MUST ser cero. Un saldo positivo SHALL mostrarse "Le deben" y uno negativo "Debe", nunca solo con color.

#### Scenario: Un almuerzo
- **WHEN** Ana paga $220.000 repartidos en $110.000, $55.000, $22.000 y $33.000 (Ana es la de $55.000)
- **THEN** a Ana le deben $165.000 y los demás deben $110.000, $22.000 y $33.000

#### Scenario: Una transferencia al cruce por confirmar
- **WHEN** Carlos propone pasar a su cruce los $125.000 que le debe a Jesús y Jesús todavía no responde
- **THEN** los saldos del parche no cambian hasta que Jesús la acepte

### Requirement: Pasar la deuda al cruce
Con el parche cerrado, la app SHALL ofrecer pasar a un cruce solo las transferencias del plan "Para saldar" entre dos personas con la app que además comparten un cruce abierto. El monto y la dirección MUST ser los de esa transferencia; si no hay ninguna, la pregunta MUST NOT aparecer. Cuando uno de los dos lo propone, la transferencia SHALL quedar "por confirmar" para los dos y todavía no se crea nada en el cruce. Solo la otra persona (no quien lo propuso) SHALL poder aceptarla o rechazarla. Al aceptarla, en una sola operación de la base se MUST crear un movimiento en el cruce por ese monto (paga quien recibe, todo le corresponde a quien debe, concepto "Parche <nombre>") y en el parche esa transferencia MUST contar como un pago entre ellos. Si la rechaza, la deuda MUST seguir en el parche y el par SHALL poder volver a proponerla. Cada par SHALL pasar la deuda al cruce una sola vez. Si las cuentas del parche cambian antes de aceptar y el plan ya no tiene esa misma transferencia, la base MUST NOT aceptarla. Proponer, aceptar y rechazar SHALL quedar en la actividad del parche.

#### Scenario: Joan y Jesús
- **WHEN** Santa Marta se cierra con saldos +$47.000 (Joan), +$125.000 (Jesús), $0 (Ana) y −$172.000 (Carlos), y "Para saldar" dice que Carlos le paga $125.000 a Jesús y $47.000 a Joan
- **THEN** a Joan y a Jesús no se les ofrece pasar nada a su cruce, aunque Joan le deba $35.000 directamente a Jesús

#### Scenario: Carlos y Jesús comparten un cruce
- **WHEN** Carlos tiene la app, comparte un cruce con Jesús y propone pasar a su cruce los $125.000 de "Para saldar"
- **THEN** los dos ven la transferencia "por confirmar": Carlos ve que falta que Jesús la acepte y Jesús ve "Aceptar" y "Rechazar"

#### Scenario: Jesús acepta
- **WHEN** Jesús acepta la propuesta de Carlos
- **THEN** su cruce tiene un movimiento de $125.000 "Parche Santa Marta" a favor de Jesús, y en el parche Jesús queda en $0 y ya no aparece el pago de Carlos a Jesús en "Para saldar"

#### Scenario: Joan rechaza
- **WHEN** Carlos propone pasar a su cruce con Joan los $47.000 y Joan la rechaza
- **THEN** no se crea nada en el cruce, Carlos sigue debiéndole $47.000 a Joan en el parche y el pago sigue en "Para saldar"

#### Scenario: No quieren pasarla
- **WHEN** responden "No, se salda en el parche"
- **THEN** la deuda se salda dentro del parche como cualquier otra

#### Scenario: El cruce se cerró antes de aceptar
- **WHEN** Joan y Carlos desvinculan su cruce mientras una propuesta entre ellos está por confirmar
- **THEN** la base no deja aceptarla y sigue por confirmar
