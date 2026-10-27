# Spec Delta

## MODIFIED Requirements

### Requirement: Recibo rosa o verde según el miembro
Las ilustraciones de "te deben" y "debes" SHALL usar la variante del miembro que mira: quien creó la cuenta ve el recibo rosa y quien se unió con código ve el recibo verde. La variante MUST guardarse por miembro. Con varios cruces, la variante SHALL ser la del cruce abierto, porque una persona puede haber creado un cruce y haberse unido a otro.

#### Scenario: Joan ve el recibo rosa
- **WHEN** Joan, que creó la cuenta, ve su saldo
- **THEN** la ilustración usa el recibo rosa

#### Scenario: El recibo cambia con el cruce
- **WHEN** Joan creó su cruce con Jesús y se unió con código al cruce de Ana
- **THEN** en su cruce con Jesús ve el recibo rosa y en su cruce con Ana ve el verde
