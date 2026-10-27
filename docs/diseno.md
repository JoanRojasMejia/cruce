# Diseño

La fuente de verdad visual es el canvas **"Cruce — 3 propuestas"** en Claude, página **"Opción A · flujo completo"**: 20 pantallas y la **Guía de estilo · Cruce**.

Los valores de la guía están en código en `ios/Cruce/DesignSystem`. Si cambias algo del diseño, cámbialo en los dos lados.

## Tokens

| Token | Valor | Uso |
|---|---|---|
| Amarillo | `#FFD12E` | Acción principal, marca, avatar de Joan |
| Violeta | `#8B6CFF` | Avatar de Jesús, invitación, ocio |
| Verde | `#3DCB4A` | Saldo a favor, éxito, mercado |
| Rosa | `#FF5C8A` | Saldo en contra, error, eliminar, comida |
| Lima | `#B5E33B` | Vista previa del saldo, "después" |
| Durazno | `#FFE19A` | Transporte, pendientes |
| Tinta | `#111111` | Texto, bordes, sombras |
| Crema | `#FBF6EA` | Fondo de pantallas |
| Gris texto | `#4A4A4A` | Texto secundario |
| Gris línea | `#E2DBCB` | Separadores |
| Gris neutro | `#D9D4C7` | Pestaña del saldo en $0 |

- **Tipografía:** Archivo 500–900 (licencia OFL, incluida en la app). Los párrafos (`body` 15 y `bodyLarge` 16) usan 22 de alto de línea. Las fechas cortas van sin "de": "14 oct", "vie 23 oct".
- **Botones lado a lado:** usan el texto de `buttonSecondary` (16 / 800) aunque sean primarios, para que quepan los dos.
- **Texto grande:** la app respeta Dynamic Type hasta `accessibility1`.
- **Bordes:** 2 / 2,5 / 3 px. **Radios:** 10 chip · 12 input · 14 botón · 16 tarjeta · 20 diálogo · 28 hoja.
- **Sombras:** sólidas, sin blur, desplazamiento igual en x e y: 2, 3, 4, 5, 6, 8 px.
- **Espaciado:** margen lateral 20, área táctil mínima 44.

## Tus cruces (sin captura en el canvas)

Con dos o más cruces, el inicio es "Tus cruces" (`CruceListView`). Se armó con las piezas de "Tus parches" y los tokens de esta guía, sin colores ni tamaños nuevos:

- **Encabezado:** el mismo del inicio (`MainHeader`: logo, aviso sin conexión y Ajustes). El título "Tus cruces" va en `title1Compact` y el texto de abajo en `body`.
- **Fila de cada cruce (`CruceRow`):** `Avatar` de la otra persona (44 pt), "Con Ana" en `rowTitle`, la frase del saldo en `secondary` y, a la derecha, el monto con signo (Archivo Black 18, con el menos tipográfico) y "a tu favor" o "a favor de Ana". Es una superficie `neoSurface` con `Radius.card` y `ShadowOffset.s`, igual que `ParcheRow`. La dirección de la deuda va en texto, no solo en el color.
- **Botones:** "Invitar a alguien" y "Tengo un código", con `NeoButtonStyle(kind: .secondary, height: 52)`. Van lado a lado si hay al menos 340 pt y, si no (iPhone SE o texto grande), uno debajo del otro.
- **Inicio de un cruce desde la lista:** `HomeView` cambia el logo por el botón de volver y el título "Con Ana" (`title2`).

## Ilustraciones

En `ios/Cruce/Resources/Assets.xcassets/Illustrations`, a @2x y @3x. Los originales están en `new-idea-proyect/ilustrations`.

| Asset | Pantalla |
|---|---|
| `il-01-bienvenida` | Onboarding 1, Conectados |
| `il-02-sin-movimientos` | Inicio vacío |
| `il-03-gasto-guardado` | Hoja "Gasto guardado" |
| `il-04-te-deben-rosa` / `-verde` | Inicio a favor (rosa = Joan, verde = Jesús) |
| `il-05-debes-rosa` / `-verde` | Inicio en contra |
| `il-06-saldar` | Saldar cuentas |
| `il-07-paz-y-salvo` | Éxito, onboarding 3 |
| `il-08-sin-conexion` | Sin conexión |
