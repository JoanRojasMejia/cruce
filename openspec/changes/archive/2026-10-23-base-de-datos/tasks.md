# Tasks

## 1. Supabase en local

- [x] 1.1 Instalar la CLI de Supabase y correr `supabase init` (verificado: existe `supabase/config.toml`)
- [x] 1.2 `supabase start` levanta Postgres, Auth y Realtime en Docker (verificado: `supabase status` muestra los servicios)
- [x] 1.3 `supabase db reset` aplica la migración sin errores (verificado: salida sin errores y tablas creadas)

## 2. Pruebas SQL (pgTAP, `supabase test db`)

- [x] 2.1 `owed_by_other` con 50/50, porcentaje y "todo es del otro", incluido el redondeo de impares (verificado: pruebas en verde)
- [x] 2.2 `ledger_balances` con el ejemplo canónico: −20.000 para Joan y +20.000 para Jesús; un movimiento borrado no cuenta (verificado: pruebas en verde)
- [x] 2.3 Máximo dos miembros por cuenta y que quien paga sea miembro (verificado: pruebas en verde)
- [x] 2.4 RLS: un tercero no ve cuentas, miembros, movimientos, saldos, perfiles ni invitaciones ajenas; nadie escribe en cuentas ajenas ni a nombre de otro (verificado: pruebas en verde)
- [x] 2.5 `create_ledger_with_invite` devuelve `CRZ-####` y deja a quien crea en rosa y amarillo; falla sin sesión (verificado: pruebas en verde)
- [x] 2.6 `redeem_invite` une a la segunda persona en verde y violeta, y rechaza códigos inexistentes, vencidos, usados y propios (verificado: pruebas en verde)
- [x] 2.7 Generar un código nuevo no borra invitaciones ya canjeadas (verificado: prueba en rojo antes de corregir la migración y en verde después)

## 3. Revisión

- [x] 3.1 Revisión independiente de las políticas RLS y de las funciones `security definer` (verificado: hallazgos resueltos o anotados abajo)
- [x] 3.2 Corregir lo confirmado, con prueba en rojo antes y en verde después: mover un movimiento a otra cuenta, reescribir `created_by`/`created_at`, cambiar `ledgers.created_by`, `TRUNCATE` desde la app, `search_path` vacío en funciones `security definer`, permisos de EXECUTE (verificado: 48 pruebas en verde)
- [x] 3.3 Código de invitación adivinable por fuerza bruta (Alta). Decisión de Joan: mantener `CRZ-####` y limitar a 5 intentos fallidos por hora. `redeem_invite` devuelve `jsonb` con `ok`/`error`/`message` para que el intento quede registrado en `invite_attempts` (verificado: pruebas en rojo y en verde; el ataque de 10.000 intentos ya no entra)

### Hallazgos de la revisión que quedan para otros checkpoints

- **Una cuenta por persona (Media):** hoy un usuario puede crear cuentas sin límite y pertenecer a varias. La app asume un solo `partner`. Decisión de producto pendiente; encaja en el CP4.
- **Regenerar un código vencido (bloquea un flujo):** no hay función para pedir otro código para la misma cuenta; hoy habría que crear otra. CP4.
- **Avisar en Invitar cuando el otro se une:** `ledger_members` no está en la publicación de tiempo real. CP4.
- **Borrar la cuenta del usuario (bloquea un flujo):** las llaves foráneas a `profiles` no tienen `on delete`; Apple exige poder borrar la cuenta. Hay que definir qué pasa con la cuenta compartida. CP11 o CP13.
- **Desvincular:** no hay política ni función. CP11 (ya estaba en el roadmap).

## 4. Nube

- [x] 4.1 Joan crea el proyecto en supabase.com y corre `supabase login` y `supabase link` (verificado: `supabase projects list` muestra `cruce`, West US/Oregon)
- [x] 4.2 `supabase db push` aplica la migración en la nube (verificado: `supabase migration list` la muestra en local y remoto; `supabase db diff --linked` no encuentra diferencias; RLS, TRUNCATE y permisos de `invite_attempts` revisados en la nube. Las pruebas pgTAP no corren en la nube porque pgTAP no está instalado ahí, y no se instala en producción)

## 5. Documentación

- [x] 5.1 `supabase/README.md` explica cómo correr las pruebas; `ROADMAP.md` y `CLAUDE.md` actualizados

## Workflow follow-up

- Archivar con `openspec archive base-de-datos`.
