# Roadmap de Cruce

Se trabaja **un checkpoint a la vez, en orden**. Cada uno termina con sus pruebas en verde y un commit.
Marca `[x]` cuando una tarea esté hecha y actualiza la sección "Estado actual" de `CLAUDE.md`.
Cada checkpoint se lleva como un cambio de OpenSpec en `openspec/changes/` (ver `CLAUDE.md` §9); al cerrarlo se archiva y sus requisitos pasan a `openspec/specs/`.

---

## Decisiones abiertas (las toma Joan)

- [ ] **Membresía de Apple Developer:** ¿se paga ya? La necesitan Sign in with Apple (CP3), las notificaciones push (CP9) y TestFlight (CP13). Sin ella, el CP3 usa inicio de sesión por correo (OTP) solo para desarrollo.
- [ ] **Hosting del backend de Go:** Fly.io, Render, Railway u otro (CP8).
- [ ] **Persistencia local para el modo sin conexión:** SwiftData o archivo JSON (CP7).
- [ ] **Pago parcial ("Cambiar monto" en Saldar):** ¿se permite pagar menos del total? (CP11).
- [ ] **Pruebas de captura:** ¿se agrega `swift-snapshot-testing`? (CP12).

---

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
*Cambio de OpenSpec: `openspec/changes/fidelidad-visual/`.*
- [x] Comparar cada pantalla con su captura en `docs/design/screens/` y anotar diferencias. *Lista en `openspec/changes/fidelidad-visual/tasks.md`.*
- [x] Corregir espaciados, tamaños y colores que no coincidan (usando solo los tokens de `DesignSystem`).
- [x] Recuperar el gesto de deslizar para volver con la barra de navegación oculta.
- [x] Revisar en iPhone SE (pantalla pequeña) e iPhone Pro Max: nada cortado y con scroll donde haga falta.
- [x] Definir el límite de Dynamic Type (por ejemplo, hasta `.accessibility1`) y probarlo. *Decidido: `.accessibility1`.*
- [ ] Animación de presionar en los botones (la sombra baja a 0), verificada en un dispositivo.

Diferencias vistas en el recorrido del CP0 (punto de partida, no la lista completa):
- Inicio: el botón de ajustes usa un engranaje y el diseño un sol; "Ver todo" va subrayado en el diseño; "Domicilio Rappi" usa ícono de comida y el diseño una bolsa en durazno; el subtítulo de las filas parte la fecha en dos líneas.
- Agregar movimiento: la vista previa "Ahora: …" queda tapada por el teclado numérico; con el teclado del sistema abierto (concepto) el teclado numérico sigue visible y la pantalla se comprime.
- A paz y salvo: el texto de "Compartir con Jesús" dice "$20.000 el hoy, vie 23 de oct".

**Hecho cuando:** cada pantalla se ve como su captura en un iPhone de tamaño estándar y no se rompe en los extremos.

## CP2 · Supabase en local y base de datos validada
- [ ] `supabase init`, `supabase start` y `supabase db reset` aplican la migración sin errores.
- [ ] Script de pruebas SQL (pgTAP o un `.sql` con asserts) que cubra:
  - [ ] `owed_by_other` con 50/50, porcentaje y "todo es del otro", incluido el redondeo de impares;
  - [ ] la vista `ledger_balances` con el ejemplo canónico (−20.000 / +20.000);
  - [ ] el máximo de dos miembros por cuenta;
  - [ ] que quien paga sea miembro;
  - [ ] RLS: un tercer usuario no ve nada; cada uno ve solo su cuenta;
  - [ ] `create_ledger_with_invite` devuelve `CRZ-####`, el creador queda rosa y amarillo;
  - [ ] `redeem_invite` une a la segunda persona en verde y violeta, y rechaza códigos vencidos, usados o propios.
- [ ] Crear el proyecto de Supabase en la nube y `supabase db push`.

**Hecho cuando:** las pruebas SQL pasan en local y la migración está aplicada en la nube.

## CP3 · Inicio de sesión
- [ ] Agregar `supabase-swift` vía SPM en `project.yml`.
- [ ] Configuración en `Config.xcconfig` (no en el código): `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
- [ ] Protocolo `AuthService` y su implementación con Supabase; sesión persistente entre aperturas.
- [ ] Con membresía de Apple: `SignInWithAppleButton` oficial y la capacidad Sign in with Apple. Sin membresía: inicio por correo (OTP) para desarrollo.
- [ ] Crear el perfil (`profiles`) con el nombre de `SignUpView`.
- [ ] `RootView` decide la etapa según la sesión real: sin sesión → onboarding; con sesión y sin cuenta → invitar; con cuenta → inicio.

**Hecho cuando:** Joan y Jesús pueden iniciar sesión en dos simuladores y la sesión sobrevive a cerrar la app.

## CP4 · Vincular a los dos
- [ ] `InviteView` llama a `create_ledger_with_invite()` y muestra el código real.
- [ ] `JoinView` valida con `redeem_invite(code)` y muestra el nombre real de quien invitó.
- [ ] `InviteView` pasa a "Conectados" sola cuando el otro se une (tiempo real sobre `ledger_members`).
- [ ] `Member.tikeVariant` y `avatarColor` salen de `ledger_members` (regla rosa y verde de verdad).
- [ ] Mensajes de error en español: código vencido, usado o inválido.

**Hecho cuando:** con dos simuladores, uno invita, el otro se une y los dos llegan al inicio vacío.

## CP5 · Movimientos contra Supabase
- [ ] `SupabaseLedgerRepository: LedgerRepository` con cargar, guardar (insert/update) y eliminar (borrado suave).
- [ ] Mapeo de `SplitRule` ↔ `split_type` + `other_share_percent`, y de `Movement.Kind` ↔ `kind`.
- [ ] El saldo se sigue calculando en la app; agregar una verificación en debug contra `ledger_balances`.
- [ ] Pruebas del mapeo (Codable) con JSON de ejemplo.
- [ ] Inyectar el repositorio real en `CruceApp`; los datos de ejemplo quedan solo para las vistas previas.

**Hecho cuando:** lo que anota uno aparece en el otro al recargar, y el saldo coincide en los dos.

## CP6 · Tiempo real
- [ ] Suscripción a `movements` del ledger (insert, update y delete suave).
- [ ] `AppState` aplica los cambios sin recargar todo y sin duplicados.
- [ ] Reconexión cuando la app vuelve al primer plano.

**Hecho cuando:** si Jesús anota un gasto, el inicio de Joan cambia en segundos sin tocar nada.

## CP7 · Modo sin conexión
- [ ] Detectar la red con `NWPathMonitor`; `AppState.isOffline` refleja la realidad.
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
- [ ] Pruebas de `AppState` (guardar, eliminar, saldar, cola sin conexión) con un repositorio falso.
- [ ] CI en GitHub Actions: `go test`, pruebas SQL y `xcodebuild test`.

**Hecho cuando:** cada PR corre las pruebas automáticamente y VoiceOver lee bien todo el flujo.

## CP13 · TestFlight
- [ ] Bundle ID definitivo, equipo y firma de distribución.
- [ ] `PrivacyInfo.xcprivacy` y textos de permisos (notificaciones).
- [ ] Ícono final y pantalla de arranque.
- [ ] Subir el build a App Store Connect e invitar a Jesús como probador.

**Hecho cuando:** Joan y Jesús tienen Cruce instalada desde TestFlight y llevan sus cuentas reales.
