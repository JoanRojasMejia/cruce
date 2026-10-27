## ADDED Requirements

### Requirement: Exportar el historial de un cruce
"Exportar historial (CSV)" en Ajustes SHALL armar un archivo CSV con los movimientos vigentes del cruce abierto y abrir la hoja para compartir del sistema. Los movimientos eliminados MUST NOT aparecer. El archivo SHALL llamarse `cruce-con-<nombre>-<AAAA-MM-DD>.csv`, con el nombre de la otra persona en minúsculas y sin tildes. Funciona en un cruce abierto o cerrado, y sin conexión.

#### Scenario: Exportar el cruce con Jesús
- **WHEN** Joan toca "Exportar historial (CSV)" el 27 oct 2026 en su cruce con Jesús
- **THEN** se abre la hoja para compartir con el archivo `cruce-con-jesus-2026-10-27.csv`

#### Scenario: Un gasto eliminado
- **WHEN** el cruce tiene tres movimientos y uno está eliminado
- **THEN** el archivo tiene dos filas de movimientos, sin el eliminado

#### Scenario: Cruce sin movimientos
- **WHEN** el cruce no tiene movimientos vigentes
- **THEN** el archivo solo tiene la fila de encabezados

### Requirement: Columnas del CSV
El CSV SHALL tener una fila de encabezados y una fila por movimiento, de la más vieja a la más nueva, con las columnas `Fecha` (AAAA-MM-DD), `Tipo` (`Gasto` o `Pago`), `Concepto`, `Categoría`, `Pagó`, `Monto`, `Parte del otro (%)`, `Le debe a quien pagó` y `Medio de pago` (vacío en los gastos). Los montos MUST ir en pesos enteros, sin `$` ni puntos de miles.

#### Scenario: Encabezados
- **WHEN** se exporta cualquier cruce
- **THEN** la primera fila es `Fecha,Tipo,Concepto,Categoría,Pagó,Monto,Parte del otro (%),Le debe a quien pagó,Medio de pago`

#### Scenario: Una cena a medias
- **WHEN** Joan pagó el 12 oct 2026 una cena de $60.000 a medias, de categoría comida
- **THEN** su fila es `2026-10-12,Gasto,Cena,Comida,Joan,60000,50,30000,`

#### Scenario: Un pago por Nequi
- **WHEN** Jesús le pagó $20.000 a Joan por Nequi el 20 oct 2026
- **THEN** su fila es `2026-10-20,Pago,Saldar cuentas,Otro,Jesús,20000,100,20000,Nequi`

### Requirement: Formato del archivo
El archivo MUST ir en UTF-8 con marca de orden de bytes (para que Excel muestre las tildes) y separado por comas. Un campo con coma, comillas o salto de línea MUST ir entre comillas, con las comillas internas dobladas.

#### Scenario: Concepto con coma y comillas
- **WHEN** un gasto se llama `Pizza, "la buena"`
- **THEN** el campo del concepto queda `"Pizza, ""la buena"""`
