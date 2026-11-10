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

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

notes_json="null"
if [[ -n "$NOTES" ]]; then
  notes_json=$(python3 -c "import json; print(json.dumps('$NOTES'))")
fi

# Solo se registra lo que de verdad está en el Release: la publicación sigue
# adelante aunque falle la compilación de Windows, y el actualizador ofrecería
# una descarga que no existe.
asset_exists() {
  curl -sfIL --retry 3 --retry-delay 2 -o /dev/null "$1"
}

# La huella solo se envía si la base ya tiene la columna (migración 014):
# publicar no puede romperse por eso.
has_sha_column=0
if curl -sf -o /dev/null "${SUPABASE_URL}/rest/v1/app_releases?select=sha256&limit=1" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"; then
  has_sha_column=1
else
  echo "::warning::app_releases sin columna sha256: se registra sin huella (falta la migración 014)"
fi

release_sha() {
  curl -sfL --retry 3 --retry-delay 2 "$1" | shasum -a 256 | cut -d' ' -f1
}

entries=""
registered=()
for item in "macos|IRIS-DP.dmg" "windows|IRIS-DP-Windows.zip"; do
  platform="${item%%|*}"
  url="${BASE_URL}/${item##*|}"
  if ! asset_exists "$url"; then
    echo "::warning::${platform}: no está en el Release, no se registra (${url})"
    continue
  fi
  sha_field=""
  if [[ "$has_sha_column" == 1 && "$platform" != "ipad" ]]; then
    sha="$(release_sha "$url" || true)"
    # 64 ceros y letras: si la descarga falló, shasum da la huella de nada.
    if [[ "$sha" =~ ^[0-9a-f]{64}$ && "$sha" != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]]; then
      sha_field=", \"sha256\": \"${sha}\""
    else
      echo "::warning::${platform}: no se pudo calcular la huella"
    fi
  fi
  entry="{\"platform\": \"${platform}\", \"version\": \"${VERSION}\", \"build_number\": ${BUILD}, \"download_url\": \"${url}\", \"release_notes\": ${notes_json}${sha_field}}"
  entries="${entries:+${entries},}${entry}"
  registered+=("${platform}: ${url}")
done

if [[ -z "$entries" ]]; then
  echo "✗ ${TAG} no tiene ningún archivo publicado: no se registra nada."
  exit 1
fi

echo "→ Registrando v${VERSION}+${BUILD} en Supabase…"

curl -sf -X POST "${SUPABASE_URL}/rest/v1/app_releases?on_conflict=platform,build_number" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "[${entries}]"

echo ""
for line in "${registered[@]}"; do
  echo "✓ ${line}"
done
