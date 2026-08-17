# Biblia V2 — Audit de implementación

Fecha: 2026-08-08  
Objetivo: cutover a motor V2 como editor documental 100% personalizable; legacy solo compatibilidad.

---

## 1. Arquitectura actual

### Legacy (Group → Section → Renderer)

```
VisualBibles (Drift)
 └── BibleSectionGroup
      └── BibleSectionDefinition
           ├── contentJson + fields
           ├── template (renderer key)
           └── estilo → SharedPreferences (BibleSectionStyleStore)
```

**Entrada:** [`visual_bible_screen.dart`](../lib/features/visual_bible/visual_bible_screen.dart)  
**Plantillas:** [`BiblePresetService.applyBundle`](../lib/features/visual_bible/bible_preset_service.dart) → blueprint + layout IRIS + estilos SP  
**Onboarding:** `structureInitialized` + [`BibleStartScreen`](../lib/features/visual_bible/widgets/bible_start_screen.dart)

### V2 (Document → Page → Block)

```
VisualBibles.engineVersion = 'v2' | 'legacy'
VisualBibleDocuments (Drift) → documentJson (BibleDocument)
 └── BiblePage[]
      └── BibleBlock[] (type, layout, style, content)
```

**Motor:** [`BibleV2Host`](../lib/features/visual_bible/v2/editor/bible_v2_host.dart) → [`BibleCanvasEditor`](../lib/features/visual_bible/v2/editor/bible_canvas_editor.dart)  
**Persistencia:** [`BibleDocumentStore`](../lib/features/visual_bible/v2/persistence/bible_document_store.dart)  
**Plantillas V2:** [`BibleTemplatePackage`](../lib/features/visual_bible/v2/templates/bible_template_package.dart) + [`BibleTemplateApplyService`](../lib/features/visual_bible/v2/templates/bible_template_apply_service.dart)

---

## 2. Flujo de creación

| Evento | Legacy (antes) | V2 (objetivo) |
|--------|----------------|---------------|
| Nuevo proyecto | `ensureVisualBibleForProject`, `structureInitialized=false` | `engineVersion=v2`, documento vacío `pages=[]` |
| Abrir Biblia | Onboarding legacy o sidebar secciones | `BibleV2Host` + empty state o canvas |
| Plantilla | `applyBundle` → seed IRIS | Preview → deep clone `BibleTemplatePackage` |
| Proyecto antiguo | Sin cambios | `engineVersion=legacy` (default migración) |

---

## 3. Flujo de plantillas

**Legacy:** Biblioteca → clic «Usar» → `BiblePresetService` → grupos/secciones Drift + SP.

**V2:** Biblioteca → seleccionar → **Preview** → «Usar esta plantilla» → `BibleTemplateApplyService.applyPackage` → clona documento con IDs nuevos.

Separación UI: **Plantilla** (base reutilizable) vs **Ejemplo** (puede incluir sample content).

---

## 4. Legacy vs V2 — decisión de motor

| Señal | Motor |
|-------|-------|
| `VisualBibles.engineVersion == 'v2'` | V2 |
| `engineVersion == 'legacy'` o null | Legacy |
| Migración manual | Legacy → V2 vía `LegacyToDocumentMigrator` + `promoteToV2Engine` |

Flag SharedPreferences `BibleEngineV2Flag` queda como compatibilidad; fuente de verdad: columna Drift.

---

## 5. Archivos implicados

| Área | Archivos |
|------|----------|
| Routing | `visual_bible_screen.dart`, `project_hub_router.dart` |
| DB | `tables.dart`, `app_database.dart` (schema 37 `engineVersion`) |
| V2 core | `v2/model/*`, `v2/persistence/*`, `v2/commands/*` |
| Editor | `bible_v2_host.dart`, `bible_canvas_editor.dart`, `bible_block_inspector.dart` |
| Plantillas | `bible_template_library_sheet.dart`, `bible_template_preview_screen.dart`, `bible_v2_builtin_templates.dart` |
| Migración | `legacy_to_document_migrator.dart`, `bible_migration_service.dart` |
| Export | `export/pdf/bible_export_pdf_renderer.dart`, `v2/pdf/bible_pdf_layout_bridge.dart` |
| Tests | `test/visual_bible_v2/*`, `test/visual_bible_onboarding_test.dart` |

---

## 6. Matriz BibleBlockKind

| Kind | Canvas | Inspector | PDF | Status real |
|------|--------|-----------|-----|-------------|
| text | Completo | Sí | Sí | live |
| narrative | Completo | Sí | Sí | live |
| heroImage | Completo | UniversalBibleImageInput | Sí | live |
| moodboardRefs | Grid de refs | Sí | Sí | live |
| chipSelect | Completo | Sí | Sí | live |
| colorPalette | Swatches + hex | Sí | Sí | live |
| telemetry | Editable | Sí | Sí | live |
| equipmentList | Completo | Sí | Sí | live |
| lightingDiagram | Preview de planta | Sí | Sí | live |
| specsTable | Completo | Sí | Sí | live |
| workflowPipeline | Pasos persistidos | Sí | Sí | live |
| dynamicBlocks | Placeholder (puente migración) | Sí | Fallback | planned |

Kinds `planned` ocultos del picker de usuario en V2.

---

## 7. SharedPreferences vs Drift

| Dato | Almacenamiento |
|------|----------------|
| Documento V2 (pages, blocks, themes) | Drift `visual_bible_documents` |
| Motor activo | Drift `visual_bibles.engine_version` |
| Blueprint legacy | SP `iris_bible_blueprint_*` |
| Estilos legacy por sección | SP `iris_bible_section_styles_*` |
| Flag experimental v2 | SP (deprecated, mirror only) |

---

## 8. Plan de migración legacy → V2

1. Usuario en proyecto legacy elige «Migrar a Biblia modular».
2. `LegacyToDocumentMigrator.migrate(...)` genera `BibleDocument`.
3. `BibleDocumentStore.save` + `promoteEngineToV2(bibleId)`.
4. Legacy rows conservadas (no destructivo); UI pasa a V2.

Riesgos: pérdida parcial de diagramas/moodboard ricos; mitigar en migrador iterativamente.

---

## 9. Riesgos

1. Doble fuente de verdad si se mezclan editores.
2. Presets built-in sin documento V2 (requieren `bible_v2_builtin_templates.dart`).
3. Export PDF debe leer solo `BibleDocument` en proyectos V2.
4. Tests legacy deben seguir pasando con `engineVersion=legacy`.

---

## 10. Fases de implementación

| Fase | Entregable | Estado |
|------|------------|--------|
| 0 | Este audit | Hecho |
| 1 | Cutover V2 vacío | En curso |
| 2 | Biblioteca + preview | En curso |
| 3 | Apply deep clone | En curso |
| 4 | CRUD páginas | En curso |
| 5 | Canvas drag-resize | En curso |
| 6 | Inspector tabs | En curso |
| 7 | Imágenes unificadas | En curso |
| 8 | Undo/autosave completo | En curso |
| 9 | Themes UI | En curso |
| 10 | Migración legacy | En curso |

Estimación restante: 4–8 semanas para criterio de éxito completo del usuario.
