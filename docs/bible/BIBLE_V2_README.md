# Biblia v2 y compositor — guía rápida

> **2026-10-03:** V2 está congelado y el compositor de export se retira. Plan vigente: `docs/PLAN_ACCION.md`. Este documento queda como referencia del código existente.

## Experiencia por defecto (usuarios)

La app usa el **motor clásico** Group → Section. El motor v2 y el compositor PDF existen como infraestructura paralela; v2 no aparece en la UI pública salvo activación explícita del flag interno.

## Activar motor v2 (experimental)

Hoy no hay forma de activarlo desde la UI: el switch **Motor modular v2 (experimental)** (`BibleEngineV2ToggleCard`) no está montado en Configuración. La biblia abre V2 solo si `VisualBibles.engineVersion == 'v2'`, y nada en la app promueve una biblia a ese valor.

Los datos legacy **no se borran**; el documento v2 vive en Drift `visual_bible_documents`.

## Compositor PDF (recomendado para entregas)

Tras configurar exportación:

1. Elige **Abrir compositor** (vs exportación clásica).
2. Reordena páginas, añade folios/post-its/anotaciones.
3. **Preview final** antes de guardar o compartir.
4. La Biblia fuente permanece intacta; solo cambia la composición de entrega.

Archivos clave: `lib/features/visual_bible/export/`.

## Desactivar v2

- No aplica mientras V2 no sea alcanzable desde la UI.
- Snapshots y documento v2 quedan en Drift para reactivar.

## Árbol `lib/features/visual_bible/v2/`

| Área | Rol |
|------|-----|
| `model/` | BibleDocument / Page / Block |
| `theme/` | Tokens Cinematic / Technical / Minimalist / Custom |
| `migration/` | Legacy → Document (lazy) |
| `commands/` | Undo/Redo + autosave |
| `persistence/` | Store Drift + snapshots |
| `widgets/` | UniversalBibleImageInput + BlockCompositor |
| `editor/` | Canvas + Inspector + Host |
| `templates/` | BibleTemplatePackage |
| `studio/` | Bible Studio shell |
| `nav/` | Command palette ⌘K |
| `pdf/` | Puente layout canvas→PDF |
| `ai/` | Stubs asistencia |

## Anotaciones compartidas

`lib/shared/annotations/` — tinta unificada en moodboard, iluminación, planos y PDF.

Persistencia: `ProjectAnnotationDocuments` (sync bundle v4).

## Moodboard

- **Lightbox:** catálogo cinematográfico editable por proyecto + marcadores «Aparece en la biblia».
- **Servicio central:** `MoodboardCatalogService` (catálogo + placement).
- **Meta por imagen:** `MoodboardReferenceMetaStore` (Drift `MoodboardImages.metaJson`).

## Política

Ver `bible_v2_policy.dart`: sin deletes de tablas legacy; solo adiciones; flag por proyecto.

## Documentación de auditoría

Estado desplegable completo: `docs/bible/BIBLE_CURRENT_STATE.md`.
