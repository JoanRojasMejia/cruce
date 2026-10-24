# Cruce · backend (Go)

Servicio pequeño que acompaña a Supabase. La app **no** pasa por aquí para leer o escribir movimientos: eso lo hace directo contra Supabase, con permisos por usuario (RLS) y tiempo real.

Este servicio se encarga de lo que Supabase no resuelve solo:

| Tarea | Estado |
|---|---|
| Recibir los Database Webhooks de `movements` | Listo (`POST /webhooks/movements`) |
| Avisarle a la otra persona con una notificación push (APNs) | Pendiente: hoy solo deja un log |
| Recordatorio mensual para saldar | Pendiente |
| Limpiar invitaciones vencidas | Pendiente |

Solo usa la librería estándar de Go.

## Correr en local

```bash
cp .env.example .env    # llena WEBHOOK_SECRET
set -a; source .env; set +a
go run ./cmd/api
curl localhost:8080/healthz
```

## Pruebas

```bash
go test ./...
```

## Conectar con Supabase

En el dashboard: **Database → Webhooks → Create a new hook**
- Tabla: `movements`, eventos: Insert, Update.
- Tipo: HTTP Request, método `POST`, URL: `https://<tu-servicio>/webhooks/movements`.
- Header: `Authorization: Bearer <WEBHOOK_SECRET>`.
