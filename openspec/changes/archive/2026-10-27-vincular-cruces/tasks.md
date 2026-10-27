# Tasks

## 1. Base de datos

- [x] 1.1 Escribir `supabase/tests/07_vincular_cruces.sql` (pgTAP) antes de la migración y verlo fallar con `supabase test db`. Casos:
  - pedir el código dos veces da el mismo y una sola cuenta pendiente;
  - un código pendiente vencido da otro código para la misma cuenta;
  - `preview_invite` devuelve "Joan" sin unir a nadie;
  - `preview_invite` con un código inválido registra un intento y, con 5 fallos, rechaza;
  - `redeem_invite` devuelve `inviter_name`;
  - un segundo cruce con la misma pareja → `already_linked` "Ya tienes un cruce con Joan", sin contar como intento;
  - un cruce con otra persona sí se permite;
  - una inserción directa de la misma pareja en otro ledger → "Ya tienen un cruce entre los dos";
  - `my_cruces()` solo lista cruces de dos personas, del más reciente al más viejo, con los colores y el recibo de cada lado;
  - `anon` no puede llamar las funciones nuevas.
- [x] 1.2 Crear la migración `supabase/migrations/<fecha>_vincular_cruces.sql`:
  - trigger `enforce_one_cruce_per_pair`, con candado por pareja;
  - `create_ledger_with_invite()` reutiliza la cuenta pendiente;
  - `redeem_invite()` con `already_linked` e `inviter_name`;
  - `preview_invite()` y `my_cruces()` nuevas;
  - revisión de duplicados que aborta si los encuentra;
  - permisos solo para `authenticated`.
  
  Verificar con `supabase db reset` y `supabase test db` en verde (las 163 pruebas actuales más las nuevas), y `03_vinculacion.sql` sin cambios o con el ajuste justificado.
- [x] 1.3 Documentar las funciones nuevas y la regla de pareja en `supabase/README.md`, con la tabla de pruebas. Verificar que lo escrito coincide con lo que prueban los pgTAP.

## 2. Modelo de la app (CruceCore)

- [x] 2.1 Agregar `CruceLink`, `InviteCheck` e `InviteRejection` y la traducción del JSON de `redeem_invite`, `preview_invite` y `my_cruces` (como `ParcheRemote`). Primero las pruebas con JSON de ejemplo (válido, `invalid`, `own`, `too_many_attempts` y `already_linked`), que deben fallar. Verificar con `swift test`.
- [x] 2.2 Cambiar `AccountDirectory`: `hasLedger` pasa a `cruces(for:)`, y se agregan `inviteCode()`, `previewInvite(_:)` y `redeemInvite(_:)`. Reescribir `InMemoryAccountDirectory` con cuentas, invitaciones, la regla de pareja y el límite de intentos. Verificar con `swift test`, ajustando las pruebas que usaban `hasLedger` sin cambiar lo que aseguran.
- [x] 2.3 En `SessionStore`:
  - guardar `cruces`;
  - con `refresh()`, ir a `.invite` sin cruces completos y a `.main` con al menos uno, tomando `me` y `partner` del más reciente;
  - agregar `loadInviteCode()`, `checkCode(_:)`, `join(code:)`, `checkForPartner()` y `pendingJoinCode`;
  - agregar el caso de rechazo en `Problem`.
  
  Escribir antes las pruebas de Swift Testing:
  - cruce pendiente → invitar;
  - cruce completo → inicio con el nombre real;
  - quien se une queda verde y violeta;
  - unirse con un código válido → `.connected`;
  - código inválido → mensaje en español y sigue en `.join`;
  - `checkForPartner()` pasa a `.connected` cuando el otro se une;
  - el mismo código dos veces no crea otra cuenta.
  
  Verificar con `swift test` en verde y `swift format lint --strict`.

## 3. App

- [x] 3.1 `SupabaseAccountDirectory`: implementar `cruces(for:)` con `my_cruces()` y las tres funciones por RPC. Quitar los colores fijos de `AppStores.live()`. Verificar compilando, y contra Supabase local con dos cuentas: Joan invita, Jesús ve "Cuenta de Joan", se une y los dos tienen el cruce, con los colores correctos.
- [x] 3.2 `InviteView`:
  - muestra el código de `loadInviteCode()`;
  - consulta cada 3 segundos con `.task` y pasa sola a "Conectados";
  - el botón de mentira de "Esperando a tu amigo…" deja de saltar de etapa.
  
  Verificar con dos simuladores contra Supabase local: Joan pasa a "Conectados" en menos de 10 segundos después de que Jesús se une.
- [x] 3.3 `JoinView`:
  - con los 4 dígitos llama a `checkCode` y muestra "CÓDIGO VÁLIDO · Cuenta de Joan" o el mensaje de error;
  - "Unirme" llama a `join`;
  - arranca con `pendingJoinCode` si viene de "Tengo un código".
  
  `ConnectedView` muestra el nombre y los colores reales. En `EnterCodeView`, `CRZ-` sin cruce pasa el código, y con cruce muestra "Pronto vas a poder tener más de un cruce". Verificar:
  - con capturas de `JoinView` (válido e inválido) y de "Conectados" en el simulador, comparadas con `docs/design/screens/15` y `16`;
  - `xcodebuild … build` de los tres esquemas.
- [x] 3.4 Actualizar las vistas previas y `DebugScreen` (con `InMemoryAccountDirectory`) para invitar, unirse (válido e inválido) y conectados. Verificar que `xcrun simctl launch … com.joanrojas.cruce.dev -screen join` abre las variantes.

## 4. Testing y documentación

- [x] 4.1 Aplicar en testing con `scripts/db-push.sh testing`, que respalda antes. Lo corre Joan. Verificar que dice "testing" y aplica la migración nueva, y con `supabase db query --linked` que existen el trigger y las funciones.
- [x] 4.2 Actualizar:
  - CLAUDE.md §2 (vinculación real), §6 (`AccountDirectory`, `SessionStore.cruces`) y §8 (lo que queda para el CP4b);
  - ROADMAP: marcar el CP4;
  - `ios/README.md`.
  
  Verificar que `rg -n "hasLedger" ios CLAUDE.md` no encuentra restos.

## 5. Verificación de punta a punta

- [x] 5.1 Correr la suite completa: `swift test`, el lint, el backend, `supabase test db` y `xcodebuild` de los tres esquemas. Después, el "Hecho cuando" del CP4 en local: con dos simuladores, uno invita, el otro se une y los dos llegan al inicio vacío, con nombres y colores reales y recibo rosa y verde. En testing, Joan y Jesús se vinculan con "Cruce Test" en sus iPhone.

*5.1 hecho el 27 oct 2026: suite local en verde (178 Swift, 190 pgTAP, lint, backend y tres esquemas); en local, invitar y unirse con el simulador y la API; en testing, Joan y Jesús se vincularon en "Cruce Test" desde sus iPhone.*

## Workflow follow-up

- Archivar con `openspec archive vincular-cruces` cuando se cumpla el "Hecho cuando" y proponer el commit.
- Seguir con el CP4b (varios cruces en la app).
