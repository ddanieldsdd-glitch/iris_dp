#!/usr/bin/env bash
# Arranca IRIS DP en modo nube con rebuild limpio (recomendado si cambiaste .env).
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
echo "→ flutter clean + pub get + run (modo nube)"
echo "   Cierra IRIS DP antes de continuar (q en Terminal o Cmd+Q)."

flutter clean
flutter pub get
flutter run -d "${1:-macos}" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
