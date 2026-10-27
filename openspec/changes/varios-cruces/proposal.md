# Proposal

## Why

Desde el CP4, la base y la sesión ya manejan varios cruces por persona (uno por pareja), pero la app todavía trabaja con uno solo:
- el inicio, el historial, saldar y Ajustes usan siempre el cruce más reciente (`SessionStore.partner`);
- los movimientos no saben de qué cruce son;
- teniendo ya un cruce no hay cómo invitar a alguien más, y "Tengo un código" con un `CRZ-` responde "Pronto vas a poder tener más de un cruce".

Este cambio hace que la funcionalidad principal, varios cruces, se pueda usar en la app.

## What Changes

- **"Tus cruces":**
  - con dos o más cruces, el inicio muestra la lista de cruces, cada uno con la otra persona y su saldo con la frase, el signo y el monto;
  - al tocar uno, se abre su inicio de siempre, con la flecha para volver a la lista;
  - con un solo cruce, el inicio es ese cruce, como en el diseño actual.
- **El cruce abierto:**
  - anotar, el historial, el detalle, saldar, "A paz y salvo", Ajustes y la pantalla sin conexión trabajan sobre el cruce abierto;
  - los colores y el recibo de quien usa la app son los de ese cruce, así que alguien puede ser rosa en un cruce y verde en otro.
- **Los movimientos son de un cruce:** el repositorio guarda y carga por cruce, y lo que se anota en un cruce no aparece en otro. En Supabase eso es `movements.ledger_id` (CP5).
- **Invitar teniendo ya un cruce:**
  - "Invitar a alguien" en "Tus cruces" y en Ajustes abre la pantalla de invitar con el código del cruce pendiente;
  - cuando la otra persona se une, aparece "Conectados" y después se abre ese cruce.
- **Unirse teniendo ya un cruce:** "Tengo un código" con un `CRZ-` abre la pantalla de unirse con el código ya escrito, con la vista previa ("Cuenta de Ana") y la regla de un cruce por pareja.
- **Parches:** "¿Lo pasas a tu cruce?" ya ofrece el cruce con cada persona; no cambia. La deuda que se pasa al cruce se ve en ese cruce cuando los movimientos estén en Supabase (CP5).

**Fuera de alcance:**
- movimientos contra Supabase (CP5);
- desvincular;
- recordar el último cruce abierto entre aperturas de la app (por ahora se abre el más reciente);
- reordenar o renombrar cruces.

## Capabilities

### New Capabilities
- `cruces`: la lista "Tus cruces", el cruce abierto y que los movimientos, el saldo y los colores sean de cada cruce.

### Modified Capabilities
- `vinculacion`: invitar a alguien y unirse con un código teniendo ya un cruce.
- `presentacion-saldo`: el recibo y el color de quien mira son los del cruce abierto.

## Impact

- **CruceCore:**
  - `SessionStore`: cruce abierto, `open(_:)`, `partner` y los colores de `me` según el cruce abierto, y detectar un cruce nuevo fuera de la etapa de invitar;
  - `LedgerRepository` e `InMemoryLedgerRepository` por cruce;
  - `LedgerStore` con movimientos por cruce y saldo de cada uno;
  - `Route`: la lista de cruces, un cruce, invitar y unirse;
  - pruebas de los stores con dos cruces.
- **App:**
  - `RootView` y `MainView`: la raíz es "Tus cruces" o el único cruce;
  - pantalla nueva `CruceListView`, con su `#Preview` y su entrada `-screen`;
  - `HomeView` (volver a la lista);
  - `SettingsView` ("Invitar a alguien");
  - `InviteView` y `JoinView` dentro de la navegación;
  - `EnterCodeView`;
  - `AppStores.sample` con cruces.
- **Base de datos:** sin cambios.
- **Documentación:** CLAUDE.md §1, §2, §5 y §6, ROADMAP y `docs/diseno.md` (la pantalla nueva sin captura del canvas).
- **Sin dependencias nuevas.**
