# Design

## Context

- **El backend** (`backend/`) usa Go 1.27, solo la librería estándar:
  - rutas `GET /healthz` y `POST /webhooks/movements`;
  - el secreto se compara en tiempo constante;
  - `LogNotifier` escribe con `slog` en JSON.
- **El Dockerfile** es de dos etapas (`golang:1.27-alpine` y `distroless/static`) y escucha en `PORT=8080`.
- **El riesgo de la imagen:** no hay `.dockerignore`, así que `COPY . .` subiría un `.env` local al builder.
- **La configuración** exige `WEBHOOK_SECRET`. `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` se leen, pero todavía no se usan.
- **Lo que falta en el log:** un aviso rechazado (401 o 400) no deja rastro.
- **Ambientes:** local (Docker) y testing (`pqdjiecynyjnianslikp`, Oregon); prod todavía no existe.
- **Webhooks de Supabase:**
  - un Database Webhook crea un trigger que llama a `pg_net` de forma asíncrona;
  - el `UPDATE` incluye el borrado suave (`deleted_at`);
  - el tiempo de espera es corto (1 s por defecto, configurable).

## Goals / Non-Goals

**Goals:**
- El backend de testing desplegado en Fly.io, prendido siempre, recibiendo los avisos de `movements`.
- Probarlo primero de punta a punta en local, con el backend corriendo en la Mac.
- Que un aviso rechazado se pueda diagnosticar desde el log.

**Non-Goals:**
- Notificaciones push y la llave `service_role` (CP9).
- Recordatorio mensual y limpieza de invitaciones (CP10).
- El backend de prod (cuando exista su proyecto de Supabase).
- Desplegar automáticamente desde GitHub Actions: por ahora es `fly deploy` a mano. Se puede agregar después con un token de Fly como secreto de la CI.

## Decisions

### D1. Una app de Fly por ambiente, con un solo `fly.toml`
- **Qué:**
  - `backend/fly.toml` describe la máquina;
  - el nombre de la app se pasa al desplegar (`fly deploy -a <app>`): por ejemplo `cruce-api-testing` y, más adelante, `cruce-api-prod`;
  - el nombre exacto lo elige Joan al crearla, porque en Fly es único en todo el mundo.
- **Por qué:** la máquina es igual en los dos ambientes; solo cambian el nombre y los secretos.
- **Alternativa descartada:** un `fly.testing.toml` y un `fly.prod.toml`, que duplican la configuración.

### D2. Una máquina siempre prendida
- **Configuración:**
  - `auto_stop_machines = "off"` y `min_machines_running = 1`;
  - `shared-cpu-1x` con 256 MB, en `primary_region = "sjc"` (San José; `sea` está obsoleta y Fly no deja crear máquinas ahí);
  - el primer despliegue usa `--ha=false`, porque Fly crea dos máquinas por defecto, y eso duplicaría el costo.
- **Health check:** HTTP a `/healthz`.
- **Por qué:**
  - un webhook que llega con la máquina apagada espera el arranque, y el tiempo de espera de Supabase es corto;
  - una sola máquina alcanza para dos personas.

### D3. Los secretos los pone Joan con `fly secrets import`
- **Qué:**
  - Joan genera `WEBHOOK_SECRET` en su terminal, por ejemplo con `openssl rand -hex 32`;
  - lo guarda con `fly secrets import` y lo pega en el header del webhook en el panel de Supabase;
  - `SUPABASE_URL` también va como secreto, por orden, aunque no sea secreta.
- **Lo que no se hace:** el agente nunca ve ni escribe esos valores.
- **`SUPABASE_SERVICE_ROLE_KEY`:** se pone en el CP9, cuando el backend la use. Una llave que no se usa es solo riesgo.

### D4. El webhook se crea en el panel, no en una migración
- **Qué:** en testing, Integrations → Database Webhooks, en `movements`, para insert y update, HTTP POST con el header `Authorization`. En local, `scripts/webhook-local.sh` crea el mismo trigger (`supabase_functions.http_request` y `pg_net`) con la URL `http://host.docker.internal:8088/webhooks/movements`; hay que correrlo después de cada `supabase db reset`.
- **Por qué no una migración:**
  - la URL y el secreto cambian por ambiente, y el secreto no puede ir en el repo;
  - leerlo desde Vault complica la migración sin ganar mucho con dos personas.
- **Tiempo de espera:** se sube a 5000 ms, para dar margen al CP9.

### D5. El log de los rechazos
- **Qué:** `handleMovementWebhook` escribe `Warn` con el motivo (`no autorizado`, `JSON inválido`, `tabla inesperada` o `sin registro`) y el estado HTTP. Nunca escribe el header ni el cuerpo.
- **Lo que no cambia:** la línea de éxito sigue en `LogNotifier`, que ya omite el concepto.

### D6. `.dockerignore`
- **Qué:** excluye `.env`, `.env.*` (salvo `.env.example`) y los archivos del editor.
- **Por qué:** `fly deploy` sube el contexto al builder remoto, y un `.env` con secretos no debe salir de la Mac.

## Risks / Trade-offs

- **[Costo]** Fly cobra por máquina prendida → Una sola máquina de 256 MB (unos US$2 al mes). Se revisa `fly scale show` después del primer despliegue.
- **[Avisos perdidos si el backend falla]** `pg_net` no reintenta → Para el CP8 alcanza con el log. En el CP9 se evalúa si un aviso perdido importa (la app ya ve el cambio por Realtime).
- **[Secreto filtrado]** Si alguien conoce el secreto, puede mandar avisos falsos → Hoy solo producen líneas de log. Se rota con `fly secrets import` y editando el webhook.
- **[Errores del notificador en el log]** El 502 escribe el `err` del notificador. Hoy `LogNotifier` nunca falla; en el CP9, el error de APNs no debe incluir el evento ni el concepto.
- **[Docker en local]** `host.docker.internal` depende de Docker Desktop o Colima → Si no resuelve, se usa la IP de la Mac en la red local.
