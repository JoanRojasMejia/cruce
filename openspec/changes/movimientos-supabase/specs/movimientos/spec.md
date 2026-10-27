# Spec Delta

## ADDED Requirements

### Requirement: Los movimientos se guardan en la nube
Anotar, editar, eliminar (borrado suave) y saldar SHALL guardarse en la base de datos del cruce abierto. Al recargar, la otra persona del cruce SHALL ver los mismos movimientos y el mismo saldo. Los movimientos MUST seguir ahí después de cerrar y abrir la app.

#### Scenario: Joan anota y Jesús recarga
- **WHEN** Joan anota una cena de $60.000 a medias en su cruce con Jesús, y Jesús recarga su inicio
- **THEN** Jesús ve la cena y "Le debes $30.000 a Joan", y Joan ve "Jesús te debe $30.000"

#### Scenario: Cerrar y abrir la app
- **WHEN** Joan anota un gasto, cierra la app y la vuelve a abrir
- **THEN** el gasto sigue en su historial

#### Scenario: Eliminar se ve en los dos
- **WHEN** Jesús elimina un gasto que anotó Joan y Joan recarga
- **THEN** el gasto ya no cuenta en el saldo de ninguno de los dos

### Requirement: Recargar los movimientos
El inicio de un cruce y "Tus cruces" SHALL recargar los movimientos al deslizar hacia abajo. La app SHALL recargarlos también al volver al primer plano.

#### Scenario: Deslizar para recargar
- **WHEN** Jesús desliza hacia abajo en su inicio después de que Joan anotó un gasto
- **THEN** el gasto aparece y el saldo se actualiza

### Requirement: Guardar no duplica
Guardar el mismo movimiento más de una vez (por ejemplo, al reintentar después de un error de red) MUST dejar un solo movimiento en la base.

#### Scenario: Reintento
- **WHEN** la app guarda un gasto y vuelve a guardarlo con el mismo identificador
- **THEN** la base tiene un solo movimiento con esos datos

### Requirement: La deuda de un parche se ve en el cruce
El movimiento que crea "pasar al cruce" al cerrar un parche SHALL aparecer en el historial y en el saldo del cruce de esas dos personas.

#### Scenario: Pasar la deuda de un parche
- **WHEN** al cerrar el parche Santa Marta, Joan pasa a su cruce con Jesús los $47.000 que Jesús le debe
- **THEN** el cruce de Joan y Jesús muestra el movimiento "Parche Santa Marta" y el saldo cambia en $47.000
