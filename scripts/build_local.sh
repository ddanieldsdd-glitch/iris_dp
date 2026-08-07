#!/usr/bin/env bash
# Build de release 100 % local: ignora .env aunque exista.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ Build local puro (sin credenciales embebidas)"
echo "→ La nube se puede vincular después desde Ajustes en la app instalada"

OS="$(uname -s)"
case "$OS" in
  Darwin)
    echo "=== Build macOS (.dmg) — modo local ==="
    flutter build macos --release --no-tree-shake-icons
    DMG_DIR="$ROOT/build/dmg"
    BUILD_DIR="$ROOT/build/macos/Build/Products/Release"
    STAGING="$DMG_DIR/staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$BUILD_DIR/iris_dp.app" "$STAGING/"
    ln -sf /Applications "$STAGING/Applications"
    mkdir -p "$DMG_DIR"
    hdiutil create -volname "IRIS DP" -srcfolder "$STAGING" -ov -format UDZO "$DMG_DIR/IRIS-DP-local.dmg"
    echo ""
    echo "✓ Instalador macOS (local): $DMG_DIR/IRIS-DP-local.dmg"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows*)
    echo "=== Build Windows — modo local ==="
    flutter build windows --release --no-tree-shake-icons
    echo "✓ Carpeta: build/windows/x64/runner/Release/"
    ;;
  *)
    echo "Sistema no soportado: $OS"
    exit 1
    ;;
esac

echo ""
echo "Para iPad local: ./scripts/build_ipad.sh (sin .env en el entorno)"
