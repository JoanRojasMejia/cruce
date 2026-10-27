# Design

## Context

- **Funciones de la base:** `create_ledger_with_invite()` y `redeem_invite(p_code)` viven solo en `20261024000000_init.sql` (líneas 221-304), que ya está en la nube y no se edita. Se redefinen con `create or replace` en una migración nueva.
  - `create_ledger_with_invite()` crea un ledger nuevo en cada llamada.
  - `redeem_invite` no revisa si la pareja ya comparte un cruce, ni devuelve quién invitó.
- **Datos:**
  - `ledger_members` tiene un trigger que limita a 2 miembros (`enforce_two_members`) y `unique(ledger_id, tike_variant)`.
  - No está en la publicación de tiempo real.
  - RLS deja a cada miembro ver la fila del otro y su `display_name`.
  - `invites` solo la ve quien la creó.
- **App:**
  - `SupabaseAccountDirectory.hasLedger` cuenta cualquier membresía, también la del cruce pendiente.
  - `SessionStore.partner` no es opcional, y en vivo lo llena `AppStores.live()` con "Tu amigo" y colores fijos.
  - `InviteView`, `JoinView` y `ConnectedView` (`Screens/Auth/AuthViews.swift`) son de mentira.
  - `EnterCodeView` reconoce `CRZ-`, pero descarta el código y, si ya hay cruce, dice "Ya tienes tu cruce con…".
- **Lo que ya supone varios cruces:** `move_parche_debt_to_cruce` busca el cruce por pareja. `SupabaseParcheRepository.crucePartners` lee todas las parejas. La prueba `04_rls.sql` ya mete a Joan en dos cruces.

## Goals / Non-Goals

**Goals:**
- Que la base garantice la regla de un cruce por pareja, sin depender de la app.
- Que la app use solo funciones de la base para vincular, como ya hacen los parches.
- Que el modelo de la app ya trabaje con una lista de cruces, para que el CP4b solo agregue la pantalla y la selección.

**Non-Goals:**
- La lista "Tus cruces", invitar teniendo ya un cruce y elegir el cruce abierto (CP4b).
- Supabase Realtime (CP6).
- Desvincular.

## Decisions

### D1. La regla de pareja vive en un trigger, y las funciones la anticipan con mensajes claros
- **El trigger:** `enforce_one_cruce_per_pair`, `before insert` en `ledger_members`. Cuando la fila es la segunda de su ledger, busca otro ledger que ya tenga a esas dos personas.
  - Si existe, lanza `'Ya tienen un cruce entre los dos'` con `hint = 'alreadyLinked'`.
  - Toma `pg_advisory_xact_lock` sobre la pareja ordenada, para que dos canjes simultáneos no se cuelen.
- **Las funciones:** `redeem_invite` y `preview_invite` comparten una función interna, `check_invite(p_code, p_lock)`, que no se puede llamar desde la app. `redeem_invite` revisa lo mismo antes de insertar y responde en JSON: `error: "already_linked"`, `message: "Ya tienes un cruce con <nombre>"`. No registra intento fallido, porque no es adivinar.
- **Alternativa descartada:** una tabla de parejas con `unique(user_a, user_b)`. Duplica datos que ya están en `ledger_members` y hay que mantenerla sincronizada.

### D2. Un solo cruce pendiente por persona
- **Qué hace:** `create_ledger_with_invite()` busca primero un ledger con un solo miembro, donde quien llama es el creador (`ledgers.created_by`).
  - Si su invitación sigue vigente y sin usar, devuelve ese código.
  - Si venció, genera un código nuevo para el mismo ledger, con la lógica actual de reintentos y sin borrar invitaciones canjeadas.
  - Solo si no hay ledger pendiente crea uno.
- **Por qué:** la pantalla de invitar puede pedir el código cada vez que se abre sin dejar cruces vacíos. La firma (`returns text`) no cambia.

### D3. `preview_invite(p_code)` para mostrar el nombre antes de unirse
- **Qué devuelve:** `jsonb` `{ok: true, inviter_name}`, o los mismos errores de `redeem_invite`: `invalid`, `own`, `too_many_attempts` y `already_linked`, con los mismos mensajes.
- **Límite de intentos:** los `invalid` registran intento en `invite_attempts`, igual que en `redeem_invite`, así que adivinar nombres cuesta lo mismo que adivinar códigos.
- **Seguridad:** es `security definer` con `search_path = ''`, como las demás, y está revocada para `anon`.
- **Alternativa descartada:** mostrar el nombre solo después de unirse. Rompe la pantalla 15 del diseño ("CÓDIGO VÁLIDO · Cuenta de Joan") y no protege más: el nombre solo se le muestra a quien tiene el código, que es a quien se lo mandaron.

### D4. `my_cruces()` lista los cruces completos
- **Qué devuelve:** `returns table(ledger_id, partner_id, partner_name, my_tike, my_avatar, partner_tike, partner_avatar, linked_at)`, solo de ledgers con dos miembros donde está quien llama. Ordena del cruce que se completó más recientemente al más viejo: `linked_at` es el `joined_at` de la segunda persona, no la fecha del ledger, porque un cruce pendiente puede llevar días esperando.
- **Seguridad:** es `security invoker`, así que RLS sigue mandando.
- **Por qué:** una sola llamada que se puede probar con pgTAP. La app no tiene que armar embebidos de PostgREST.

