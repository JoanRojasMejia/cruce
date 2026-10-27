# Roadmap de Cruce

Se trabaja **un checkpoint a la vez, en orden**. Cada uno termina con sus pruebas en verde y un commit.
Marca `[x]` cuando una tarea esté hecha y actualiza la sección "Estado actual" de `CLAUDE.md`.
Cada checkpoint se lleva como un cambio de OpenSpec en `openspec/changes/` (ver `CLAUDE.md` §9); al cerrarlo se archiva y sus requisitos pasan a `openspec/specs/`.

---

## Decisiones abiertas (las toma Joan)

- [ ] **Membresía de Apple Developer:** ¿se paga ya? La necesitan Sign in with Apple, las notificaciones push (CP9) y TestFlight (CP13). Por ahora no se paga: el CP3 se hizo con inicio de sesión por correo (código de 6 dígitos) y Sign in with Apple queda como función posterior.
- [ ] **Hosting del backend de Go:** Fly.io, Render, Railway u otro (CP8).
- [ ] **Persistencia local para el modo sin conexión:** SwiftData o archivo JSON (CP7).
- [ ] **Pago parcial ("Cambiar monto" en Saldar):** ¿se permite pagar menos del total? (CP11).
- [ ] **Pruebas de captura:** ¿se agrega `swift-snapshot-testing`? (CP12).
- [x] **Una cuenta por persona:** ¿una persona puede pertenecer a más de una cuenta compartida? *Decidido el 27 oct 2026: **varios cruces, uno por pareja**. Con uno solo el inicio es ese cruce; con varios, el inicio muestra "Tus cruces". La regla va en el CP4 y la lista en el CP4b.*
- [ ] **Borrar la cuenta de usuario:** Apple lo exige; falta definir qué pasa con sus cruces y los movimientos de los otros (CP11 o CP13).

---

## Parches · grupos con inicio y fin
*Hecho en el cambio `parches` (26 oct 2026), fuera del orden de los checkpoints. Migración `20261026095551_parches.sql` aplicada en local y en la nube.*
- [x] Reparto en pesos enteros (iguales, por consumo con ítems, por partes, por porcentaje y propina) y saldos, mínimo de transferencias y deuda directa entre dos, en CruceCore.
- [x] Base de datos: tablas, RLS (solo los del parche ven el parche), validación de sumas, actividad y funciones (`create_parche`, `join_parche`, `add_parche_participant`, `claim_parche_place`, `save_parche_expense`, `record_parche_payment`, `confirm_parche_payment`, `close_parche`, `move_parche_debt_to_cruce`, `mark_parche_seen`…), con pgTAP (`06_parches.sql`).
- [x] Pantallas: "Tus parches", nuevo parche, "Tengo un código" (`PCH-`, `SOY-`), detalle, anotar gasto y pago, cerrar con "¿Lo pasas a tu cruce?" y tickets para compartir.
- [x] `SupabaseParcheRepository` en `AppStores.live()`, con la cola sin conexión guardada en disco.
- [x] Probado contra Supabase local con tres cuentas y en el simulador.

**Límites conocidos:** sin tiempo real (lo de los demás se ve al abrir el parche o al recargar); el movimiento que deja "pasar al cruce" está en `movements` pero la app solo lo muestra cuando llegue el CP5; sin notificaciones push (los avisos son dentro de la app); la cola sin conexión es del teléfono, no de la cuenta.

## CP0 · Levantar el proyecto y compilar
- [x] `git init`, primer commit con todo lo que hay.
- [x] `cd ios && xcodegen` genera el proyecto sin errores.
- [x] Corregir los errores de compilación de Swift (el código nunca se ha compilado; ver CLAUDE.md §8). *Compiló sin errores. Se corrigió `NeoSurface`: con `shadow: 0` pintaba un bloque de tinta detrás, y las tarjetas punteadas transparentes ("Antes", "Esperando a tu amigo…") se veían negras.*
- [x] `xcodebuild … build test` pasa en el simulador, con `BalanceCalculatorTests` y `MoneyTests` en verde.
- [x] Verificar que las fuentes Archivo cargan (no debe verse la fuente del sistema).
- [x] Verificar que las ilustraciones y el ícono aparecen.
- [x] Recorrer el flujo completo en el simulador: onboarding → crear cuenta → invitar → conectados → inicio → agregar → gasto guardado → historial → detalle → eliminar → saldar → a paz y salvo → ajustes → cerrar sesión.
- [x] `cd backend && go test ./...` en verde.

