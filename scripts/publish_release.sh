#!/usr/bin/env bash
# Publicación manual: registra una release ya subida a GitHub en Supabase.
# Para CI automático, ver .github/workflows/release.yml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

TAG="${1:-}"
REPO="${2:-}"

if [[ -z "$TAG" ]]; then
  echo "Uso: $0 <tag> [owner/repo]"
  echo "Ejemplo: $0 v1.0.2 mi-usuario/iris-dp"
  echo ""
  echo "Requiere SUPABASE_SERVICE_ROLE_KEY en .env o entorno."
  exit 1
fi

if [[ -z "$REPO" ]]; then
  if git -C "$ROOT/.." rev-parse --is-inside-work-tree &>/dev/null; then
    REPO=$(git -C "$ROOT/.." config --get remote.origin.url | sed -E 's#.*github.com[:/](.+)(\.git)?#\1#' | tr -d '\n')
  elif git -C "$ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    REPO=$(git -C "$ROOT" config --get remote.origin.url | sed -E 's#.*github.com[:/](.+)(\.git)?#\1#' | tr -d '\n')
  fi
fi

if [[ -z "$REPO" ]]; then
  echo "Indica el repo: $0 $TAG owner/repo"
  exit 1
fi

chmod +x "$ROOT/scripts/register_app_release.sh"
exec "$ROOT/scripts/register_app_release.sh" --tag "$TAG" --repo "$REPO"
