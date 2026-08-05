#!/usr/bin/env bash
# Empaqueta iris_dp.app en un DMG para macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="iris_dp"
BUILD_DIR="$ROOT/build/macos/Build/Products/Release"
DMG_DIR="$ROOT/build/dmg"
DMG_NAME="IRIS-DP.dmg"

cd "$ROOT"

ENV_FILE="$ROOT/.env"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

BUILD_ARGS=(build macos --release)
if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_ANON_KEY" ]]; then
  BUILD_ARGS+=(
    --dart-define=SUPABASE_URL="$SUPABASE_URL"
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  )
  echo "→ Incluyendo credenciales Supabase desde .env"
fi

if [[ "${SKIP_FLUTTER_BUILD:-}" != "1" ]]; then
  flutter "${BUILD_ARGS[@]}"
else
  echo "→ SKIP_FLUTTER_BUILD=1 (solo empaquetar DMG)"
fi

mkdir -p "$DMG_DIR"
rm -f "$DMG_DIR/$DMG_NAME"

# DMG simple con hdiutil
STAGING="$DMG_DIR/staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$BUILD_DIR/$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/assets/branding/iris_dp_logo_master.png" "$STAGING/IRIS-DP-logo.png"

hdiutil create -volname "IRIS DP" -srcfolder "$STAGING" -ov -format UDZO "$DMG_DIR/$DMG_NAME"
echo "✓ $DMG_DIR/$DMG_NAME"

# Notarización (requiere APPLE_ID, APPLE_APP_PASSWORD, TEAM_ID en entorno):
# xcrun notarytool submit "$DMG_DIR/$DMG_NAME" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$TEAM_ID" --wait
# xcrun stapler staple "$DMG_DIR/$DMG_NAME"
