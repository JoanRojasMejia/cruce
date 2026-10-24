# formato-pesos Specification

## Purpose
Representar, mostrar y capturar dinero en pesos colombianos enteros, de forma consistente en toda la app.

## Requirements

### Requirement: Dinero en pesos enteros
Todos los montos SHALL manejarse como pesos enteros, sin centavos ni decimales, tanto en la app como en la base de datos. Los montos de un movimiento MUST ser positivos.

#### Scenario: Monto sin decimales
- **WHEN** se registra un gasto de $36.000
- **THEN** el monto se guarda y se calcula como el entero 36000

### Requirement: Formato de montos
Los montos SHALL mostrarse con el signo `$` y punto como separador de miles, sin decimales ni el texto "COP". Cuando el monto lleva signo, el negativo MUST usar el signo menos tipográfico (U+2212, `−`), no un guion. El cero se muestra sin signo.

#### Scenario: Separador de miles
- **WHEN** se muestra el monto 1800000
- **THEN** se ve `$1.800.000`

#### Scenario: Montos con signo
- **WHEN** se muestran +18000 y −50000 con signo
- **THEN** se ven `+$18.000` y `−$50.000`, con el carácter U+2212 en el segundo

### Requirement: Captura de montos desde el teclado
El monto escrito en el teclado numérico SHALL convertirse a pesos ignorando cualquier carácter que no sea un dígito y aceptando como máximo 12 dígitos. Una entrada vacía MUST equivaler a $0.

#### Scenario: Escribir un monto
- **WHEN** se escribe "6" y luego "000" en el teclado de monto
- **THEN** el monto mostrado es `$6.000`