**Hecho cuando:** la app corre en el simulador, todas las pruebas pasan y el flujo se recorre sin crashes.

## CP1 · Fidelidad visual contra el diseño
*Cambio de OpenSpec archivado en `openspec/changes/archive/2026-10-23-fidelidad-visual/`.*
- [x] Comparar cada pantalla con su captura en `docs/design/screens/` y anotar diferencias. *Lista en `openspec/changes/fidelidad-visual/tasks.md`.*
- [x] Corregir espaciados, tamaños y colores que no coincidan (usando solo los tokens de `DesignSystem`).
- [x] Recuperar el gesto de deslizar para volver con la barra de navegación oculta.
- [x] Revisar en iPhone SE (pantalla pequeña) e iPhone Pro Max: nada cortado y con scroll donde haga falta.
- [x] Definir el límite de Dynamic Type (por ejemplo, hasta `.accessibility1`) y probarlo. *Decidido: `.accessibility1`.*
- [x] Animación de presionar en los botones (la sombra baja a 0), verificada en un dispositivo. *En un iPhone 17 Pro; el botón queda hundido al menos 120 ms para que se vea en toques rápidos.*

Diferencias vistas en el recorrido del CP0 (punto de partida, no la lista completa):
- Inicio: el botón de ajustes usa un engranaje y el diseño un sol; "Ver todo" va subrayado en el diseño; "Domicilio Rappi" usa ícono de comida y el diseño una bolsa en durazno; el subtítulo de las filas parte la fecha en dos líneas.
- Agregar movimiento: la vista previa "Ahora: …" queda tapada por el teclado numérico; con el teclado del sistema abierto (concepto) el teclado numérico sigue visible y la pantalla se comprime.
- A paz y salvo: el texto de "Compartir con Jesús" dice "$20.000 el hoy, vie 23 de oct".

**Hecho cuando:** cada pantalla se ve como su captura en un iPhone de tamaño estándar y no se rompe en los extremos.

## CP2 · Supabase en local y base de datos validada
*Cambio de OpenSpec archivado en `openspec/changes/archive/2026-10-23-base-de-datos/`. 54 pruebas pgTAP en `supabase/tests/`.*
- [x] `supabase init`, `supabase start` y `supabase db reset` aplican la migración sin errores.
- [x] Script de pruebas SQL (pgTAP o un `.sql` con asserts) que cubra:
  - [x] `owed_by_other` con 50/50, porcentaje y "todo es del otro", incluido el redondeo de impares;
  - [x] la vista `ledger_balances` con el ejemplo canónico (−20.000 / +20.000);
  - [x] el máximo de dos miembros por cuenta;
  - [x] que quien paga sea miembro;
  - [x] RLS: un tercer usuario no ve nada; cada uno ve solo su cuenta;
  - [x] `create_ledger_with_invite` devuelve `CRZ-####`, el creador queda rosa y amarillo;
  - [x] `redeem_invite` une a la segunda persona en verde y violeta, y rechaza códigos vencidos, usados o propios.
- [x] Crear el proyecto de Supabase en la nube y `supabase db push`. *Proyecto `cruce` en West US (Oregon).*
- [x] Revisión independiente de seguridad. *Se corrigieron 6 hallazgos, incluido el código de invitación adivinable: ahora hay máximo 5 intentos fallidos por hora.*

**Hecho cuando:** las pruebas SQL pasan en local y la migración está aplicada en la nube.

