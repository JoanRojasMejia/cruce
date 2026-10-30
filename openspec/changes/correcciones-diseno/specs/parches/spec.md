## MODIFIED Requirements

### Requirement: Estados del parche
Un parche SHALL estar abierto o cerrado. Solo quien creó el parche SHALL poder cerrarlo, después de confirmar; a los demás la base MUST rechazarlo y la app MUST mostrarles "Pídele a <nombre> que lo cierre" en lugar del botón. Si quien lo creó ya no tiene la app, cualquier participante con la app SHALL poder cerrarlo. Cerrar MUST quedar en la actividad del parche. Un parche cerrado MUST NOT aceptar gastos nuevos ni ediciones de gastos y MUST NOT reabrirse. Un parche cerrado en el que todos los saldos son cero SHALL mostrarse "A paz y salvo".

#### Scenario: Cerrar
- **WHEN** Jesús creó el parche, lo cierra y confirma
- **THEN** ya no se pueden anotar gastos, se siguen pudiendo anotar pagos y los del parche ven "Jesús cerró el parche"

#### Scenario: Otra persona quiere cerrarlo
- **WHEN** Ana está en el parche que creó Jesús
- **THEN** en vez de "Cerrar el parche" ve "Pídele a Jesús que lo cierre", y si lo intenta igual la base responde "Solo Jesús puede cerrar el parche"

#### Scenario: Queda a paz y salvo
- **WHEN** en un parche cerrado se confirma el último pago pendiente y todos los saldos quedan en cero
- **THEN** el parche se muestra "A paz y salvo" en la lista de parches
