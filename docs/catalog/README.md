# Catálogo técnico IRIS DP

Fuente de verdad humana del material técnico (cámaras, modos de sensor, ópticas, luces).

## Archivos

| Archivo | Rol |
|---------|-----|
| `lista_de_material_tecnico_v1_7.xlsx` | Excel completo v1.7 (Fase 1 verificación) |
| `cameras_modos_v1_7.json` | Cámaras + modos → Drift |
| `lenses_v1_7.json` | Ópticas → Drift |
| `lights_v1_7.json` | Luces → Drift |
| `design/` | Hojas meta/diseño en markdown (no Drift) |

Regenerar desde Excel:

```bash
python3 tools/export_catalog_excel_to_json.py \
  docs/catalog/lista_de_material_tecnico_v1_7.xlsx \
  docs/catalog/
```

## Import en app (`CatalogExcelImporter`)

Orden Claude (P2):

1. Cámaras + Modos_Cámara → `importCamerasFromJson` / `importCameras`
2. Ópticas → `importLensesFromJson`
3. Luces → `importLightsFromJson`
4. Película / Formatos_Referencia / Fuentes → **no** (aún; Película sin tabla Drift)

Reglas:

- Solo actualiza `isCustom=false`
- No persiste `estado_dato` / auditoría
- No toca sync / `cloud_project_snapshots`
- Roundtrip de **proyecto** sigue en `EquipmentSpreadsheetService` (v0)

## Decisiones cerradas

1. Excel/JSON de catálogo **gana** sobre expansion embebida al importarse.
2. Película: JSON estático futuro, sin Drift.
3. Metadatos de curación: no en Drift.
