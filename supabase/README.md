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

Con la [CLI de Supabase](https://supabase.com/docs/guides/cli):

```bash
supabase init            # solo la primera vez; crea config.toml
supabase start           # base local con Docker
supabase db reset        # aplica las migraciones en local

supabase link --project-ref <tu-ref>
supabase db push         # aplica en el proyecto en la nube
```

## Pendiente para el punto 2

- Activar **Sign in with Apple** en Authentication → Providers.
- Configurar el Database Webhook hacia el backend de Go.
