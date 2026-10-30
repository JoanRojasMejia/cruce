# desvincular Specification

## Purpose
Permitir que cualquiera de los dos cierre su cruce: queda de solo lectura para ambos, con su historial, y la pareja puede volver con un código nuevo.

## Requirements

### Requirement: Desvincular cierra el cruce para los dos
Desde Ajustes del cruce, cualquiera de las dos personas SHALL poder desvincular a la otra. Antes de hacerlo, la app MUST pedir confirmación y explicar qué pasa: el cruce se cierra para los dos, no se puede anotar ni saldar nada más y el historial se conserva para verlo y exportarlo. Al confirmar, el cruce SHALL quedar cerrado para las dos personas, con la fecha en que se cerró.

#### Scenario: Joan desvincula a Jesús
- **WHEN** Joan toca "Desvincular a Jesús" en Ajustes del cruce y confirma
- **THEN** su cruce con Jesús queda cerrado para Joan y para Jesús

#### Scenario: Cancelar
- **WHEN** Joan toca "Desvincular a Jesús" y luego cancela
- **THEN** el cruce sigue abierto y nada cambia

#### Scenario: Solo los del cruce
- **WHEN** alguien que no es de un cruce intenta cerrarlo
- **THEN** la base lo rechaza y el cruce sigue abierto

### Requirement: Saldar primero al desvincular
Si el saldo no es $0, la confirmación de desvincular MUST decir el saldo pendiente y SHALL ofrecer "Saldar primero", que cierra la confirmación y abre "Saldar cuentas" sin cerrar el cruce. Con el saldo en $0, la confirmación MUST NOT ofrecer "Saldar primero".

#### Scenario: Desvincular con saldo pendiente
- **WHEN** Jesús le debe $20.000 a Joan y Joan toca "Desvincular a Jesús"
- **THEN** la confirmación dice que Jesús le debe $20.000 y que ese saldo queda en el historial, y ofrece "Saldar primero"

#### Scenario: Saldar primero
- **WHEN** Jesús le debe $20.000 a Joan y Joan toca "Saldar primero" en la confirmación
- **THEN** se abre "Saldar cuentas" y el cruce sigue abierto

#### Scenario: Desvincular a paz y salvo
- **WHEN** el saldo del cruce es $0 y Joan toca "Desvincular a Jesús"
- **THEN** la confirmación no ofrece "Saldar primero"

### Requirement: La app muestra un cruce cerrado en solo lectura
En un cruce cerrado, la app MUST NOT ofrecer "Anotar", "Saldar", editar ni eliminar (en el detalle y en el historial), "Desvincular" ni "Reparto por defecto". El saldo, el historial, el detalle y exportar a CSV SHALL seguir disponibles para los dos, con un aviso de que el cruce está cerrado y desde cuándo.

#### Scenario: Ver un cruce cerrado
- **WHEN** Jesús abre su cruce con Joan después de que Joan lo cerró
- **THEN** ve el saldo y el historial, un aviso "Cruce cerrado" con la fecha, y no ve "Anotar" ni "Saldar"

### Requirement: La base protege un cruce cerrado
En un cruce cerrado, la base MUST rechazar anotar, editar, eliminar y saldar movimientos, vengan de la app, de otro teléfono o de la cola sin conexión.

#### Scenario: Anotar en un cruce cerrado
- **WHEN** un teléfono intenta guardar un gasto en un cruce que ya está cerrado (por ejemplo, desde la cola sin conexión)
- **THEN** la base lo rechaza, el gasto sale de la cola y el saldo del cruce no cambia

### Requirement: Dónde aparece un cruce cerrado
Los cruces cerrados SHALL seguir apareciendo en "Tus cruces", en una sección "Cerrados" al final, en tono gris y con el nombre de la otra persona completo (sin cortarse). El inicio SHALL ser directamente un cruce solo cuando la persona tiene un único cruce y está abierto; en cualquier otro caso con cruces, el inicio SHALL ser "Tus cruces", con "Invitar a alguien" y "Tengo un código".

#### Scenario: El único cruce se cierra
- **WHEN** Joan solo tenía su cruce con Jesús y lo desvincula
- **THEN** el inicio de Joan pasa a ser "Tus cruces", con su cruce con Jesús en la sección "Cerrados" y los botones para invitar o unirse

#### Scenario: Un cruce abierto y uno cerrado
- **WHEN** Joan tiene un cruce abierto con Ana y uno cerrado con Jesús
- **THEN** "Tus cruces" muestra a Ana en la lista y a Jesús en la sección "Cerrados", al final y en gris, con "Con Jesús" completo

### Requirement: Volver a vincularse
Un cruce cerrado MUST NOT impedir que la misma pareja se vincule de nuevo. Al usar un código nuevo entre ellos SHALL crearse un cruce nuevo, abierto y sin movimientos, y el cerrado SHALL conservarse con su historial. La regla de un solo cruce por pareja MUST contar solo los cruces abiertos.

#### Scenario: Joan y Jesús vuelven
- **WHEN** Joan y Jesús tienen un cruce cerrado y Jesús usa un código nuevo de Joan
- **THEN** se crea un cruce nuevo entre los dos, en $0, y el cerrado sigue en "Tus cruces" con su historial

#### Scenario: Dos cruces abiertos entre la misma pareja
- **WHEN** Joan y Jesús ya tienen un cruce abierto y Jesús intenta usar otro código de Joan
- **THEN** el código se rechaza con "Ya tienes un cruce con Joan"
