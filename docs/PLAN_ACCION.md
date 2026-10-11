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
- [ ] **L9. Giro, recintos con techo, sol repensado, paleta y propiedades.** Giro: el asa ya no deselecciona al pulsarla, hay anillo de giro, grados a la vista y saltos de 15° con Mayús. Recintos: las paredes que se cierran forman un recinto con techo (se puede marcar a cielo abierto, con altura y suelo propios; se guarda con el esquema de luz). Sol: se calcula con la altura de cada cosa; bajo techo solo entra por los huecos, entre alféizar y dintel, y se mide a 1,5 m. El cielo entra por los huecos como fuente blanda. Sol y cielo excitan rebotes, marcos y paredes; la mancha de sol del suelo devuelve luz. Difusión o cortina en la ventana convierten el sol en fuente blanda. Luces de techo con inclinación. Árbol, roca, vehículo, colina y relieve tapan la luz según su altura; relieve dibujado como talud y colina con curvas de nivel. Paleta de luces por familias (LED, HMI, tungsteno, fluorescente, prácticas) con buscador y catálogo de Equipo dentro. Propiedades en bloques plegables; Luka y Cine Tracer en «Exportar a 3D». Pendiente: sombras de sol dentro de las salas, hora y fecha para el sol, rebotes encadenados, y limpiar duplicados y tipos mal puestos del catálogo de luces.
- [ ] **L10. Huecos de verdad, sombras, terreno, posiciones y lentes del proyecto.** La apertura de puertas y ventanas decide por dónde entra la luz (hojas de cristal que giran; puerta maciza). Filtros en el cristal o en un marco por dentro o por fuera, cortina por dentro o por fuera, y ND de Rosco (209, 210, 211, 299). La mancha de sol se recorta con lo que tape dentro (hojas, negros, telas, personas) y coincide con el cálculo. Lo que difunde (cortina, tela) pasa a ser fuente blanda y los rebotes la ven. Un recinto con techo da una sola sombra. La colina es una loma, con curvas de nivel a intervalo fijo y cota de cima; el talud lleva su altura. Calles, taludes y colinas se pintan debajo de la luz. Actores vistos desde arriba (de pie, sentado, tumbado) y con varias posiciones, igual que la cámara: cada una con su giro, y en las de cámara se ve qué encuadra. Diálogo «Cámaras y lentes del proyecto» (letras A/B, juegos enteros con focales sueltas fuera), lentes por juego en la cámara de la planta y zoom con deslizador. Pendiente: lente distinta por posición, ver la luz con el actor en otra posición, sol que cruza un edificio por dos huecos enfrentados, y desvanecer las sombras muy largas.

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
- [x] **W2. Marco de punto y complementos.** Menú «⋯» en cada punto (`BiblePointFrame`, lo pone `BibleSectionScaffold`): duplicar, eliminar, añadir imágenes y añadir texto complementario. Los complementos se guardan en `values['<clave>__extra']` y salen en el PDF tras el punto. Pendiente: renombrar, ancho y mover desde el menú (hoy en «Ajustes de pantalla»), y llevar el marco a las pantallas personalizadas.
- [x] **W8. Fichas ampliadas** (2026-10-05). Actos y tarjetas dejan los diálogos: tocar abre una ficha de edición directa (`bible_card_editor.dart`), como en las referencias, con portada, galería y, en los actos, puntos que lo desarrollan. Las fichas se abren en un navegador propio del contenido: los laterales de la biblia siguen a la vista.
- [x] **W9. Un solo selector de imágenes**, el del moodboard, con importar archivo y pegar con ⌘V; lo pegado o importado queda elegido.
- [x] **W10. Cabecera de pantalla.** Cada pantalla abre con su título en grande sobre una imagen elegida por el usuario (`BibleScreenHero`, `values['__hero']`). En el PDF, la sección abre con una banda con esa imagen. Fuera quedan Moodboard y Resumen. La cabecera es una tarjeta con menú «⋯»: imagen, color de la pantalla (filo de la cabecera y del PDF), cambiar nombre y **reiniciar pantalla** (borra lo escrito y los puntos añadidos; conserva nombre, imagen, color, moodboard, actos del proyecto y elementos con ficha propia). Pendiente: que el color se vea en el lateral, y nombre/reinicio completos en Localización, Pruebas de cámara y pantallas personalizadas.
- [x] **W3. Widget de paleta.** `BiblePaletteWidget`: muestras con código y nombre, y extracción desde una imagen del moodboard.
- [x] **W4. Referencias.** Varias imágenes por referencia y pantalla de detalle con edición directa.
- [ ] **W5. Disposición responsiva.** Ancho por punto: completo, medio o tercio.
- [ ] **W6. PDF.** Cada widget y sus complementos, en cualquier sección. Hecho para actos, paletas e «Imágenes»; faltan las imágenes de las referencias añadidas por el usuario.
- **W7. Dirección y Concepto sobre el sistema**, y revisión en la app.
  - [x] **W7a. Widgets específicos y catálogo por familias.** Widgets nuevos: división por actos, pilares, puntos con título, etiquetas, paleta maestra, paleta compacta y simbología de color. El catálogo se agrupa en familias (Texto, Narrativa y estructura, Color, Imagen, Referencias, Datos) y cada pantalla propone primero los suyos. Un punto guarda con qué widget se pinta (`BibleSectionField.widget`). Todos salen en el PDF.
  - [x] **W7a-2. Actos con imagen y paletas compuestas.** «División por actos» tiene vista propia (tarjeta con imagen, número, fase y línea de progreso) y cada acto lleva sus imágenes. «Paleta maestra» y «Simbología de color» combinan paleta, imágenes y texto; el menú «⋯» del punto elige qué se muestra sin borrar lo oculto. En el PDF salen las imágenes de actos, paletas y del widget «Imágenes».
  - **W7b. Los puntos de fábrica de Dirección y Concepto pasan a pintarse con esos widgets**, sin perder su contenido. Repaso con Stitch y orden nuevo acordados el 2026-10-05.
    - [x] **Dirección.** Orden: intención narrativa con etiquetas, tono y atmósfera, estrategia visual, intención por acto, lenguaje de transiciones, referencias. Tono y transiciones son «Puntos con título», la estrategia son «Pilares» y los actos «División por actos»: todo se puede borrar y reordenar, y el texto ya no se corta. Fuera la cabecera de escena y el Key Frame. Cada punto guarda su valor en `values[clave]`; mientras no lo tenga, se lee de donde estaba (`DirectionPoints`), así que no hay migración que pueda perder datos. El PDF lee de lo mismo.
    - [x] **Actos del proyecto.** Los actos (cuántos, fase, título, orden) son del proyecto y se guardan en `VisualBibles.actVisualNotes`; cada pantalla escribe encima su intención y sus imágenes (`BibleActsValue`). Un punto puede pasar a «actos propios», independientes, y volver sin perder nada. Un acto se puede marcar como punto de giro: no se numera. Pendiente: que las pantallas personalizadas ofrezcan también los actos del proyecto.
    - [ ] **Concepto.** Orden acordado: intención narrativa junto a atmósfera visual (etiquetas); filosofía de luz junto a tratamiento de sombras; paleta maestra junto a simbología; composición; contraste y textura (resumen de Textura); intención visual por acto (actos del proyecto, con la composición de cada uno); referencias visuales. Widgets nuevos: «Texto con datos», «Atmósfera» y «Resumen de otra pantalla». El Key Frame pasa a ser una referencia destacada, también en Dirección.
    - [ ] **Paridad del PDF de Concepto:** paleta de partida, actos vacíos y composición por actos salen distinto en pantalla y en PDF; las fichas solo llevan la portada.

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
- [x] **3.3 Jornada de rodaje.** Sustituido por G5: la jornada es un documento de rodaje de tipo `technical_day`, sin tablas nuevas. Queda fuera el estado por plano (rodado, pendiente).

