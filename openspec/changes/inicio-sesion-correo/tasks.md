# Tasks

Cada tarea con commit termina en uno solo (Conventional Commits, descripción en español) directo en `main`; `git push` solo cuando el usuario lo pida. Antes de cada commit, en verde (§7 de `CLAUDE.md`): `cd ios/Packages/CruceCore && swift test`, `swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore` y, si el commit toca la app, `cd ios && xcodegen && xcodebuild -project Cruce.xcodeproj -scheme Cruce -destination 'platform=iOS Simulator,name=iPhone 17' build` con `BUILD SUCCEEDED`. Las tareas RED no tienen commit propio.

Modos de `CLAUDE.local.md`: las tareas 1 a 3 son “Lógica pura” o compilación sin simulador; la 4.2 es “Integración” (Colima con 2 GB, Supabase mínimo **sin excluir `mailpit`** y un solo simulador). Al terminar: `xcrun simctl shutdown all` y `supabase stop && colima stop`.

## 1. Lógica en CruceCore

- [ ] 1.1 RED: pruebas de `SessionStore` con dobles de `AuthService` y `AccountDirectory`: etapa sin sesión, sin perfil, sin cuenta y con cuenta; pedir y verificar código (correcto, incorrecto); validación del correo; nombre de 1 a 40 caracteres; cerrar sesión vuelve a onboarding. Sin commit propio
- [ ] 1.2 GREEN: protocolos `AuthService` y `AccountDirectory`, dobles en memoria para pruebas y vistas previas, y `SessionStore.refresh()`, `sendCode`, `verify`, `createProfile` y `signOut`. Commit: `feat(ios): agregar la sesión con código por correo a CruceCore`

## 2. Supabase en la app

- [ ] 2.1 Agregar supabase-swift por SPM al target de la app en `project.yml` (versión fija), `Config.example.xcconfig`, `Config.xcconfig` en `.gitignore`, las claves en `Info.plist` y su lectura al arrancar con error claro si faltan. Commit: `build(ios): agregar supabase-swift y la configuración por xcconfig`
- [ ] 2.2 `SupabaseAuthService` y `SupabaseAccountDirectory` en `ios/Cruce/Data/` con un solo `SupabaseClient`, conectados en `AppStores.live()`; `AppStores.sample()` sigue con los dobles. Commit: `feat(ios): conectar la sesión con Supabase Auth`
- [ ] 2.3 Plantilla `supabase/templates/codigo.html` con `{{ .Token }}` y su referencia en `config.toml` para enlace mágico y confirmación. Commit: `feat(supabase): enviar el código de 6 dígitos en el correo`

## 3. Pantallas

- [ ] 3.1 Antes de esta tarea, Joan aprueba el cambio de la pantalla de entrada. `SignUpView` sin el botón simulado de Apple: campo de correo, pantalla del código (6 dígitos, reenviar, mensajes en español) y pantalla del nombre; `RootView` llama a `session.refresh()` al arrancar; cerrar sesión desde ajustes. `DebugScreen` agrega las pantallas nuevas. Commit: `feat(ios): pantallas de inicio de sesión con código por correo`

## 4. Verificación

- [ ] 4.1 `swift test`, `swift format lint` y `xcodebuild … build` en Debug y Release en verde. Sin commit
- [ ] 4.2 En local (modo Integración): entrar con un correo nuevo leyendo el código en mailpit, crear el perfil, llegar a invitar, cerrar y abrir la app con la sesión viva, cerrar sesión; un código equivocado muestra el error; repetir con una segunda cuenta en el mismo simulador. Sin commit
- [ ] 4.3 Con aprobación: pegar la plantilla en el panel de Supabase (nube) y probar con los correos de Jesús y Joan desde un build Release en el simulador. Sin commit

## 5. Documentación y cierre

- [ ] 5.1 `CLAUDE.md` (§2, §4, §6, §8), `docs/ROADMAP.md` (CP3 hecho por correo; Apple como función posterior) e `ios/README.md` (cómo crear `Config.xcconfig` y leer el código en mailpit). Commit: `docs: documentar el inicio de sesión por correo`
