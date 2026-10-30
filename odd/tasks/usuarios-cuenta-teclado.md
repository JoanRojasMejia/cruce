# usuarios-cuenta-teclado

Objetivo: @usuario único, borrar la cuenta, intentos fallidos con `PCH-`/`SOY-`, verificaciones pendientes, reglas por papel y la regla del teclado de montos.
Ramas: `feat/usuarios-y-cuenta` (cambio OpenSpec `usuarios-y-cuenta`) y `feat/teclado-de-montos` (cambio `teclado-de-montos`), cada una en su worktree; la documentación general va en `main` al final.
Entrega: `ask-on-risk`. Pruebas: `supabase test db --local` (pgTAP), `swift test` en `ios/Packages/CruceCore`, `swift format lint --strict`, `xcodebuild` y el simulador.

## Specs

**S1. Reglas y documentación por papel.** "el tema de en las reglas y la documentación. O sea, esa parte hagamos lo que vos mencionas. Ustedes quedan solo como datos de ejemplo." Las reglas de CLAUDE.md, `openspec/specs` y `docs/` hablan de papeles ("quien creó el cruce", "quien se unió"), no de Joan y Jesús; ellos quedan solo en ejemplos. **El onboarding no cambia:** "Dejemos el tema del onboarding como está actualmente. O sea, con Joan y Jesús."

**S2. @usuario único.** "Vamos a ir por la parte de un usuario único. Una arroba con usuario único. También tengamos en cuenta el tema de cuando se quiere editar." Acordado:
- De 3 a 20 caracteres: minúsculas, números, `.` y `_`. Único sin importar mayúsculas.
- Al registrarse es un paso después del nombre, con una sugerencia basada en ese nombre. Se edita en Tu perfil y avisa si está ocupado.
- Se ve en la vista previa del código, en Tus cruces y en los parches.
- La app identifica a las personas por `id`, nunca por el nombre.

**S3. Usuarios que ya existen.** "Y con los usuarios que ya existen actualmente. Que digamos en producción solo somos 3." La migración le asigna un @usuario a cada perfil existente a partir de su nombre (con un sufijo si choca), y luego cada uno lo puede cambiar.

**S4. Borrar la cuenta.** "Podemos arreglar de una vez la de borrar la cuenta". Decisión (Joan: "hagámoslo como mencionas"):
- Se borran su perfil, correo, @usuario y color.
- Sus cruces se cierran, como al desvincular, y la otra persona conserva el historial con "Cuenta borrada".
- En los parches, su lugar y sus gastos se quedan con el nombre "Cuenta borrada", sin descuadrar las cuentas de los demás.
- Arreglo del trigger `parche_participants_before_update`: `user_id` puede pasar a null solo si ese usuario ya no existe en `auth.users`.
- "Borrar mi cuenta" está en Tu perfil, con confirmación.
- Si vuelve con el mismo correo, es una cuenta nueva y nada se reconecta.
- El @usuario se libera de inmediato ("Sí, vamos con la 1").

**S5. Intentos fallidos.** "Una, a la de unirse al parche y reclamar el lugar, que todavía no cuentan con intentos fallidos, hagámoslo de una vez." `join_parche` y `claim_parche_place` cuentan los intentos fallidos en el mismo límite que `preview_parche_code` y `CRZ-` (5 por hora).

**S6. Rechazo de pasar al cruce.** "que aparezca en la aplicación como esa notificación dentro de la parte de notificaciones. No con otro componente ni nada." Ya existe (`debtRejectedForCruce` en la Actividad, con pruebas); se verifica de punta a punta y se corrige si no se ve.

**S7. Deshacer.** Volver a probar el aviso "Deshacer" (borrar un gasto del parche) con calma en el simulador; corregirlo si falla.

**S8. ROADMAP.** "Lo del correo de prod, dejémoslo como para un futuro en el roadmap, igual que la membresía de Apple, políticas de privacidad también" y "lo de solo pesos colombianos y español … Dejémoslo también en el roadmap como para más adelante."

**S9. Teclado de montos.** Regla: "el monto principal se escribe con el teclado de Cruce; los montos secundarios, con el del sistema". Joan: "Estoy de acuerdo con todo lo que mencionas. Tanto el punto 1, 2 y 3."
1. El teclado de Cruce (`AmountKeypad`, con `000`) va **acoplado abajo en todas** (Nuevo movimiento, Anotar un pago del parche y Anotar o editar un gasto del parche). Anotar un pago del parche pasa a la tarjeta amarilla arriba.
2. **Nuevo:** el monto arranca activo. **Editar:** nada arranca activo y tocar la tarjeta abre el teclado.
3. **Cambio entre teclados:** tocar la tarjeta abre el de Cruce y cierra el del sistema; otro campo hace lo contrario; el espacio vacío cierra los dos.
- Los montos secundarios (pagador, ítem, propina) siguen con el teclado del sistema. "Cambiar monto" en Saldar sigue en una hoja.
- VoiceOver: cada tecla lleva su etiqueta ("borrar", "tres ceros") y al cambiar se anuncia el monto ("Monto: sesenta mil pesos").