## Fase G — Guion técnico, guion literario y jornadas (objetivos 1 y 4)

Añadida el 2026-10-06. Rama `plan/g1-guion-tecnico` (worktree `iris_dp_guion`). Sube el esquema a 46; antes de pasar a 45 la app guarda sola una copia de la base (`iris_dp.db.antes-de-esquema-45`).

- [x] **G1. Tabla del guion técnico.** A todo el ancho, reordenar planos con renumeración, eliminar planos y escenas sin dejar restos.
- [x] **G2. Hoja como el Word.** Vista hoja u oscura, cabecera con el color de la escena, celdas ligeras, barra de formato (negrita, cursiva, subrayado, marcador, color de plano y de celda, fuente, columnas), movimientos propios, miniatura de planta, referencia y storyboard enlazados con menú de imagen (arrastrar, pegar, ordenador, moodboard), y escenas creadas con «¿Dónde ocurre?».
- [x] **Listas reordenables que no colapsan.** `SafeReorderableColumn` sustituye a `ReorderableListView` en toda la app: mover una fila con avisos emergentes rompía la pantalla. No entra limpio en `main` por separado; llega con esta rama.
- [x] **L. Guion literario.** Actualizar el guion empareja las escenas por contenido, se revisa antes de aplicar y nunca borra un plano; escenas fuera del guion; mover planos entre escenas; personajes que aparecen en la acción; lista de escenas a todo el alto y menú de edición compacto.
- [x] **G3. Exportar a PDF y Word** con la misma hoja.
- [x] **G4. Sol y meteorología.** Cálculo del sol sin conexión y previsión de Open-Meteo (gratis solo para uso no comercial).
- [x] **Ubicación en Localizaciones (2026-10-08):** la ubicación de cada localización se fija en su ficha de Localizaciones (buscador o coordenadas pegadas, sol de un día, abrir en Maps) y, más ligera, en la sección Localización de la biblia; la jornada solo la lee. Las migraciones 45 y 46 añaden cada columna solo si falta.
- [x] **G5. Guion técnico de rodaje.** Jornada con fecha, lugar, meteorología y orden de rodaje, y su PDF y Word. Pendiente: ver una jornada desde la pantalla del guion técnico.

