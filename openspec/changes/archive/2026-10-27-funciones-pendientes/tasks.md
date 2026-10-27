## 1. Base de datos

- [x] 1.1 Migración nueva `funciones_pendientes.sql`: `ledgers.closed_at` y `closed_by`, `close_cruce(p_ledger)`, trigger que rechaza movimientos en cruces cerrados (`hint = 'cruceClosed'`), `enforce_one_cruce_per_pair` y `check_invite` solo con cruces abiertos, y `my_cruces()` con `closed_at` y `default_other_percent` (abiertos primero)
- [x] 1.2 Pruebas pgTAP `09_funciones_pendientes.sql`: cerrar (miembro, ajeno, sin sesión, idempotente), anotar, editar, eliminar y saldar en un cerrado (también sin RLS, como escriben las funciones security definer de parches), volver a vincularse tras cerrar, `my_cruces` con las dos columnas y el orden, y cambiar `display_name` y `default_other_percent`
- [x] 1.3 `supabase db reset` y `supabase test db` en verde

## 2. Lógica en CruceCore

- [x] 2.1 `CruceLink` con `closedAt` y `defaultOtherPercent` (opcionales al decodificar), `CruceRemote` lee las columnas nuevas; pruebas de decodificación, también de un `sesion.json` viejo
- [x] 2.2 `AccountDirectory`: `updateDisplayName`, `setDefaultOtherPercent` y `closeCruce`, en el protocolo y en `InMemoryAccountDirectory`
- [x] 2.3 `SessionStore`: `updateName` (recorta, 1 a 40), `setDefaultSplit`, `closeOpenCruce`, `isOpenCruceClosed` y el cruce por defecto (abierto más reciente); pruebas de cada uno
- [x] 2.4 `BalanceCalculator.settlement(amount:)` y `LedgerStore.settle(paymentMethod:amount:)`; `save`, `delete` y `settle` no hacen nada en un cruce cerrado; pruebas (parcial, total, fuera de rango, cruce cerrado)
- [x] 2.5 `HistoryCSV.make` y `fileName`; pruebas con los escenarios del spec (cena a medias, pago por Nequi, comillas, eliminados, vacío, nombre con tilde)

## 3. App

- [x] 3.1 `SupabaseAccountDirectory`: las tres funciones nuevas contra la base
- [x] 3.2 Saldar: "Cambiar monto" con `AmountKeypad` en una hoja, tarjeta, botón y "después" con el monto elegido; `SettleSuccessView` con "Pago anotado" y lo que falta
- [x] 3.3 Ajustes: perfil (`ProfileView`), reparto por defecto (`DefaultSplitView`), exportar con `ShareLink` (URL de un archivo ya escrito), desvincular con confirmación y saldo pendiente; ocultar lo que no aplica en un cruce cerrado
- [x] 3.4 `AddMovementView` arranca con el reparto por defecto del cruce
- [x] 3.5 Cruce cerrado: aviso en el inicio sin "Anotar" ni "Saldar", detalle sin editar ni eliminar, "Cerrado" en `CruceRow` y raíz de `MainView` según la regla nueva
- [x] 3.6 Historial con `List` y `swipeActions` → `DeleteConfirmation`; comparar con la captura 07
- [x] 3.7 `#Preview` y entradas `-screen` para las pantallas nuevas (perfil, reparto, saldar con monto, pago anotado, cruce cerrado); filas en la tabla de `CLAUDE.md` §5

## 4. Verificación y cierre

- [x] 4.1 `swift test`, `swift format lint --strict`, `xcodebuild … build`, `supabase test db` en verde
- [x] 4.2 En local, simulador y API: pago parcial, exportar (el archivo abre en Archivos), cambiar nombre (Jesús lo ve), reparto 70 % en "Nuevo movimiento", deslizar para eliminar, desvincular (los dos ven el cruce cerrado y vuelven a vincularse con un código nuevo)
- [x] 4.3 Subir la migración a testing (Joan corre `scripts/backup-db.sh testing` y `scripts/db-push.sh testing`)
- [x] 4.4 Marcar el CP11 en `ROADMAP.md` (y la decisión del pago parcial), actualizar `CLAUDE.md` §2, §5, §6 y §8, archivar y proponer el commit
