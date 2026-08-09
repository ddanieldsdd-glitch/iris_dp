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