## CP3 · Inicio de sesión
*Hecho por correo en el cambio `inicio-sesion-correo` (26 oct 2026), sin membresía de Apple. En testing (27 oct 2026) se configuró SMTP de Gmail y la plantilla, y Joan entró en "Cruce Test" con el código del correo. Falta que Jesús entre para cumplir el "Hecho cuando".*
- [x] Agregar `supabase-swift` vía SPM en `project.yml`. *Versión fija 2.55.4, solo en el target de la app.*
- [x] Configuración en `Config.xcconfig` (no en el código): `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
- [x] Protocolo `AuthService` y su implementación con Supabase; sesión persistente entre aperturas.
- [x] Inicio por correo con un código de 6 dígitos (sin enlace mágico ni contraseña).
- [ ] *Función posterior, con la membresía de Apple:* `SignInWithAppleButton` oficial y la capacidad Sign in with Apple.
- [x] Crear el perfil (`profiles`) con el nombre de `SignUpView`.
- [x] `RootView` decide la etapa según la sesión real: sin sesión → onboarding; sin perfil → pedir el nombre; con sesión y sin cuenta → invitar; con cuenta → inicio.

**Hecho cuando:** Joan y Jesús pueden iniciar sesión en dos simuladores y la sesión sobrevive a cerrar la app.

## CP4 · Vincular a los dos
*Hecho en local en el cambio `vincular-cruces` (27 oct 2026). En vez de tiempo real, la pantalla de invitar revisa cada 3 segundos (el tiempo real llega en el CP6). La migración ya está en testing (27 oct 2026); falta vincular a Joan y Jesús en "Cruce Test".*
- [x] Regla en la base: dos personas tienen como máximo un cruce entre ellas (migración nueva; `redeem_invite` responde con un error claro si ya existe ese cruce).
- [x] `InviteView` llama a `create_ledger_with_invite()` y muestra el código real.
- [x] `JoinView` valida con `redeem_invite(code)` y muestra el nombre real de quien invitó.
- [x] `InviteView` pasa a "Conectados" sola cuando el otro se une (tiempo real sobre `ledger_members`).
- [x] `Member.tikeVariant` y `avatarColor` salen de `ledger_members` (regla rosa y verde de verdad).
- [x] Mensajes de error en español: código vencido, usado o inválido.

**Hecho cuando:** con dos simuladores, uno invita, el otro se une y los dos llegan al inicio vacío.

## CP4b · Varios cruces
- [ ] La sesión conoce todos los cruces de quien entró (con quién, colores y recibo de cada uno), no un solo `partner`.
- [ ] El inicio: con un cruce, ese cruce (el diseño actual); con dos o más, "Tus cruces" con el saldo de cada uno, y al tocar uno se abre su inicio.
- [ ] "Invitar a alguien" desde el inicio y desde Ajustes crea un cruce nuevo con su código `CRZ-`; "Tengo un código" también acepta `CRZ-`.
- [ ] Los movimientos, el historial, saldar y Ajustes trabajan sobre el cruce abierto.
- [ ] "¿Lo pasas a tu cruce?" al cerrar un parche ofrece el cruce con cada persona que tenga la app.
- [ ] Pruebas de los stores con dos cruces y capturas de "Tus cruces".

**Hecho cuando:** Joan tiene un cruce con Jesús y otro con una tercera cuenta, ve los dos en "Tus cruces" con su saldo, y lo que anota en uno no aparece en el otro.

## CP5 · Movimientos contra Supabase
- [ ] `SupabaseLedgerRepository: LedgerRepository` con cargar, guardar (insert/update) y eliminar (borrado suave), siempre sobre el cruce abierto.
- [ ] Mapeo de `SplitRule` ↔ `split_type` + `other_share_percent`, y de `Movement.Kind` ↔ `kind`.
- [ ] El saldo se sigue calculando en la app; agregar una verificación en debug contra `ledger_balances`.
- [ ] Pruebas del mapeo (Codable) con JSON de ejemplo.
- [ ] Inyectar el repositorio real en `AppStores.live()` (raíz de composición en `CruceApp`); los datos de ejemplo ya quedan solo para Debug y las vistas previas (`AppStores.sample`).

**Hecho cuando:** lo que anota uno aparece en el otro al recargar, y el saldo coincide en los dos.

## CP6 · Tiempo real
- [ ] Suscripción a `movements` del ledger (insert, update y delete suave).
- [ ] `LedgerStore` aplica los cambios sin recargar todo y sin duplicados.
- [ ] Reconexión cuando la app vuelve al primer plano.

**Hecho cuando:** si Jesús anota un gasto, el inicio de Joan cambia en segundos sin tocar nada.

## CP7 · Modo sin conexión
- [ ] Detectar la red con `NWPathMonitor`; `LedgerStore.isOffline` refleja la realidad.
- [ ] Persistencia local de los movimientos (según la decisión abierta) y cola de pendientes.
- [ ] Reintentar automáticamente al volver la red; "Reintentar" en `OfflineView` fuerza el envío.
- [ ] Conflictos: si se editó en los dos lados, gana el último `updated_at`.

**Hecho cuando:** en modo avión se pueden anotar gastos, y al volver la red se sincronizan sin perder ni duplicar nada.

## CP8 · Backend desplegado
- [ ] Desplegar `backend/` con su Dockerfile en el hosting elegido.
- [ ] Variables `WEBHOOK_SECRET`, `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` configuradas como secretos.
- [ ] Database Webhook de `movements` (insert y update) apuntando a `/webhooks/movements` con `Authorization: Bearer`.
- [ ] Logs visibles con cada movimiento recibido.

**Hecho cuando:** anotar un gasto en la app deja una línea en el log del backend en producción.

## CP9 · Notificaciones push
- [ ] Migración nueva: tabla `device_tokens` (user_id, token, created_at) con RLS.
- [ ] La app pide permiso, registra el token y lo guarda.
- [ ] El backend firma un JWT ES256 con la llave de APNs (librería estándar `crypto/ecdsa`) y envía por HTTP/2.
- [ ] Avisar **solo a la otra persona**: "Jesús anotó Mercado Éxito · $100.000", "Joan saldó las cuentas" y "Jesús eliminó Almuerzo".
- [ ] Respetar el switch "Cuando … anote un gasto" de Ajustes (guardarlo en `profiles` o en una tabla de preferencias).

**Hecho cuando:** un gasto en el iPhone de Joan genera una notificación en el iPhone de Jesús.

## CP10 · Tareas programadas
- [ ] Recordatorio mensual para saldar si el saldo es distinto de $0 (en Go con un ticker, o con `pg_cron`).
- [ ] Limpieza diaria de invitaciones vencidas.
- [ ] Ajustes → "Recordarme saldar": nunca, cada semana o cada mes.

**Hecho cuando:** las dos tareas corren solas y dejan un registro.

## CP11 · Funciones pendientes de la interfaz
- [ ] "Cambiar monto" en Saldar (pago parcial), según la decisión abierta.
- [ ] Exportar el historial a CSV (ShareLink con el archivo).
- [ ] Desvincular a la otra persona, con confirmación y explicación de qué pasa con el historial.
- [ ] Editar el perfil (nombre).
- [ ] Reparto por defecto (`ledgers.default_other_percent`) usado en "Nuevo movimiento".
- [ ] Filas del historial: deslizar para eliminar, con confirmación.

**Hecho cuando:** ningún botón de la app está vacío.

## CP12 · Calidad
- [ ] Pruebas de captura de las pantallas principales (si se aprueba la dependencia).
- [ ] Recorrido completo con VoiceOver.
- [ ] Pruebas de la cola sin conexión de `LedgerStore` con un repositorio falso (guardar, eliminar, saldar y fallo de sincronización ya tienen pruebas desde `ordenar-app-ios`).
- [x] CI en GitHub Actions: `go test`, pruebas SQL y `swift test` en Linux; `xcodebuild` se corre a mano con `ios.yml` (hecho en `base-de-calidad`).

**Hecho cuando:** cada PR corre las pruebas automáticamente y VoiceOver lee bien todo el flujo.

## CP13 · TestFlight
- [ ] Bundle ID definitivo, equipo y firma de distribución.
- [ ] `PrivacyInfo.xcprivacy` y textos de permisos (notificaciones).
- [ ] Ícono final y pantalla de arranque.
- [ ] Subir el build a App Store Connect e invitar a Jesús como probador.

**Hecho cuando:** Joan y Jesús tienen Cruce instalada desde TestFlight y llevan sus cuentas reales.
