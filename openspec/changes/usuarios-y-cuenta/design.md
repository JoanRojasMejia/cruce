# Design

## Context

Inventario de lo que apunta a una cuenta (revisado en `supabase/migrations/`):

| Referencia | Acción al borrar | Problema si se borra el usuario de Auth |
|---|---|---|
| `profiles.id → auth.users` | `on delete cascade` | Borra el perfil y, en cascada, `ledger_members` (el cruce pierde a uno de los dos) |
| `ledger_members.user_id → profiles` | `cascade` | El otro se queda con un cruce de una persona |
| `ledgers.created_by`, `invites.created_by`, `invites.redeemed_by`, `movements.payer_id`, `movements.created_by → profiles` | sin acción | El borrado del perfil falla si hay movimientos o cruces |
| `ledgers.closed_by → profiles` | `set null` | — |
| `parche_participants.user_id → auth.users` | `set null` | El trigger `parche_participants_before_update` lo rechaza ("Ese lugar ya es de alguien"): por eso hoy borrar un usuario de un parche falla |
| `invite_attempts.user_id → auth.users` | `cascade` | — |
| `parches.created_by` | apunta a un participante, no a la cuenta | — |

Los saldos se calculan sumando movimientos (`payer_id` y `created_by` apuntan al perfil) y, en los parches, sumando gastos y pagos por participante. Nada de eso puede perder filas.

## Goals / Non-Goals

**Goals:**
- Un @usuario único por perfil, elegible al registrarse y editable, visible donde aparecen personas.
- Borrar la cuenta sin descuadrar cruces ni parches, liberando el @usuario y el correo.
- Que `join_parche` y `claim_parche_place` cuenten intentos sin romper las versiones anteriores de la app en el camino feliz.

**Non-Goals:**
- Buscar personas por @usuario o invitar por @usuario (sigue siendo con códigos).
- Mostrar el @usuario en la vista previa de `PCH-` y `SOY-`: un `PCH-` lleva a un grupo y un `SOY-` a alguien sin la app, que no tiene @usuario.
- Reabrir un cruce o recuperar una cuenta borrada.

## Decisions

### 1. El perfil borrado queda como lápida
Se borra el usuario de `auth.users` (correo, identidades y sesiones se van en cascada), pero la fila de `profiles` se queda con el mismo `id` como lápida: `display_name = 'Cuenta borrada'`, `username` y `avatar_color` en null y `deleted_at` con la fecha. Así `movements`, `ledgers`, `invites` y `ledger_members` siguen apuntando a una fila que existe y los saldos no cambian. Para eso se quita la llave `profiles.id → auth.users`: un perfil solo se crea con `id = auth.uid()` (política "crear mi perfil"), así que sigue sin haber perfiles de usuarios que no existieron.
- Alternativa descartada: anonimizar el usuario de Auth en vez de borrarlo (cambiarle el correo y bloquearlo). Deja datos en `auth` y no libera el correo de verdad.
- Alternativa descartada: borrar el perfil y reasignar sus movimientos a un perfil "Cuenta borrada" compartido. Cambia `payer_id` en cruces cerrados (el trigger de solo lectura lo rechaza) y mezcla a varias personas borradas.
- El nombre "Cuenta borrada" se guarda en la fila (y no lo pone la app) para que las versiones anteriores, el CSV y los nombres de los parches lo muestren igual.
- Una lápida no se puede editar (trigger `profiles_before_update`): el token de la sesión borrada sigue vigente hasta una hora y no debe poder ponerle otro nombre.

### 2. El borrado lo hace un trigger antes de borrar el usuario de Auth
`forget_account()` es un trigger `before delete on auth.users`; `delete_my_account()` (lo que llama la app) solo borra `auth.users` donde `id = auth.uid()`. Así también un borrado desde el panel de Supabase deja todo consistente. El trigger, con el usuario todavía presente:
1. Cierra sus cruces completos abiertos (`closed_at`, `closed_by`) y borra su cruce pendiente con su `CRZ-`.
2. Marca sus lugares en los parches: `display_name = 'Cuenta borrada'`, `account_deleted_at = now()`; deja su color del parche (el color de cada lugar es del parche y no identifica a la persona fuera de él).
3. Rechaza las propuestas de pasar al cruce por confirmar donde está su lugar (ya no tienen cruce abierto donde caer).
4. Deja el perfil como lápida.
Después la llave `on delete set null` pone `user_id = null` en sus lugares; el trigger de participantes ahora lo permite solo si la cuenta ya no está en `auth.users`.

