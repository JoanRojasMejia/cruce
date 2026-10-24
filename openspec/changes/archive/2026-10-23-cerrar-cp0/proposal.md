# Proposal

## Why

La app de iOS se escribió sin Xcode y nunca se había compilado ni probado. El CP0 del roadmap la deja corriendo en el simulador, con las pruebas en verde, y fija como línea base de OpenSpec las reglas de producto que ya están implementadas y probadas.

## What Changes

- El proyecto se genera con XcodeGen, compila y corre en el simulador (iPhone 16, iOS 18.2).
- Las 12 pruebas de Swift (`BalanceCalculatorTests`, `MoneyTests`) y `go test` del backend pasan.
- Corrección visual: las superficies con borde punteado y fondo transparente ("Antes" en Gasto guardado, Eliminar y Saldar; "Esperando a tu amigo…" en Invitar) se veían como un bloque negro. Ahora muestran su contenido.
- Se registran como specs las reglas de producto vigentes: saldo neto, formato de pesos, movimientos, saldar cuentas y presentación del saldo.

## Capabilities

### New Capabilities
- `saldo-neto`: cálculo del saldo único entre las dos personas a partir de los movimientos y sus repartos.
- `formato-pesos`: representación, redondeo, formato y captura de montos en pesos colombianos enteros.
- `movimientos`: datos de un movimiento, categorías, edición y eliminación.
- `saldar-cuentas`: pago que deja el saldo en $0 y su medio de pago.
- `presentacion-saldo`: cómo se comunica quién le debe a quién (texto, signo, ilustraciones y colores por miembro).

### Modified Capabilities

## Impact

- Código: `ios/Cruce/DesignSystem/NeoSurface.swift` (no pinta sombra cuando el desplazamiento es 0).
- Repositorio: git iniciado y publicado en GitHub; `ios/Cruce/Info.plist` (generado por XcodeGen) y `.atl/` quedan en `.gitignore`.
- Documentación: `docs/ROADMAP.md` (CP0 marcado) y `CLAUDE.md` §2.
- Sin cambios en el backend, la migración SQL ni las dependencias.
