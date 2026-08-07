#!/usr/bin/env bash
# Arranca IRIS DP en modo 100 % local (sin credenciales Supabase embebidas).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Modo local: sin --dart-define de Supabase/Cloudinary"
echo "→ Puedes vincular la nube después en Ajustes → Modo local / Nube"
echo "   (Cierra la app anterior por completo antes de continuar)"

flutter run -d "${1:-macos}"
