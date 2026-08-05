#!/usr/bin/env bash
# Registra en Supabase todas las releases de GitHub que falten en app_releases.
# Uso: ./scripts/backfill_app_releases.sh owner/repo
set -euo pipefail

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "Uso: $0 owner/repo"
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$ROOT/scripts/register_app_release.sh"

echo "→ Tags en GitHub para $REPO…"
tags=$(gh release list --repo "$REPO" --limit 50 --json tagName -q '.[].tagName')

for tag in $tags; do
  echo "  · $tag"
  SUPABASE_URL="$SUPABASE_URL" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
    "$ROOT/scripts/register_app_release.sh" --tag "$tag" --repo "$REPO" || true
done

echo "✓ Backfill completado"
