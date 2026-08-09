# Backlog — deuda fuera del plan operativo actual

Items registrados para no perderlos; no bloquean Fase 1 ni Fase 2.

## Export compositor — template de citas narrativas

**Detectado:** revisión visual PDF Fase 1 (9 ago 2026).

**Síntoma:** en el compositor (`BibleExportPdfRenderer` / bloques de cita del template), las secciones **Cámara**, **Exposición** y **Localización** muestran un bloque de cita vacío con comillas literales `""` cuando no hay texto narrativo para esa sección. Debería ocultarse el bloque entero si está vacío.

**Notas:**
- No ocurre en export clásico.
- Óptica se ve bien cuando sí hay narrativa.
- Bug cosmético preexistente del template de citas; **no** relacionado con integración `contentJson` ni alcance Fase 1.

**Relacionado (menor):** en la página de **Óptica** del compositor, "Intención narrativa" puede aparecer duplicada (cita en encabezado + primera fila de tabla). Redundante, no incorrecto.

**Archivos probables:** `lib/features/visual_bible/export/pdf/`, `lib/features/visual_bible/export/builder/bible_export_composition_builder.dart`.

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
| `captureResolution` | `camera_sensor_section.dart` | Sí | Sí (Camera) | Campo de Cámara; Format lee blob primero vía resolve |
| `formatNarrativeIntent` | ~~NarrativeBridgeCard Format~~ | No (oculto) | — | Duplicado eliminado en Format |
| `formatNarrativeIntent` | Otras secciones vía `setNarrativeIntentForSection` | Sí (otras secciones) | Por sección | No afecta Format tras ocultar bridge |
| `aspectRatioJustification` | Ningún widget activo | Solo lectura legacy | Evaluar | Fallback de `intentNarrative`; sin escritor UI |

### Pendiente post-Format (fuera de alcance)

- **Completion** de otras secciones sin blob.
- **Migración Camera** de `captureResolution`.
- **Presets** escribiendo `aspectRatio` sin blob.

No es bug del piloto si queda documentado; evaluar antes de migrar otras secciones.

## Fase 6 — design system: badges de rol

**Detectado:** Checkpoint C A-CAM/B-CAM (9 ago 2026).

Los chips de rol en Equipo/Format/Optics Lab (`project_camera_roster_bar`, badges en `equipment_brand_grouped_list`) reutilizan tokens (`AppPalette` / `AppTypography` / `AppSpacing`) pero **no** un widget compartido: no existía uno adecuado para rol + título + hint.

**Candidato:** extraer `AppRoleBadge` y consolidar con la pill `ACTIVE` de Format y el badge LUKA.

---

## Pendiente post-routing (no iniciado — 9 ago 2026)

### Piloto Camera (`camera_sensor_section.dart`)

Dualidad columnas vs `contentJson` intacta (nunca empezado). El futuro «modo de sensor a nivel de proyecto» (unificación PHFX/Format) debería vivir en blob de cámara — razón para no aplazarlo indefinidamente. **No empezar** hasta cerrar verificación real de Format piloto en PDF.

### Unificación modos PHFX (Format ↔ Optics Lab)

Dos modelos hoy: `sensorMode` string en Format vs `SensorModeSpec` (mm/px) en catálogo PHFX → Optics Lab. Requiere diseño nuevo; aplazada hasta routing estable (**routing ya en `69c6aec`**). Format sigue heredando solo dimensiones mm vía `resolveProjectCamera()`.

### Import Excel catálogo v1.1

Código actual (`equipment_spreadsheet_service` / `catalog_importer`) solo conoce hojas/columnas v0. **No escribir importador** hasta cerrar estas 3 decisiones:

1. **`Modos_Cámara` vs JSON embebido:** ¿sustituye el merge `cameras_expansion.json` / `phfx_camera_formats.json` → `sensorModesJson`, o convive (Excel gana / JSON fallback)?
2. **`Película`:** no hay tabla Drift; propuesta por defecto — catálogo estático JSON (no asignable a proyecto como cámara/óptica), sin migración de schema.
3. **`estado_dato` / `Auditoría` / `Fuentes`:** metadatos de curación humana; **no** persistir en Drift (salvo que producto pida trazabilidad en app).

Datos Excel (referencia): Cámaras 6/70 verificadas, Ópticas 65/416, Luces 0/90, Modos_Cámara 43 filas (5 cámaras), Película 8. Curación en paralelo, no bloquea código de routing/Format.
