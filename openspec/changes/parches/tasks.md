# Tasks

Cada tarea con commit termina en uno solo (Conventional Commits, descripción en español) directo en `main`. Antes de cada commit, en verde (§7 de `CLAUDE.md`): `cd ios/Packages/CruceCore && swift test`, `swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore` y, si el commit toca la app, `cd ios && xcodegen && xcodebuild … build` con `BUILD SUCCEEDED`; si toca `supabase/`, `supabase test db` en verde. Las tareas RED no tienen commit propio. Modos de `CLAUDE.local.md`: la sección 1 es "Lógica pura", la 2 "Base de datos", la 3 "UI / simulador" y la 4.4 "Integración". Al terminar cada sesión: `xcrun simctl shutdown all` y `supabase stop && colima stop` si se prendieron.

Depende de `inicio-sesion-correo` (sesión real) para la sección 4.

## 1. Lógica en CruceCore

- [ ] 1.1 RED + GREEN: `Allocation.split(total:weights:)` con mayor residuo (siempre suma el total, empates por orden, pesos en cero dan error) y los cuatro repartos (iguales, por consumo con ítems, por partes, por porcentaje) más la propina proporcional, con los escenarios de `reparto-parche`. Commit: `feat(ios): agregar el reparto de gastos de parches`
- [ ] 1.2 RED + GREEN: modelos `Parche`, `ParcheParticipant`, `ParcheExpense` (pagadores, partes resueltas, ítems, borrado suave), `ParchePayment` (pendiente/confirmado), `ParcheCruceTransfer`; `ParcheCalculator` con saldos, a paz y salvo, mínimo de transferencias, deuda directa entre dos y los escenarios de `saldar-parche`. Commit: `feat(ios): calcular saldos y transferencias de parches`
- [ ] 1.3 RED + GREEN: `ParcheRepository`, `InMemoryParcheRepository`, `ParcheStore` (crear, unirse, agregar sin la app, reclamar lugar, anotar/editar/borrar gasto, anotar/confirmar pago, cerrar, pasar al cruce, aviso de duplicado, cola sin conexión con reintento idempotente, avisos sin ver) y datos de ejemplo `MockParches`. Commit: `feat(ios): agregar ParcheStore con cola sin conexión`

## 2. Base de datos

- [ ] 2.1 RED: `supabase/tests/06_parches.sql` (pgTAP): crear y unirse con código, agregar sin la app, reclamar lugar (y no si ya está), RLS (fuera del parche no ve nada; `anon` nada), gastos solo con el parche abierto, pagos y confirmación, cerrar sin reabrir, validación de sumas, pasar la deuda al cruce (movimiento en `movements`, una sola vez, solo si comparten cruce), actividad. Sin commit propio
- [ ] 2.2 GREEN: migración nueva `supabase/migrations/<timestamp>_parches.sql` con tablas, tipos, triggers de validación y actividad, RLS y funciones de `design.md` §8. `supabase test db` en verde (74 + las nuevas). Commit: `feat(supabase): agregar parches`

## 3. Pantallas y tickets

- [ ] 3.1 Rutas y pantallas: "Tus parches" en el inicio, nuevo parche, detalle (saldos, gastos, pagos, actividad con contador), anotar gasto (pagadores, monto, concepto, reparto, propina, aviso de duplicado), anotar y confirmar pago, cerrar (con la pregunta del cruce) y "Tengo un código" (`CRZ-`/`PCH-`/`SOY-`) también desde invitar; `ParcheStore` en `AppStores` y `DebugScreen` con las pantallas nuevas. Commit: `feat(ios): agregar las pantallas de parches`
- [ ] 3.2 Tickets personal y del parche como vistas, `ImageRenderer` y `ShareLink`, con fecha del corte, sello y código `SOY-`. Commit: `feat(ios): compartir tickets de parches`
- [ ] 3.3 Verificación visual en el simulador de las pantallas nuevas con `-screen` y capturas en el scratchpad (no en el repo). Sin commit

## 4. Conexión real

- [ ] 4.1 `SupabaseParcheRepository` (consultas, `upsert` por `id`, llamadas a las funciones) conectado en `AppStores.live()`, con la cola sin conexión persistida en disco. Commit: `feat(ios): conectar parches con Supabase`
- [ ] 4.2 `swift test`, `swift format lint` y `xcodebuild … build` en Debug y Release en verde. Sin commit
- [ ] 4.3 Aplicar la migración en la nube: `supabase db push --linked --dry-run` (solo la migración de parches) y `supabase db push --linked`; comprobar las tablas y políticas con un volcado del esquema. Sin commit
- [ ] 4.4 En local (Integración): dos cuentas (correo y código desde mailpit) crean y se unen a un parche, agregan a alguien sin la app, anotan con varios repartos, un pago pendiente se confirma, se reclama un lugar con `SOY-`, se cierra y se genera un ticket. Sin commit

## 5. Documentación

- [ ] 5.1 `CLAUDE.md` (§1 Parches ya no es futura, §2 estado, §3 estructura, §6 piezas), `docs/ROADMAP.md` (sección Parches) e `ios/README.md`. Commit: `docs: documentar parches`
