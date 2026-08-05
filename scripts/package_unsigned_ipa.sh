#!/usr/bin/env bash
# Empaqueta Runner.app sin firma en IRIS-DP.ipa (SideStore re-firma en el dispositivo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/build/ios/iphoneos/Runner.app"
OUT_DIR="$ROOT/build/ios/ipa"
IPA_NAME="IRIS-DP.ipa"
STAGING="$OUT_DIR/staging"

if [[ ! -d "$APP_SRC" ]]; then
  echo "No se encontró $APP_SRC — ejecuta primero: flutter build ios --release --no-codesign"
  exit 1
fi

rm -rf "$STAGING" "$OUT_DIR/$IPA_NAME"
mkdir -p "$STAGING/Payload"
cp -R "$APP_SRC" "$STAGING/Payload/"

cd "$STAGING"
zip -qr "$OUT_DIR/$IPA_NAME" Payload
rm -rf "$STAGING"

echo "✓ $OUT_DIR/$IPA_NAME"