- [x] **G6. Planta y bocetos en el guion técnico (2026-10-11).** La casilla Planta admite bocetos: imágenes (pegar, arrastrar, moodboard) y bocetos dibujados en Plantas de cámara y luz («Boceto nuevo», a mano alzada o con elementos; son esquemas de luz en estado `boceto`, guardados en el plano como `setup:<id>` sin cambiar su esquema de luz, nunca automáticos). Las imágenes de una casilla se ordenan y se copian al portapapeles (⌘C/⌘V). El texto pegado entra limpio. El PDF y el Word llevan la columna PLANTA (planta dibujada + bocetos) cuando está visible. Pendiente: la planta exportada sale con el fondo oscuro del lienzo; versión clara para papel si Daniel la pide.

- [x] **G7. Segunda vuelta tras probar (2026-10-11).** Deshacer/rehacer en el guion técnico (⌘Z, celdas, colores, cabecera, orden, imágenes); casilla Planta con «planta · boceto · las dos» (general y por plano, también en el export); lienzo blanco de dibujo («Dibujar» en Referencia, Storyboard y Planta, reeditable); storyboard con visor nuevo (barra fija con Cerrar, flechas entre planos, título = Encuadre, «Plano nuevo»); el moodboard se abre con todas las imágenes; Iluminación sin localizaciones repetidas y con menú renombrar/unir/eliminar que avisa de escenas y planos afectados (`LocationAdmin`); Localización de la biblia rehecha: tarjetas por localización y página propia (ubicación, enlaces a Google Maps/Waze/Earth/Apple, sol, meteorología, la misma ficha de luz que Iluminación y cada set con su ficha). Quitado el botón «Set: …» de la barra de la biblia. Pendiente: PDF de Localización por localización; la ficha de cada set aún repite bloques de mapa/sol manuales que ya da la tarjeta de arriba; contraste visual con Stitch.

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

## Fase B — Biblia: todas las pantallas sobre la versión nueva

