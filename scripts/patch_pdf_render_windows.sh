#!/usr/bin/env bash
# Corrige el bug de pdf_render_maintained en Windows:
# el plugin declara su target CMake como "pdf_render_maintained",
# pero Flutter espera "pdf_render_maintained_plugin" (convención _plugin).
# Debe ejecutarse DESPUÉS de `flutter pub get` (que crea el symlink) y
# ANTES de `flutter build windows`.
set -e

CMAKE_FILE="windows/flutter/ephemeral/.plugin_symlinks/pdf_render_maintained/windows/CMakeLists.txt"

if [ ! -f "$CMAKE_FILE" ]; then
  echo "No se encontró $CMAKE_FILE"
  echo "¿Se ejecutó 'flutter pub get' antes de este script?"
  exit 1
fi

echo "Parcheando $CMAKE_FILE"

# 1. Cambia el nombre del target a pdf_render_maintained_plugin
sed -i.bak 's/set(PLUGIN_NAME "pdf_render_maintained")/set(PLUGIN_NAME "pdf_render_maintained_plugin")/' "$CMAKE_FILE"

# 2. Añade la variable de librerías bundled con el nombre exacto que
#    generated_plugins.cmake espera ("${plugin}_bundled_libraries")
if ! grep -q "set(pdf_render_maintained_bundled_libraries" "$CMAKE_FILE"; then
  echo 'set(pdf_render_maintained_bundled_libraries ${PLUGIN_BUNDLED_LIBRARIES} PARENT_SCOPE)' >> "$CMAKE_FILE"
fi

rm -f "$CMAKE_FILE.bak"
echo "Parche aplicado correctamente."
