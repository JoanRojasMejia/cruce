# Arquitectura

```
 Un iPhone ─────┐                        ┌─ Database Webhook ──► Backend Go ──► APNs (push)
                 ├──► Supabase ───────────┤
 Otro iPhone ───┘   (Auth · Postgres ·   └─ Tiempo real ──► los dos iPhones
                      RLS · Realtime)
```

## Decisiones

1. **La app habla directo con Supabase.** Para dos usuarios, Supabase ya da inicio de sesión con Apple, base de datos con permisos por fila y tiempo real. Poner un servidor en medio obligaría a reenviar el tiempo real a mano y complicaría el modo sin conexión.
2. **La lógica sensible vive en Postgres.** El saldo es una vista (`ledger_balances`); crear y canjear invitaciones son funciones (`create_ledger_with_invite`, `redeem_invite`). Así las reglas valen igual desde la app o desde cualquier otro cliente.
3. **Go va al lado, no en medio.** Se encarga de lo asíncrono: notificaciones push cuando el otro anota algo, recordatorio mensual para saldar y limpieza de invitaciones. Si luego hace falta más lógica en servidor, ya hay dónde ponerla.
4. **Dinero en enteros.** Pesos como `Int`/`bigint`. El redondeo de repartos es al peso más cercano (.5 hacia arriba), igual en Swift (`Money.share`) y en SQL (`owed_by_other`).
5. **El saldo nunca se guarda.** Se calcula sumando movimientos. Saldar es un movimiento más (`kind = settlement`, reparto "todo es del otro").
6. **Eliminar es borrado suave** (`deleted_at`) para poder avisarle al otro y, si hace falta, deshacer.
7. **Recibo rosa o verde** según quién usa la app: se guarda en `ledger_members.tike_variant` (rosa = quien creó la cuenta).
8. **Varios cruces, uno por pareja.** Cada `ledger` tiene exactamente dos miembros y una persona puede estar en varios; la base impide dos cruces entre las mismas dos personas. El color y el recibo son por cruce (quien crea ese cruce es amarillo y rosa), así que alguien puede ser rosa en un cruce y verde en otro. Los parches pasan la deuda directa al cruce con esa persona (`move_parche_debt_to_cruce` ya lo busca por pareja).

## Ambientes

| Ambiente | App (configuración · esquema) | Supabase |
|---|---|---|
| local | Debug · `Cruce` ("Cruce Dev") | Docker en la Mac |
| testing | Staging · `Cruce Test` ("Cruce Test") | Proyecto `pqdjiecynyjnianslikp` |
| prod | Release · `Cruce Prod` ("Cruce") | Proyecto propio, se crea antes de TestFlight |

- **Un proyecto de Supabase por ambiente.** Cuentas, RLS, plantillas de correo y datos nunca se mezclan.
- **Prod no tiene plan B:** si le faltan sus claves, la app se detiene; nunca usa las de testing.
- **Las migraciones llegan primero a testing** y después a prod, con `scripts/db-push.sh`, que en prod pide confirmación y respalda antes.
- El backend de Go tiene una app de Fly.io por ambiente (CP8), una máquina pequeña siempre prendida para no perder webhooks: `cruce-api-testing` ahora y la de prod cuando exista su proyecto. Cada una tiene su `WEBHOOK_SECRET`, y el Database Webhook de cada proyecto de Supabase apunta a la suya.

## Próximos pasos (punto 2)

1. Crear el proyecto en Supabase, aplicar la migración y activar Sign in with Apple.
2. Agregar `supabase-swift` a la app y crear `SupabaseLedgerRepository` con la misma interfaz que `InMemoryLedgerRepository`.
3. Cola local para movimientos pendientes cuando no hay conexión.
4. Desplegar el backend y conectar el Database Webhook.
5. Notificaciones push con APNs (requiere la membresía de Apple Developer).

## Cuentas borradas (30 oct 2026)

`delete_my_account()` borra el usuario de `auth.users`. El trigger `forget_account` (antes del borrado, así que también aplica si se borra desde el panel) cierra sus cruces, borra su cruce pendiente y su código, rechaza lo que estuviera por confirmar para pasar al cruce, marca sus lugares en los parches (`account_deleted_at`) y deja su perfil como **lápida**: el mismo `id`, "Cuenta borrada", sin @usuario, color ni correo y con `deleted_at`. Por eso `profiles` ya no tiene la llave foránea a `auth.users` (`profiles_id_fkey`): con `on delete cascade` el perfil se borraba y se llevaba a la persona de `ledger_members`, y los movimientos dejaban de cuadrar. Un perfil solo se crea con `id = auth.uid()` y una lápida no se puede editar.
