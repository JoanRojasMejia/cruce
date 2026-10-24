# Cruce · Supabase

Base de datos, inicio de sesión y tiempo real.

## Qué hay en la migración inicial

- **Tablas:** `profiles`, `ledgers` (la cuenta compartida), `ledger_members` (máximo 2), `movements`, `invites`.
- **Montos:** `bigint` en pesos enteros. `owed_by_other` se calcula sola: lo que quien no pagó le debe a quien pagó.
- **Saldo:** la vista `ledger_balances` suma los movimientos. `net > 0` significa que el otro le debe a ese usuario.
- **Regla de colores:** quien crea la cuenta queda con recibo `rosa` y avatar amarillo; quien se une, con `verde` y violeta.
- **Seguridad:** RLS en todas las tablas; cada persona solo ve las cuentas de las que es miembro.
- **Funciones para la app:**
  - `create_ledger_with_invite()` → crea la cuenta y devuelve un código tipo `CRZ-4821` (vence en 24 h).
  - `redeem_invite(p_code)` → une a la segunda persona.
- **Eliminar** es un borrado suave (`deleted_at`), para poder avisarle al otro.
- **Tiempo real** activado para `movements`.

## Aplicar

Con la [CLI de Supabase](https://supabase.com/docs/guides/cli) (`brew install supabase/tap/supabase`) y Docker Desktop abierto:

```bash
supabase start           # base local con Docker (la primera vez descarga varias imágenes)
supabase db reset        # aplica las migraciones en local
supabase test db         # corre las pruebas de supabase/tests

supabase link --project-ref <tu-ref>
supabase db push         # aplica en el proyecto en la nube
```

`config.toml` ya está en el repo; no hace falta `supabase init`.

## Pruebas

Son pruebas [pgTAP](https://pgtap.org) en `supabase/tests/`. Cada archivo corre en una transacción que se deshace al final, así que no dejan datos.

| Archivo | Qué prueba |
|---|---|
| `01_saldo.sql` | `owed_by_other` con cada reparto y el redondeo; el ejemplo canónico en `ledger_balances`; un borrado no cuenta |
| `02_reglas.sql` | Máximo dos personas, quien paga es miembro, saldar es "todo es del otro" |
| `03_vinculacion.sql` | `create_ledger_with_invite` y `redeem_invite`: formato, colores, vencimiento, códigos usados, propios e inexistentes |
| `04_rls.sql` | Un tercero no ve ni escribe nada ajeno; nadie anota a nombre de otro ni se agrega como miembro directamente |

Para actuar como una persona, las pruebas usan `set local role authenticated` y fijan `request.jwt.claims` con su `sub`, que es lo que lee `auth.uid()`.

## Pendiente para el punto 2

- Activar **Sign in with Apple** en Authentication → Providers.
- Configurar el Database Webhook hacia el backend de Go.