### 3. @usuario
- Columna `profiles.username` con `check (username ~ '^[a-z0-9._]{3,20}$')` e índice único. Solo minúsculas, así que el índice único ya es "sin importar mayúsculas". Null solo en una lápida (`check (username is not null or deleted_at is not null)`).
- `username_suggestion(name)`: minúsculas, sin tildes (`translate`), espacios y guiones a punto, quita lo demás, recorta a 20 y, si choca, agrega 2, 3… recortando la base. Si queda con menos de 3 caracteres, usa "usuario".
- Un trigger `before insert` en `profiles` le pone la sugerencia a un perfil sin @usuario: el paso de la entrada solo la confirma o la cambia, y si la app se cierra en ese paso la persona ya tiene uno. El relleno de los perfiles que ya existen usa la misma función, en el orden de `created_at`.
- `check_username(p)` y `set_username(p)` devuelven `{ok, username}` o `{ok: false, error, message}` (`format`, `taken`) en vez de lanzar, como `code_error`. `set_username` atrapa la violación del índice único (dos personas al tiempo) y la devuelve como `taken`. `username` no se puede editar con `update` directo: se quitan los permisos de columna y solo quedan `display_name` y `avatar_color`.
- Dónde se lee: `my_cruces()` agrega al final `my_username`, `partner_username` y `partner_deleted` (las columnas de antes no cambian); `check_invite`/`preview_invite` agregan `inviter_username`; los participantes lo traen con el campo calculado `participant_username(parche_participants)` de PostgREST (`security definer`, solo para quien está en ese parche, porque RLS de `profiles` no deja ver a los del parche que no son pareja de cruce).

### 4. Intentos en `join_parche` y `claim_parche_place`
Una excepción deshace el `insert` en `invite_attempts`, así que un código que no existe (o un `SOY-` ya usado o propio) ya no lanza: registra el intento y devuelve null. Con 5 intentos en la última hora lanzan `tooManyAttempts` antes de buscar el código (no hay nada que registrar). Los demás errores no cambian. La app nueva traduce el null a "Ese código no existe" (`ParcheRepositoryError.invalidCode`). Las versiones anteriores llaman primero a `preview_parche_code`, así que un null solo les llega si el código cambió entre la vista previa y entrar; ahí ven un error genérico.

### 5. App
- `Profile.username`, `Member.username` y `Member.isDeleted`, `ParcheParticipant.username` y `isDeletedAccount`, `InviteCheck.valid(inviterName:username:)`/`CodePreview.cruce(inviterName:username:)`. Todo opcional al decodificar para leer bases y archivos guardados de antes.
- `SessionStore.Phase.chooseUsername`: `createProfile` pasa a esa etapa; `checkUsername` revisa mientras se escribe (solo cuenta la última respuesta, como `checkCode`) y `chooseUsername` guarda y pasa a invitar. `updateUsername` para Tu perfil y `deleteAccount()` (llama `delete_my_account` y luego `signOut()`).

## Risks / Trade-offs

- Un borrado desde el panel con la versión anterior del trigger no aplica: esta migración debe estar en la nube antes de borrar a alguien.
- `partner_color` llega null para una cuenta borrada: la app nueva y la anterior caen al color del rol (`partner_avatar`).
- Las versiones anteriores ven un error genérico con un `PCH-`/`SOY-` que no existe solo si se saltan la vista previa.
- Dos registros al mismo tiempo con el mismo nombre pueden chocar en el trigger de la sugerencia: el segundo falla y se reintenta al tocar "Seguir" otra vez.
- El token de quien borró su cuenta sigue vigente hasta que vence: no puede crear otro perfil con ese `id` ni editar la lápida, y sus cruces están cerrados y sus lugares ya no son suyos.
