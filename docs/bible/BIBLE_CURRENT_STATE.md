# Biblia Visual — Estado desplegable

Fecha: 2026-08-08 (actualizado tras compositor PDF y cierre de auditoría)  
Principio: **no destructivo** — legacy vivo; v2 y compositor como capas paralelas.

## 1. Jerarquía operativa

```
VisualBible (Drift VisualBibles + VisualBibleData)
 └── BibleSectionGroup (sidebar)
      └── BibleSectionDefinition (pantalla)
           ├── contentJson → BibleSectionField[] + values
           ├── template (renderer key)
           ├── tablas hijas (color/exposure/lighting/tests/moodboard)
           └── estilo visual → SharedPreferences
```

**Paralelo (no sustituye legacy en UI pública):**

- Motor v2: `lib/features/visual_bible/v2/` → `VisualBibleDocuments` (Drift schema 34+)
- Compositor export: `lib/features/visual_bible/export/` → borrador versionado en SharedPreferences
- Anotaciones transversales: `lib/shared/annotations/` → `ProjectAnnotationDocuments` (schema 36)

## 2. Flujos principales

| Flujo | Entrada | Salida |
|-------|---------|--------|
| Edición clásica | `visual_bible_screen.dart` | Secciones Stitch + moodboard |
| Export clásico | Config sheet → `_runExport` | PDF legacy + preview final |
| Export compositor | Config sheet → compositor → preview | PDF híbrido (`BibleExportPdfRenderer`) |
| Moodboard detalle | `moodboard_lightbox.dart` | Catálogo + marcadores pantalla + anotaciones |
| Sync proyecto | `project_content_bundle.dart` v4 | Biblia + moodboard + anotaciones + setups |

## 3. Compositor PDF (no destructivo)

- **Modelo:** `BibleExportComposition` / `BibleExportPage` (cover, generated, blank, custom)
- **Builder:** `BibleExportCompositionBuilder` — enriquece desde bundle legacy/v2 sin mutar fuente
- **Store:** hasta 20 revisiones en SharedPreferences por proyecto
- **UI:** rail reordenable, preview A4, post-its, `AnnotationCanvas`, undo/redo
- **PDF:** bloques principales + imágenes (`PdfSafeImage`) + trazos + diagramas iluminación

La Biblia fuente **no se altera** al montar ni exportar; solo la entrega.

## 4. Moodboard ↔ Biblia ↔ PDF

| Pieza | Rol |
|-------|-----|
| `MoodboardAssociation` | Reglas visibilidad por `assignedSections` |
| `MoodboardCatalogService` | Catálogo editable por proyecto + sugerencia de pantallas |
| `MoodboardReferenceMetaStore` | Meta cinematográfica por imagen (SharedPreferences) |
| `MoodboardSectionAssignField` | Marcadores de pantalla (chips) |
| Lightbox `_SidePanel` | Catálogo + «Aparece en la biblia» + sugerir desde catálogo |
| `BibleReferencesPanel` | Paste/drop en sección → sync `assignedSections` |
| PDF legacy / compositor | Orden y filtros respetan `assignedSections` |

## 5. Anotaciones (Apple Pencil)

Sistema compartido integrado en:

- Moodboard lightbox (`moodboard_image`)
- Diagramas iluminación (`lighting_setup`)
- Planos cámara (`camera_plan_shot/site/set`)
- PDF plantas (`camera_plan_pdf.dart`) y export compositor

Migración one-shot desde SharedPreferences legacy del moodboard.

## 6. Sync (bundle v4)

Export/import incluye: `VisualBibles`, secciones, `ExposureBlocks`, `LightingSetups`, `CameraTests`, `VisualBibleDocuments`, `MoodboardImages`, `ProjectAnnotationDocuments`, con remapeo `bibleKey`.

Tests: `test/visual_bible_sync_test.dart`.

## 7. PDF — paridad legacy vs gaps

**Cubiertos en PDF legacy (`visual_bible_pdf_service.dart`):**

- direction, concept, color, lighting (+ diagramas), exposure/camera, moodboard (modo full), tests, optics
- format, texture, workflow (secciones de texto)

**Compositor híbrido:** cubre bloques enriquecidos del builder + anotaciones.

**Gap pendiente:** pantalla **Localización** (`location`) sin página PDF dedicada en legacy.

## 8. UX cerrada en auditoría

- **Resumen:** `bible_overview_section.dart` (pantalla dinámica, no persistida)
- **Onboarding biblia vacía:** `BibleStartScreen`, `structureInitialized`, bibliotecas pantallas/plantillas
- **Personalizar Biblia:** textos unificados sidebar / quick adjust / master config
- **Responsive iPad:** sidebar, AppBar, compositor
- **v2 oculto** en UI pública; flag `bible_engine_v2` default off

## 9. Tests relevantes

| Área | Archivo |
|------|---------|
| Composición export | `test/visual_bible_export/*` |
| Sync biblia | `test/visual_bible_sync_test.dart` |
| Anotaciones | `test/shared/annotations/*` |
| Moodboard catálogo | `test/moodboard_catalog_service_test.dart` |
| v2 modelo | `test/visual_bible_v2/bible_document_model_test.dart` |
| Onboarding / completion | `test/visual_bible_onboarding_test.dart`, `visual_bible_completion_test.dart` |

Suite global (última verificación): **172 passed, 4 skipped** (`widget_test`, `phase_1b`, `camera_catalog_expansion`).

## 10. QA manual pendiente

- iPad: compositor ~20 páginas con imágenes reales (memoria)
- Revisión visual export compositor vs preview
- Lightbox: marcadores ↔ strips en secciones ↔ orden PDF

## 11. Referencias

- Guía v2: `docs/bible/BIBLE_V2_README.md`
- Flag y política: `lib/features/visual_bible/v2/bible_v2_policy.dart`
- Puente PDF v2: `lib/features/visual_bible/v2/pdf/bible_pdf_layout_bridge.dart` (`pdfGaps`: solo `location`)
