#!/usr/bin/env bash
# Traduce un ambiente de la nube (testing o prod) en el identificador de su proyecto de Supabase,
# leyendo supabase/ambientes.env. Lo usan backup-db.sh y db-push.sh:
#
#   source scripts/lib/ambiente.sh && ref="$(project_ref_for testing)"
#
# También se puede correr solo para ver el identificador: scripts/lib/ambiente.sh testing

AMBIENTES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/supabase/ambientes.env"

# Escribe el identificador del proyecto del ambiente, o falla con un mensaje en stderr.
project_ref_for() {
    local env="${1:-}" var ref
    case "$env" in
        testing) var="TESTING_PROJECT_REF" ;;
        prod) var="PROD_PROJECT_REF" ;;
        *)
            echo "Error: ambiente desconocido '${env}'. Usa testing o prod." >&2
            return 2
            ;;
    esac
    if [[ ! -f "$AMBIENTES_FILE" ]]; then
        echo "Error: no está $AMBIENTES_FILE." >&2
        return 1
    fi
    # Se lee la línea en vez de hacer `source`, para no ejecutar nada del archivo.
    ref="$(sed -n "s/^${var}=//p" "$AMBIENTES_FILE" | tr -d '[:space:]')"
    if [[ -z "$ref" ]]; then
        if [[ "$env" == "prod" ]]; then
            echo "Error: prod todavía no existe. Crea el proyecto y llena PROD_PROJECT_REF en supabase/ambientes.env (pasos en supabase/README.md)." >&2
        else
            echo "Error: falta ${var} en supabase/ambientes.env." >&2
        fi
        return 1
    fi
    echo "$ref"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    project_ref_for "${1:-}"
fi