Añadida el 2026-10-08. Rama `plan/b1-biblia-pantallas`. Orden del lateral; se conservan los puntos de cada pantalla y lo escrito, se pintan con widgets del catálogo, sin diálogos, sin inglés y sin datos de ejemplo; el PDF lee lo mismo. Daniel revisa después pantalla a pantalla.

- [x] **B0.1 Ancho por punto** (W5): completo, dos tercios, medio o tercio desde el menú «⋯»; los estrechos comparten fila a partir de 1.100 px.
- [x] **B0.2 Widgets nuevos:** «Tabla», «Medidores» y «Texto con datos», con su versión en PDF.
- [x] **B0.3 Equipo tentativo y definitivo.** Widget «Cámaras del proyecto»: cada cámara con su letra, estado (tentativa/definitiva), nota, datos de su ficha y una alternativa con su nota. Se guarda en la biblia (`BibleEquipmentItem`), sin cambio de esquema; la cámara A sigue siendo la principal del proyecto. Pendiente: lo mismo para lentes (con Óptica) y llevarlo a la pantalla de Equipo si Daniel lo valida.
- [x] **B1 Concepto.** Orden: intención narrativa con etiquetas de atmósfera · filosofía de luz junto a tratamiento de sombras · paleta maestra junto a simbología · composición · intención visual por acto (actos del proyecto) · referencias. Key Frame y «Composición por actos» pasan a opcionales. Fuera diálogos, paleta de partida y títulos de acto de ejemplo. Lectura de lo antiguo en `ConceptPoints`. Pendiente: «Contraste y textura» como resumen de Textura (cuando Textura esté hecha).
- [x] **B2 Cámara y sensor.** El bloque único se parte en: intención · cámaras (dos tercios) junto a ficha del cuerpo · formato y cadencia junto a color en cámara · matriz de grabación (tabla) · filosofía · movimientos (tarjetas) · filtros, soportes y accesorios (tabla) · gestión de datos · referencias. Las biblias guardadas antes reciben los puntos nuevos una sola vez (versión 4 de la lista de puntos). Fuera 6 diálogos y todos los valores de ejemplo. Lectura de lo antiguo en `CameraPoints`; el PDF lee lo mismo.
- [x] **B3 Óptica.** Juegos de lentes (tentativo/definitivo, con alternativa; se eligen por serie del catálogo) junto a filtros (medidores con densidad y para qué) · filosofía de lentes con T de trabajo y factor anamórfico · carácter óptico (bokeh, flares) · tabla de focales junto a revisión del juego · referencias. Los juegos se siguen escribiendo en `opticsConfigJson.lensSets` para Formato. Biblias anteriores: puntos nuevos añadidos una vez (versión 5). Fuera 12 diálogos, inglés y filtros de ejemplo. Lectura de lo antiguo en `OpticsPoints`.
- [x] **B4 Exposición.** Intención con etiquetas · exposición de trabajo (ISO, T, obturador, ND, altas luces, sombras; el ISO nativo de la cámara sale en gris) junto a niveles de señal (medidores en IRE) · cadena de exposición (fuente, sensor, óptica) · bloques de exposición (tabla; los de la tabla antigua de la base se leen) · exposición por localización (tabla, con botón para añadir las localizaciones del proyecto) · referencias. Biblias anteriores: puntos nuevos una vez (versión 6). Fuera diálogos, monitor y forma de onda decorativos, inglés y ejemplos. Lectura de lo antiguo en `ExposurePoints`.
- [x] **B5 Iluminación (primera pasada).** Ya tenía diseño propio y reciente (visión general con métricas globales, comportamiento de la luz, referencias fílmicas y localizaciones como mazos de fichas con detalle): se conserva. Hecho: notas por set y fuentes principales se escriben en el sitio (fuera 3 diálogos), rótulos en castellano, 600 líneas de código muerto fuera, y los 4 tests desfasados puestos al día (la suite queda en verde). Pendiente: el diálogo «Hero de iluminación» del mazo, enlazar los esquemas con la planta de luz nueva, revisar los valores de partida de temperatura (3200/5600 K) y pasar su PDF a los componentes comunes.
- [x] **B6 Color e imagen.** Intención · LUT y ciencia de color (dos tercios) junto a temperatura base (medidor) · paletas por bloque · referencias. Las paletas por bloque siguen en su tabla (`VisualBibleColorBlocks`, que leen el moodboard, el resumen y la planta) y se editan en el sitio: nombre, intención, kelvin y tres paletas (dominantes, acentos, se evitan). Fuera diálogos, etiquetas de LUT de ejemplo e inglés. Lectura de lo antiguo en `ColorPoints`; el PDF lee lo mismo.
- [x] **B7 Formato (primera pasada).** Tiene lógica propia que funciona (modo de sensor + factor anamórfico = relación calculada, vista previa del encuadre) y siete tests: se conserva. Hecho: fuera la cabecera duplicada, todo en castellano, y el factor anamórfico y el tipo salen de los juegos de lentes de Óptica en vez de inventar una anamórfica 2x. Pendiente: sus 3 diálogos (modo de sensor, factor, datos del sistema) a edición en el sitio, partir el bloque en puntos y pasar su PDF a los componentes comunes.
- [x] **B8 Textura.** Intención · comparación de textura (imágenes del moodboard lado a lado) · grano junto a difusión (medidores) · ruido del sensor · referencias. Fuera los deslizadores que no gobernaban nada, «Save Preset», «Reset» y todo el inglés; un grano o una difusión que estaban apagados no traen sus números de partida. Los rótulos de fábrica en inglés de biblias guardadas pasan al castellano. Lectura de lo antiguo en `TexturePoints`; el PDF lee lo mismo y ahora precarga las imágenes de los puntos propios de cada pantalla.
- [x] **B9 Localización (primera pasada).** Conserva su diseño (imagen principal, luz del sitio, sol, atmósfera, puesta en escena, colores, mapa, galería). Hecho: fuera todos los valores inventados (horas de sol, ratios, equipo, tiempo, paleta), lo vacío se ve como «—»; todo en castellano; los datos se editan en un cuadro rápido que guarda con Intro o al cerrar, sin «Guardar/Cancelar»; ubicación y sol calculado ya estaban. Pendiente: pasarla al armazón común (cabecera, menú «⋯», añadir puntos), edición en el propio dato en vez de cuadro, y su PDF con los componentes comunes.
- [x] **B11 Workflow.** Era un esquema fijo de ejemplo que no se podía editar. Ahora: intención (ya se guarda; antes no tenía dónde) · del rodaje a la entrega (tabla con los cinco pasos y sus columnas en blanco) · equipo de datos junto a formatos y entrega (códec y cadencia salen en gris de Cámara). Biblias anteriores: puntos nuevos una vez (versión 7). Lectura de lo antiguo en `WorkflowPoints`; el PDF lee lo mismo.
- [ ] **B10 Pruebas de cámara (revisada, sin cambios).** Ya estaba en castellano, con cabecera, comparador A/B y su tabla propia. Pendiente: pasarla al armazón común, añadir «objetivo de las pruebas» y «conclusiones», y que crear una prueba sea una ficha y no una hoja con «Guardar prueba».
- [ ] **B12 Moodboard.** Sin tocar: solo coherencia de cabecera y vocabulario cuando Daniel la revise.
- [ ] **Segunda vuelta (tras la revisión de Daniel pantalla a pantalla):** Iluminación, Formato y Localización completas sobre el armazón común y con su PDF en los componentes comunes; «Contraste y textura» de Concepto como resumen de Textura; equipo tentativo/definitivo en la pantalla de Equipo; unificar el aspecto de los campos de texto (con recuadro o sin él).