### D5. `AccountDirectory` deja de responder "¿tiene cuenta?" y pasa a responder "¿qué cruces tiene?"
- **Cambios en el protocolo:**
  - `hasLedger(_:)` se reemplaza por `cruces(for:) -> [CruceLink]`. `CruceLink` es un tipo nuevo de CruceCore, `Sendable` y `Equatable`, con el id del cruce, el `Member` propio y el del otro.
  - Se agregan `inviteCode() -> String`, `previewInvite(_:) -> InviteCheck` y `redeemInvite(_:) -> InviteCheck`. `InviteCheck` es `.valid(inviterName)` o `.rejected(InviteRejection, message)`, con el mensaje de la base.
- **`InMemoryAccountDirectory`:** modela ledgers con miembros, invitaciones, la regla de pareja y el límite de intentos, para probar `SessionStore` con `swift test`.
- **`SupabaseAccountDirectory`:** llama a las cuatro funciones por RPC. La traducción del JSON vive en CruceCore (como `ParcheRemote`), para probarla sin red.

### D6. `SessionStore` guarda `cruces` y deriva `partner`
- **`refresh()`:** con perfil y sin cruces → `.invite`; con cruces → `.main`. Además:
  - `me` toma su color y recibo del cruce más reciente;
  - `partner` es el otro de ese cruce.
  
  `partner` sigue sin ser opcional para no tocar las vistas del inicio (el CP4b lo cambia). Sin cruces queda un marcador que ninguna pantalla muestra.
- **Acciones nuevas:**
  - `loadInviteCode()` llena `inviteCode`;
  - `checkCode(_:)` llena `invitePreview`;
  - `join(code:)` canjea y, si sale bien, recarga los cruces y pasa a `.connected`;
  - `checkForPartner()` recarga los cruces y, si aparece uno nuevo estando en `.invite`, pasa a `.connected`.
- **`Problem`** gana un caso para el rechazo del código, con el mensaje de la base.

### D7. Quien invita consulta cada 3 segundos, solo con la pantalla abierta
- **Qué:** `InviteView` corre un `.task` que llama a `session.checkForPartner()` cada 3 segundos. SwiftUI lo cancela al salir de la pantalla.
- **Por qué:** con dos personas cuesta poco, no exige agregar `ledger_members` a la publicación de tiempo real y no adelanta el CP6.
- **Alternativa descartada:** Realtime sobre `ledger_members`. Necesita la publicación y una suscripción, que es el trabajo del CP6.

### D8. "Tengo un código" con `CRZ-` lleva el código a `JoinView`
- **Sin cruce:** `EnterCodeView` guarda el código en `session` (`pendingJoinCode`) y pasa a `.join`. `JoinView` arranca con los 4 dígitos escritos y la vista previa hecha.
- **Con cruce:** el mensaje "Ya tienes tu cruce con…" choca con la decisión de varios cruces. Se reemplaza por "Pronto vas a poder tener más de un cruce", hasta que el CP4b lo resuelva.

### D9. Ajustes de la revisión independiente
- **Límite de intentos con peticiones simultáneas:** `check_invite` toma un candado por persona antes de contar y registrar intentos. Sin él, una ráfaga de peticiones veía menos de 5 intentos en cada una (ya pasaba en `init.sql`; la vista previa lo hacía más barato).
- **Carrera de dos canjes cruzados:** si Joan y Jesús canjean el código del otro al mismo tiempo, quien pierde recibe el JSON `already_linked` en vez de la excepción del trigger: `redeem_invite` atrapa `unique_violation`.
- **Cuenta pendiente:** además de tener un solo miembro, ningún código suyo se canjeó nunca. Así un cruce que estuvo completo y perdió a la otra persona (al borrar una cuenta o, más adelante, al desvincular) no se reusa con alguien nuevo que heredaría la historia.

## Risks / Trade-offs

- **[Cruces repetidos en la nube]** Si testing ya tuviera dos cruces entre la misma pareja, el trigger no los toca, porque solo mira inserciones nuevas → La migración revisa y aborta con un mensaje si encuentra duplicados. Hoy testing solo tiene a Joan, así que no debería pasar.
- **[Consultar cada 3 segundos]** Mientras la pantalla está abierta hace unas 20 llamadas por minuto → Es aceptable para 2 personas y se cancela al salir. El CP6 lo cambia por tiempo real.
- **[Vista previa y adivinar nombres]** Sin límite, `preview_invite` revelaría nombres → Comparte el límite de 5 intentos fallidos por hora con `redeem_invite`.
- **[`partner` con marcador]** Mientras no hay cruce, `partner` no es real → Ninguna pantalla lo muestra en `.invite` ni en `.join`. Se cubre con pruebas de `SessionStore`, y el CP4b lo vuelve opcional o por cruce.
- **[Correo]** Probar con dos cuentas en testing manda correos por Gmail (unos 500 al día) → La prueba de punta a punta se hace primero en local con mailpit; en testing basta con Joan y Jesús.

## Migration Plan

1. Probar en local: `supabase db reset` y `supabase test db`, con pgTAP nuevo.
2. Respaldar y aplicar en testing: `scripts/db-push.sh testing`.
3. Si sale mal: una migración nueva que restaure las definiciones de `init.sql` y borre el trigger y las funciones nuevas. No borra datos.
