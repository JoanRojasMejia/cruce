## MODIFIED Requirements

### Requirement: Exportar el historial de un cruce
"Exportar historial (CSV)" en Ajustes del cruce SHALL armar un archivo CSV con los movimientos vigentes del cruce abierto y abrir la hoja para compartir del sistema. Los movimientos eliminados MUST NOT aparecer. El archivo SHALL llamarse `cruce-con-<nombre>-<AAAA-MM-DD>.csv`, con el nombre de la otra persona en minúsculas y sin tildes. Funciona en un cruce abierto o cerrado, y sin conexión.

#### Scenario: Exportar el cruce con Jesús
- **WHEN** Joan toca "Exportar historial (CSV)" el 27 oct 2026 en Ajustes de su cruce con Jesús
- **THEN** se abre la hoja para compartir con el archivo `cruce-con-jesus-2026-10-27.csv`

#### Scenario: Un gasto eliminado
- **WHEN** el cruce tiene tres movimientos y uno está eliminado
- **THEN** el archivo tiene dos filas de movimientos, sin el eliminado

#### Scenario: Cruce sin movimientos
- **WHEN** el cruce no tiene movimientos vigentes
- **THEN** el archivo solo tiene la fila de encabezados
