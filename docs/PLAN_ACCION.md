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
- **La planta de luz y cámara va por capas, por referencia y sin copias** (2026-10-04). La localización solo lleva el entorno (paredes, puertas, ventanas, calles, árboles, relieve, props). El set toma el entorno de su localización. El esquema de luz es libre y se comparte: los planos que lo usan aparecen bajo él. El plano solo lleva cámara y actores.
- **La biblia es la fase inicial de la luz.** Un boceto de luz hecho en la biblia aparece en la planta como «boceto», catalogable, para desarrollarlo después.
- **Un solo lienzo** (2026-10-04). Las capas se guardan por separado, pero se editan juntas: desde un plano se puede tocar la luz, el set o el entorno, y un aviso dice a qué afecta. El set es una zona del plano maestro de su localización.
- **Blush es inspiración, no molde.** Se importan los archivos del usuario; no se copia su aspecto ni su catálogo.

## Cómo trabajamos

- Un ítem = una rama y un PR a `main`, pequeño y revisable.
- Cada PR pasa `flutter analyze` y `flutter test`.
- Cada ítem declara a qué objetivo de producto sirve (1 proyecto único, 2 decisión fotográfica, 3 look entregable, 4 set y colaboración).

## Fase P — Planta de luz y cámara (prioritaria) (objetivos 2 y 4)

Añadida el 2026-10-04. **Va por delante de todo lo pendiente de las fases 1 a 5.**

Cuatro capas: entorno (localización) → set → esquema de luz → cámara (plano). Cada capa ve las anteriores por referencia. Un esquema de luz tiene estado (boceto, en desarrollo, definitivo) y origen (planta, biblia, Blush), y puede ser libre, sin localización ni escenas.

- [ ] **P1. Modelo por capas y plantas sin escenas (schema 42).** Tabla `LightSetups`; `Shots.lightSetupId`; `LightingSetups.planSetupId`; `LocationBasePlans.sitePlacementJson`; `CameraPlanElements.propsJson`. Formato v2 del plano con escala, fondo y propiedades por elemento; la v1 se sigue leyendo. Migración con test: las luces de cada plano pasan a esquemas compartidos por set, los diagramas de la biblia pasan a esquemas «boceto», y se quitan del plano las paredes copiadas del set. El bundle de sync lleva lo nuevo. La pantalla deja de exigir escenas.
- [ ] **P2. Inicio por escenas, un solo lienzo y editor oscuro con haces.** La entrada va por Localización › Set › Escena › Planos: cada plano es una tarjeta con la miniatura de lo que se ve y una etiqueta de color con su esquema de luz, que se puede cambiar sin entrar; los esquemas del set salen como leyenda en su cabecera; vista por guion con la misma tarjeta. Tocar abre la pantalla de trabajo, con **un solo lienzo**: se ve todo y se edita cualquier elemento desde cualquier nivel; lo que se añade va a su capa por tipo y un aviso dice a qué afecta. Barra de capas con ojo, esquema y plano. **El set es una zona marcada sobre el plano maestro.** Editor al estilo de Blush, con identidad propia: lienzo oscuro, haces de luz con apertura, alcance, intensidad y temperatura de color, cono de cámara según focal y sensor, paleta fija a la izquierda y lista de material a la derecha. Toda escritura de planta marca el proyecto como modificado para que la sincronización no la pise.
- [ ] **P3. Editor base.** Paredes, calles y relieve punto a punto, rectos o curvos, con asas en los extremos y en el centro. Escala en metros (2 cm por unidad mientras no se calibre), barra de escala, longitud de cada tramo y herramienta de medir. Deshacer y rehacer, duplicar, selección múltiple con Mayús, imán a rejilla y a extremos, atajos de teclado. La zona del set se mueve y se redimensiona con asas. Árbol, roca y vehículo como elementos de entorno. Sin candados de capa: se decidió que todo se edita desde cualquier nivel. Pendiente: partir `camera_plan_editor.dart` en archivos.
### Motor de luz y tiros (va antes de P5)

