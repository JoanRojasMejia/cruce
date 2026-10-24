# Prompt para retomar en Claude Code u OpenCode

Pega esto en una sesión nueva abierta en `~/Projects/personal/cruce`:

---

Vas a continuar el desarrollo de **Cruce**, una app de iPhone (SwiftUI) para que dos amigos lleven sus cuentas compartidas con un solo saldo neto. Tiene un backend pequeño en Go y una base de datos en Supabase.

Antes de hacer nada:

1. Lee completo `CLAUDE.md`. Ahí están la especificación del producto, las reglas que no se negocian, la estructura del repo, cómo levantar cada parte, el diseño, la arquitectura, las convenciones y los riesgos conocidos.
2. Lee `docs/ROADMAP.md` y ubica **el primer checkpoint con tareas sin marcar**.
3. Mira las capturas en `docs/design/screens/`. Son la referencia visual: el código tiene que verse así.

Cómo vamos a trabajar:

- **Un checkpoint a la vez, en orden.** No adelantes trabajo de checkpoints siguientes.
- Antes de tocar código, dame un plan corto del checkpoint (qué archivos vas a cambiar y cómo lo vas a verificar) y espera mi visto bueno.
- Ejecuta tú mismo los comandos de compilación y pruebas (`xcodegen`, `xcodebuild … build test`, `go test ./...`, `supabase db reset`). No me pidas que los corra si puedes hacerlo.
- Si algo es una decisión de producto (está en "Decisiones abiertas" o no está definido), pregúntame en vez de asumir.
- Usa solo los tokens de `ios/Cruce/DesignSystem/` para colores, tipografía, radios, bordes, sombras y espacios.
- No agregues dependencias sin preguntarme.
- Al terminar el checkpoint:
  1. verifica sus criterios de "Hecho cuando";
  2. marca las casillas en `docs/ROADMAP.md`;
  3. actualiza la tabla "Estado actual" de `CLAUDE.md`;
  4. propón un commit en español.

Empieza por el **CP0 · Levantar el proyecto y compilar**. Ojo: el código de Swift se escribió sin Xcode y nunca se ha compilado. Espera errores y corrígelos sin cambiar el comportamiento ni el diseño.
