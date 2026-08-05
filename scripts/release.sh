#!/usr/bin/env bash
# Publica una versión nueva con un solo comando.
# GitHub Actions compila macOS + Windows + iPad, crea el Release y registra Supabase.
#
# Uso:
#   ./scripts/release.sh              # sube solo build (+1), tag v1.0.5+11
#   ./scripts/release.sh 1.0.6        # versión 1.0.6+11 (build +1)
#   ./scripts/release.sh 1.0.6 12       # versión 1.0.6 build 12 exactos
#   ./scripts/release.sh --dry-run      # muestra qué haría sin cambiar nada
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

NEW_NAME="${ARGS[0]:-$CURRENT_NAME}"
NEW_BUILD="${ARGS[1]:-$((CURRENT_BUILD + 1))}"
TAG="v${NEW_NAME}"
NEW_VERSION="${NEW_NAME}+${NEW_BUILD}"

echo "=== IRIS DP Release ==="
echo "  Actual:  ${CURRENT_NAME}+${CURRENT_BUILD}"
echo "  Nueva:   ${NEW_VERSION}"
echo "  Tag:     ${TAG}"
echo ""

if [[ "$DRY_RUN" == "1" ]]; then
  echo "(dry-run) No se modificó nada."
  echo "GitHub Actions publicaría .dmg, .zip, .ipa y registraría Supabase."
  exit 0
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "✗ El tag ${TAG} ya existe. Elige otra versión."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "→ Hay cambios sin commit. Se incluirán en el release."
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
REPO=$(git config --get remote.origin.url | sed -E 's#.*github.com[:/](.+)(\.git)?#\1#')
echo "  https://github.com/${REPO}/actions"
echo ""
echo "iPad — cuando termine CI:"
echo "  1. En el iPad: instala SideStore (sidestore.io)"
echo "  2. Ajustes → Buscar actualizaciones → Descargar IPA"
echo "     o desde el Release en GitHub"
echo "  3. Abrir el .ipa con SideStore"
echo ""
echo "  Guía completa: docs/ipad_sidestore.md"
