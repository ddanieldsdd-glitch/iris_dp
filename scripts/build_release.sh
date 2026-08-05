#!/usr/bin/env bash
# Genera instalador según el sistema donde ejecutas el script.
# No existe un único instalador universal: macOS, Windows e iPad requieren builds distintos.
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

DART_DEFINES=()
if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_ANON_KEY" ]]; then
  DART_DEFINES=(
    --dart-define=SUPABASE_URL="$SUPABASE_URL"
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  )
  echo "→ Modo nube: credenciales desde .env"
else
  echo "→ Modo local (sin .env). Crea .env con SUPABASE_URL y SUPABASE_ANON_KEY para incluir la nube."
fi

OS="$(uname -s)"
case "$OS" in
  Darwin)
    echo "=== Build macOS (.dmg) ==="
    flutter build macos --release --no-tree-shake-icons "${DART_DEFINES[@]:-}"
    chmod +x scripts/build_macos_dmg.sh
    # build_macos_dmg asume que flutter build ya se hizo
    DMG_DIR="$ROOT/build/dmg"
    BUILD_DIR="$ROOT/build/macos/Build/Products/Release"
    STAGING="$DMG_DIR/staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$BUILD_DIR/iris_dp.app" "$STAGING/"
    ln -sf /Applications "$STAGING/Applications"
    mkdir -p "$DMG_DIR"
    hdiutil create -volname "IRIS DP" -srcfolder "$STAGING" -ov -format UDZO "$DMG_DIR/IRIS-DP.dmg"
    echo ""
    echo "✓ Instalador macOS: $DMG_DIR/IRIS-DP.dmg"
    echo "  1. Abre el .dmg"
    echo "  2. Arrastra IRIS DP a Aplicaciones"
    echo "  3. Para otro Mac: copia el .dmg (AirDrop, USB, Drive…)"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows*)
    echo "=== Build Windows ==="
    flutter build windows --release --no-tree-shake-icons "${DART_DEFINES[@]:-}"
    echo "✓ Carpeta: build/windows/x64/runner/Release/"
    echo "  Comprime y comparte esa carpeta con otros PCs Windows."
    ;;
  *)
    echo "Sistema no soportado para build automático: $OS"
    exit 1
    ;;
esac

echo ""
echo "=== iPad / iPhone ==="
echo "Desde un Mac con Xcode:"
echo "  ./scripts/build_ipad.sh"
echo "Luego instala vía TestFlight o Apple Configurator (ver docs/distribuir_app.md)."