**S10. Revisión.** "Y realiza una revisión exhaustiva para validar que todo funcione correctamente."

## Tasks

| ID | Specs | Ruta | Estado | Evidencia |
|---|---|---|---|---|
| T1 | S2–S6 | delegada: escritora A, worktree `feat/usuarios-y-cuenta` (paralelo con T2) | hecha | `5536903`…`90f47a0`; arreglo del bloqueo en `abb695d` |
| T2 | S7, S9 | delegada: escritora B, worktree `feat/teclado-de-montos` (paralelo con T1) | hecha | `7666efc`, `978149b`; 351 pruebas de Swift; Deshacer funciona (era el tiempo de 5 s) |
| T3 | S1, S8 | en línea, rama `docs/reglas-por-papel` | hecha | `fc22d43` docs: reglas por papel y pendientes para más adelante |
| T4 | S10 | delegada: verificadora independiente, por ser de riesgo alto (migraciones, auth, borrado) | hecha | S1–S9 PASS salvo S4 (B1); B1 corregido y revisado con su script |

## Log

- L1 (2026-10-30, Joan): "Listo. Dejemos el tema del onboarding como está actualmente. … Vamos a ir por la parte de un usuario único. Una arroba con usuario único. También tengamos en cuenta el tema de cuando se quiere editar. … Y con los usuarios que ya existen actualmente. … Podemos arreglar de una vez la de borrar la cuenta … Lo del correo de prod, dejémoslo como para un futuro en el roadmap, igual que la membresía de Apple, políticas de privacidad también … Una, a la de unirse al parche y reclamar el lugar, que todavía no cuentan con intentos fallidos, hagámoslo de una vez. Otra, que es cuando rechazan el cruce, que nadie lo ve que se rechazó, entonces coloquemos como la notificación por ahora … dentro de la parte de notificaciones. No con otro componente ni nada. … Y lo de solo pesos colombianos y español … Dejémoslo también en el roadmap como para más adelante."
- L2 (Joan): "Sí, respecto a lo que me propones, de la decisión que es mía, hagámoslo como mencionas." / "Sí, vamos con la 1." (el @usuario se libera de inmediato)
- L3 (Joan): "Sí. Estoy de acuerdo con todo lo que mencionas. Tanto el punto 1, 2 y 3. Además de lo que mencionas, que dejarías como está, y lo que hay que cuidar al hacerlo."
- L4 (Joan): "Sí, arranca con eso así. Arranca con todo mejor de una vez. Y realiza una revisión exhaustiva para validar que todo funcione correctamente."
- L5: ruta. T1 y T2 son dos unidades independientes con superficies disjuntas y cada una más pesada que lanzar un subagente; van en paralelo y en worktrees separados (las dos regeneran el `.xcodeproj` y compilan). T4 es la verificadora por riesgo alto.
- L6: integración en `feat/usuarios-cuenta-teclado` (merge de las dos ramas y de `docs/reglas-por-papel`; conflicto solo en `DebugScreen.swift`). Avatar de cuenta borrada sin borde punteado (`eb7abe7`).
- L7: verificadora: S1–S3 y S5–S9 PASS; S4 FAIL por B1 (la sesión vigente de una cuenta borrada creaba y canjeaba cruces abiertos). Arreglo: `20261030130000_cuenta_borrada_guardas.sql` (`require_session()` exige la cuenta en `auth.users`, trigger en `ledger_members`, el rechazo automático lo firma el lugar borrado) + `18_cuenta_borrada_sin_sesion.sql` (RED 5/6 → GREEN). Su script `blocker_deleted_jwt_open_cruce.py` ahora pasa. Suites: pgTAP 477/18, Swift 377/37, lint limpio, build OK, `openspec validate --all --strict` 31/31.
- L8: avisos para Joan (decisiones): deudas con "Cuenta borrada" en un parche no se pueden saldar (el pago queda por confirmar); el color del lugar borrado se queda en el parche; el tope del monto pasó de 9 a 12 dígitos. Arreglado: "Es tu @usuario" en Tu perfil (`7dcd1a0`).
