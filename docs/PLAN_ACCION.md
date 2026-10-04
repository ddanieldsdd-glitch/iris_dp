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
  - [x] Inter embebida en el PDF, con Noto Sans de respaldo para los glifos que le falten. JetBrains Mono no se usa.
  - [ ] Pendiente: los puntos propios salen al final de su sección; intercalarlos con los puntos dedicados se hace en cada sección de 1.5.
- **1.5 Sección por sección** (análisis acordado → pantalla → PDF → revisión lado a lado):
  - [x] Dirección — puntos: intención narrativa, tono y atmósfera, estrategia visual, intención por acto, referencias, transiciones. Key Frame pasa a opcional. Referencias como fichas con porqué y para qué, con detalle; imágenes del moodboard en tono, estrategia, actos y transiciones.
  - [x] Concepto — puntos: intención narrativa, paleta maestra propia, simbología de color, filosofía de luz, tratamiento de sombras, composición, intención visual por acto, Key Frame, referencias visuales razonadas. Cada punto admite imágenes del moodboard.
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

### 1.6 Sistema de widgets reutilizable

Añadido el 2026-10-03. La biblia es una maqueta de partida hecha con piezas que el usuario puede añadir, mover y ampliar en cualquier sección. Va antes que el resto de secciones de 1.5.

- [x] **W1. Catálogo único de widgets.** `widgets/catalog/bible_widget_catalog.dart`: texto, lista, datos técnicos, paleta, imágenes y referencias (narrativas, visuales, técnicas). Lo leen las secciones, las pantallas personalizadas y «Añadir punto».
- [ ] **W2. Marco de punto y complementos.** Menú «⋯» en cada punto: renombrar, ancho, mover, quitar, y añadirle imágenes o una paleta.
- [x] **W3. Widget de paleta.** `BiblePaletteWidget`: muestras con código y nombre, y extracción desde una imagen del moodboard.
- [x] **W4. Referencias.** Varias imágenes por referencia y pantalla de detalle con edición directa.
- [ ] **W5. Disposición responsiva.** Ancho por punto: completo, medio o tercio.
- [ ] **W6. PDF.** Cada widget y sus complementos, en cualquier sección.
- **W7. Dirección y Concepto sobre el sistema**, y revisión en la app.
  - [x] **W7a. Widgets específicos y catálogo por familias.** Widgets nuevos: división por actos, pilares, puntos con título, etiquetas, paleta maestra, paleta compacta y simbología de color. El catálogo se agrupa en familias (Texto, Narrativa y estructura, Color, Imagen, Referencias, Datos) y cada pantalla propone primero los suyos. Un punto guarda con qué widget se pinta (`BibleSectionField.widget`). Todos salen en el PDF.
  - [ ] **W7b. Los puntos de fábrica de Dirección y Concepto pasan a pintarse con esos widgets** (hoy tienen vista propia y solo se nombran por el widget al que equivalen), con migración de su contenido.

### 1.7 Configuración coherente

Añadido el 2026-10-04. Regla: **Biblia → Pantallas → Puntos.** Un punto tiene un tipo fijo, que decide cómo se ve en pantalla y en el PDF. De cara al usuario solo se usan esas tres palabras. Va antes de W2 y W5.

- [x] **C1. Un solo «Añadir punto» y tipo fijo.** El diálogo tiene dos grupos: «De esta pantalla» (puntos propios que no están puestos) y «Widgets». Desaparecen «Añadir módulo Stitch» y «Cambiar tipo». Quitar un punto pide confirmación: uno del usuario se borra con su contenido; uno de la pantalla lo conserva.
- [x] **C2. «Restablecer pantalla».** Vuelven los puntos de fábrica y los del usuario quedan al final. No borra contenido.
- [x] **C3. Estilos fuera de la interfaz.** Sin selector Cinematic / Technical / Minimalist en ningún sitio. Una pantalla personalizada nueva nace con tres puntos: intención narrativa, contenido y referencias visuales.
- [x] **C4. Panel «Ajustes de pantalla»** con dos pestañas: Puntos y Pantallas. En Moodboard, «Puntos» muestra las fuentes de imágenes.
- [x] **C5. Configuración general** con dos bloques: Pantallas y Plantillas. Cada acción existe una vez y confirma. Una plantilla guarda pantallas y puntos, no lo escrito; aplicarla o restablecer la estructura conserva el contenido, deja ocultas las pantallas que sobran y los puntos del usuario al final.
- [x] **C6. Vocabulario y textos** de la configuración, el panel, el tutorial y la ayuda de plantillas: sin «Stitch», «módulo», «sub-apartado» ni «Template Vault»; en castellano. Los textos propios de cada pantalla («bloque de color», «preset» de grano) se revisan al rehacer esa pantalla en 1.5.
- **C7. Garantías** (repartidas): tipo fijo y borrado de valores [x]; «Composición» ya no se reinserta sola [x]; todo widget del catálogo sale en el PDF [ ]; las pantallas personalizadas no nacen con bloques V2 [x].

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
- [x] **4.2b Flujo v2.0 (SXT + Super Speed).** Tercer Excel como capa superior: cuatro cámaras con sus gates, ficha y 14 formatos de la ALEXA SXT, cinco ZEISS Super Speed con círculo típico y peor caso, y medios y tiempos de grabación de la SXT. En Almacenamiento, plan de grabación y volcado para las cámaras con esos datos.
- [ ] **4.3 Modos de sensor.** Cada modo trae también códec, fps máximo y relación de aspecto.
- [ ] **4.4 Laboratorio óptico según el master.** Con círculo típico y peor caso, semáforo de la hoja `18_Cobertura`: CUBRE / LÍMITE / RIESGO / VIÑETEA. Cobertura CUBRE / NO CUBRE con confianza, INDETERMINADO si falta el círculo de imagen o el gate, CONFLICTO, NO APLICA. Se elimina el círculo de imagen inventado; la tabla por formato solo se ofrece como estimación rotulada. Panel «¿Por qué?» con entradas, estado y fuente.
- [ ] **4.5 Pantalla Equipo.** Semáforo por estado, fuente con enlace, campos verificados, ficha por focal y filtro «apto para cálculos».
- [ ] **4.6 Secciones técnicas de la biblia** (dentro de 1.5). Cámara y sensor, Óptica, Exposición y Formato leen la cámara, el modo y la lente del proyecto en lugar de valores de ejemplo.

## Fase 5 — Limpieza (se intercala)

- [ ] Look Bible antiguo: mover `GoodNotesModuleType` y borrar pantalla y PDF propios.
- [ ] Borrar `BibleV2Host`, el flag huérfano, los stubs `features/shots` y `features/scenes`, y el wrapper `daily_pdf`.

## Fuera de este plan

Motor de decisión técnica, trabajo nuevo en V2, Unreal/LUKA de ida y vuelta, permisos por módulo.