## Fase C — Biblia, segunda vuelta: Iluminación, Cámara y Óptica

Añadida el 2026-10-10, tras la primera prueba de Daniel. Datos técnicos: se autocompleta con lo que tenga el catálogo y se marca lo que falta. Luz por localización: una ficha por localización con sus sets dentro.

- [x] **C3.0 Fichas repetidas.** El sembrado de fichas de Iluminación se pedía tres veces a la vez y creaba tres por set. Ahora va en serie, y `mergeDuplicates` funde las que había conservando texto, portada e imágenes (probado sobre una copia de la base real: 23 → 10 en KEBAB KHALED).
- [x] **C3.1 Widget «Luz: color y contraste»** (`LightingMetricsWidget`, modelo `LightingMetrics`): temperatura sobre una barra con su color real y referencias con nombre; tinte verde/magenta; muestra del color resultante y cómo se ve con el balance de la cámara; los diez ratios clave:relleno dibujados como esferas, con sus stops y su uso; y receta de gelatinas (CTO/CTB del motor de la planta, plus/minus green) desde la fuente elegida, con la luz que se pierde. Nace vacío. Sustituye a «Sensación de temperatura». Pendiente: pasarle el balance de blancos de la cámara en la pantalla.
- [x] **C3.2 Ideas de luz** (antes «Comportamiento de la luz»): dentro de cada idea, el widget de color y contraste y «sub-puntos» que se abren en ficha con texto e imágenes; siguen las etiquetas, la paleta de la portada y los bloques de refuerzo. Pendiente: paleta propia de la idea, tarjeta con el dato encima en el mosaico, y decidir si «bloques de refuerzo» y «sub-puntos» se funden.
- [x] **C3.4 Luz por localización:** cada localización una sola vez, con su imagen y sus métricas; al abrirla, sus sets uno debajo de otro, cada uno con imágenes de cómo lo imaginamos, texto, color y contraste (con el general del proyecto marcado) y paleta. «Ficha técnica» abre el detalle anterior con los esquemas. Pendiente: miniatura de la planta de luz, día/noche, que estas imágenes salgan en el PDF y la relación con la pantalla Localización.
- [x] **L · Fichas desarrolladas (2026-10-10).** Cada ficha de Iluminación (idea de luz, luz de un set, referencia de cine) es una página con sus propios puntos: cabecera con imagen, título y pastillas de dato, y debajo los widgets del catálogo con «⋯», anchos y «Añadir punto» (`BiblePointsHost`, `LightingCardView`, modelo `LightingCardPage` en `metaJson['page']`). Plantillas por tipo; lo que la ficha tenía (texto, imágenes, métricas, paleta, sub-puntos, bloques de refuerzo) pasa a sus puntos. Widget nuevo «Mosaico de imágenes con nota». Luz por localización: cada set es una ficha completa. Pendiente: elegir «película» o «grupo de stills» al crear una referencia (hoy nace como película), tarjetas-imagen en las listas de ideas y referencias, punto «Planta de luz» con miniatura, y el PDF de estas fichas.
- [x] **L1 · Color en el widget de luz.** Conmutador Luz blanca / Color: luces de color con papel (clave, relleno, contra, ambiente, práctico), tono, saturación e intensidad; colores de partida de fiesta; la esfera se ilumina con cada color desde su lado sumando la luz; valores HSI y RGB para programar los aparatos. Pendiente: escribir el HEX a mano y que la tarjeta de la localización enseñe los colores.
- [x] **L · PDF de Iluminación.** La pantalla sale con la cabecera y los componentes comunes: tratamiento de luz, «Luz: color y contraste» del proyecto (muestra de color, temperatura, contraste en stops, corrección de gelatinas o los colores de la escena con sus valores HSI/RGB), fuentes principales y, después, cada ficha con sus puntos en su orden, agrupadas en ideas de luz, referencias de cine y luz por localización. Una ficha sin nada escrito no sale. Comprobado abriendo el PDF de prueba. Referencias de cine: al añadir se elige película o grupo de stills. Las tarjetas de ideas y referencias enseñan imagen, texto y dato de luz.
- [ ] **C3.3 Referencias de cine** (película o grupo de stills) y **C3.5** (último diálogo, 3200/5600 K de partida en el panel técnico).
- [ ] **C1 Cámara** y **C2 Óptica**: todo lo técnico desde el catálogo, formato elegible con aviso de recorte y de fps, matriz de grabación con los modos de la cámara, peso del conjunto, «Cómo actúa la cámara» como fichas, tabla de focales autocompletada, imagen del material.
