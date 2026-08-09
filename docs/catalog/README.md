# Catálogo técnico IRIS DP

Fuente de verdad humana del material técnico (cámaras, modos de sensor, ópticas, luces).

## Archivos

| Archivo | Rol |
|---------|-----|
| `lista_de_material_tecnico_v1_7.xlsx` | Excel completo v1.7 (Fase 1 verificación) |
| `cameras_modos_v1_7.json` | Cámaras + modos normalizados para import en app |
| `cameras_modos_v1_7_clean.xlsx` | Subconjunto Cámaras/Modos (referencia; el paquete Dart `excel` puede no abrirlo) |

Regenerar JSON:

```bash
python3 tools/export_catalog_excel_to_json.py \
  docs/catalog/lista_de_material_tecnico_v1_7.xlsx \
  docs/catalog/cameras_modos_v1_7.json
```

## Import en app

- Roundtrip de **equipo de proyecto** (custom): `EquipmentSpreadsheetService` (v0).
- Import de **catálogo oficial**:
  - JSON (recomendado): `CatalogExcelImporter.importCamerasFromJson`
  - Excel simple: `CatalogExcelImporter.importCameras` (workbooks que `package:excel` sí abre)
  - Upsert: `upsertCatalogCameras` — solo `isCustom=false`
  - `Modos_Cámara` → `Cameras.sensorModesJson` (shape `SensorModeSpec` + extras)
  - No persiste `estado_dato` / auditoría / Fuentes
  - No toca sync / `cloud_project_snapshots`

## Decisiones (cerradas)

1. Excel/JSON de catálogo **gana** sobre `cameras_expansion.json` al importarse (convive: embebido primero, Excel después).
2. Película: fuera de alcance (JSON estático futuro, sin tabla Drift).
3. Metadatos de curación: no en Drift.

## Hojas no importadas

README, Instrucciones, Auditoría, Fuentes, Mapa_Sistema, Flujo_Eleccion, Control_Datos, Funciones_Futuras, Pendientes, Fase_2_*, Arquitectura_Dependencias, Verificacion_Fase_1, etc.
