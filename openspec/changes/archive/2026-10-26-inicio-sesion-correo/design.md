# Design

## Context

Sin membresía de Apple Developer no hay Sign in with Apple ni Associated Domains (enlaces universales). Supabase Auth ya está en el proyecto local y en la nube, con `otp_length = 6` en `supabase/config.toml`. `SessionStore` (CruceCore) tiene `Phase` con `onboarding`, `signUp`, `invite`, `join`, `connected` y `main`, hoy movida a mano por las pantallas.

## Goals / Non-Goals

**Goals:** entrar con código por correo, sesión persistente, perfil, etapa derivada de la sesión y cerrar sesión, todo probado sin red en CruceCore.

**Non-Goals:** Apple, crear la cuenta compartida o canjear invitaciones (CP4), movimientos en Supabase (CP5), SMTP propio.

## Decisions

### Código de 6 dígitos y no enlace mágico
`signInWithOTP(email:shouldCreateUser: true)` y `verifyOTP(email:token:type: .email)`. Un enlace mágico necesita que el correo abra la app: los enlaces universales piden Associated Domains (de pago) y un esquema propio (`cruce://`) funciona, pero falla si el correo se abre en otro aparato, como la Mac. El código funciona en cualquier caso.

Alternativa descartada: correo y contraseña. Agrega recordar y restablecer contraseñas, y el roadmap ya eligió OTP.

### `AuthService` en CruceCore, implementación en la app
```swift
public protocol AuthService: Sendable {
    func currentUserID() async -> UUID?
    func sendCode(to email: String) async throws
    func verify(email: String, code: String) async throws -> UUID
    func signOut() async throws
}
```
Más dos lecturas para la etapa: `profile(for:)` y `hasLedger(_:)`, en un protocolo aparte (`AccountDirectory`) para no mezclar auth con datos. `SessionStore` recibe ambos en su `init` y calcula la etapa con `refresh()`. CruceCore no importa supabase-swift: la CI en Linux sigue igual y las pruebas usan dobles en memoria.

`SupabaseAuthService` y `SupabaseAccountDirectory` viven en `ios/Cruce/Data/` y comparten un solo `SupabaseClient`, creado en `AppStores.live()`.

### Configuración por xcconfig
`Config.xcconfig` (ignorado) define `SUPABASE_URL` y `SUPABASE_ANON_KEY` por configuración; `Info.plist` los expone y la app los lee al arrancar. Debug apunta a `http://127.0.0.1:54321` (el simulador llega a localhost de la Mac); Release a la nube. Se versiona `Config.example.xcconfig`. Si falta la configuración, la app falla al arrancar con un mensaje claro.

### Etapa de entrada
`refresh()` resuelve en este orden: sin usuario → `.onboarding`; sin perfil → `.signUp` (pedir nombre); sin `ledger_members` → `.invite`; con cuenta → `.main`. `join` y `connected` siguen como pasos manuales hasta el CP4.

### Plantilla del correo
`supabase/templates/codigo.html` con `{{ .Token }}`, referida desde `[auth.email.template.magic_link]` y `[auth.email.template.confirmation]` en `config.toml`: Supabase usa la de enlace mágico para el OTP de alguien que ya existe y, si la confirmación de correo está activa, la de confirmación para alguien nuevo. Se verifica en local que las dos lleguen con el código. En la nube se pega la misma plantilla en el panel; no se usa `supabase config push`, porque empujaría toda la configuración local (por ejemplo `site_url`).

### Debug y vistas previas
`AppStores.sample()` y `DebugScreen` (`-screen <nombre>`) no cambian: usan dobles y datos de ejemplo. Solo `AppStores.live()` usa Supabase.

## Risks / Trade-offs

- **2 correos por hora con el SMTP por defecto de la nube** → alcanza para los dos dueños en beta; SMTP propio cuando entren más personas.
- **El SMTP por defecto solo envía a miembros de la organización** → Jesús y Joan ya lo son.
- **Correo local** → hay que levantar Supabase sin excluir `mailpit` para leer el código en `http://127.0.0.1:54324`.
- **Cambio de diseño de la pantalla de entrada** → lo aprueba Joan antes de implementar la tarea de UI.

## Migration Plan

Sin migraciones de base de datos. El único paso en la nube (plantilla del correo) va con aprobación explícita, después de probar todo en local.
