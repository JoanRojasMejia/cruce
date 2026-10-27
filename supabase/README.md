# Cruce · Supabase

Base de datos, inicio de sesión y tiempo real.

## Qué hay en la migración inicial

- **Tablas:** `profiles`, `ledgers` (la cuenta compartida), `ledger_members` (máximo 2 por cuenta; una persona puede estar en varias, una por pareja), `movements`, `invites` e `invite_attempts` (intentos fallidos de canje, solo para el límite).
- **Montos:** `bigint` en pesos enteros. `owed_by_other` se calcula sola: lo que quien no pagó le debe a quien pagó.
- **Saldo:** la vista `ledger_balances` suma los movimientos. `net > 0` significa que el otro le debe a ese usuario.
- **Regla de colores:** quien crea la cuenta queda con recibo `rosa` y avatar amarillo; quien se une, con `verde` y violeta.
- **Seguridad:** RLS en todas las tablas; cada persona solo ve las cuentas de las que es miembro.
- **Funciones para la app:**
  - `create_ledger_with_invite()` → crea la cuenta y devuelve un código tipo `CRZ-4821` (vence en 24 h).
  - `redeem_invite(p_code)` → une a la segunda persona. Devuelve `{"ok": true, "ledger_id": …, "inviter_name": …}` o `{"ok": false, "error": "invalid" | "own" | "too_many_attempts" | "already_linked", "message": …}`; máximo 5 intentos fallidos por hora.
  - Desde `20261027065544_vincular_cruces.sql` (CP4):
    - **Un cruce por pareja:** el trigger `ledger_members_one_cruce_per_pair` rechaza a dos personas que ya comparten un cruce ("Ya tienen un cruce entre los dos", `23505`), y las funciones lo avisan antes con `already_linked` ("Ya tienes un cruce con Joan"), sin contarlo como intento fallido.
    - `create_ledger_with_invite()` devuelve el código del **único cruce pendiente** de quien llama; si venció, genera otro para ese mismo cruce. Abrir la pantalla de invitar varias veces no crea cuentas vacías.
    - `preview_invite(p_code)` → `{"ok": true, "inviter_name": "Joan"}` o el mismo error que daría canjearlo. No une a nadie; los códigos inválidos cuentan para el límite de intentos.
    - `my_cruces()` → los cruces completos de quien llama (con quién, y colores y recibo de cada lado), del que se completó más recientemente al más viejo. Respeta RLS.
- **Eliminar** es un borrado suave (`deleted_at`), para poder avisarle al otro.
- **Tiempo real** activado para `movements`.

## Aplicar

