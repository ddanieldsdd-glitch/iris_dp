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
| Flujo v2.0 | `fuentes/flujo_sxt_superspeed_v2_0.xlsx` | Cámaras que faltaban, gates por modo, ALEXA SXT (ficha, formatos, medios y tiempos) y ZEISS Super Speed con círculo medido. Gana a todo lo anterior |

Reglas del master que aplica el generador:

- El círculo de imagen solo se guarda si la fuente lo publica. El de la base estaba inferido por formato y se descarta.
- El squeeze solo aplica a ópticas anamórficas.
- Un modo de sensor sin gate no entra en el catálogo.
- Toda ficha lleva estado y fuente. Lo que la lista marca como verificado contra una fuente pero no ha pasado su auditoría queda como SECUNDARIO.

### Luces (L13, 2026-10-21)

El tipo de luz es un vocabulario cerrado, «tecnología_formato» (`led_fresnel`, `tungsten_fresnel`, `hmi_open`…). Lo lee `lib/shared/equipment/light_kind.dart`.

- **Formato** (cómo emite): `fresnel`, `panel`, `flex` (panel flexible), `tube` (tubo), `cob` (COB/puntual), `balloon` (globo), `practical` (práctica), `open` (PAR/abierta), `profile` (recorte). Cada formato trae su haz, su tamaño y si emite en todas direcciones; es lo que usa la planta cuando la ficha no dice otra cosa.
- **Tecnología** (cuánta luz por vatio): `led`, `hmi`, `tungsten`, `fluorescent`.

Entre la lista v1.8 y la salida hay una capa de revisión, `tools/catalog_base/lights_revision.json`: corrige tipos y potencias mal puestos en la lista (L7-C, L5-C y LED 20K eran «fresnel» y se calculaban como tungsteno; el LED 20K figuraba con 20 000 W), arregla LUKA, marca duplicados y añade haz y fotometría con su fuente. Lo que la revisión corrige sale en el informe como «corregir en el Excel». Los duplicados van a `assets/catalog/retired.json` (`lights`), y al importar, la app pasa el equipo de los proyectos y las luces de las plantas a la ficha que se queda antes de borrar la otra.

**Columnas que añadir a la hoja «Luces» de la lista** (el generador ya las lee y, rellenas, mandan sobre la revisión):

| Columna | Qué lleva | Ejemplo |
|---|---|---|
| `formato` | Uno del vocabulario de arriba, en español o en código | `fresnel` |
| `tecnologia` | Ya existe. Uno de: LED, HMI, tungsteno, fluorescente | `LED` |
| `haz_grados` | Ángulo de haz (mitad de intensidad) con el que está tomada la fotometría | `58` |
| `fotometria_lux` | Lux en el eje, a plena potencia | `1100` |
| `fotometria_distancia_m` | Distancia de esa medida | `10` |
| `fotometria_condicion` | Accesorio y ajuste (lo pide la regla COND-0003 del master) | `flood, lámpara 1800 W` |
| `haz_spot_grados` | Haz más cerrado, si el aparato enfoca | `15` |
| `haz_flood_grados` | Haz más abierto | `58` |
| `fotometria_spot_lux` | Lux en el eje en spot, a `fotometria_distancia_m` | `11250` |
| `fotometria_flood_lux` | Lux en el eje en flood, a la misma distancia | `1100` |

Spot y flood salen en `lights.json` como `optics` (rango y puntos de fotometría). No pasan por la base: la planta los lee del asset por `externalId` (`lib/shared/equipment/light_optics.dart`). Un aparato sin rango en la ficha que por formato enfoca (fresnel, abierta, recorte) toma el típico de su formato, marcado como estimado.

La fuente y el estado de la fotometría van en las columnas de verificación de siempre (`fuente_verificacion`, `url_verificacion`, `estado_verificacion`, `campos_verificados`).

**Alta rápida de una luz que no está**: en la app se elige formato, marca y modelo, color (fija, bicolor o RGB) y vatios. Se guarda como luz propia con `externalId` = `marca_modelo` en minúsculas y la fuente «Alta rápida en IRIS · pendiente de configurar». Para completarla, se añade al Excel una fila con ese mismo `external_id`: al regenerar e importar el catálogo, la ficha del Excel la completa y la luz pasa a ser oficial.

Además de cámaras, ópticas y luces, genera `assets/catalog/recording.json`: medios y formatos de grabación por cámara, con tasa de datos y minutos por medio.

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
