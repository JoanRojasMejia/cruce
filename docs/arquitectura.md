# Arquitectura

```
 iPhone de Joan ─┐                        ┌─ Database Webhook ──► Backend Go ──► APNs (push)
                 ├──► Supabase ───────────┤
 iPhone de Jesús ┘   (Auth · Postgres ·   └─ Tiempo real ──► los dos iPhones
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

## Próximos pasos (punto 2)

1. Crear el proyecto en Supabase, aplicar la migración y activar Sign in with Apple.
2. Agregar `supabase-swift` a la app y crear `SupabaseLedgerRepository` con la misma interfaz que `InMemoryLedgerRepository`.
3. Cola local para movimientos pendientes cuando no hay conexión.
4. Desplegar el backend y conectar el Database Webhook.
5. Notificaciones push con APNs (requiere la membresía de Apple Developer).
