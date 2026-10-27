# Design

## Context

- **Ajustes** (`SettingsView`) tiene cuatro acciones vacías: la tarjeta del perfil, "Reparto por defecto", "Exportar historial (CSV)" y "Desvincular". **Saldar** (`SettleView`) tiene "Cambiar monto" vacío.
- **El historial** (`HistoryView`) es un `ScrollView` con `ForEach`, no un `List`, así que `swipeActions` no funciona tal cual.
- **La base:**
  - ya deja editar `profiles.display_name` (política "editar mi perfil") y `ledgers.default_other_percent` (`grant update`);
  - no tiene forma de cerrar un cruce;
  - `my_cruces()` no devuelve ni el reparto ni si está cerrado;
  - la regla de un cruce por pareja vive en dos lugares: el trigger `enforce_one_cruce_per_pair` y `check_invite` (que da "Ya tienes un cruce con …").
- **La sesión** (`SessionStore`) pasa a `.main` con cualquier cruce completo. `MainView` muestra `HomeView` con un cruce y `CruceListView` con dos o más.
- **Saldar** usa `BalanceCalculator.settlement`, que siempre paga el total.

## Goals / Non-Goals

**Goals**
- Ningún botón vacío en Saldar ni en Ajustes, salvo los del CP9 (switch de notificaciones) y el CP10 (recordatorio).
- Un cruce cerrado lo garantiza la base, no solo la app.
- La lógica nueva (CSV, pago parcial, cierre y reparto en la sesión) se prueba con `swift test`; la de la base, con pgTAP.

**Non-Goals**
- Borrar la cuenta: sigue como decisión abierta.
- Reabrir un cruce cerrado: para volver se usa un código nuevo.
- Pagos parciales en parches: ya tienen sus propios pagos.

## Decisions

### 1. Cerrar el cruce: `ledgers.closed_at` y `close_cruce(p_ledger)`
- **La migración** agrega `closed_at timestamptz` y `closed_by uuid` a `ledgers`.
- **`close_cruce(p_ledger uuid)`** es `security definer`:
  - exige sesión y que quien llama sea del cruce, y que el cruce esté completo;
  - si ya estaba cerrado, no hace nada (idempotente).
- **Alternativa descartada:** abrir un `grant update (closed_at)`. Dejaría poner cualquier fecha o reabrir el cruce.

### 2. El bloqueo de movimientos va en un trigger
- **El trigger:** `before insert or update` en `movements`. Si el cruce tiene `closed_at`, lanza un error con `hint = 'cruceClosed'`.
- **Por qué un trigger:** cubre la app, la cola sin conexión, otros teléfonos y las funciones `security definer` de parches que pasan deudas al cruce ("pasar a tu cruce").
- **Alternativa descartada:** cambiar las políticas RLS. No alcanzan a las funciones `security definer`.
- **En la app:** la cola sin conexión ya saca lo que la base rechaza, así que un gasto anotado offline en un cruce que se cerró desaparece al sincronizar.

### 3. La regla de un cruce por pareja ignora los cerrados
- `enforce_one_cruce_per_pair` y `check_invite` se redefinen (`create or replace`) para contar solo cruces con `closed_at is null`.
- **Por qué funciona:** el código nuevo crea un cruce nuevo, porque `create_ledger_with_invite` solo reusa cruces pendientes de una persona y nunca uno que tuvo a dos.

### 4. `my_cruces()` devuelve `closed_at` y `default_other_percent`
- **Cómo:** cambia la forma del resultado, así que la migración hace `drop function` y la crea de nuevo, con los mismos permisos.
- **Orden:** primero los abiertos y después los cerrados, cada grupo del más reciente al más viejo.
- **En la app:** `CruceLink` gana `closedAt: Date?` (`isClosed`) y `defaultOtherPercent: Int`. Los dos son opcionales al decodificar, para que una sesión guardada en el teléfono (`sesion.json`) de antes siga abriendo.

### 5. La sesión y el inicio con cruces cerrados
- **El cruce que se abre por defecto:** el abierto más reciente; si no hay abiertos, el más reciente.
- **La raíz de `MainView`:** `HomeView` solo con un único cruce abierto; si no, `CruceListView`, que ya tiene "Invitar a alguien" y "Tengo un código".
- **La lista:** `CruceRow` muestra "Cerrado" para los cerrados.
- **`SessionStore.closeOpenCruce()`:**
  - llama a `AccountDirectory.closeCruce`, recarga los cruces y vuelve a la raíz;
  - la vista hace `router.popToRoot()`, como "Cerrar sesión".
- **`SessionStore.isOpenCruceClosed`:** lo leen las vistas para esconder acciones.
- **Las acciones que se esconden en un cruce cerrado:**
  - en el inicio, "Anotar" y "Saldar", con un aviso "Cruce cerrado el …";
  - en el detalle, editar y eliminar;
  - en el historial, deslizar;
  - en Ajustes, "Desvincular" y "Reparto por defecto".
