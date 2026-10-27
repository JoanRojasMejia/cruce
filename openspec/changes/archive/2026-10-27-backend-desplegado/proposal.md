# Proposal

## Why

El backend de Go ya recibe los webhooks de `movements`, pero solo corre en la Mac. Las notificaciones push (CP9) y el recordatorio mensual (CP10) necesitan que esté en la nube, prendido siempre, y que Supabase le avise de cada movimiento. Joan eligió Fly.io el 27 oct 2026 (ver las decisiones del ROADMAP).

## What Changes

- **Despliegue en Fly.io:**
  - `backend/fly.toml` define una app con una sola máquina pequeña (shared-cpu-1x, 256 MB), siempre prendida, en la región de San José (`sjc`), cerca de Supabase en Oregon (Fly ya no deja crear máquinas en Seattle, `sea`);
  - Fly revisa `/healthz`;
  - `backend/.dockerignore` deja `.env` fuera de la imagen.
- **Un backend por ambiente:**
  - ahora se despliega el de testing, contra el proyecto de Supabase `pqdjiecynyjnianslikp`;
  - el de prod se crea cuando exista su proyecto de Supabase, antes de TestFlight.
- **Secretos:**
  - `WEBHOOK_SECRET` y `SUPABASE_URL` se guardan con `fly secrets import`; Joan los pega en su terminal (no quedan en el historial) y nunca van al repo;
  - `SUPABASE_SERVICE_ROLE_KEY` se agrega en el CP9, cuando el backend la use por primera vez.
- **Database Webhook en Supabase:**
  - en `movements`, para insert y update, apuntando a `https://<app>.fly.dev/webhooks/movements` con `Authorization: Bearer <WEBHOOK_SECRET>`;
  - en testing se crea en el panel; en local, con `scripts/webhook-local.sh`, apuntando al backend que corre en la Mac.
- **Logs:**
  - cada movimiento recibido deja una línea JSON, como hoy, sin concepto ni nombres;
  - un webhook rechazado (secreto incorrecto, JSON inválido u otra tabla) ahora también deja una línea de aviso, sin el secreto, para poder diagnosticar.
- **Documentación:** `backend/README.md` explica cómo crear la app, poner los secretos, desplegar y ver los logs.

## Capabilities

### New Capabilities
- `avisos-backend`: el backend recibe de Supabase cada cambio de un movimiento, rechaza a quien no tiene el secreto, deja todo en el log sin datos personales y está siempre disponible en cada ambiente.

### Modified Capabilities
<!-- Ninguna. -->

## Impact

- **Código:** `backend/internal/httpapi/server.go` (logs de rechazo) y sus pruebas.
- **Archivos nuevos:** `backend/fly.toml`, `backend/.dockerignore` y `scripts/webhook-local.sh` (el webhook en Supabase local).
- **Documentación:** `backend/README.md`, `CLAUDE.md` §2, §4 y §6, y `docs/ROADMAP.md`.
- **Sistemas:**
  - una cuenta de Fly.io de Joan, con tarjeta (unos US$2 al mes);
  - `flyctl`, que se instala con `brew install flyctl`;
  - un Database Webhook en el proyecto de testing de Supabase.
- **Sin cambios** en la app iOS, en la base de datos ni en las dependencias de Go.
