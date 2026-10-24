# Spec Delta

## Purpose

Comunicar sin ambigüedad quién le debe a quién y cuánto, de forma accesible y con la identidad visual de cada miembro.

## ADDED Requirements

### Requirement: La dirección de la deuda nunca depende solo del color
Toda vista del saldo o del efecto de un movimiento SHALL indicar la dirección de la deuda con texto: la frase ("Jesús te debe $20.000", "Le debes $20.000 a Jesús"), el signo `+` o `−` y "a tu favor" o "a favor de Jesús". La flecha MUST ir de quien debe a quien recibe.

#### Scenario: Inicio con saldo a favor
- **WHEN** Jesús le debe $20.000 a Joan y Joan abre el inicio
- **THEN** ve "Jesús te debe", `$20.000` y "Jesús → tú"

#### Scenario: Fila de un movimiento a favor del otro
- **WHEN** Jesús pagó un mercado de $100.000 a medias
- **THEN** la fila de Joan muestra `−$50.000` y "a favor de Jesús"

### Requirement: Recibo rosa o verde según el miembro
Las ilustraciones de "te deben" y "debes" SHALL usar la variante del miembro que mira: quien creó la cuenta ve el recibo rosa y quien se unió con código ve el recibo verde. La variante MUST guardarse por miembro.

#### Scenario: Joan ve el recibo rosa
- **WHEN** Joan, que creó la cuenta, ve su saldo
- **THEN** la ilustración usa el recibo rosa

### Requirement: Color de avatar por rol
Quien crea la cuenta SHALL tener avatar amarillo y quien se une MUST tener avatar violeta.

#### Scenario: Avatares en Conectados
- **WHEN** Joan y Jesús quedan conectados
- **THEN** el avatar de Joan es amarillo y el de Jesús violeta

### Requirement: Comparación antes y después legible
Las cajas que comparan el saldo antes y después de una acción (Gasto guardado, Eliminar, Saldar) y la tarjeta "Esperando a tu amigo…" SHALL mostrar su texto sobre el fondo de la pantalla, con borde punteado y sin relleno opaco.

#### Scenario: Caja "Antes" al saldar
- **WHEN** se abre Saldar cuentas con "Jesús te debe $20.000"
- **THEN** la caja "ANTES" muestra "Jesús te debe $20.000" con borde punteado y fondo transparente