- **`LedgerStore`:** `save`, `delete` y `settle` no hacen nada en un cruce cerrado, como segunda barrera.

### 6. Pago parcial en `BalanceCalculator.settlement(amount:)`
- **El parámetro:** `amount: Int? = nil`. `nil` paga el total; un valor entre 1 y `abs(net)` paga eso; fuera de rango devuelve `nil`.
- **Quién paga** se decide igual que hoy, por el signo del saldo.
- **`LedgerStore.settle(paymentMethod:amount:)`** lo pasa tal cual.
- **En `SettleView`:**
  - "Cambiar monto" abre una hoja con `AmountKeypad`, que ya existe en "Nuevo movimiento";
  - el monto elegido vive en `@State`;
  - el "después" de `BeforeAfter` usa `ledger.phrase(forNet:)` con el saldo que quedaría.
- **En `SettleSuccessView`:** si el saldo después del pago no es $0, dice "Pago anotado" y "Todavía te debe …" o "Todavía le debes …".
- **"Movimientos desde el último pago":** un pago parcial también es tipo pago, así que cuenta como último pago. Es lo que pasa en la vida real.

### 7. CSV en CruceCore (`HistoryCSV`)
- **Qué es:** una función pura `HistoryCSV.make(movements:me:partner:)` que devuelve un `String`, más `HistoryCSV.fileName(partner:date:)`.
- **Formato:**
  - RFC 4180: comas, `\r\n` y comillas solo cuando hacen falta;
  - la fecha en el calendario gregoriano y la zona horaria del teléfono;
  - la marca de orden de bytes UTF-8 se agrega al escribir el archivo.
- **En la vista:** Ajustes escribe el archivo en `tmp/Exportar/` (solo queda el último) con `.task(id:)` cuando cambian los movimientos o los nombres, y la fila es un `ShareLink` con su URL. Así no hace falta UIKit.
- **Alternativa descartada (probada en el simulador):** `ShareLink` con un `Transferable` (`FileRepresentation`). "Guardar en Archivos" fallaba con "no estás autorizado a verlo" y, con `allowAccessingOriginalFile`, no recibía nada.

### 8. Perfil y reparto en `AccountDirectory`
- **`updateDisplayName(_:for:)`:** `update profiles set display_name`. `SessionStore.updateName(_:)` valida (recorta, 1 a 40), guarda y actualiza `me`.
- **`setDefaultOtherPercent(_:in:)`:** `update ledgers set default_other_percent`. `SessionStore.setDefaultSplit(_:)` lo guarda y actualiza el `CruceLink` abierto.
- **Los dobles en memoria** implementan las dos funciones, para las pruebas.
- **`AddMovementView`:** sin `editing`, arranca con `session.openCruce?.defaultOtherPercent` en vez de 50, con el mismo mapeo de `SplitMode`.

### 9. Deslizar en el historial
- **Cómo:** el historial pasa a `List` con `.listStyle(.plain)`, filas sin separador, fondo transparente y los mismos márgenes, y `swipeActions(edge: .trailing)` con "Eliminar".
- **La confirmación:** abre la misma `DeleteConfirmation` del detalle, en una hoja.
- **Alternativa descartada:** un gesto de arrastre propio sobre el `ScrollView`. Pelea con el scroll vertical y con VoiceOver; `swipeActions` ya trae la acción para VoiceOver.

## Risks / Trade-offs

- **[Riesgo] `List` cambia el aspecto del historial.** Mitigación: comparar con `docs/design/screens/07-*.png` en el simulador; si no se logra igual, se vuelve al `ScrollView` y la acción va con un menú contextual (se le pregunta a Joan).
- **[Riesgo] Cerrar el cruce mientras el otro tiene gastos en la cola sin conexión.** Esos gastos se pierden al sincronizar. Es lo esperado (el cruce se cerró); no hay aviso en este cambio.
- **[Riesgo] `drop function my_cruces()`** deja la función un instante sin existir durante la migración. La migración corre en una transacción, así que no se nota.
- **[Trade-off] El nombre que ve el otro** se actualiza cuando recarga sus cruces (al abrir la app o al volver), no en tiempo real.

## Migration Plan

1. **Migración nueva** `supabase/migrations/<fecha>_funciones_pendientes.sql`; no se edita ninguna aplicada.
2. **En local:** `supabase db reset` y `supabase test db`.
3. **En testing:** `scripts/backup-db.sh testing` y luego `scripts/db-push.sh testing`. Los corre Joan, porque piden la contraseña de la base.
4. **Volver atrás:** una migración nueva que quite el trigger y las columnas. Los cruces cerrados quedarían abiertos otra vez.
