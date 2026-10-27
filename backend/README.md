# Cruce · backend (Go)

Servicio pequeño que acompaña a Supabase. La app **no** pasa por aquí para leer o escribir movimientos: eso lo hace directo contra Supabase, con permisos por usuario (RLS) y tiempo real.

Este servicio se encarga de lo que Supabase no resuelve solo:

| Tarea | Estado |
|---|---|
| Recibir los Database Webhooks de `movements` | Listo (`POST /webhooks/movements`), desplegado en Fly.io (CP8) |
| Avisarle a la otra persona con una notificación push (APNs) | Pendiente: hoy solo deja un log |
| Recordatorio mensual para saldar | Pendiente |
| Limpiar invitaciones vencidas | Pendiente |

Solo usa la librería estándar de Go.

## Logs

- **Formato:** una línea JSON por evento (`slog`).
- **Cada aviso de Supabase** deja `movimiento cambió` con `type` (`INSERT` o `UPDATE`; un borrado suave llega como `UPDATE`), `ledger`, `movement`, `kind`, `amount` y `created_by`.
- **Un aviso rechazado** deja `webhook rechazado` con `motivo` (`no autorizado`, `JSON inválido`, `tabla inesperada` o `sin registro`) y `status`.
- **Lo que nunca se escribe:** el concepto, los nombres, el header `Authorization` ni el cuerpo que llegó.

## Correr en local

```bash
cp .env.example .env    # llena WEBHOOK_SECRET
set -a; source .env; set +a
go run ./cmd/api
curl localhost:8080/healthz
```

### El webhook en Supabase local

1. **Levanta el backend** en el puerto 8088, porque el 8080 suele estar ocupado en la Mac, con el secreto `dev`:

   ```bash
   PORT=8088 WEBHOOK_SECRET=dev go run ./cmd/api
   ```

2. **Crea el webhook.** Con Supabase local prendido, desde la raíz del repo:

   ```bash
   scripts/webhook-local.sh
   ```

   - Crea el mismo trigger que crea el panel en la nube (`supabase_functions.http_request` con `pg_net`), apuntando a `http://host.docker.internal:8088/webhooks/movements`.
   - Hay que volver a correrlo después de cada `supabase db reset`.
   - `BACKEND_PORT` y `WEBHOOK_SECRET` cambian el puerto y el secreto (solo letras, números, `-` y `_`).

3. **Comprueba:** anotar, editar o eliminar un gasto (en la app "Cruce Dev" o por la API) deja una línea en la terminal del backend. Lo que respondió el backend queda en `net._http_response`.

## Pruebas

```bash
gofmt -l .          # no debe imprimir nada (lista los archivos sin formato)
go vet ./...
staticcheck ./...   # análisis estático; no es dependencia del módulo
go test ./...
```

`staticcheck` se instala una vez con `go install honnef.co/go/tools/cmd/staticcheck@2026.2.2` (queda en `$(go env GOPATH)/bin`). La CI corre los mismos cuatro comandos.

## Desplegar en Fly.io

Hay una app de Fly por ambiente, todas con la misma máquina:
- **La máquina:** una `shared-cpu-1x` de 256 MB, siempre prendida, en San José (`sjc`), descrita en `fly.toml`. Cuesta unos US$2 al mes.
- **El nombre:** se pasa con `-a`. Aquí se usa `cruce-api-testing`; si ese nombre ya está tomado en Fly, usa otro y cámbialo en los comandos.
- **Prod:** se crea igual cuando exista su proyecto de Supabase.

### Una sola vez

```bash
brew install flyctl
fly auth login                                  # tu cuenta de Fly.io (pide tarjeta)
fly apps create cruce-api-testing
```

### Secretos

Escríbelos tú, en tu terminal. Nunca van al repo ni al chat.

```bash
openssl rand -hex 32                            # genera el WEBHOOK_SECRET; guárdalo para el webhook
fly secrets import -a cruce-api-testing         # lee de la entrada: pega las dos líneas y termina con Ctrl-D
```

Las dos líneas que pegas (así el secreto no queda en el historial de la terminal):

```
WEBHOOK_SECRET=<el secreto>
SUPABASE_URL=https://pqdjiecynyjnianslikp.supabase.co
```

- `SUPABASE_SERVICE_ROLE_KEY` se agrega en el CP9, cuando el backend la use.
- Para rotar el secreto, vuelve a correr `fly secrets import` y edita el header del webhook en Supabase.

### Desplegar y revisar

Desde `backend/`:

```bash
fly deploy -a cruce-api-testing --ha=false      # --ha=false: una sola máquina (por defecto Fly crea dos)
fly scale show -a cruce-api-testing             # debe mostrar 1 máquina de 256 MB
curl https://cruce-api-testing.fly.dev/healthz  # {"status":"ok"}
fly logs -a cruce-api-testing                   # los logs en vivo
```

- **Qué sube `fly deploy`:** esta carpeta, a un builder remoto.
- **Qué no sube:** `.dockerignore` deja fuera `.env`.

## Conectar con Supabase (testing y prod)

En el panel del proyecto: **Integrations → Database Webhooks** (pestaña **Webhooks**) → **Create a new hook**.
- **Nombre:** `cruce_backend_movements`.
- **Tabla:** `movements`; eventos: **Insert** y **Update**. Update también cubre el borrado suave.
- **Tipo:** HTTP Request, método `POST`, URL `https://cruce-api-testing.fly.dev/webhooks/movements`, tiempo de espera de 5000 ms.
- **Headers:** `Content-Type: application/json` y `Authorization: Bearer <WEBHOOK_SECRET>`.

Si es la primera vez, el panel ofrece activar los webhooks (activa `pg_net`).
