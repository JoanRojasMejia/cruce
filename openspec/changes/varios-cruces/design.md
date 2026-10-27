# Design

## Context

- **Sesión:** `SessionStore` ya tiene `cruces: [CruceLink]` (del más reciente al más viejo) y deriva `partner` y los colores de `me` del más reciente (`apply`). Unas 30 lecturas de `session.partner` en las vistas (inicio, anotar, historial, detalle, saldar, "A paz y salvo", Ajustes, sin conexión y `MovementRow`) suponen una sola otra persona. `member(_:)` devuelve `partner` para cualquier id que no sea `me`.
- **Movimientos:**
  - `Movement` no tiene id de cruce;
  - `LedgerRepository` (`loadMovements`, `save`, `delete`) e `InMemoryLedgerRepository` son una sola lista plana;
  - `LedgerStore` guarda un solo arreglo y calcula `net`, `phrase` y `settle` con `session.me` y `session.partner`.
- **Navegación:**
  - `Route` no tiene un caso para los cruces ni para invitar;
  - `MainView` arranca en `HomeView`;
  - `InviteFlow` vive solo en la etapa `.invite`, y desde el inicio no hay forma de invitar;
  - "Tengo un código" con `CRZ-` en `.main` responde "Pronto vas a poder tener más de un cruce".
- **Parches:** `ParcheStore.cruceCandidates` ya ofrece una tarjeta por cada persona con cruce, y la base elige el cruce de esa pareja.
- **Datos de ejemplo:** `AppStores.sample` nunca llena `cruces`, y `apply` es privado.
- **Diseño:** el canvas no tiene una pantalla "Tus cruces".

## Goals / Non-Goals

**Goals:**
- Que las vistas sigan leyendo `session.partner` sin cambiar, pero que `partner` sea siempre la otra persona del cruce abierto.
- Que la frontera de los movimientos (`LedgerRepository`) ya sea por cruce, para que en el CP5 `SupabaseLedgerRepository` solo agregue el `ledger_id`.

**Non-Goals:**
- Movimientos en Supabase (CP5).
- Desvincular.
- Recordar el cruce abierto entre aperturas de la app.
- Diseñar en el canvas: la pantalla nueva se arma con los componentes y los tokens que ya existen.

## Decisions

### D1. El cruce abierto vive en `SessionStore`
- **Qué hay:** `openCruceID: UUID?`, `openCruce: CruceLink?` y `open(_ id:)`.
- **`open`:** fija el cruce y copia su `partner`, `myAvatarColor` y `myTikeVariant` a `partner` y a `me`. `partner` sigue siendo una propiedad guardada, así que ninguna de las ~30 vistas cambia.
- **`refresh()` y `join`:** conservan el cruce abierto si sigue existiendo; si no, abren el más reciente.
- **Datos de ejemplo:** `SessionStore.init` acepta `cruces:` y abre el primero.
- **Alternativa descartada:** pasar el `CruceLink` a cada vista por parámetro. Toca 30 lugares y cada `#Preview`, sin ganar nada sobre una sola fuente de verdad.

### D2. Los movimientos se guardan por cruce en el repositorio, no en `Movement`
- **Cambio en `LedgerRepository`:**
  - `loadMovements(in cruce: UUID)`;
  - `save(_:in:)`;
  - `delete(id:in:)`.
- **`InMemoryLedgerRepository`:** guarda `[cruce: [id: Movement]]`.
- **`Movement` no cambia:** el cruce es dónde vive el movimiento, no un dato que se edite (la base ya impide moverlo de cuenta). En el CP5 el repositorio de Supabase lo mapea a `movements.ledger_id`.
- **Alternativa descartada:** agregar `cruceID` a `Movement`. Obliga a llenarlo en cada `Movement(...)` de las pruebas y de `MockData` y abre la puerta a un movimiento con un cruce distinto al del repositorio.

### D3. `LedgerStore` guarda los movimientos de cada cruce
- **Movimientos:** `movementsByCruce: [UUID: [Movement]]`. `movements`, `visibleMovements`, `net`, `balance`, `phrase` y `settle` leen los del cruce abierto. Así las vistas no cambian.
- **Para la lista:** `net(of:)` y `phrase(forNet:partner:)` dan el saldo y la frase de cualquier cruce.
- **Cargar:**
  - `load()` carga los de todos los cruces de la sesión;
  - `save`, `delete` y `settle` escriben en el cruce abierto;
  - la cola de pendientes sin conexión sigue siendo una sola cuenta, que es lo que muestra la pantalla de sin conexión.
