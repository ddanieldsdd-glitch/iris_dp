#!/usr/bin/env bash
# Registra URLs de GitHub Releases en Supabase (tabla app_releases).
# Uso: register_app_release.sh --tag v1.0.2 --repo owner/repo
# Requiere: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG=""
REPO=""
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

if [[ -z "$TAG" || -z "$REPO" ]]; then
  echo "Uso: $0 --tag v1.0.2 --repo owner/repo [--notes \"Cambios...\"]"
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY"
  exit 1
fi

VERSION_LINE=$(grep '^version:' "$ROOT/pubspec.yaml" | head -1)
FULL="${VERSION_LINE#version: }"
FULL="${FULL// /}"
VERSION="${FULL%%+*}"
BUILD="${FULL##*+}"

MACOS_URL="https://github.com/${REPO}/releases/download/${TAG}/IRIS-DP.dmg"
WIN_URL="https://github.com/${REPO}/releases/download/${TAG}/IRIS-DP-Windows.zip"

notes_json="null"
if [[ -n "$NOTES" ]]; then
  notes_json=$(python3 -c "import json; print(json.dumps('$NOTES'))")
fi

payload=$(cat <<EOF
[
  {
    "platform": "macos",
    "version": "${VERSION}",
    "build_number": ${BUILD},
    "download_url": "${MACOS_URL}",
    "release_notes": ${notes_json}
  },
  {
    "platform": "windows",
    "version": "${VERSION}",
    "build_number": ${BUILD},
    "download_url": "${WIN_URL}",
    "release_notes": ${notes_json}
  }
]
EOF
)

echo "→ Registrando v${VERSION}+${BUILD} en Supabase…"

curl -sf -X POST "${SUPABASE_URL}/rest/v1/app_releases?on_conflict=platform,build_number" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "$payload"

echo ""
echo "✓ macOS: ${MACOS_URL}"
echo "✓ Windows: ${WIN_URL}"