Añadido el 2026-10-04, tras analizar a fondo cómo calcula Blush. Sustituye a lo que quedaba de P4. Decisiones de Daniel:

- **La luz se calcula, no se dibuja.** Cae con los metros, depende de los vatios y del aparato, se atenúa con difusiones y gelatinas, las paredes la cortan y las ventanas la dejan pasar. Se mide en stops con un fotómetro, como en la app de fotómetro.
- **Los datos salen de Equipo.** La cámara, las lentes y las luces de la planta son las del proyecto, definidas en la pantalla Equipo, con la información del Excel de material, que se irá ampliando con lo que haga falta (fotometría incluida).
- **Sin dato fotométrico se estima, y se dice.** La estimación parte de vatios, tecnología y ángulo de haz, y va marcada como «estimado». En cada aparato se puede escribir el dato real («12.000 lux a 3 m») y pasa a «medido». Mismos estados de dato que el master.
- **Inicio por tiros de luz.** Dentro de cada escena, los planos se agrupan por el esquema que comparten: una planta por grupo, con todas sus cámaras rotuladas, y los planos debajo.
- **Todas las cámaras a la vista, una activa.** En un esquema se ven las cámaras de todos sus planos; la del plano abierto a todo color. Un plano puede llevar ajustes de luz propios (apagar una luz, mover una bandera) sin romper el esquema.

- [ ] **L1. Motor fotométrico.** Candelas de cada fuente (medidas, del fabricante o estimadas), caída con el cuadrado de la distancia, perfil del haz, fuentes grandes de cerca, y exposición: de lux a diafragma con ISO, obturación, fps y ND, y diferencias en stops. Tablas de difusiones, redes y gelatinas Rosco (CTO, CTB, difusión blanca…) con su transmisión y su cambio de temperatura de color. Código puro, con tests.
- [ ] **L2. Paredes y ventanas.** Las paredes cortan la luz; ventanas, puertas abiertas y aberturas la dejan pasar, con su propia difusión si la llevan. El haz se dibuja recortado por lo que encuentra. Sombra del talento, opcional.
- [ ] **L3. Fotómetro y mapa de exposición.** Fotómetro que se coloca en la planta y lee diafragma, lux y lo que sobra o falta respecto al diafragma de trabajo. Al seleccionarlo, o al seleccionar un actor: clave, relleno y contra respecto a la cámara, contraste en stops y lo que aporta cada fuente. Lectura bajo cada actor. Mapa de exposición en falso color con su leyenda. La cámara de la planta lleva ISO, obturación, fps, ND y diafragma de trabajo; lo que no diga se toma del plano. Pendiente: escribir esos ajustes de vuelta en el plano y tomarlos de Equipo (L5).
- [ ] **L4. Simulador: colisiones, grip y rebotes.** Puertas y ventanas se enganchan a la pared y le abren hueco; la puerta tiene ancho, apertura, una o dos hojas y lado de bisagra, y su hoja hace sombra; la ventana admite cortina y gelatina. Personas y cámaras hacen sombra. Grip con su largo real y funcionando: el negro y el cortador cortan, la red quita medio stop, la gelatina en marco tiñe, el marco de difusión corta el haz y lo devuelve más ancho, y el rebote devuelve la luz con el tinte de su material. Las paredes devuelven luz a la sala según su material (blanca, crema, gris, hormigón, ladrillo, madera, negra). Pendiente: book light y CRLS como piezas propias, y varios rebotes encadenados.
- [ ] **L5. Equipo como fuente (schema 43).** La paleta enseña las luces del proyecto y un buscador del catálogo de Equipo; cada una entra con su potencia, tecnología, haz, rango de color y, si la trae, su fotometría de fabricante. La cámara de la planta toma la cámara del proyecto (sensor e ISO nativo) y sus lentes. Columnas nuevas en el Excel y en el catálogo: `angulo_haz`, `fotometria_lux` y `fotometria_distancia_m`. Pendiente: rellenarlas en el Excel y regenerar el catálogo.
- [ ] **L6. Tiros y cámaras por esquema.** En el inicio, los planos de cada escena se agrupan por el esquema que comparten: una planta por tiro con todas sus cámaras rotuladas y los planos debajo. En el editor se ven, atenuadas, las cámaras de los otros planos del mismo esquema, y tocarlas cambia de plano. Una luz del esquema se puede ajustar solo en un plano (`Shots.lightOverridesJson`) sin tocar el esquema.
- [ ] **L7. Ambiente y corriente.** Cada esquema lleva su ambiente: día o noche, sol con dirección y altura, tiempo (despejado, bruma, nublado), cielo y rebote de paredes. El sol da sombra según su altura y entra por las ventanas. La lista de material suma los vatios encendidos y dice amperios y circuitos de 16 A. Pendiente: enchufes y reparto por circuito, y generadores.