- **Cuándo recargar:** la vista llama `ledger.load()` al cambiar los cruces (por ejemplo, después de unirse), igual que hoy al arrancar.

### D4. Navegación: la raíz depende de cuántos cruces hay
- **La raíz de `MainView`:** `CruceListView` si hay dos o más cruces; si no, `HomeView`.
- **Rutas nuevas en `Route`:**
  - `.cruce(UUID)` abre ese cruce (`session.open`) y empuja `HomeView`;
  - `.invite` y `.join` empujan `InviteView` y `JoinView` dentro de la misma pila.
- **"Conectados" desde `.main`:** se muestra como hoja completa cuando aparece `session.lastLinked` (igual que `lastSettlement` abre "A paz y salvo"). "Ir al inicio" hace `popToRoot` y abre el cruce nuevo.
- **Alternativa descartada:** volver a la etapa `.invite` o `.connected`. Cambiar de etapa desmonta toda la navegación del inicio y los parches.

### D5. Invitar y unirse sin cambiar de etapa
- **`checkForPartner()`:**
  - en `.invite` hace lo de siempre (pasa a `.connected`);
  - en `.main` detecta un cruce cuyo id no estaba antes, lo guarda en `lastLinked` y lo abre.
- **`join(code:)`:**
  - en `.join` pasa a `.connected`, como hoy;
  - en `.main` deja `lastLinked` y abre el cruce nuevo.
- **"Tengo un código" con `CRZ-`:**
  - en `.main` guarda `pendingJoinCode` y empuja `.join`;
  - sin cruce sigue como hoy.

### D6. "Tus cruces" se arma como la lista de parches
- **`CruceListView`:** el encabezado del inicio (logo y botón de Ajustes), el título "Tus cruces" y una fila por cruce.
- **Cada fila:** `Avatar` de la otra persona, su nombre, la frase de `phrase(forNet:partner:)` y el monto con signo (`Money.format(_, showsSign:)`). Así la dirección no depende solo del color.
- **Debajo:** los botones "Invitar a alguien" y "Tengo un código", con el mismo estilo de `ParcheEntryButtons`, y la sección "Tus parches".
- **Estilo:** solo los tokens de `DesignSystem` (`neoSurface`, `Radius`, `Spacing`, `TextStyleToken`).
- **Sin canvas:** se documenta en `docs/diseno.md` y Joan revisa las capturas.

### D7. El inicio de un cruce, cuando hay varios
- **Encabezado:** con dos o más cruces, `HomeView` cambia el logo por un botón de volver y el título "Con Ana". El botón de Ajustes sigue a la derecha.
- **Con un solo cruce:** el encabezado no cambia.

### D8. Ajustes
- **Cruce abierto:** la sección "CUENTA COMPARTIDA" sigue mostrando el cruce abierto.
- **Fila nueva:** "Invitar a alguien", que empuja `.invite`.
- **Lo que no cambia:** el perfil, las notificaciones y cerrar sesión.

### D9. Datos de ejemplo con varios cruces
- **`MockData`:** suma a Ana y unos movimientos de ejemplo con ella.
- **`AppStores.sample(cruces:)`:**
  - por defecto, un solo cruce Joan–Jesús, para que las pantallas y capturas actuales no cambien;
  - `-screen cruces` usa dos cruces con saldos distintos;
  - `-screen cruceAna` abre el inicio del cruce con Ana.

## Risks / Trade-offs

- **[Dónde se abre `HomeView`]** `HomeView` aparece como raíz o empujada → Un parámetro (`showsBack`) decide el encabezado, y la vista previa cubre los dos casos.
- **[Cambio de raíz al pasar de uno a dos cruces]** Al unirse al segundo cruce, la raíz cambia de `HomeView` a `CruceListView` → "Ir al inicio" hace `popToRoot` y abre el cruce nuevo. Se revisa en el simulador.
- **[Movimientos solo en memoria]** Hasta el CP5, los movimientos de los cruces reales empiezan vacíos en cada apertura → Es igual que hoy. Las pruebas usan el repositorio en memoria con dos cruces.
- **[La deuda que viene de un parche]** El movimiento que crea "pasar al cruce" está en la base pero no en `LedgerStore` → Ya pasaba antes y se resuelve en el CP5. Va en el ROADMAP.
- **[`member(_:)`]** Devuelve `partner` para cualquier id que no sea `me` → Como `LedgerStore` solo da los movimientos del cruce abierto, los ids siempre son de esas dos personas.