Con la [CLI de Supabase](https://supabase.com/docs/guides/cli) (`brew install supabase/tap/supabase`) y Docker Desktop abierto:

```bash
supabase start           # base local con Docker (la primera vez descarga varias imágenes)
supabase db reset        # aplica las migraciones en local
supabase test db         # corre las pruebas de supabase/tests
```

`config.toml` ya está en el repo; no hace falta `supabase init`.

## Ambientes

| Ambiente | Dónde | Identificador del proyecto |
|---|---|---|
| local | Docker (`supabase start`) | — |
| testing | Nube, Oregon | `pqdjiecynyjnianslikp` |
| prod | Nube | todavía no existe |

- Los identificadores de los proyectos están en `supabase/ambientes.env` (versionado: no son secretos). Los scripts los leen con `scripts/lib/ambiente.sh`.
- Los scripts vinculan el proyecto del ambiente que nombras en cada corrida. **No uses `supabase link` y `supabase db push` a mano**: el vínculo guardado en `supabase/.temp` no dice a qué ambiente apunta.
- Las migraciones llegan siempre primero a testing y después a prod.

```bash
scripts/db-push.sh testing      # muestra las migraciones pendientes y las aplica en testing
scripts/db-push.sh prod         # pide escribir "prod", respalda prod y después aplica
scripts/backup-db.sh testing    # respaldo en backups/<fecha>_<hora>_testing/
scripts/backup-db.sh --local    # respaldo de la base local
```

Cada proyecto tiene su propia contraseña de la base: la pide el CLI, o la lee de `SUPABASE_DB_PASSWORD`. Antes, una sola vez, `supabase login`.

**Proyectos pausados:** en el plan gratis, Supabase pausa un proyecto tras una semana sin uso. Si testing no responde, reactívalo desde el panel (Project → Restore). Tarda unos minutos.

**Correo con el código:** El plan gratis de Supabase no deja editar la plantilla con su correo por defecto (que además trae un enlace, no el código), así que cada proyecto necesita SMTP propio.

1. **SMTP propio** (Authentication → Emails → SMTP Settings → Enable custom SMTP). Testing usa una cuenta de Gmail solo para Cruce con una contraseña de aplicación: host `smtp.gmail.com`, puerto `587`, usuario y remitente = la dirección completa, nombre `Cruce`. La contraseña la escribe el dueño en el panel; nunca va en el repo. Gmail permite unos 500 correos al día; con SMTP propio el límite de Supabase sube a 30 por hora y ya no está restringido a miembros de la organización.
2. **Plantilla:** pega `supabase/templates/codigo.html` en "Magic link or OTP" y en "Confirm signup" (pestaña Source), con el asunto `Tu código para entrar a Cruce`. Para copiarla sin dañar las tildes: `LANG=en_US.UTF-8 pbcopy < supabase/templates/codigo.html` (en Nushell: `with-env {LANG: "en_US.UTF-8"} { open --raw supabase/templates/codigo.html | pbcopy }`). El preview del panel muestra `{{ .Token }}` sin reemplazar; es normal.
3. **Email OTP Length** en `6` (Authentication → Sign In / Providers → Email).

### Crear prod (antes de la primera versión en TestFlight)

1. En el panel de Supabase, crea el proyecto `cruce-prod` en la misma organización y región que testing, y guarda la contraseña de la base en tu gestor de contraseñas.
2. Llena `PROD_PROJECT_REF` en `supabase/ambientes.env` con su identificador y súbelo en un commit.
3. `scripts/db-push.sh prod` para aplicar las migraciones (el primer respaldo sale vacío de datos).
4. Configura el SMTP propio y la plantilla del correo (ver arriba). Para prod conviene un proveedor transaccional (por ejemplo Resend) con un dominio propio verificado, en vez de Gmail.
5. En `ios/Config.xcconfig`, llena `SUPABASE_URL[config=Release]` con `https:/$()/<ref>.supabase.co` y `SUPABASE_ANON_KEY[config=Release]` con la clave anon de `supabase projects api-keys --project-ref <ref>`.
6. Compila el esquema `Cruce Prod` y entra con tu correo.

## Pruebas

Son pruebas [pgTAP](https://pgtap.org) en `supabase/tests/`. Cada archivo corre en una transacción que se deshace al final, así que no dejan datos.

| Archivo | Qué prueba |
|---|---|
| `01_saldo.sql` | `owed_by_other` con cada reparto y el redondeo; el ejemplo canónico en `ledger_balances`; un borrado no cuenta |
| `02_reglas.sql` | Máximo dos personas, quien paga es miembro, saldar es "todo es del otro" |
| `03_vinculacion.sql` | `create_ledger_with_invite` y `redeem_invite`: formato, colores, vencimiento, códigos usados, propios e inexistentes, límite de 5 intentos fallidos por hora |
| `04_rls.sql` | Un tercero no ve ni escribe nada ajeno; nadie anota a nombre de otro ni se agrega como miembro directamente |
| `05_rls_endurecido.sql` | Las políticas son solo para `authenticated`, usan `(select auth.uid())` y tienen sus índices; sin sesión no se ve nada |
| `06_parches.sql` | Parches: crear, unirse, sin la app, repartos, pagos, reclamar lugar, cerrar, pasar al cruce y RLS |
| `07_vincular_cruces.sql` | Un solo cruce pendiente por persona, vista previa del código, el nombre al unirse, un cruce por pareja (también directo en la tabla), cruces con personas distintas, `my_cruces` (también con RLS) y el límite de intentos con la vista previa |

Para actuar como una persona, las pruebas usan `set local role authenticated` y fijan `request.jwt.claims` con su `sub`, que es lo que lee `auth.uid()`.

## Pendiente para el punto 2

- Activar **Sign in with Apple** en Authentication → Providers.
- Configurar el Database Webhook hacia el backend de Go.
