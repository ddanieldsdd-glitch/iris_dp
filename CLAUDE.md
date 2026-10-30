# IRIS DP · notas para Claude

App Flutter de dirección de fotografía (guion técnico, planta de cámara y luz, 3D, Unreal, biblia visual). Contexto general en `AI_CONTEXT.md` y `ARCHITECTURE.md`.

## Dónde está cada plan (planes vivos, con estado por punto)

- `docs/PLAN_ACCION.md`: tablero general; fase G = guion técnico, exports y hoja de rodaje.
- `docs/PLAN_F6_3D_PREVIS.md`: planta 2D, 3D, IRIS Stage y Unreal (F6.20 lleva los assets, Fab/Quixel y RealityScan).
- `docs/PLAN_IPHONE.md`: IRIS en el iPhone (IP.x).
- `docs/PLAN_IRIS_PC.md`: Windows.

Al terminar un punto, marca su estado en el plan en el mismo PR.

## Cómo se trabaja

- Una rama `plan/<fase>` por bloque y un PR a `main`. Antes de empezar, `git fetch` y partir de `origin/main` actualizado.
- No commitear los registrantes de plugins de `windows/` y `macos/` si solo cambian finales de línea.
- Formatear solo los archivos nuevos: `dart format` reescribe enteros los existentes.
- Textos de la interfaz y mensajes de commit en español.

## Comandos

```
flutter pub get
flutter analyze          # hay ~110 avisos «info» heredados; no debe haber «error»
flutter test             # suite completa
flutter test test/technical_script test/shoot_documents test/shared
```

En Windows: `scripts/run_windows.ps1` y `scripts/build_windows.ps1` (ver `docs/DESARROLLO_EN_WINDOWS.md`).

## Mapa rápido

- Guion técnico: `lib/features/technical_script/`; exports en `lib/shared/technical_script_export/` y `lib/shared/pdf_export/technical_script_pdf.dart`.
- Hoja de rodaje (orden propio por jornada): `lib/features/shoot_documents/`.
- Planta y 3D: `lib/features/camera_plan/` (3D en `rig/`, visor en `assets/viewer3d/`).
- Unreal: `lib/features/unreal_link/` y `tools/unreal/iris_stage/`.
