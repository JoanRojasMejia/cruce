#!/usr/bin/env bash
# Respaldo de la base de datos de Supabase (esquema y datos) en backups/<AAAA-MM-DD_HHMMSS>/.
#
#   scripts/backup-db.sh           respalda el proyecto vinculado de la nube
#   scripts/backup-db.sh --local   respalda la base local (supabase start)
#
# La contraseña de la base nunca va en este script: la pide el CLI o la lee de la
# variable SUPABASE_DB_PASSWORD del entorno. backups/ está en .gitignore.
set -euo pipefail

usage() {
    echo "Uso: scripts/backup-db.sh [--local]" >&2
}

target="--linked"
case "${1:-}" in
    "") ;;
    --local) target="--local" ;;
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

if ! command -v supabase >/dev/null 2>&1; then
    echo "Error: no está el CLI de Supabase. Instálalo con: brew install supabase/tap/supabase" >&2
    exit 1
fi

if [[ "$target" == "--linked" && ! -s supabase/.temp/project-ref ]]; then
    echo "Error: no hay un proyecto vinculado. Corre primero 'supabase login' y 'supabase link'." >&2
    exit 1
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
dest="backups/$(date +%Y-%m-%d_%H%M%S)"
while [[ -e "$dest" ]]; do
    sleep 1
    dest="backups/$(date +%Y-%m-%d_%H%M%S)"
done
mv "$tmp" "$dest"
trap - EXIT

echo "Respaldo listo en $dest"
