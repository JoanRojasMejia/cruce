#!/usr/bin/env bash
# Respaldo de la base de datos de Supabase (esquema y datos) en backups/<AAAA-MM-DD_HHMMSS>_<ambiente>/.
#
#   scripts/backup-db.sh testing   respalda el proyecto de testing de la nube
#   scripts/backup-db.sh prod      respalda el proyecto de prod de la nube
#   scripts/backup-db.sh --local   respalda la base local (supabase start)
#
# Los identificadores de los proyectos están en supabase/ambientes.env. Antes de respaldar la nube,
# el script vincula el proyecto del ambiente elegido: nunca confía en el último `supabase link`.
#
# La contraseña de la base nunca va en este script: la pide el CLI o la lee de la
# variable SUPABASE_DB_PASSWORD del entorno. backups/ está en .gitignore.
set -euo pipefail

usage() {
    echo "Uso: scripts/backup-db.sh <testing|prod|--local>" >&2
}

case "${1:-}" in
    testing | prod)
        env="$1"
        target="--linked"
        ;;
    --local)
        env="local"
        target="--local"
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac

# Siempre desde la raíz del repo, para que el CLI encuentre supabase/.
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib/ambiente.sh
source scripts/lib/ambiente.sh

ref=""
if [[ "$target" == "--linked" ]]; then
    ref="$(project_ref_for "$env")"
fi

if ! command -v supabase >/dev/null 2>&1; then
    echo "Error: no está el CLI de Supabase. Instálalo con: brew install supabase/tap/supabase" >&2
    exit 1
fi

if [[ "$target" == "--linked" ]]; then
    echo "Respaldando $env (proyecto $ref)."
    if ! supabase link --project-ref "$ref"; then
        echo "Error: no se pudo vincular $env. Corre primero 'supabase login' y revisa la contraseña de la base." >&2
        exit 1
    fi
else
    echo "Respaldando la base local."
fi

# Se escribe en una carpeta temporal y solo se mueve a backups/ si los dos volcados salen bien.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

supabase db dump "$target" -f "$tmp/schema.sql"
supabase db dump "$target" --data-only -f "$tmp/data.sql"

for f in schema.sql data.sql; do
    if [[ ! -s "$tmp/$f" ]]; then
        echo "Error: $f quedó vacío; no se guarda el respaldo." >&2
        exit 1
    fi
done

mkdir -p backups
dest="backups/$(date +%Y-%m-%d_%H%M%S)_$env"
while [[ -e "$dest" ]]; do
    sleep 1
    dest="backups/$(date +%Y-%m-%d_%H%M%S)_$env"
done
mv "$tmp" "$dest"
trap - EXIT

echo "Respaldo listo en $dest"
