# Biblia v2 y compositor — guía rápida

## Experiencia por defecto (usuarios)

La app usa el **motor clásico** Group → Section. El motor v2 y el compositor PDF existen como infraestructura paralela; v2 no aparece en la UI pública salvo activación explícita del flag interno.

## Activar motor v2 (experimental)

1. Abre **Biblia → Configuración**.
2. Activa **Motor modular v2 (experimental)** (`bible_engine_v2`, default **off**).
3. Los datos legacy **no se borran**; el documento v2 vive en Drift `visual_bible_documents`.

## Compositor PDF (recomendado para entregas)

Tras configurar exportación:

1. Elige **Abrir compositor** (vs exportación clásica).
2. Reordena páginas, añade folios/post-its/anotaciones.
3. **Preview final** antes de guardar o compartir.
4. La Biblia fuente permanece intacta; solo cambia la composición de entrega.

Archivos clave: `lib/features/visual_bible/export/`.

## Desactivar v2

- Switch en Configuración o **Modo clásico** en la barra del editor v2.
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
- **Meta por imagen:** `MoodboardReferenceMetaStore` (SharedPreferences).

## Política

Ver `bible_v2_policy.dart`: sin deletes de tablas legacy; solo adiciones; flag por proyecto.

## Documentación de auditoría

Estado desplegable completo: `docs/bible/BIBLE_CURRENT_STATE.md`.
