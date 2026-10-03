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

Viven fuera del repo, en `Documents/IRIS DP/REFERENCIAS STITCH/`. Cada carpeta trae capturas (`.png`) y el código HTML de Stitch (en archivos `.md`):

| Carpeta | Sección de la biblia |
|---|---|
| `1 concepto de imagen` | Concepto |
| `2 direccion` | Dirección |
| `3 camara y sensor`, `6 camara y sensor` | Cámara |
| `4 iluminacion` | Iluminación |
| `5 lentes` | Óptica |
| `7 localizacion` | Localización |
| `8 textura y grano` | Textura |
| `editor de imagenes` | Lightbox del moodboard |
| `pdf export` | PDF de entrega |

Sin referencia: Exposición, Color, Formato, Pruebas de cámara, Workflow y Moodboard. Parten de la base compartida.

## Fase 0 — Preparación

- [x] Tablero, convención de referencias y docs al día.

## Fase 1 — Biblia estructurada, ampliable y con PDF en paridad (objetivo 3)

Principio: la lista de puntos de cada sección (`BibleSectionDefinitions.contentJson`) es la única fuente de estructura. Pantalla y PDF la recorren en el mismo orden, y cada tipo de punto tiene una vista de pantalla y una de PDF.

- [x] **1.1 Quitar el compositor de export.** Exportar va directo al PDF. Se borran `export/composer/` (menos la vista previa), `export/builder/`, `export/commands/`, `export/model/`, `export/store/` y `export/pdf/bible_export_pdf_renderer.dart`.
- [x] **1.2 Base compartida de pantalla.** Panel de cristal y cabecera de sección únicos; una vista genérica por tipo de punto (texto, narrativa, referencias, imagen, bloques, y los nuevos `specs` y `list`) en lugar del aviso «módulo personalizado sin vista dedicada».
- [x] **1.3 Ampliable por el usuario.** Al añadir un punto se elige tipo, nombre y posición; ocultar sin borrar; restaurar la sección; acceso «Añadir punto» al final de cada sección.
- [x] **1.4 Base compartida de PDF y contrato de orden.** `bible_pdf_kit.dart` con un componente por tipo de punto. El PDF sigue el orden de secciones de la biblia, incluye los puntos propios del usuario y las pantallas personalizadas. Test de paridad en `test/visual_bible_export/bible_pdf_parity_test.dart`.
  - [ ] Pendiente: embeber Inter y JetBrains Mono en el PDF (hoy Noto Sans). Hay que añadir los TTF a `assets/fonts/`.
  - [ ] Pendiente: los puntos propios salen al final de su sección; intercalarlos con los puntos dedicados se hace en cada sección de 1.5.
- **1.5 Sección por sección** (análisis acordado → pantalla → PDF → revisión lado a lado):
  - [x] Dirección — puntos: intención narrativa, tono y atmósfera, estrategia visual, intención por acto, referencias, transiciones. Key Frame pasa a opcional.
  - [x] Concepto — puntos: intención narrativa, paleta maestra, simbología de color, filosofía de luz, tratamiento de sombras, intención visual por acto, Key Frame, referencias clave. «Composición por actos» pasa a opcional.
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

## Fase 4 — Material técnico (objetivo 2)

Añadida el 2026-10-03. Se hace después de Concepto y antes de las secciones técnicas de la biblia (Cámara, Óptica, Exposición, Formato), para que estas lean datos reales.

Los Excel viven en `Desktop/LISTA DE MATERIAL TECNICO/`:

- **Master** (`IRIS_DP_v1_8_MASTER_AUDITORIA_REGRESION…`, versión más reciente `v17`): libro de reglas. Define estados de dato, resultados de cobertura permitidos, validaciones y el contrato con la app. Manda como contrato y sus datos confirmados tienen prioridad.
- **Lista v1.8** (`lista_de_material_tecnico_v1_8_IRIS_DP_fase_2_estudio.xlsx`): el volumen. 72 cámaras, 252 modos, 477 ópticas, 104 luces, con estado de verificación.

- [x] **4.0 Almacenamiento marcado como «en desarrollo».** Distintivo en la pestaña y aviso en la calculadora. Tarjetas, tasas de datos y horas de grabación quedan fuera de este plan.
- [x] **4.1 Contrato de datos del master (schema 41).** Los diez estados de `77_Estados_Dato` y columnas de estado, confianza y fuente en cámaras, ópticas y luces. En ópticas, además: tipo de proyección, área de imagen, área de iluminación, estados de viñeteo, shading y portholing, y ficha por focal.
- [x] **4.2 Exportador e importador.** El script lee los dos libros sin `openpyxl`, aplica las validaciones de `86_Reglas_Validacion` y genera los packs de `assets/catalog/`: una sola fuente, el Excel. El import fusiona en vez de pisar con vacíos, y abrir Equipo deja de reimportar a la fuerza.
- [ ] **4.3 Modos de sensor.** Cada modo trae también códec, fps máximo y relación de aspecto.
- [ ] **4.4 Laboratorio óptico según el master.** Cobertura CUBRE / NO CUBRE con confianza, INDETERMINADO si falta el círculo de imagen o el gate, CONFLICTO, NO APLICA. Se elimina el círculo de imagen inventado; la tabla por formato solo se ofrece como estimación rotulada. Panel «¿Por qué?» con entradas, estado y fuente.
- [ ] **4.5 Pantalla Equipo.** Semáforo por estado, fuente con enlace, campos verificados, ficha por focal y filtro «apto para cálculos».
- [ ] **4.6 Secciones técnicas de la biblia** (dentro de 1.5). Cámara y sensor, Óptica, Exposición y Formato leen la cámara, el modo y la lente del proyecto en lugar de valores de ejemplo.

## Fase 5 — Limpieza (se intercala)

- [ ] Look Bible antiguo: mover `GoodNotesModuleType` y borrar pantalla y PDF propios.
- [ ] Borrar `BibleV2Host`, el flag huérfano, los stubs `features/shots` y `features/scenes`, y el wrapper `daily_pdf`.

## Fuera de este plan

Motor de decisión técnica, trabajo nuevo en V2, Unreal/LUKA de ida y vuelta, permisos por módulo.
