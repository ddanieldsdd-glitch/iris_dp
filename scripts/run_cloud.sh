#!/usr/bin/env bash
# Arranca IRIS DP en modo nube leyendo credenciales de .env (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta $ENV_FILE. Copia .env.example → .env y rellena SUPABASE_URL y SUPABASE_ANON_KEY."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Define SUPABASE_URL y SUPABASE_ANON_KEY en .env"
  exit 1
fi

echo "→ SUPABASE_URL=$SUPABASE_URL"
echo "→ Arrancando IRIS DP (modo nube)…"
echo "   (Cierra la app anterior por completo antes de continuar)"

# Rebuild limpio para que --dart-define se aplique (hot reload no basta).
flutter run -d "${1:-macos}" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
