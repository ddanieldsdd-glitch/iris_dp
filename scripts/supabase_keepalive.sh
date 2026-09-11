#!/usr/bin/env bash
# Genera actividad real en Postgres (PostgREST) para que el plan free no pause.
# Uso: ./scripts/supabase_keepalive.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta $ENV_FILE"
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Define SUPABASE_URL y SUPABASE_ANON_KEY en .env"
  exit 1
fi

BASE="${SUPABASE_URL%/}"

ping_table() {
  local table="$1"
  local url="${BASE}/rest/v1/${table}?select=*&limit=1"
  echo "GET ${url}"
  local code
  code=$(curl -sS \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "Accept: application/json" \
    -H "Prefer: count=exact" \
    -o /tmp/iris_keepalive.json \
    -w "%{http_code}" \
    "$url")
  echo "HTTP $code"
  head -c 400 /tmp/iris_keepalive.json || true
  echo
  if [[ "$code" != "200" ]]; then
    echo "Fallo ${table}: HTTP $code"
    return 1
  fi
}

ping_table app_releases
ping_table profiles
ping_table cloud_projects
echo "OK: queries a Postgres enviadas."
