# Cruce · app iOS (SwiftUI)

iOS 17+, solo iPhone, modo claro. Hoy funciona con **datos de ejemplo**: todo el flujo se puede recorrer sin backend.

## Abrir el proyecto

```bash
brew install xcodegen      # una sola vez
cd ios
xcodegen                   # genera Cruce.xcodeproj desde project.yml
open Cruce.xcodeproj
```

En Xcode: **Signing & Capabilities → Team**, elige tu cuenta y corre en el simulador o en tu iPhone.
Las pruebas corren con `⌘U`.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `Cruce/DesignSystem` | Tokens de la guía de estilo: colores, tipografía Archivo, radios, bordes, sombras, espaciados, botones e ilustraciones. |
| `Cruce/Components` | Piezas reutilizables: tarjeta carpeta, fila de movimiento, chips, segmentado, teclado, avatar, logo. |
| `Cruce/Models` | `Member`, `Movement`, `SplitRule`, `MovementCategory`. |
| `Cruce/Domain` | Lógica pura: saldo neto (`BalanceCalculator`), formato de pesos (`Money`), fechas en español. |
| `Cruce/Data` | `LedgerRepository` (interfaz) + versión en memoria y datos de ejemplo. Aquí entra Supabase en el punto 2. |
| `Cruce/Screens` | Las pantallas del canvas, cada una con su `#Preview`. |
| `Cruce/Resources` | Fuentes Archivo (licencia OFL), ilustraciones @2x/@3x, ícono de la app. |
| `CruceTests` | Pruebas del saldo y del formato de pesos. |

## Pantallas del canvas → código

| Canvas | Vista |
|---|---|
| 01, 11, 12 Onboarding | `OnboardingView` |
| 13 Crear cuenta · 14 Invitar · 15 Unirse · 16 Conectados | `SignUpView`, `InviteView`, `JoinView`, `ConnectedView` |
| 02, 03, 04, 20 Inicio (vacío, te deben, debes, vista de Jesús) | `HomeView` (cambia según el saldo y quién usa la app) |
| 05 Agregar movimiento | `AddMovementView` (también edita) |
| 06 Gasto guardado | `MovementSavedSheet` |
| 07 Historial | `HistoryView` |
| 17 Detalle · 18 Eliminar | `MovementDetailView` + `DeleteConfirmation` |
| 08 Saldar · 09 A paz y salvo | `SettleView`, `SettleSuccessView` |
| 10 Sin conexión | `OfflineView` |
| 19 Ajustes | `SettingsView` |

## Reglas que el código respeta

- **Recibo rosa o verde:** sale de `Member.tikeVariant` (rosa para quien creó la cuenta, verde para quien se unió). Ver `AppState.balanceIllustration`.
- **Dinero:** `Int` en pesos, nunca `Double`. Formato `$30.000` con `Money.format`.
- **Saldo:** nunca se guarda; se calcula con `BalanceCalculator.net`.
- **Quién le debe a quién:** siempre con texto, signo y flecha, no solo color.

## Pendiente

- Botón oficial `SignInWithAppleButton` (requiere la membresía de Apple Developer) y sesión de Supabase.
- `SupabaseLedgerRepository` con tiempo real y cola para el modo sin conexión.
- "Cambiar monto" en Saldar (pago parcial), exportar CSV y desvincular.
