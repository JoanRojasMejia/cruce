# Proposal

## Why

Varios botones de la app no hacen nada todavía: "Cambiar monto" en Saldar, y en Ajustes la tarjeta del perfil, "Reparto por defecto", "Exportar historial (CSV)" y "Desvincular". El historial tampoco deja eliminar deslizando. Es el CP11 del roadmap; Joan y Jesús ya usan la app en testing y se topan con esos botones vacíos.

## What Changes

- **Pago parcial en Saldar (decidido por Joan el 27 oct 2026):** "Cambiar monto" deja escribir cuánto se paga, entre $1 y el total que se debe. El pago queda como un movimiento de tipo pago y el saldo baja sin llegar a $0. La pantalla de éxito dice cuánto falta.
- **Exportar el historial a CSV:** Ajustes arma un archivo con los movimientos vigentes del cruce abierto y lo comparte con la hoja del sistema.
- **Desvincular (decidido por Joan el 27 oct 2026):** el cruce se cierra para los dos. Nadie puede anotar, editar, eliminar ni saldar en él, pero los dos siguen viendo y exportando su historial. Pueden volver a vincularse con un código nuevo, que crea un cruce nuevo.
- **Editar el perfil:** la tarjeta de Ajustes abre una pantalla para cambiar el nombre.
- **Reparto por defecto:** se elige por cruce en Ajustes y "Nuevo movimiento" arranca con ese reparto.
- **Deslizar para eliminar** una fila del historial, con la misma confirmación del detalle.
- **Base de datos:** una migración nueva agrega el cierre del cruce (`ledgers.closed_at`), la función para cerrarlo, el bloqueo de movimientos en cruces cerrados y los datos nuevos de `my_cruces()` (cerrado y reparto por defecto). La regla de un cruce por pareja deja de contar los cruces cerrados.

Fuera de este cambio: el switch de notificaciones (CP9), "Recordarme saldar" (CP10) y borrar la cuenta (decisión abierta).

## Capabilities

### New Capabilities
- `desvincular`: cerrar un cruce, qué se puede hacer con un cruce cerrado y cómo volver a vincularse.
- `exportar-historial`: el archivo CSV con los movimientos de un cruce y cómo se comparte.
- `perfil`: cambiar el nombre propio y que el otro lo vea.
- `reparto-por-defecto`: el reparto de cada cruce que usa "Nuevo movimiento" al empezar.

### Modified Capabilities
- `saldar-cuentas`: saldar también acepta un pago parcial, que no deja el saldo en $0.
- `movimientos`: el historial permite eliminar deslizando una fila, con confirmación.

## Impact

- **Supabase:** una migración nueva (`ledgers.closed_at`, `close_cruce`, trigger en `movements`, `my_cruces()` con dos columnas más, `enforce_one_cruce_per_pair` y `check_invite` sin cruces cerrados) y pruebas pgTAP nuevas. Hay que subirla a testing con `scripts/db-push.sh testing`.
- **CruceCore:** `CruceLink` (cerrado y reparto), `AccountDirectory` (cambiar nombre, cerrar cruce y guardar el reparto), `SessionStore`, `LedgerStore.settle(amount:)`, `BalanceCalculator.settlement` y un generador de CSV nuevo, con sus pruebas.
- **App:** `SettleView`, `SettleSuccessView`, `SettingsView`, `HistoryView`, `HomeView`, `CruceListView`, `MovementDetailView`, `AddMovementView` y dos pantallas nuevas (perfil y reparto por defecto), cada una con su `#Preview` y su entrada `-screen`.
- **Sin dependencias nuevas.**
