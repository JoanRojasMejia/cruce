#!/usr/bin/env bash
# Crea en Supabase local el mismo Database Webhook de `movements` que en la nube, apuntando al backend
# que corre en la Mac. Hay que volver a correrlo después de cada `supabase db reset`.
#
#   scripts/webhook-local.sh          avisa a http://host.docker.internal:8088 con el secreto "dev"
#   BACKEND_PORT=8080 WEBHOOK_SECRET=otro scripts/webhook-local.sh
#
# Solo toca la base local (el contenedor supabase_db_cruce). En testing y prod el webhook se crea en el
# panel, porque lleva el secreto de ese ambiente y no puede ir en una migración.
set -euo pipefail

port="${BACKEND_PORT:-8088}"
secret="${WEBHOOK_SECRET:-dev}"

# Los dos valores van dentro de un texto SQL y de un JSON: solo se aceptan caracteres seguros.
if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    echo "BACKEND_PORT debe ser un número" >&2
    exit 2
fi
if [[ ! "$secret" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "WEBHOOK_SECRET solo puede tener letras, números, - y _" >&2
    exit 2
fi
url="http://host.docker.internal:${port}/webhooks/movements"
headers="{\"Content-Type\":\"application/json\",\"Authorization\":\"Bearer ${secret}\"}"

docker exec -i supabase_db_cruce psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<SQL
set client_min_messages = warning;
create extension if not exists pg_net;
drop trigger if exists cruce_backend_movements on public.movements;
create trigger cruce_backend_movements
    after insert or update on public.movements
    for each row execute function supabase_functions.http_request('${url}', 'POST', '${headers}', '{}', '5000');
SQL

echo "Webhook local listo: insert y update de movements → ${url}"
