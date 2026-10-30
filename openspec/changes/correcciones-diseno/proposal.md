## Why

La revisión de diseño de los flujos nuevos (entrar con correo, varios cruces, parches y tickets) encontró reglas de
negocio que no cuadran con lo que la gente espera (pasar al cruce, colores, cierre del parche, pagos de más) y
pantallas largas o repetidas. Este cambio aplica esas correcciones sin romper los datos que ya están en la nube.

## What Changes

- "Pasar al cruce" sale de "Para saldar", lo propone una persona y la otra lo acepta o lo rechaza.
- Desvincular ofrece "Saldar primero" cuando el saldo no es $0 (el cruce cerrado sigue sin aceptar gastos ni pagos).
- Cada persona tiene un color fijo (también quien está sin la app); el rosa o verde queda solo para el Tike.
- Varios pagadores con monto por cada uno, repartido en partes iguales por defecto; aviso de pago de más en parches.
- Solo quien creó un parche puede cerrarlo.
- Ajustes de la cuenta y Ajustes del cruce separados; detalle del parche más corto (hoja de "Los del parche" y
  actividad aparte); pantallas de llegada con `PCH-` y `SOY-`; una sola pantalla "Tengo un código" con errores
  separados y enlace `cruce://codigo/…`; cruces cerrados en su propia sección; el cruce abierto desde la lista no
  repite "Tus parches".
- Detalles: un solo aviso sin conexión con "Sin enviar"; ítems con nombre; formas de reparto con ejemplo; deshacer
  al borrar; cuenta regresiva para pedir otro código; enlace del código `SOY-` en el ticket.
- Espacios para 15 ilustraciones nuevas, con la ilustración actual mientras llegan.

El detalle, con el texto de Joan y sus decisiones, está en `brief.md`.

## Capabilities

### New Capabilities
- `colores-persona`: color fijo por persona y por quien está sin la app.
- `codigos`: una sola entrada de códigos (`CRZ-`, `PCH-`, `SOY-`), sus errores, el enlace y la llegada a un parche.

### Modified Capabilities
- `saldar-parche`: pasar al cruce desde "Para saldar" con aceptación; aviso de pago de más; quién cierra.
- `reparto-parche`: varios pagadores con monto, ítems con nombre, formas de reparto.
- `desvincular`: "Saldar primero".
- `navegacion`: Ajustes de la cuenta y del cruce, cruces cerrados aparte, detalle del parche y actividad.
- `parches`: aviso sin conexión, deshacer al borrar.
- `ticket-parche`: enlace del código `SOY-`, ilustraciones neutrales.
- `inicio-sesion`: cuenta regresiva para pedir otro código.

## Impact

- Migraciones nuevas y aditivas en `supabase/migrations/` (pasar al cruce, colores, autor del parche, códigos, ítems
  con nombre), que Joan aplica en testing y prod con `scripts/db-push.sh`.
- CruceCore (Parches, State, Data), pantallas de `ios/Cruce/Screens/`, `DesignSystem/Illustration.swift` y
  `Assets.xcassets`, `project.yml` (esquema de URL `cruce`).
- Sin dependencias nuevas.
