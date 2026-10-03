# Plan de acción IRIS DP

Tablero vivo. Cada ítem es un PR a `main`; se marca aquí al fusionarlo.

Aprobado el 2026-10-03.

## Decisiones

- **El motor clásico de la biblia es la referencia del producto.** V2 queda congelado: no se borra y no recibe trabajo nuevo.
- **Una biblia estructurada y con la misma estética en todas las secciones.** Los bocetos y el código de Stitch son referencia, no especificación.
- **Las secciones sin boceto parten de una base compartida** con las demás.
- **La biblia es ampliable por el usuario:** puede añadir puntos a una sección.
- **El PDF respeta cada pantalla:** mismos puntos y mismo orden, adaptado a PDF. No es una captura.
- **Se quita el compositor de export.** El PDF no se reordena después.

## Cómo trabajamos

- Un ítem = una rama y un PR a `main`, pequeño y revisable.
- Cada PR pasa `flutter analyze` y `flutter test`.
- Cada ítem declara a qué objetivo de producto sirve (1 proyecto único, 2 decisión fotográfica, 3 look entregable, 4 set y colaboración).

## Referencias de Stitch

Viven fuera del repo, en `Documents/IRIS DP/REFERENCIAS STITCH/`. Una subcarpeta por id de sección, con `code.html` y `screen.png`:

`direction/` · `concept/` · `camera/` · `optics/` · `exposure/` · `lighting/` · `color_image/` · `format/` · `texture/` · `location/` · `camera_tests/` · `workflow/` · `moodboard/`

Las secciones sin referencia se dejan sin carpeta.

## Fase 0 — Preparación

- [x] Tablero, convención de referencias y docs al día.

## Fase 1 — Biblia estructurada, ampliable y con PDF en paridad (objetivo 3)

Principio: la lista de puntos de cada sección (`BibleSectionDefinitions.contentJson`) es la única fuente de estructura. Pantalla y PDF la recorren en el mismo orden, y cada tipo de punto tiene una vista de pantalla y una de PDF.

- [x] **1.1 Quitar el compositor de export.** Exportar va directo al PDF. Se borran `export/composer/` (menos la vista previa), `export/builder/`, `export/commands/`, `export/model/`, `export/store/` y `export/pdf/bible_export_pdf_renderer.dart`.
- [ ] **1.2 Base compartida de pantalla.** Panel de cristal y cabecera de sección únicos; una vista genérica por tipo de punto (texto, narrativa, referencias, imagen, bloques, y los nuevos `specs` y `list`) en lugar del aviso «módulo personalizado sin vista dedicada».
- [ ] **1.3 Ampliable por el usuario.** Al añadir un punto se elige tipo, nombre y posición; ocultar sin borrar; restaurar la sección; acceso «Añadir punto» al final de cada sección.
- [ ] **1.4 Base compartida de PDF y contrato de orden.** `bible_pdf_kit.dart` con un componente por tipo de punto, Inter y JetBrains Mono embebidas, y el PDF recorriendo la lista de puntos del usuario. Test de paridad genérico.
- **1.5 Sección por sección** (análisis acordado → pantalla → PDF → revisión lado a lado):
  - [ ] Dirección
  - [ ] Concepto
  - [ ] Cámara
  - [ ] Óptica
  - [ ] Exposición
  - [ ] Iluminación
  - [ ] Color
  - [ ] Formato
  - [ ] Textura
  - [ ] Localización
  - [ ] Pruebas de cámara
  - [ ] Workflow
  - [ ] Moodboard

## Fase 2 — Sync fiable (objetivos 1 y 3)

- [ ] **2.1 Bundle v5.** Que viajen `moodboardImages.metaJson` y `assignedCardIds`, `VisualBibleNarrativeCards`, `BibleSectionEvidence`, los FK de localización de `lightingSetups` y los campos de `Shots` que hoy se pierden (`shutterAngle`, `fps`, `description`, `autoNumbering`).
- [ ] **2.2 SharedPreferences → Drift (schema 41).** Estilos de sección, blueprint y catálogo de moodboard pasan a columnas de `VisualBibles`; anotaciones resueltas a `ProjectAnnotationDocuments`.

## Fase 3 — El plano como eje (objetivos 1 y 4)

- [ ] **3.1 Identidad estable.** `uid` en `Scenes` y `Shots`; el bundle deja de identificar por número; claves de media unificadas.
- [ ] **3.2 Hub con salud.** Total de planos, con planta, con storyboard, con lente, y una siguiente acción.
- [ ] **3.3 Jornada de rodaje.** `ShootDays` y `ShootDayShots` (plano, orden, estado).

## Fase 4 — Confianza en el dato (objetivo 2)

- [ ] Estado de verificación y fuente por ficha de cámara, lente y luz; semáforo en la ficha y en el laboratorio óptico. Revierte la decisión de no persistir fuentes (`BACKLOG.md`); se confirma al llegar.

## Fase 5 — Limpieza (se intercala)

- [ ] Look Bible antiguo: mover `GoodNotesModuleType` y borrar pantalla y PDF propios.
- [ ] Borrar `BibleV2Host`, el flag huérfano, los stubs `features/shots` y `features/scenes`, y el wrapper `daily_pdf`.

## Fuera de este plan

Motor de decisión técnica, trabajo nuevo en V2, Unreal/LUKA de ida y vuelta, permisos por módulo.
