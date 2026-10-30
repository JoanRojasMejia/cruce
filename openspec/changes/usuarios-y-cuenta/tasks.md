# Tasks

## 1. Base: @usuario

- [x] 1.1 pgTAP `15_usuarios.sql` (rojo): formato, único sin mayúsculas, sugerencia con sufijo, relleno, `check_username`, `set_username`, sin `update` directo, `my_cruces` con columnas nuevas y las de antes iguales, `inviter_username`, `participant_username` solo para los del parche
- [x] 1.2 Migración `usuarios`: `profiles.username`, `username_suggestion`, trigger de la sugerencia, relleno, `check_username`, `set_username`, permisos de columna, `my_cruces()`, `check_invite`/`preview_invite`, `participant_username`

## 2. Base: borrar la cuenta e intentos

- [x] 2.1 pgTAP `16_borrar_cuenta.sql` (rojo): `delete_my_account`, lápida, cruces cerrados con el mismo saldo, cruce pendiente borrado, lugares "Cuenta borrada" con los mismos saldos del parche, propuesta rechazada, @usuario libre, mismo correo es cuenta nueva, trigger de participantes, borrado desde el panel
- [x] 2.2 pgTAP `17_intentos_parche.sql` (rojo): `join_parche` y `claim_parche_place` cuentan intentos y respetan el límite; el límite de `CRZ-` no cambia
- [x] 2.3 Migración `borrar_cuenta`: llave de `profiles`, `deleted_at`, `account_deleted_at`, `forget_account` en `auth.users`, `delete_my_account`, trigger de participantes, lápida inmutable
- [x] 2.4 Migración `intentos_parche`: `join_parche` y `claim_parche_place`

## 3. App: @usuario

- [x] 3.1 Pruebas de CruceCore (rojo): `UsernameRules` (normalizar, validar, sugerir), `CruceRemote` (`my_cruces` con y sin @usuario, `inviter_username`, `check_username`), `ParcheRemote` (`participant_username`, `account_deleted_at`, null de unirse), `SessionStore` (etapa de elegir, revisar, guardar, cambiar)
- [x] 3.2 Modelos, `AccountDirectory`, dobles en memoria, `SessionStore` y `SupabaseAccountDirectory`/`SupabaseParcheRepository`
- [x] 3.3 Pantallas: paso "Elige tu @usuario", Tu perfil, vista previa del `CRZ-`, filas de "Tus cruces" y los del parche; `-screen` y `#Preview`

## 4. App: borrar la cuenta

- [x] 4.1 Pruebas de `SessionStore.deleteAccount()` (rojo) y del participante borrado en los parches
- [x] 4.2 "Borrar mi cuenta" en Tu perfil con confirmación; cierra sesión y borra lo guardado
- [x] 4.3 "Cuenta borrada" en el cruce, en los del parche y en los tickets (sin "sin la app" ni `SOY-`)

## 5. Verificación

- [x] 5.1 `supabase db reset --local`, `supabase test db --local`, `swift test`, `swift format lint --strict`, `xcodebuild`
- [ ] 5.2 Simulador: registro con @usuario, cambiarlo, verlo en la vista previa; borrar una cuenta con cruce y parche y ver "Cuenta borrada" desde la otra; intentos con `PCH-`/`SOY-` (hecho contra Supabase local por la API y con las pantallas `-screen`; falta tocarlo en el simulador con la sesión real)
- [x] 5.3 Rechazo de pasar al cruce en la Actividad de quien lo propuso (S6)
