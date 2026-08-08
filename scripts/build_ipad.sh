#!/usr/bin/env bash
# Genera IRIS-DP.ipa sin firma (SideStore re-firma en el iPad).
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

ARGS=(build ios --release --no-codesign --no-tree-shake-icons)
if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_ANON_KEY" ]]; then
  ARGS+=(
    --dart-define=SUPABASE_URL="$SUPABASE_URL"
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  )
  echo "→ Modo nube: credenciales desde .env"
fi
if [[ -n "${CLOUDINARY_CLOUD_NAME:-}" && -n "${CLOUDINARY_UPLOAD_PRESET:-}" ]]; then
  ARGS+=(
    --dart-define=CLOUDINARY_CLOUD_NAME="$CLOUDINARY_CLOUD_NAME"
    --dart-define=CLOUDINARY_UPLOAD_PRESET="$CLOUDINARY_UPLOAD_PRESET"
  )
  echo "→ Cloudinary: credenciales desde .env"
fi

echo "=== Build iPad/iPhone (IPA sin firma) ==="
flutter "${ARGS[@]}"

chmod +x scripts/package_unsigned_ipa.sh
./scripts/package_unsigned_ipa.sh

IPA="$ROOT/build/ios/ipa/IRIS-DP.ipa"
echo ""
echo "✓ IPA listo: $IPA"
echo ""
echo "=== Instalar en iPad con SideStore ==="
echo "  1. Mac (solo la 1ª vez): instala SideServer desde sidestore.io"
echo "  2. iPad: instala SideStore (misma web)"
echo "  3. Empareja iPad ↔ Mac por USB"
echo "  4. Pasa el IPA al iPad (AirDrop, Archivos, o descarga del GitHub Release)"
echo "  5. Abrir IRIS-DP.ipa con SideStore"
echo ""
echo "Guía: docs/ipad_sidestore.md"
