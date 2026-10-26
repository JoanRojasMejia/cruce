# Proposal

## Why

Cruce hoy cruza cuentas entre dos personas que comparten un cruce permanente. En un viaje o una salida con amigos el problema es otro: son varias personas, el grupo existe solo mientras dura el plan, una persona paga la cuenta del almuerzo y cada quien consumió algo distinto, y algunas personas (un tío, un abuelo) no van a instalar la app. Hoy esas cuentas se llevan a mano o en otra app. Los **parches** resuelven eso sin cambiar el cruce de dos.

## What Changes

- **Parche**: grupo de varias personas con nombre, que pasa por *abierto* (se anotan gastos y pagos) → *cerrado* (solo pagos) y queda *a paz y salvo* cuando nadie le debe a nadie. Un parche cerrado no se reabre. Lo puede cerrar cualquiera del parche que tenga la app.
- **Participantes con y sin la app**: quien tiene la app entra con el código del parche (`PCH-XXXXXX`); a quien no la tiene se le agrega por nombre ("Carlos (sin la app)"). Cada persona sin la app tiene un código personal (`SOY-XXXXXX`) que aparece en su ticket: si después instala la app, entra con ese código y se queda con su lugar y su historial.
- **Cualquiera con la app anota** gastos y pagos, también por quien no la tiene. Cada gasto muestra quién lo anotó; editar y borrar (borrado suave) queda registrado y avisado.
- **Repartos**: en partes iguales entre todos o entre algunos; **por consumo** (cada ítem de la cuenta con su monto y quiénes lo consumieron, para cuentas mixtas como una entrada compartida más los platos de cada uno); por partes; por porcentaje. **Propina opcional** que se reparte según lo consumido. Varios pagadores por gasto. Todo en pesos enteros con un redondeo fijo y probado.
- **Pagos**: un pago anotado por quien lo recibió cuenta de una vez; anotado por otra persona queda *pendiente* hasta que quien lo recibió lo confirme (si quien lo recibió no tiene la app, cuenta de una vez).
- **Saldar**: la app calcula el **mínimo de transferencias** ("Ana le paga $45.000 a Jesús").
- **Pasar al cruce**: al cerrar el parche, si dos de sus personas comparten un cruce, la app pregunta si lo que se deben entre ellas pasa a su cruce como un movimiento. Esa deuda se calcula directamente entre los dos, antes de simplificar las del grupo.
- **Sin conexión**: los gastos y pagos se anotan sin señal y se envían al volver la conexión; la app avisa si un gasto parece duplicado (mismo monto y mismo pagador en las últimas 3 horas).
- **Tickets**: imágenes generadas en el teléfono (`ImageRenderer` + `ShareLink`) con la personalidad de la app: el **personal** (cuánto debe, a quién, el detalle y su código `SOY-`) y el **del parche** (total y transferencias). Ambos con la fecha y hora del corte y el sello *Pendiente* o *A paz y salvo*.
- **Avisos dentro de la app**: actividad del parche ("Ana editó un gasto que anotaste", "Carlos ahora tiene la app") con un contador de no vistos. Sin notificaciones push.
- **Documentación**: `CLAUDE.md`, `docs/ROADMAP.md` (sección Parches) e `ios/README.md`.

No es parte de este cambio: otras monedas, cruces permanentes de más de dos, notificaciones push, página web, tiempo real (los datos se recargan al abrir y al deslizar hacia abajo) y conectar el cruce de dos a Supabase (CP5): el movimiento que pasa al cruce se guarda en la base, pero la app lo mostrará en el cruce cuando exista el CP5.

## Capabilities

### New Capabilities
- `parches`: crear, unirse con código, participantes con y sin la app, quedarse con el lugar, estados, cerrar, avisos y sin conexión.
- `reparto-parche`: tipos de reparto, propina proporcional, varios pagadores y redondeo.
- `saldar-parche`: saldos, pagos con confirmación, mínimo de transferencias y pasar al cruce.
- `ticket-parche`: ticket personal y del parche como imagen para compartir.

### Modified Capabilities
<!-- Ninguna: el cruce de dos no cambia. -->

## Impact

- **CruceCore**: modelos y cálculo de parches (`Parche`, `ParcheParticipant`, `ParcheExpense`, `ParchePayment`, `ParcheCalculator`, `Allocation`), repositorio y `ParcheStore`, con pruebas de Swift Testing.
- **Base de datos**: una migración nueva con tablas, RLS solo para `authenticated`, funciones (`create_parche`, `join_parche`, `claim_parche_place`, `close_parche`, `confirm_parche_payment`, `move_parche_debt_to_cruce`, `mark_parche_seen`) y pruebas pgTAP. Se aplica en la nube con dry-run antes.
- **App**: pantallas de parches, tickets, entrada "Tengo un código" para quien no tiene cruce, `SupabaseParcheRepository` con cola sin conexión y entradas nuevas en `DebugScreen`.
- **Depende de** `inicio-sesion-correo` (sesión real).
- **Riesgo**: tamaño del cambio; reglas de redondeo y de la deuda que pasa al cruce; no hay diseño de Joan para estas pantallas (se usan los componentes existentes).
