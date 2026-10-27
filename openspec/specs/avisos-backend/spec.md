# avisos-backend Specification

## Purpose
Define cómo el backend de Cruce se entera de cada cambio en los movimientos de un cruce, para poder avisarle a la otra persona, y cómo se mantiene disponible y seguro en cada ambiente.

## Requirements

### Requirement: El backend recibe cada cambio de un movimiento
Cuando alguien anota, edita o elimina un movimiento, la base de datos SHALL avisarle al backend de su mismo ambiente. El backend SHALL dejar una línea en su log por cada aviso, con el tipo de cambio, el cruce, el movimiento, el tipo de movimiento, el monto y quién lo anotó.

#### Scenario: Anotar un gasto en testing
- **WHEN** Joan anota un gasto en la app "Cruce Test"
- **THEN** el log del backend de testing muestra una línea con el cambio `INSERT`, el id del cruce y el monto

#### Scenario: Eliminar un gasto
- **WHEN** Jesús elimina un gasto
- **THEN** el log del backend muestra una línea con el cambio `UPDATE` de ese movimiento

### Requirement: El log no guarda datos personales
El log del backend MUST NOT incluir el concepto de un movimiento, nombres, correos ni secretos. Solo SHALL incluir ids, tipos y montos.

#### Scenario: Gasto con concepto
- **WHEN** llega el aviso de un gasto con el concepto "Mercado Éxito"
- **THEN** la línea del log no contiene "Mercado Éxito"

### Requirement: Solo Supabase puede avisar
El backend SHALL aceptar un aviso solo si trae el secreto compartido en `Authorization: Bearer`. Un aviso sin secreto, con otro secreto, con un JSON inválido o de otra tabla MUST rechazarse sin avisarle a nadie, y SHALL dejar una línea de advertencia en el log sin el secreto que llegó.

#### Scenario: Secreto incorrecto
- **WHEN** alguien envía un aviso con un secreto que no es el del backend
- **THEN** recibe 401, nadie recibe aviso y el log muestra la advertencia sin el secreto enviado

### Requirement: Siempre disponible
El backend de cada ambiente SHALL estar prendido todo el tiempo, sin dormirse por falta de tráfico, para no perder avisos. `GET /healthz` SHALL responder `{"status":"ok"}`.

#### Scenario: Después de una noche sin movimientos
- **WHEN** nadie anota nada durante horas y luego Joan anota un gasto
- **THEN** el backend recibe el aviso en el primer intento

### Requirement: Un backend por ambiente
Cada ambiente que tenga backend SHALL tener el suyo, con su propio secreto, y SHALL recibir avisos solo de la base de su ambiente. Los secretos MUST NOT estar en el repositorio.

#### Scenario: Gasto en local
- **WHEN** alguien anota un gasto en "Cruce Dev"
- **THEN** el backend de testing no recibe ningún aviso
