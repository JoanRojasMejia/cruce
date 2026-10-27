# Tasks

## 1. Movimientos por cruce (CruceCore)

- [x] 1.1 Cambiar `LedgerRepository` a `loadMovements(in:)`, `save(_:in:)` y `delete(id:in:)`; `InMemoryLedgerRepository` guarda por cruce y `FailingLedgerRepository` se ajusta. Escribir antes la prueba "lo que se guarda en un cruce no aparece en otro" y verla fallar; ajustar las pruebas actuales del repositorio sin cambiar lo que aseguran. Verificar con `swift test`.
- [x] 1.2 `LedgerStore` con `movementsByCruce`:
  - lecturas del cruce abierto;
  - `net(of:)` y `phrase(forNet:partner:)` para cualquier cruce;
  - `save`, `delete` y `settle` en el cruce abierto;
  - `load()` de todos los cruces.
  
  Pruebas antes:
  - anotar en el cruce de Ana no cambia el de Jesús;
  - saldar uno deja el otro igual;
  - la frase de cada cruce nombra a su persona ("Le debes $15.000 a Ana").
  
  Las pruebas actuales de `LedgerStore` pasan a una sesión con un cruce. Verificar con `swift test` y `swift format lint --strict`.

## 2. Cruce abierto en la sesión (CruceCore)

- [x] 2.1 `SessionStore`:
  - `openCruceID`, `openCruce` y `open(_:)`, que copia `partner`, color y recibo;
  - `init(cruces:)` para los datos de ejemplo;
  - `refresh()` y `join` conservan el cruce abierto si sigue existiendo;
  - `lastLinked`;
  - `checkForPartner()` y `join(code:)` en `.main` detectan el cruce nuevo, lo abren y dejan `lastLinked` sin cambiar de etapa.
  
  Pruebas antes:
  - abrir el cruce de Ana cambia `partner` y el recibo a verde;
  - el cruce abierto se conserva después de `refresh()`;
  - en `.main`, cuando alguien se une al código pendiente, aparece `lastLinked` y la etapa sigue en `.main`;
  - unirse en `.main` abre el cruce nuevo.
  
  Verificar con `swift test`.
- [x] 2.2 `Route`: agregar `.cruce(UUID)`, `.invite` y `.join`, con sus pruebas del `Router` si aplica. Verificar con `swift test`.

## 3. Pantallas

- [x] 3.1 `MockData.ana` con movimientos de ejemplo, y `AppStores.sample(cruces:)`: por defecto un cruce Joan–Jesús y, si se pide, dos cruces. Verificar que `xcodebuild … build` compila y que las capturas actuales de `-screen homeTheyOwe` y `history` no cambian.
- [x] 3.2 `CruceListView` ("Tus cruces"):
  - filas con avatar, nombre, frase y monto con signo;
  - "Invitar a alguien" y "Tengo un código";
  - la sección de parches;
  - su `#Preview` y `-screen cruces`.
  
  `MainView` usa la lista como raíz con dos o más cruces. Verificar con la captura de `-screen cruces` en iPhone 16 y SE, con la frase y el signo de cada fila, y solo con tokens de `DesignSystem`.
- [x] 3.3 `RouteDestinations`: `.cruce(id)` abre y empuja `HomeView(showsBack:)` (volver y "Con Ana"); `.invite` y `.join` empujan sus pantallas. "Conectados" sale como hoja completa con `lastLinked`, y "Ir al inicio" abre el cruce nuevo. Verificar con `-screen cruceAna`: el encabezado con volver, el saldo con Ana y el recibo verde.
- [x] 3.4 Ajustes con "Invitar a alguien". `EnterCodeView` con `CRZ-` en `.main` empuja `.join` con el código, y se borra el mensaje "Pronto vas a poder tener más de un cruce". Verificar con `xcodebuild … build` de los tres esquemas.

## 4. Verificación y documentación

- [x] 4.1 De punta a punta contra Supabase local: Joan (simulador) con un cruce con Jesús (API) invita desde "Tus cruces" o Ajustes; Ana (API) se une, y en la app de Joan aparece "Conectados" con Ana y después la lista con dos cruces. Luego Joan se une con "Tengo un código" al código de Pedro (API) y queda con tres. Anotar un gasto en el cruce de Ana y verificar que no aparece en el de Jesús.
- [x] 4.2 Actualizar:
  - CLAUDE.md §1 (quitar "hasta entonces la app asume uno solo"), §2, §5 (fila de "Tus cruces" y `-screen cruces` y `cruceAna`), §6 (`openCruce`, `LedgerStore` por cruce y rutas) y §8;
  - `docs/diseno.md` (la pantalla nueva y sus componentes);
  - ROADMAP: marcar el CP4b;
  - `ios/README.md`.
  
  Verificar que `rg -n "Pronto vas a poder" ios` no encuentra nada.
- [ ] 4.3 Suite completa: `swift test`, el lint, el backend, `supabase test db` (sobre una base limpia) y `xcodebuild` de los tres esquemas. Después Joan y Jesús prueban en "Cruce Test": cada uno invita o se une con una tercera cuenta y ve "Tus cruces".

## Workflow follow-up

- Archivar con `openspec archive varios-cruces` cuando se cumpla el "Hecho cuando" del CP4b y proponer el commit.
- Siguiente: CP5 (movimientos contra Supabase, por cruce).
