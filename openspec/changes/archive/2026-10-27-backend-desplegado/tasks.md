# Tasks

## 1. Backend

- [x] 1.1 Escribir antes las pruebas y verlas fallar:
  - un aviso con secreto incorrecto, JSON inválido u otra tabla deja una advertencia en el log, sin el secreto ni el cuerpo;
  - la línea de un aviso correcto no contiene el concepto.

  Implementar los `Warn` en `handleMovementWebhook`. Verificar con `gofmt`, `go vet`, `staticcheck` y `go test`.
- [x] 1.2 Crear `backend/.dockerignore` y `backend/fly.toml`:
  - una máquina siempre prendida, `shared-cpu-1x` con 256 MB, región `sjc`;
  - el health check a `/healthz`.

  Verificar que la imagen se construye con `docker build` y que `/healthz` responde con el contenedor corriendo.

## 2. De punta a punta en local

- [x] 2.1 Correr el backend en la Mac (puerto 8088, porque el 8080 suele estar ocupado) y crear el webhook con `scripts/webhook-local.sh` (Studio no se levanta en local), apuntando a `host.docker.internal:8088`. Anotar, editar y eliminar un gasto por la API. Verificar:
  - el log muestra `INSERT` y `UPDATE` sin concepto;
  - un secreto incorrecto deja la advertencia.

## 3. Testing en Fly.io (Joan escribe los secretos)

- [x] 3.1 Joan:
  - instala `flyctl`, entra a su cuenta, crea la app y pone `WEBHOOK_SECRET` y `SUPABASE_URL` con `fly secrets import`;
  - despliega con `fly deploy -a <app> --ha=false`.

  Verificar que `https://<app>.fly.dev/healthz` responde y que `fly scale show` muestra una sola máquina.
- [x] 3.2 Joan crea el Database Webhook en el panel de testing, con el header `Authorization` y un tiempo de espera de 5000 ms. Anotar un gasto en "Cruce Test" deja una línea en `fly logs`.

## 4. Documentación y cierre

- [x] 4.1 Actualizar:
  - `backend/README.md`: Fly.io, secretos, despliegue, logs y el webhook en local y en testing;
  - `CLAUDE.md` §2, §4 y §6;
  - el ROADMAP: se marca el CP8 cuando Joan termine las tareas 3.1 y 3.2; el despliegue de prod queda para cuando exista su proyecto.

  Verificar el backend completo y `openspec validate --all --strict`.
