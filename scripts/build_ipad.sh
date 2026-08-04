#!/usr/bin/env bash
# Genera IRIS-DP.ipa para iPad/iPhone (requiere Mac + Xcode + cuenta Apple Developer).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

ARGS=(build ipa --release)
if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_ANON_KEY" ]]; then
  ARGS+=(
    --dart-define=SUPABASE_URL="$SUPABASE_URL"
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  )
fi

echo "=== Build iPad/iPhone (IPA) ==="
flutter "${ARGS[@]}"

IPA=$(find build/ios/ipa -name '*.ipa' 2>/dev/null | head -1)
echo ""
if [[ -n "$IPA" ]]; then
  echo "✓ IPA generado: $IPA"
else
  echo "✓ Build completado. Busca el .ipa en build/ios/ipa/"
fi
echo ""
echo "Cómo instalar en iPad:"
echo "  A) TestFlight — sube el IPA con la app Transporter (App Store Connect)"
echo "  B) Desarrollo — conecta el iPad al Mac, abre Xcode → Window → Devices, arrastra el IPA"
echo "  C) Apple Configurator — instala el IPA en iPads gestionados"
echo ""
echo "Ver docs/distribuir_app.md para más detalle."
