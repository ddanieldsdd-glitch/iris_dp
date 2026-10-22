#!/usr/bin/env bash
# Deja lista la instalación automática de IRIS DP en el iPad:
#   1. guarda el equipo de firma (Personal Team de Xcode),
#   2. copia install_ipad.sh a un sitio fijo (no cambia al cambiar de rama),
#   3. programa una tarea de macOS que cada hora mira si toca renovar.
#
#   setup_ipad_install.sh [TEAM_ID]     configura y programa
#   setup_ipad_install.sh --uninstall   quita la tarea programada
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$HOME/Library/Application Support/IRIS-DP-installer"
LOG_DIR="$HOME/Library/Logs/IRIS-DP"
LABEL="com.ddanieldsdd.irisdp.ipad-install"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "✓ Tarea programada quitada."
  exit 0
fi

# ── 1. Equipo de firma ──────────────────────────────────────────────────────
TEAM="${1:-}"
if [[ -z "$TEAM" ]]; then
  # El que Xcode escribe al elegir «Team» en Signing & Capabilities.
  for pbx in "$(dirname "$ROOT")"/iris_dp*/ios/Runner.xcodeproj/project.pbxproj; do
    TEAM="$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]{10};' "$pbx" 2>/dev/null | grep -oE '[A-Z0-9]{10}' || true)"
    [[ -n "$TEAM" ]] && break
  done
fi
if [[ -z "$TEAM" ]]; then
  # O el del certificado «Apple Development» (campo OU).
  TEAM="$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | grep -oE 'OU *= *[A-Z0-9]{10}' | head -1 | grep -oE '[A-Z0-9]{10}' || true)"
fi
if [[ -z "$TEAM" ]]; then
  cat <<'TXT'
No encuentro tu equipo de firma. Una sola vez, en Xcode:
  1. Abre ios/Runner.xcworkspace de esta carpeta.
  2. Runner (azul, arriba a la izquierda) → target Runner → Signing & Capabilities.
  3. Team → elige «<tu nombre> (Personal Team)».
Luego vuelve a ejecutar este script.
TXT
  exit 1
fi
echo "$TEAM" > "$STATE_DIR/team_id"
echo "✓ Equipo de firma: $TEAM"

# ── 2. Copia fija del instalador ────────────────────────────────────────────
cp "$ROOT/scripts/install_ipad.sh" "$STATE_DIR/install_ipad.sh"
chmod +x "$STATE_DIR/install_ipad.sh"
echo "✓ Instalador en $STATE_DIR"

# ── 3. Tarea programada (cada hora y al iniciar sesión) ─────────────────────
FLUTTER_BIN="$(dirname "$(command -v flutter)")"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$STATE_DIR/install_ipad.sh</string>
    <string>--auto</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$FLUTTER_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>LANG</key><string>es_ES.UTF-8</string>
    <key>LC_ALL</key><string>es_ES.UTF-8</string>
  </dict>
  <key>StandardOutPath</key><string>$LOG_DIR/launchd.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/launchd.log</string>
</dict>
</plist>
PLIST
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "✓ Tarea programada: cada hora mira si toca renovar (registro en $LOG_DIR)."
