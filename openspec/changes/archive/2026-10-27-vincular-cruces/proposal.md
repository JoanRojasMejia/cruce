# Proposal

## Why

El CP4 conecta la vinculación con Supabase. Hoy invitar y unirse son de mentira:
- `InviteView` muestra "CRZ-····";
- "Esperando a tu amigo…" es un botón que salta a "Conectados";
- `JoinView` acepta cualquier código;
- la app no lee de la base ni el nombre de la otra persona ni los colores.

Además, el 27 oct 2026 se decidió que una persona puede tener **varios cruces, uno por pareja**. La base ya permite estar en varios cruces, pero no impide dos cruces entre las mismas dos personas. Y `create_ledger_with_invite()` crea un cruce nuevo cada vez que se llama, así que abrir la pantalla de invitar dejaría cruces vacíos.

## What Changes

- **Base de datos (migración nueva; `init.sql` no se toca):**
  - **Un cruce por pareja:** dos personas no pueden tener dos cruces entre ellas. Unirse con el código de alguien con quien ya tienes cruce se rechaza con un mensaje claro.
  - **Un solo cruce pendiente por persona:** pedir el código de invitación devuelve el código vigente del cruce pendiente. Si venció, se genera uno nuevo para ese mismo cruce, en vez de crear otro.
  - **Ver de quién es un código antes de unirse:** devuelve el nombre de quien invita. Los fallos cuentan para el límite de 5 intentos por hora.
  - **Unirse devuelve el nombre de quien invitó.**
  - **Lista de los cruces completos de quien entró:** con quién es cada uno, y los colores y el recibo de cada lado.
- **App:**
  - `InviteView` muestra el código real. Mientras está abierta, revisa cada pocos segundos si la otra persona ya se unió y pasa sola a "Conectados".
  - `JoinView` valida los 4 dígitos con la base. Muestra "CÓDIGO VÁLIDO · Cuenta de Joan" o el error en español; al unirse pasa a "Conectados".
  - "Conectados" y el inicio muestran el nombre real de la otra persona. Tus colores y tu recibo salen de la base: quien se une ve el recibo verde.
  - **La etapa de entrada solo llega al inicio con un cruce completo, de dos personas.** Un cruce pendiente, que solo tiene a quien invitó, sigue en "Invitar".
  - "Tengo un código" con un `CRZ-` antes de tener cruce lleva a `JoinView` con el código ya escrito.
- **Fuera de alcance (CP4b):**
  - la lista "Tus cruces";
  - invitar a otra persona cuando ya se tiene un cruce;
  - que movimientos, saldar y Ajustes trabajen sobre el cruce elegido.
  
  En el CP4, la app usa como `partner` el cruce más reciente.
- **Fuera de alcance también:**
  - tiempo real con Supabase Realtime (CP6): por ahora se consulta cada pocos segundos;
  - movimientos contra Supabase (CP5).

## Capabilities

### New Capabilities
<!-- Ninguna: todo cae en capacidades existentes. -->

### Modified Capabilities
- `vinculacion`:
  - un cruce por pareja;
  - un solo cruce pendiente por persona;
  - ver de quién es un código;
  - unirse devuelve el nombre;
  - quien invita se entera de la unión;
  - el límite de intentos también cuenta la vista previa.
- `inicio-sesion`: la etapa de entrada pide un cruce completo para ir al inicio, y la app usa los colores y el recibo guardados.

## Impact

- **Supabase:**
  - `supabase/migrations/<nueva>_vincular_cruces.sql`: trigger de pareja, `create_ledger_with_invite()` y `redeem_invite()` redefinidas, y `preview_invite()` y `my_cruces()` nuevas;
  - pgTAP nuevo (`07_vincular_cruces.sql`) y ajustes en `03_vinculacion.sql` si cambia algún resultado.
  
  Se aplica en testing con `scripts/db-push.sh testing`.
- **CruceCore:**
  - `AccountDirectory`: `hasLedger` pasa a la lista de cruces, y se agregan crear código, vista previa y unirse;
  - `InMemoryAccountDirectory` con cruces de verdad;
  - `SessionStore`: cruces, código, vista previa, unirse y revisar si ya se unió;
  - pruebas.
- **App:**
  - `SupabaseAccountDirectory`;
  - `AuthViews.swift` (`InviteView`, `JoinView` y `ConnectedView`);
  - `EnterCodeView`;
  - `AppStores.live()`, sin colores fijos.
- **Documentación:** CLAUDE.md §2 y §6, `supabase/README.md` y ROADMAP.
- **Sin dependencias nuevas.**
