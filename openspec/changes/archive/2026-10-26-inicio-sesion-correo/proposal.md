# Proposal

## Why

La app todavía no tiene inicio de sesión real: `SignUpView` muestra un botón "Continuar con Apple" que solo simula el paso, y `SessionStore` arranca con datos de ejemplo. Sin sesión real no se puede avanzar a vincular a los dos (CP4) ni a guardar movimientos en Supabase (CP5).

Sign in with Apple requiere la membresía de Apple Developer (USD 99 al año), que por ahora no se va a pagar. El roadmap ya prevé el camino sin membresía: inicio de sesión por correo con un código de un solo uso (OTP). Este cambio implementa ese camino. Sign in with Apple queda como una función posterior, para cuando se pague la membresía.

## What Changes

- **Inicio de sesión con código por correo**: la persona escribe su correo, recibe un código de 6 dígitos y lo escribe en la app (`signInWithOTP` y `verifyOTP` de supabase-swift). No usa enlaces mágicos, porque abrir la app desde un enlace del correo requiere Associated Domains, que también exige la membresía. El mismo flujo sirve para crear la cuenta y para volver a entrar.
- **Se quita el botón simulado "Continuar con Apple"** de `SignUpView`. En su lugar va el campo de correo y, después, la pantalla del código. Apple exige su botón oficial, así que el botón simulado no puede quedar en la app.
- **Sesión persistente**: la sesión sobrevive a cerrar y abrir la app (supabase-swift la guarda en el llavero).
- **Perfil**: después del primer código, la app pide el nombre y crea la fila en `profiles` (`id = auth.uid()`, ya permitido por la política "crear mi perfil").
- **`RootView` decide la etapa según la sesión real**: sin sesión → onboarding; con sesión y sin perfil → pedir el nombre; con perfil y sin cuenta compartida → invitar; con cuenta → inicio.
- **`AuthService`**: un protocolo en `CruceCore` (para probar `SessionStore` con un doble, sin red) y su implementación con supabase-swift en la app.
- **Configuración fuera del código**: `SUPABASE_URL` y `SUPABASE_ANON_KEY` en `Config.xcconfig`; Debug apunta a Supabase local y Release a la nube. La clave anónima es pública por diseño (la protege RLS).
- **Plantilla del correo con el código** (`{{ .Token }}`) en `supabase/templates/`, usada en local; en la nube se pega la misma plantilla desde el panel.
- **Cerrar sesión** de verdad desde ajustes.
- **Documentación**: `CLAUDE.md` (§2 estado, §4 cómo correr, §6 piezas clave, §8 Apple), `docs/ROADMAP.md` (CP3 y la decisión de Apple) e `ios/README.md`.

No es parte de este cambio: Sign in with Apple, crear la cuenta compartida o canjear invitaciones (CP4), movimientos contra Supabase (CP5), SMTP propio ni cambios de diseño fuera de la pantalla de entrada.

## Capabilities

### New Capabilities
- `inicio-sesion`: entrar con un código por correo, mantener la sesión, crear el perfil, decidir la etapa de entrada y cerrar sesión.

### Modified Capabilities
<!-- Ninguna. -->

## Impact

- **App** (`ios/Cruce`): `project.yml` agrega supabase-swift por SPM solo al target de la app; nuevos `Config.xcconfig` (ignorado por git) y `Config.example.xcconfig`; `SupabaseAuthService`; cambian `SignUpView`, `RootView`, `CruceApp`/`AppStores.live()` y ajustes. `AppStores.sample()` y `DebugScreen` siguen igual.
- **CruceCore**: protocolo `AuthService`, `SessionStore` con la etapa derivada de la sesión y pruebas con Swift Testing y un doble de `AuthService`. CruceCore no depende de supabase-swift, así que la CI en Linux no cambia.
- **Base de datos**: sin migraciones. `supabase/config.toml` apunta a la plantilla del correo.
- **Nube**: un solo paso manual y con aprobación: pegar la plantilla del código en el panel de Supabase (Auth → Emails).
- **Correo en la nube**: el SMTP de Supabase por defecto solo envía a miembros de la organización y hasta 2 correos por hora. Alcanza para Jesús y Joan en beta; para más personas hará falta SMTP propio.
- **Riesgo**: el límite de 2 correos por hora en la nube; la pantalla de inicio de sesión cambia de diseño (decisión de producto de Joan).
