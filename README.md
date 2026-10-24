# Cruce

App para que dos amigos lleven sus cuentas compartidas: cada gasto se cruza con lo que el otro debe y siempre hay **un solo saldo neto**.

## Repositorio

```
cruce/
├── ios/        App en SwiftUI (iOS 17+). Proyecto generado con XcodeGen.
├── backend/    Servicio en Go: webhooks de Supabase, notificaciones y tareas programadas.
├── supabase/   Migraciones de la base de datos (Postgres + RLS + tiempo real).
└── docs/       Arquitectura, decisiones y referencia del diseño.
```

## Arquitectura en una línea

La app habla **directo con Supabase** (auth, datos, tiempo real). El backend de Go va **al lado**, no en medio: recibe los webhooks de Supabase y se encarga de notificaciones y recordatorios. Detalle en [`docs/arquitectura.md`](docs/arquitectura.md).

## Empezar

- **Contexto completo para agentes (Claude Code / OpenCode):** [`CLAUDE.md`](CLAUDE.md) y [`docs/ROADMAP.md`](docs/ROADMAP.md). Prompt para retomar: [`docs/PROMPT-INICIO.md`](docs/PROMPT-INICIO.md).
- Capturas del diseño final: [`docs/design/screens/`](docs/design/screens/).

- App: ver [`ios/README.md`](ios/README.md).
- Backend: ver [`backend/README.md`](backend/README.md).
- Base de datos: ver [`supabase/README.md`](supabase/README.md).

## Estado

- [x] Diseño cerrado (opción A, 20 pantallas + guía de estilo).
- [x] App con todas las pantallas y datos de ejemplo.
- [x] Esquema de base de datos con permisos y funciones de invitación.
- [x] Backend con webhooks y pruebas.
- [ ] Conectar la app a Supabase (sesión, repositorio, tiempo real).
- [ ] Notificaciones push y recordatorio mensual.
- [ ] TestFlight.