- [ ] **L8. Luz más real.** El haz se pinta desde varios puntos de la fuente: las sombras salen con penumbra, más ancha cuanto mayor es la fuente y más lejos está el objeto, y el borde del haz se apaga en vez de cortarse. Ventanas con hojas que se abren y cortina parcial (visillo, lino, gruesa, opaca). Puertas y ventanas abren hueco también en paredes curvas. Telas con los nombres de los palios de Rosco (Grid Cloth, Silent Grid Cloth, grid teñido, frost, sedas, muselinas, gasas), con la reducción que publica Rosco donde la publica. Aparatos colgados del techo, con altura: hacen un charco de luz y pasan sobre las personas. El sol dibuja la sombra de paredes y personas según su dirección y su altura. Pendiente: rebotes encadenados, book light, y un cálculo por celdas para la luz en reposo.

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
- [ ] **W6. PDF.** Cada widget y sus complementos, en cualquier sección. Hecho para actos, paletas e «Imágenes»; faltan las imágenes de las referencias añadidas por el usuario.
- **W7. Dirección y Concepto sobre el sistema**, y revisión en la app.
  - [x] **W7a. Widgets específicos y catálogo por familias.** Widgets nuevos: división por actos, pilares, puntos con título, etiquetas, paleta maestra, paleta compacta y simbología de color. El catálogo se agrupa en familias (Texto, Narrativa y estructura, Color, Imagen, Referencias, Datos) y cada pantalla propone primero los suyos. Un punto guarda con qué widget se pinta (`BibleSectionField.widget`). Todos salen en el PDF.
  - [x] **W7a-2. Actos con imagen y paletas compuestas.** «División por actos» tiene vista propia (tarjeta con imagen, número, fase y línea de progreso) y cada acto lleva sus imágenes. «Paleta maestra» y «Simbología de color» combinan paleta, imágenes y texto; el menú «⋯» del punto elige qué se muestra sin borrar lo oculto. En el PDF salen las imágenes de actos, paletas y del widget «Imágenes».
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

- [x] **2.0 Sincronizar no pierde datos.** Añadido el 2026-10-05, tras perderse datos de «lala» en una descarga. Subir o descargar se decide por huellas del contenido guardadas en la última sincronización, no por horas. Sin revisión no se resuelve ningún conflicto. Actualizar nombre o estado desde la nube ya no reemplaza el contenido. Antes de una descarga se guarda una copia de la base (`iris_dp.db.antes-de-descargar-…`, se conservan cinco) y la importación es todo o nada. Viajan los datos de los stills (`metaJson`, `assignedCardIds`), las tarjetas narrativas y las evidencias, y los enlaces de la biblia a imágenes se rehacen al importar.
- [ ] **2.1 Bundle v5 (resto).** Los FK de localización de `lightingSetups` y los campos de `Shots` que hoy se pierden (`shutterAngle`, `fps`, `description`, `autoNumbering`).
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
