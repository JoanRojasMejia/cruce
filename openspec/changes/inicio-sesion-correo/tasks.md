# Tasks

Cada tarea con commit termina en uno solo (Conventional Commits, descripción en español) directo en `main`; `git push` solo cuando el usuario lo pida. Antes de cada commit, en verde (§7 de `CLAUDE.md`): `cd ios/Packages/CruceCore && swift test`, `swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore` y, si el commit toca la app, `cd ios && xcodegen && xcodebuild -project Cruce.xcodeproj -scheme Cruce -destination 'platform=iOS Simulator,name=iPhone 17' build` con `BUILD SUCCEEDED`. Las tareas RED no tienen commit propio.

Modos de `CLAUDE.local.md`: las tareas 1 a 3 son “Lógica pura” o compilación sin simulador; la 4.2 es “Integración” (Colima con 2 GB, Supabase mínimo **sin excluir `mailpit`** y un solo simulador). Al terminar: `xcrun simctl shutdown all` y `supabase stop && colima stop`.

## 1. Lógica en CruceCore

- [x] 1.1 RED: pruebas de `SessionStore` con dobles de `AuthService` y `AccountDirectory`: etapa sin sesión, sin perfil, sin cuenta y con cuenta; pedir y verificar código (correcto, incorrecto); validación del correo; nombre de 1 a 40 caracteres; cerrar sesión vuelve a onboarding (verificado: `swift test` no compila porque faltan `InMemoryAuthService` e `InMemoryAccountDirectory`). Sin commit propio
- [x] 1.2 GREEN: protocolos `AuthService` y `AccountDirectory`, dobles en memoria para pruebas y vistas previas, y `SessionStore.refresh()`, `sendCode`, `verify`, `createProfile` y `signOut` (verificado: 55 pruebas de Swift Testing en verde, 17 más que antes; `swift format lint --strict` limpio; la app compila con `signOut()` asíncrono en ajustes). Commit: `feat(ios): agregar la sesión con código por correo a CruceCore`

## 2. Supabase en la app

- [x] 2.1 Agregar supabase-swift por SPM al target de la app en `project.yml` (versión fija), `Config.example.xcconfig`, `Config.xcconfig` en `.gitignore`, las claves en `Info.plist` y su lectura al arrancar con error claro si faltan (verificado: supabase-swift fijo en 2.55.4; `Config.xcconfig` entra con `#include?` desde `ios/Cruce/Config/Cruce.xcconfig`, así la app compila aunque falte; `xcodebuild -showBuildSettings` muestra `SUPABASE_URL = http://127.0.0.1:54321` en Debug; `git status` no lista `Config.xcconfig`). Commit: `build(ios): agregar supabase-swift y la configuración por xcconfig`
- [x] 2.2 `SupabaseAuthService` y `SupabaseAccountDirectory` en `ios/Cruce/Data/` con un solo `SupabaseClient`, conectados en `AppStores.live()`; `AppStores.sample()` sigue con los dobles (verificado: `BUILD SUCCEEDED`; CruceCore no importa Supabase: `rg -n "import Supabase" ios/Packages` no encuentra nada). Commit: `feat(ios): conectar la sesión con Supabase Auth`
- [x] 2.3 Plantilla `supabase/templates/codigo.html` con `{{ .Token }}` y su referencia en `config.toml` para enlace mágico y confirmación (verificado en la 4.2: con Supabase local, el correo de un usuario nuevo y el de uno que ya existe llegan a mailpit con el asunto "Tu código para entrar a Cruce" y el código de 6 dígitos). Commit: `feat(supabase): enviar el código de 6 dígitos en el correo`

## 3. Pantallas

- [x] 3.1 Cambio de la pantalla de entrada dado por aprobado la noche del 26 oct 2026 (el dueño dejó aprobada toda la implementación; Joan puede pedir ajustes de diseño después). `SignUpView` sin el botón simulado de Apple: campo de correo, pantalla del código (6 dígitos, reenviar, mensajes en español) y pantalla del nombre; `RootView` llama a `session.refresh()` al arrancar; cerrar sesión desde ajustes. `DebugScreen` agrega las pantallas nuevas (verificado: capturas de `-screen signUp`, `signUpCode` y `signUpName` en el iPhone 17; de paso, un botón `.dark` deshabilitado ya no queda con el texto blanco sobre blanco). Commit: `feat(ios): pantallas de inicio de sesión con código por correo`

## 4. Verificación

- [x] 4.1 `swift test`, `swift format lint` y `xcodebuild … build` en Debug y Release en verde (verificado: 56 pruebas en verde, lint sin salida, `BUILD SUCCEEDED` en Debug y en Release, también después del arreglo de ajustes). Sin commit
- [x] 4.2 En local (modo Integración): entrar con un correo nuevo leyendo el código en mailpit, crear el perfil, llegar a invitar, cerrar y abrir la app con la sesión viva, cerrar sesión; un código equivocado muestra el error; repetir con una segunda cuenta en el mismo simulador (verificado el 26 oct 2026 en el iPhone 17 con Colima 2 GB y Supabase con mailpit: un correo mal escrito muestra "Ese correo no parece válido…"; el código llega a mailpit; un código equivocado muestra "El código no es correcto o ya venció…" y la sesión no se abre; el correcto pide el nombre y crea la fila en `profiles` con `id = auth.uid()`; llega a invitar; al cerrar y abrir la app vuelve a invitar sin pedir el correo; "Cerrar sesión" lleva al onboarding y sigue ahí al reabrir; una segunda cuenta que ya tenía perfil entra sin pedir el nombre; con una fila en `ledger_members` la app abre en el inicio, y "Cerrar sesión" desde ajustes vuelve al onboarding también después de reabrir. `supabase test db`: 74 pruebas en verde. La prueba encontró el texto "Cuenta de Apple conectada" en ajustes, corregido en `fix(ios): quitar la mención de Apple en ajustes`). Sin commit
- [ ] 4.3 (pendiente: requiere al dueño) Con aprobación: pegar la plantilla en el panel de Supabase (nube) y probar con los correos de Jesús y Joan desde un build Release en el simulador. Sin commit

## 5. Documentación y cierre

- [x] 5.1 `CLAUDE.md` (§2, §4, §6, §8), `docs/ROADMAP.md` (CP3 hecho por correo; Apple como función posterior) e `ios/README.md` (cómo crear `Config.xcconfig` y leer el código en mailpit). Commit: `docs: documentar el inicio de sesión por correo`
