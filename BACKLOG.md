# Backlog — deuda fuera del plan operativo actual

Items registrados para no perderlos; no bloquean Fase 1 ni Fase 2.

## Export compositor — template de citas narrativas

**Resuelto (9 ago 2026):**
- `_narrativeBlock` omite el bloque si `text` está vacío/blanco → ya no se pintan comillas literales `""`.
- Óptica: si la página ya tiene bloque `narrative`, el enrich no vuelve a inyectar «Intención narrativa» en la tabla de specs.

---

## Fase 3 piloto Format — acoplamientos no resueltos

Tras unificar escritura en `formatData`, columnas legacy (`aspectRatio`, `captureResolution`, etc.) pueden quedar stale.

### Correcciones aplicadas en cierre piloto (9 ago 2026)

- **PDF clásico:** slots Format resueltos vía `FormatPilotResolve` (blob → legacy); filas custom excluyen claves piloto.
- **NarrativeBridge Format:** módulo stitch `narrative` oculto; mismo concepto que `intentNarrative` en Director's Intent (blob canónico).
- **Optics / Concept / Completion / export hash:** lectura con `FormatPilotResolve` + `formatSectionContentJson`.

### Escritores externos (permanecen — no migrados en este piloto)

| Campo | Escritor | ¿Sigue columna? | ¿Migrar después? | Motivo |
| ----- | -------- | --------------- | ---------------- | ------ |
| `aspectRatio` | `bible_preset_service.dart` | Sí | Sí (presets) | Aplica plantillas globales; fuera alcance Format |
| `captureResolution` | ~~`camera_sensor_section.dart`~~ | Solo fallback | Hecho (Camera) | Escritura canónica en blob; columna legacy sin dual-write |
| `formatNarrativeIntent` | ~~NarrativeBridgeCard Format~~ | No (oculto) | — | Duplicado eliminado en Format |
| `formatNarrativeIntent` | Otras secciones vía `setNarrativeIntentForSection` | Sí (otras secciones) | Por sección | No afecta Format tras ocultar bridge |
| `aspectRatioJustification` | Ningún widget activo | Solo lectura legacy | Evaluar | Fallback de `intentNarrative`; sin escritor UI |

### Pendiente post-Format (fuera de alcance)

- **Completion** de otras secciones sin blob.
- **Presets** escribiendo `aspectRatio` sin blob.

No es bug del piloto si queda documentado; evaluar antes de migrar otras secciones.

## Fase 6 — design system: badges de rol

**Detectado:** Checkpoint C A-CAM/B-CAM (9 ago 2026).

Los chips de rol en Equipo/Format/Optics Lab (`project_camera_roster_bar`, badges en `equipment_brand_grouped_list`) reutilizan tokens (`AppPalette` / `AppTypography` / `AppSpacing`) pero **no** un widget compartido: no existía uno adecuado para rol + título + hint.

**Candidato:** extraer `AppRoleBadge` y consolidar con la pill `ACTIVE` de Format y el badge LUKA.

---

## Pendiente post-routing (no iniciado — 9 ago 2026)

### Piloto Camera (`camera_sensor_section.dart`) — cerrado (9 ago 2026)

**Migrado:** `captureResolution` → blob canónico `cameraData` vía `CameraPilotResolve`; UI Cámara escribe/lee blob (columna legacy solo fallback); hash export incluye resolución resuelta; label PDF «Resolución de captura»; completion/sidebar/overview leen blob vía `cameraSectionContentJson`.

**Tests:** `camera_pilot_resolve_test`, `camera_section_persistence_pilot_test`, `camera_pdf_export_regression_test`, `camera_completion_pilot_test`.

**Fuera de alcance (post-piloto):** unificación modos sensor Format ↔ Optics Lab (PHFX); migrar más campos Camera al blob.

### Unificación modos PHFX (Format ↔ Optics Lab)

Dos modelos hoy: `sensorMode` string en Format vs `SensorModeSpec` (mm/px) en catálogo PHFX → Optics Lab. Requiere diseño nuevo; aplazada hasta routing estable (**routing ya en `69c6aec`**). Format sigue heredando solo dimensiones mm vía `resolveProjectCamera()`.

### Import Excel catálogo v1.1 / v1.7 — slice Cámeras+Modos (iniciado)

**Hecho:** `CatalogExcelImporter` + `upsertCatalogCameras`; fixture `docs/catalog/cameras_modos_v1_7.json`; tool `tools/export_catalog_excel_to_json.py`.

**Decisiones cerradas:**
1. **`Modos_Cámara`:** → `sensorModesJson`; al importar catálogo, Excel/JSON **gana** sobre expansion embebida (no borra JSON assets; se aplica después).
2. **`Película`:** aplazada (JSON estático futuro, sin Drift).
3. **`estado_dato` / Auditoría / Fuentes:** no persistir en Drift.

**Pendiente:** UI de import en Equipo; Ópticas/Luces; rellenar gates faltantes en Excel (muchos modos sin `gate_*_mm`).

---
