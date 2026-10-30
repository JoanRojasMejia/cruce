# Proposal

## Why

Hoy dos personas con el mismo nombre ("Juan") no se distinguen en la vista previa de un código, en "Tus cruces" ni en los parches, y nadie puede borrar su cuenta: borrar un usuario desde el panel falla si está en un parche (el trigger `parche_participants_before_update` choca con el `on delete set null`). Además, `join_parche` y `claim_parche_place` no cuentan los intentos fallidos, así que el límite de 5 por hora de `preview_parche_code` se salta llamándolas directo.

## What Changes

- **@usuario único:** cada perfil tiene un @usuario de 3 a 20 caracteres (minúsculas, números, `.` y `_`), único sin importar mayúsculas. Al registrarse se elige en un paso después del nombre, con una sugerencia basada en ese nombre; se cambia en Tu perfil y la app avisa si está ocupado. Se ve en la vista previa de un `CRZ-`, en "Tus cruces" y en los del parche. La app sigue identificando a las personas por `id`.
- **Usuarios que ya existen:** la migración le asigna a cada perfil un @usuario a partir de su nombre (con un sufijo si choca).
- **Borrar la cuenta:** "Borrar mi cuenta" en Tu perfil, con confirmación. Se borran el perfil (nombre, @usuario y color), el correo y la sesión; los cruces se cierran como al desvincular y la otra persona conserva el historial con "Cuenta borrada"; en los parches, su lugar y sus gastos quedan como "Cuenta borrada" sin cambiar el saldo de nadie. El @usuario se libera de inmediato y volver con el mismo correo crea una cuenta nueva.
- **Arreglo del trigger:** `parche_participants.user_id` puede pasar a null solo si esa cuenta ya no existe en `auth.users`.
- **Intentos fallidos:** `join_parche` y `claim_parche_place` cuentan los códigos que no sirven en el mismo límite de 5 por hora que `CRZ-` y `preview_parche_code`.
- **Rechazo de pasar al cruce:** se verifica de punta a punta que quien propuso ve el rechazo en la Actividad del parche (ya existe como `debtRejectedForCruce`).

## Capabilities

### New Capabilities
- `usuario`: el @usuario único de cada persona: formato, cómo se elige al registrarse, cómo se cambia y dónde se ve.
- `borrar-cuenta`: borrar la cuenta propia y cómo queda lo compartido (cruces y parches) para los demás.

### Modified Capabilities
- `codigos`: unirse a un parche y quedarse con un lugar también cuentan los intentos fallidos.

## Impact

- Base de datos: dos migraciones nuevas y aditivas (`profiles.username`, `profiles.deleted_at`, `parche_participants.account_deleted_at`, funciones `check_username`, `set_username`, `delete_my_account`, `participant_username`; `my_cruces()` con columnas nuevas al final; `check_invite`/`preview_invite` con `inviter_username`; `join_parche` y `claim_parche_place` sin lanzar error con un código que no existe). Se quita la llave foránea `profiles.id → auth.users` para que el perfil borrado quede como lápida.
- App: `Profile`, `Member`, `CruceLink`, `ParcheParticipant`, `InviteCheck`/`CodePreview`, `SessionStore` (etapa nueva para elegir el @usuario y borrar la cuenta), `AccountDirectory`, `SupabaseAccountDirectory`, `SupabaseParcheRepository`, la entrada, Tu perfil, "Tengo un código", "Tus cruces" y los del parche.
- Versiones anteriores de la app: siguen funcionando. `my_cruces()` conserva sus columnas; un `PCH-` o `SOY-` que no existe al unirse o reclamar les llega como respuesta vacía (error genérico) en vez de "Ese código no existe".
