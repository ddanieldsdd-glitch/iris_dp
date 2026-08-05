#!/usr/bin/env bash
# Publica una versión nueva con un solo comando.
# GitHub Actions compila macOS + Windows + iPad, crea el Release y registra Supabase.
#
# Uso:
#   ./scripts/release.sh              # build +1; si el tag ya existe, sube patch (1.0.6 → 1.0.7)
#   ./scripts/release.sh 1.0.8        # versión 1.0.8+5 (build +1)
#   ./scripts/release.sh 1.0.8 12     # versión 1.0.8 build 12 exactos
#   ./scripts/release.sh --dry-run    # muestra qué haría sin cambiar nada
#
# Requisitos (una vez):
#   - GitHub Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
#   - git push origin main
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=1
  else
    ARGS+=("$arg")
  fi
done

CURRENT_LINE=$(grep '^version:' pubspec.yaml | head -1)
CURRENT="${CURRENT_LINE#version: }"
CURRENT="${CURRENT// /}"
CURRENT_NAME="${CURRENT%%+*}"
CURRENT_BUILD="${CURRENT##*+}"

semver_re='^[0-9]+\.[0-9]+\.[0-9]+$'
build_re='^[0-9]+$'

bump_patch() {
  local major minor patch
  IFS='.' read -r major minor patch <<< "$1"
  echo "${major}.${minor}.$((patch + 1))"
}

tag_exists() {
  git rev-parse "$1" >/dev/null 2>&1
}

NEW_NAME="${ARGS[0]:-$CURRENT_NAME}"
NEW_BUILD="${ARGS[1]:-$((CURRENT_BUILD + 1))}"
AUTO_BUMPED=0

if [[ ! "$CURRENT_NAME" =~ $semver_re || ! "$CURRENT_BUILD" =~ $build_re ]]; then
  echo "✗ pubspec.yaml tiene una versión inválida: ${CURRENT_NAME}+${CURRENT_BUILD}"
  echo "  Corrige la línea version: (ej. version: 1.0.3+3)"
  exit 1
fi

if [[ ${#ARGS[@]} -ge 1 && ! "$NEW_NAME" =~ $semver_re ]]; then
  echo "✗ Versión inválida: «${NEW_NAME}»"
  echo "  Uso: ./scripts/release.sh [1.0.4] [build_number]"
  echo "  No pegues comentarios (# ...) en la misma línea del comando."
  exit 1
fi

if [[ ! "$NEW_BUILD" =~ $build_re ]]; then
  echo "✗ Build number inválido: «${NEW_BUILD}»"
  exit 1
fi

# Sin versión explícita: si vX.Y.Z ya existe, sube patch hasta encontrar tag libre.
if [[ ${#ARGS[@]} -eq 0 ]]; then
  while tag_exists "v${NEW_NAME}"; do
    NEW_NAME="$(bump_patch "$NEW_NAME")"
    AUTO_BUMPED=1
  done
fi

TAG="v${NEW_NAME}"
NEW_VERSION="${NEW_NAME}+${NEW_BUILD}"

echo "=== IRIS DP Release ==="
echo "  Actual:  ${CURRENT_NAME}+${CURRENT_BUILD}"
echo "  Nueva:   ${NEW_VERSION}"
echo "  Tag:     ${TAG}"
if [[ "$AUTO_BUMPED" == "1" ]]; then
  echo "  Nota:    tag v${CURRENT_NAME} ya existía → versión patch automática"
fi
echo ""

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "⚠ Estás en la rama «${CURRENT_BRANCH}», no en main."
  echo "  El release funcionará, pero conviene: git checkout main && git pull"
  echo ""
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "(dry-run) No se modificó nada."
  echo "GitHub Actions publicaría .dmg, .zip, .ipa y registraría Supabase."
  exit 0
fi

if tag_exists "$TAG"; then
  echo "✗ El tag ${TAG} ya existe. Indica otra versión:"
  echo "  ./scripts/release.sh 1.0.7"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "→ Hay cambios sin commit en el repo (no se incluyen automáticamente)."
  echo "  Haz commit antes del release si quieres que entren en el build."
fi

# Actualizar pubspec.yaml
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
else
  sed -i "s/^version: .*/version: ${NEW_VERSION}/" pubspec.yaml
fi

git add pubspec.yaml
git commit -m "release: ${TAG}" || true

git tag -a "$TAG" -m "Release ${NEW_VERSION}"

echo ""
echo "→ Subiendo a GitHub…"
git push origin HEAD
git push origin "$TAG"

echo ""
echo "✓ Tag ${TAG} enviado."
echo ""
echo "GitHub Actions (2-5 min):"
echo "  • IRIS-DP.dmg (Mac)"
echo "  • IRIS-DP-Windows.zip"
echo "  • IRIS-DP.ipa (iPad / SideStore)"
echo "  • Registro automático en Supabase"
echo ""
echo "Sigue el progreso:"
REPO=$(git config --get remote.origin.url | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')
echo "  https://github.com/${REPO}/actions"
echo ""
echo "iPad — cuando termine CI:"
echo "  1. En el iPad: instala SideStore (sidestore.io)"
echo "  2. Ajustes → Buscar actualizaciones → Descargar IPA"
echo "     o desde el Release en GitHub"
echo "  3. Abrir el .ipa con SideStore"
echo ""
echo "  Guía completa: docs/ipad_sidestore.md"
