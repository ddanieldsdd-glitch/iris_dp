# Catálogo técnico IRIS DP

Fuente de verdad humana del material técnico (cámaras, modos de sensor, ópticas, luces).

## Catálogo embebido (desde 2026-10-03)

El catálogo que trae la app en `assets/catalog/` se **genera**; no se edita a mano.

```bash
python3 tools/build_catalog.py
```

Capas, de menor a mayor prioridad:

| Capa | Archivo | Qué aporta |
|------|---------|------------|
| Base heredada | `tools/catalog_base/*.json` | Fichas y modos de sensor previos (PHFX). Sin estado ni fuente |
| Lista v1.8 | `fuentes/lista_material_tecnico_v1_8.xlsx` | Volumen: cámaras, modos, ópticas, luces y su verificación |
| Master v17 | `fuentes/master_auditoria_v17.xlsx` | Reglas y datos contrastados; ganan a la lista |

Reglas del master que aplica el generador:

- El círculo de imagen solo se guarda si la fuente lo publica. El de la base estaba inferido por formato y se descarta.
- El squeeze solo aplica a ópticas anamórficas.
- Un modo de sensor sin gate no entra en el catálogo.
- Toda ficha lleva estado y fuente. Lo que la lista marca como verificado contra una fuente pero no ha pasado su auditoría queda como SECUNDARIO.

El resultado y las incidencias de cada generación quedan en [`INFORME_CATALOGO.md`](INFORME_CATALOGO.md).

Para actualizar el catálogo: sustituir los Excel de `fuentes/`, ejecutar el script, subir `CATALOG_VERSION` en el script y `kEmbeddedCatalogVersion` en `lib/shared/equipment/catalog_models.dart`, y revisar el informe.

## Archivos (import manual v1.7)

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

## UI Equipo

Menú ⋮ → **Importar catálogo oficial (JSON)** (multi-archivo).
Clasifica por nombre (`cameras_*` / `lenses_*` / `lights_*`) o por forma del JSON.
Código: `lib/shared/equipment/official_catalog_import.dart`.

Distinto de **Importar lista desde Excel** (roundtrip del proyecto).

## Import en app (`CatalogExcelImporter`)

Orden Claude (P2):

1. Cámaras + Modos_Cámara → `importCamerasFromJson` / `importCameras`
2. Ópticas → `importLensesFromJson`
3. Luces → `importLightsFromJson`
4. Película / Formatos_Referencia / Fuentes → **no** (aún; Película sin tabla Drift)

Reglas:

- Solo actualiza `isCustom=false`
- El import actual todavía no guarda `estado_dato` ni fuentes; las columnas existen desde schema 41 y el import las rellenará en el ítem 4.2 de `docs/PLAN_ACCION.md`
- No toca sync / `cloud_project_snapshots`
- Roundtrip de **proyecto** sigue en `EquipmentSpreadsheetService` (v0)

## Decisiones cerradas

1. Excel/JSON de catálogo **gana** sobre expansion embebida al importarse.
2. Película: JSON estático futuro, sin Drift.
3. ~~Metadatos de curación: no en Drift.~~ Revertida el 2026-10-03: estado, confianza y fuente se guardan por ficha (schema 41, `CatalogProvenanceColumns`), con los estados de `77_Estados_Dato` del master (`lib/shared/equipment/catalog_data_status.dart`).
