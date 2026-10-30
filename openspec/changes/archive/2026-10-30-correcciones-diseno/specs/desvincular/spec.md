## MODIFIED Requirements

### Requirement: Desvincular cierra el cruce para los dos
Desde Ajustes del cruce, cualquiera de las dos personas SHALL poder desvincular a la otra. Antes de hacerlo, la app MUST pedir confirmación y explicar qué pasa: el cruce se cierra para los dos, no se puede anotar ni saldar nada más y el historial se conserva para verlo y exportarlo. Si el saldo no es $0, la confirmación MUST decir el saldo pendiente y SHALL ofrecer "Saldar primero", que cierra la confirmación y abre "Saldar cuentas" sin cerrar el cruce. Con el saldo en $0, la confirmación MUST NOT ofrecer "Saldar primero". Al confirmar, el cruce SHALL quedar cerrado para las dos personas, con la fecha en que se cerró.

#### Scenario: Joan desvincula a Jesús
- **WHEN** Joan toca "Desvincular a Jesús" en Ajustes del cruce y confirma
- **THEN** su cruce con Jesús queda cerrado para Joan y para Jesús

#### Scenario: Desvincular con saldo pendiente
- **WHEN** Jesús le debe $20.000 a Joan y Joan toca "Desvincular a Jesús"
- **THEN** la confirmación dice que Jesús le debe $20.000 y que ese saldo queda en el historial, y ofrece "Saldar primero"

#### Scenario: Saldar primero
- **WHEN** Jesús le debe $20.000 a Joan y Joan toca "Saldar primero" en la confirmación
- **THEN** se abre "Saldar cuentas" y el cruce sigue abierto

#### Scenario: Desvincular a paz y salvo
- **WHEN** el saldo del cruce es $0 y Joan toca "Desvincular a Jesús"
- **THEN** la confirmación no ofrece "Saldar primero"

#### Scenario: Cancelar
- **WHEN** Joan toca "Desvincular a Jesús" y luego cancela
- **THEN** el cruce sigue abierto y nada cambia

#### Scenario: Solo los del cruce
- **WHEN** alguien que no es de un cruce intenta cerrarlo
- **THEN** la base lo rechaza y el cruce sigue abierto

### Requirement: Dónde aparece un cruce cerrado
Los cruces cerrados SHALL seguir apareciendo en "Tus cruces", en una sección "Cerrados" al final, en tono gris y con el nombre de la otra persona completo (sin cortarse). El inicio SHALL ser directamente un cruce solo cuando la persona tiene un único cruce y está abierto; en cualquier otro caso con cruces, el inicio SHALL ser "Tus cruces", con "Invitar a alguien" y "Tengo un código".

#### Scenario: El único cruce se cierra
- **WHEN** Joan solo tenía su cruce con Jesús y lo desvincula
- **THEN** el inicio de Joan pasa a ser "Tus cruces", con su cruce con Jesús en la sección "Cerrados" y los botones para invitar o unirse

#### Scenario: Un cruce abierto y uno cerrado
- **WHEN** Joan tiene un cruce abierto con Ana y uno cerrado con Jesús
- **THEN** "Tus cruces" muestra a Ana en la lista y a Jesús en la sección "Cerrados", al final y en gris, con "Con Jesús" completo
