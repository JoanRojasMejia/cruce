#!/usr/bin/env bash
# Sube las migraciones de supabase/migrations a un ambiente de la nube.
#
#   scripts/db-push.sh testing   aplica las migraciones pendientes en testing
#   scripts/db-push.sh prod      pide escribir "prod", respalda prod y después aplica
#
# Los identificadores de los proyectos están en supabase/ambientes.env. El script vincula el
# proyecto del ambiente elegido antes de tocar nada: nunca confía en el último `supabase link`.
# Las migraciones llegan primero a testing y después a prod. La contraseña de la base la pide el
# CLI o la lee de SUPABASE_DB_PASSWORD; nunca va en este script.
set -euo pipefail

usage() {
    echo "Uso: scripts/db-push.sh <testing|prod>" >&2
}

case "${1:-}" in
    testing | prod) env="$1" ;;
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

ref="$(project_ref_for "$env")"

if ! command -v supabase >/dev/null 2>&1; then
    echo "Error: no está el CLI de Supabase. Instálalo con: brew install supabase/tap/supabase" >&2
    exit 1
fi

echo "Ambiente: $env (proyecto $ref)."

if [[ "$env" == "prod" ]]; then
    read -r -p "Vas a cambiar la base de datos de PROD. Escribe prod para seguir: " answer
    if [[ "$answer" != "prod" ]]; then
        echo "Cancelado: no se respaldó ni se aplicó nada." >&2
        exit 1
    fi
    # Sin respaldo no se migra prod (set -e corta aquí si falla).
    scripts/backup-db.sh prod
fi

if ! supabase link --project-ref "$ref"; then
    echo "Error: no se pudo vincular $env. Corre primero 'supabase login' y revisa la contraseña de la base." >&2
    exit 1
fi

echo "Migraciones pendientes en $env:"
supabase db push --linked --dry-run

supabase db push --linked
echo "Listo: $env tiene todas las migraciones."
