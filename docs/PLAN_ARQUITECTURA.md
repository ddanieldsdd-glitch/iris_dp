# Plan AR · Arquitectura de las localizaciones y luz en el set (2026-11-22)

## Por qué

Daniel (2026-11-22): las hojas de luz sirven para ver **con claridad la arquitectura y las luces**. La arquitectura va a ser determinante en toda la app: en la planta 2D en metros, en las posiciones de luz y en el 3D. Hay que inspirarse en Vectorworks Spotlight, WYSIWYG y Capture. No solo en cómo pasan la obra a papel, sino en **cómo se crea**: el flujo de trabajo para levantar el sitio y colgar las luces.

Este plan sigue a LZ.8 (`PLAN_LUZ.md`), que se ocupa de los formatos (MVR y GDTF). Aquí va el **flujo de dibujo** y la **forma de representar**. Se apoya en lo ya hecho en el plan CA (paredes con grosor, puertas, ventanas, calle con perfil y farolas) y en F6 (3D y Unreal).

## Ya hecho en `plan/autoria` (2026-11-22)

- **La pantalla «Alzado y perfil» es la hoja de luz.** Enseña la misma hoja que sale en PDF, con interruptores para:
  - conos de luz;
  - manchas en el suelo;
  - personas y cámaras;
  - números;
  - una hoja o dos.

  Lo que se elige ahí lo usa la ventana de exportar (`LightSheetPrefs`).
- **Hoja de luz:**
  - Personas y cámaras, fuera por defecto.
  - Cada foco lleva una flecha hacia donde apunta.
  - Las farolas se dibujan como farolas: brazo desde la fachada, o poste, y su campana en el alzado.
  - En sets grandes, los símbolos tienen un tamaño mínimo para que los focos se sigan viendo.

## Cómo trabajan los referentes

### Vectorworks (Architect + Spotlight)

- **Se dibuja con objetos, no con líneas.**
  - Un muro tiene grosor, altura, capas y material.
  - Una puerta o ventana se encaja en el muro y lo corta sola.
  - Losas, cubiertas, escaleras y pilares son objetos con medidas.
- **Plantas por niveles** (*stories*), cada una con su altura de suelo y techo. Las **capas de diseño** van por nivel y las **clases** por tipo: muros, mobiliario, luz, cotas. Cada clase se enciende o apaga en cada vista.
- **Un modelo, muchas vistas.** Planta, alzado, sección y 3D salen del mismo modelo. Las hojas (*sheet layers*) se componen con *viewports*, cada uno con su escala y sus clases visibles. Por eso la planta de luz y la de arquitectura son la misma con distintas clases.
- **Spotlight:**
  - Hay **posiciones de cuelgue** con nombre (vara 1, truss FOH, pie de calle). Cada aparato se pega a una y hereda su altura.
  - El aparato es un símbolo 2D/3D con sus datos: canal, circuito, color, accesorio y foco.
  - El **rótulo** (*label legend*) va pegado al símbolo y se coloca solo.
  - Informes e inventario salen del dibujo y se actualizan solos.
  - **Foco de enfoque** (*focus point*): el aparato apunta a un punto con nombre. Si se mueve el punto, se reenfocan todos.

### WYSIWYG (CAST)

- **Tres modos:**
  - **CAD**, para dibujar el sitio y colgar;
  - **Design**, para la planta, las vistas y la documentación;
  - **Live/Shaded**, para ver la luz en tiempo real.
- El sitio se levanta con **herramientas de sala**: suelo, paredes, escenario y gradas, partiendo de una biblioteca de recintos. También se puede importar el DWG del arquitecto y **extruirlo**.
- **Capas** por tipo y **escenas** (estados guardados de la luz).
- Las vistas guardadas (cámaras) se reutilizan en los papeles.

### Capture

- **Rapidez por encima de todo.**
  - Se dibuja el recinto con formas simples (rectángulos, polígonos) que se **extruyen** a una altura.
  - Los objetos se sueltan desde la biblioteca **arrastrando**.
  - Todo se ve en 3D mientras se trabaja.
- **Una sola escena 3D, varias vistas**: planta, frente y cámaras con nombre. Los papeles se componen desde esas vistas.
- **Luz visible**: haz en el aire con humo, mancha en el suelo y gobos. Ayuda a entender el diseño de un vistazo.

## Lo que se lleva a IRIS

1. **Objetos con medidas, no trazos.** Hoy ya están las paredes con grosor y altura, y las puertas y ventanas (CA). Faltan:
   - **suelo y techo de la sala** como objetos, con cota y material;
   - **pilares y vigas** como objetos con sección;
   - **escaleras y desniveles**: tarimas, escalones y rampas;
   - **cubierta** de la nave, a dos aguas o plana;
   - en todos, cotas en metros editables en el panel.
2. **Niveles.** Cada localización puede tener **planta baja, entreplanta y planta 1**, con su altura. Un foco o una cámara pertenece a un nivel y su altura cuenta desde ese suelo. En la hoja de luz, un nivel por vista.
3. **Clases visibles por vista.** Cada vista (planta de cámara, planta de luz, hoja de luz, alzado, 3D y PDF de jornada) elige qué clases enseña:
   - arquitectura;
   - decorado;
   - aparatos;
   - conos;
   - manchas;
   - personas;
   - cámaras;
   - cotas;
   - rigging.

   Es la generalización de los interruptores de hoy. Se guarda por vista y sigue el patrón del centro de ajustes: global + excepción.
4. **Posiciones de cuelgue.**
   - Varas, truss, techo, pared (aplique) y pie. Cada foco va **pegado a una**, como los tubos de pared de CA.3 y el rigging de LZ.1, y hereda su altura.
   - Al mover la posición, se mueven sus focos.
   - En la hoja de luz, la posición lleva su nombre y su altura.
5. **Puntos de enfoque.** Un punto con nombre («Actor A», «Barra», «Puerta») al que apuntan uno o varios focos. Al mover el punto se reorientan todos, y la flecha de dirección de la hoja de luz apunta a él.
6. **Del boceto a la sala en un gesto, como Capture.**
   - Se dibuja un rectángulo o polígono y se pide «hacer sala»: se crean suelo, paredes a la altura por defecto y techo.
   - Una línea a lo largo de una pared pide «hacer fachada».
   - Desde la biblioteca de **recintos tipo** (bar, plató, nave, calle, piso) se parte con medidas reales y se ajusta.
   - Lo que llega del escaneo (plan ES) entra por el mismo camino.
7. **Importar el plano del arquitecto.**
   - Un DXF o un PDF se usa de calco, a escala.
   - De un DXF, las líneas de muro se extruyen a paredes, como en WYSIWYG.
   - Esto completa LZ.8.3, que importa MVR.
8. **Un modelo, muchas vistas.** Planta, alzado, perfil, sección y 3D salen del mismo modelo, que ya existe: `PlanScene3d`. Se añade la **sección** por una línea, que hace falta para ver la altura de un techo con vigas. La hoja de luz se compone con esas vistas, igual que hoy.
9. **Luz visible, a elegir.** El cono, la mancha en el suelo y el haz con humo en 3D son representaciones de la misma luz, cada una con su interruptor. En el PDF salen contorneados y claros; en 3D, con F6.3 (IES) y F6.9 (humo).

## Fases propuestas

| Id | Qué | Depende de |
|----|-----|-----------|
| AR.1 | Clases visibles por vista: los interruptores de la hoja de luz, en la planta y en el 3D | hecho (2026-11-22) |
| AR.2 | Sala en un gesto: rectángulo o polígono → suelo, paredes y techo; recintos tipo | CA |
| AR.3 | Pilares, vigas, tarimas y escalones como objetos con medidas; sección | AR.2 |
| AR.4 | Posiciones de cuelgue con nombre y focos pegados | hecho (2026-11-22) |
| AR.5 | Puntos de enfoque | AR.4 |
| AR.6 | Niveles por localización | AR.2 |
| AR.7 | Calco e importación de DXF del arquitecto | LZ.8.3 |

**Orden propuesto:** AR.1 → AR.4 → AR.5 (lo que más mejora la hoja de luz) → AR.2 → AR.3 → AR.6 → AR.7.

**AR.1, cómo quedó:** `PlanClass` (`plan_classes.dart`) da a cada elemento su clase: arquitectura, decorado, aparatos de luz, grip, rigging, personas o cámaras.
- En la planta, el menú de vista (paleta) enseña u oculta cada clase. Se guarda por separado para la planta de cámara y la de luz; la de luz parte sin personas ni cámaras.
- Lo oculto no se dibuja ni se coge con el dedo, pero sigue dando luz y sombra, y cuenta para el material.
- El 3D oculta las mismas clases, salvo los aparatos: sin ellos no habría luz.
- Cotas y manchas quedan para cuando la planta las dibuje como hoja (AR.4).

**AR.4, cómo quedó:** `HangingPositions` (`rig/hanging_positions.dart`) da a cada truss su nombre: el que tenga o «Truss 1», «Truss 2»… de arriba abajo y de izquierda a derecha.
- En la hoja de luz:
  - cada truss lleva su nombre y su altura («VARA FOH · +4,00») en la planta y en los alzados;
  - la columna MONTAJE de la lista dice de qué truss cuelga cada foco, o si va en techo, pared o pie.
- En el panel:
  - el foco dice de dónde cuelga y a qué altura;
  - el truss dice qué posición es y cuántos focos lleva.
- Las luces de pared recuerdan su pared (`props['onWall']`) y la siguen si se mueve, como ya hacían las de truss.

**Esquema:** AR.1, AR.4 y AR.5 caben en `props` de los elementos, sin columnas nuevas. AR.6 necesita decidir si el nivel va en el elemento o en el set.

**Unreal:** cada objeto de arquitectura sale ya en el glTF del set (F6.21.3). Las posiciones de cuelgue salen como `Truss` en el MVR (LZ.8.1).

## Por decidir con Daniel

- ¿Qué recintos tipo hacen falta primero? Propuesta: bar, calle, piso, nave y plató.
- ¿Niveles ya, o cuando haya un rodaje con entreplanta?
- En la planta de cámara, ¿también se ocultan conos y manchas por defecto, o solo en la hoja de luz?

---

# Plan AM · Motor arquitectónico (2026-11-22)

Aprobado por Daniel el 2026-11-22, para hacerlo después de AR.4. La AM.0 de abajo es AR.4 y ya está hecha.

### Contexto

Daniel quiere poder crear, con cuidado y de forma realista, cualquier lugar de rodaje:
- casas e interiores;
- edificios, calles y puentes;
- casetas de feria;
- estaciones e interiores de vagón;
- montañas y playas.

Todo en tela, madera, hormigón, vidrio y demás. Debe valer para la planta 2D en metros, para las posiciones de luz, para el 3D y para Unreal. La idea es **un motor**: piezas básicas con las que se construye cualquier cosa, como en los programas de arquitectura. No una plantilla por lugar.

**Decisiones de Daniel (2026-11-22):**
- Los cuatro grupos de lugares a la vez, sobre la misma base: casa e interiores, edificios y calle, estación y vagón, naturaleza.
- **Texturas CC0 ya** (ambientCG y Poly Haven). Con esto queda dado el visto bueno pendiente UN.6.
- Antes, terminar AR.4, que está a medias.

#### Lo que ya hay (revisado en el código el 2026-11-22)
- **Muros** (`plan_segment.dart`): rectos o curvos, con grosor, altura, nivel y material. En 2D no se ve el grosor y las esquinas no se unen.
- **Aberturas** (`plan_opening.dart`): puertas, ventanas, huecos y rejas, que cortan el muro en la luz y en el 3D.
- **Nave paramétrica** (`rig/plan_hall.dart`, `HallRecipe`): contorno, lados y cubierta plana, a dos aguas o de lona. Se construye en piezas sueltas marcadas con `hallUid`; lo tocado a mano se respeta (`detached`). **Este es el patrón de las recetas.**
- **Calle con perfil** (`plan_street.dart`): bandas, fachadas y farolas. Su extrusión (`addSurface`) es la única de polígonos que hay en el 3D.
- **Terreno:** colinas y desniveles solo en 2D y en la luz. En 3D no existe (`plan_scene3d.dart:173`, `:479`).
- **Recintos:** solo en la luz (`light/rooms.dart`, `SceneRoom`). Su techo y su suelo no tienen geometría.
- **Materiales** (`light/surfaces.dart`): reflectancia y color. Sin rugosidad ni texturas. La clave `material` choca entre muros y telas.
- **Niveles:** `PlanLevel` es solo una altura, sin forjado.
- **3D:** three.js en un WebView (`assets/viewer3d/viewer.js`), alimentado por el JSON de `PlanScene3d`.
- **Unreal:** recibe la estructura como GLB (`structureGlb`) solo con `baseColor`, y el plugin usa un material de color plano (`iris_stage_link.py:750`).

#### Referentes y qué se toma de cada uno
- **SketchUp:** dibujar una forma y estirarla en altura (empujar/tirar); componentes que se repiten.
- **Revit y ArchiCAD:** muros, forjados, cubiertas y escaleras como objetos con medidas; familias paramétricas; plantas por niveles; sección y alzado del mismo modelo.
- **Vectorworks:** clases por vista (hecho en AR.1), extrusión a lo largo de un camino y hojas.
- **Sweet Home 3D:** interiores habitación a habitación, con biblioteca de muebles.
- **Capture y WYSIWYG:** rapidez, recintos tipo y el 3D a la vista mientras se dibuja.
- **Unreal y World Machine:** terreno por alturas con pinceles y capas de material; agua.

### Principios (sin excepción; son los mismos que F6)

1. **Un solo modelo:** `PlanElement` + `props` → `PlanScene3d`. Sin columnas nuevas: el esquema sigue en 66.
2. **Cada pieza nueva cumple el contrato completo** antes de darse por hecha:
   - 2D (painter);
   - luz (`blockersOf`, recintos y rebote en `light_scene.dart`);
   - 3D (lista en el JSON y constructor en `viewer.js`);
   - Unreal (en el GLB de estructura, con su material);
   - DXF (una capa);
   - hoja de luz y alzado (`plan_elevation.dart`);
   - clase de AR.1 (`PlanClass`).
3. **Recetas como la nave:** un elemento receta guarda los parámetros y genera piezas normales marcadas con su `uid`. Se puede editar a mano y lo tocado se respeta.
4. **Medidas reales en metros**, con valores por defecto de la vida real: puertas de 0,82 × 2,03 m, peldaño de 17,5 × 28 cm, andén de 0,76–1,10 m, vagón de unos 2,9 m de ancho.

### Fases

**AM.0 · Cerrar AR.4** (hecho el 2026-11-22)
- Partir las líneas largas añadidas, sin formatear archivos enteros.
- En el panel del foco, una línea «Cuelga de Truss 2 · +5,00 m» o «En la pared» (`HangingPositions`).
- Pruebas: nombres automáticos y propios, `mountOf`, la luz de pared que sigue a su pared y la que se despega, y la hoja con un truss renombrado.
- Commit y push a `plan/autoria`, y actualizar `PLAN_ARQUITECTURA.md`.

**AM.1 · Biblioteca de materiales PBR con texturas CC0**
- Archivo nuevo `lib/features/camera_plan/arch/arch_material.dart`. `ArchMaterial` lleva:
  - `id`, nombre y familia (tela, madera, hormigón, ladrillo, piedra, yeso, metal, vidrio, agua, arena, hierba, tierra, asfalto, baldosa);
  - `albedoRgb`, `roughness`, `metalness`, `transmission`, `ior`;
  - el tamaño real de la textura en metros;
  - un `textureId` CC0;
  - la reflectancia y el desplazamiento de color para la luz, que salen del albedo y sustituyen a los números puestos a mano.
- `kWallMaterials`, `kFloorMaterials` y `kDrapeMaterials` pasan a ser vistas de esta biblioteca, sin romper los `id` guardados.
- Clave nueva `props['mat']` para el material de una cara. `material` se sigue leyendo como hasta ahora.
- **Texturas:**
  - Un juego de partida de unos 24 materiales a 1K (albedo, normal y rugosidad) va dentro de la app.
  - El resto se descarga a la carpeta de la app al usarlo, desde las API de ambientCG y Poly Haven, con su licencia CC0 anotada en un manifiesto.
- **Visor 3D:** registro de materiales por `id` (sustituye los fijos de `viewer.js:685-734`, `:829` y `:944`), con repetición de textura según los metros y coordenadas UV en muros, suelos y extrusiones.
- **Unreal:** el GLB lleva PBR y texturas. `iris_stage_link.py` crea material instances por `id`.
- **Selector de material** con miniaturas, compartido por muros, suelos, cubiertas, volúmenes y telas.

*Hecho en parte (2026-11-22, rama `plan/motor-arquitectonico`, sin publicar). Cómo quedó:*
- `arch/arch_material.dart`: 35 materiales en 14 familias, 24 con textura de ambientCG (CC0). Los de pared y suelo de siempre son entradas de la biblioteca con sus mismos números (`wallLegacy`, `floorLegacy`); una prueba comprueba que la luz y el color no cambian. Los nuevos sacan la reflectancia y el tinte del color medio de su textura.
- `kWallMaterials` y `kFloorMaterials` se quedan como estaban (sin mover nada de la luz). Las telas de colgar tienen su PBR en `drape-<id>`.
- Las texturas van **a 512 px y no a 1K**: 4 MB en la app en lugar de unos 25 MB. La descarga al usarlo (a 1K o 2K, y Poly Haven) **queda pendiente**.
- Escena 3D: `mat` en paredes (y en calzada, acera, suelo de nave y telas) y un registro `materials` con lo que usa la escena. La luz lee `mat` antes que `material`; al elegir uno de los de siempre se guardan los dos, para que una versión anterior lo siga leyendo.
- Visor: registro por `id`, coordenadas de textura en metros proyectadas por caras. Los metales se rebajan en pantalla (sin mapa de entorno se ven negros); al glTF va el valor real.
- Selector con miniaturas por familias en: pared, suelo del recinto (la luz de la mancha de sol lo lee), calle (calzada, aceras y fachadas; al separar las fachadas en paredes se quedan con el suyo) y nave (suelo y cubierta, salvo la de lona). Al elegir uno de los de siempre se guarda su `id` de siempre.
- Pendiente de AM.1: la descarga al usarlo, a más resolución.

**AM.2 · Forjados y volúmenes: dibujar y estirar**
- Herramienta polígono (o rectángulo) que crea:
  - un **forjado**: suelo o techo con grosor, cota y huecos (escalera, patio). Sirve para tarimas, aceras y andenes;
  - un **volumen**: polígono estirado a una altura, con el lado superior inclinado o no. Sirve para barras, casetas, plintos, bancos y bloques de edificio.
- **Empujar/tirar:** asa de altura en la planta y en el 3D (`plan_3d_edit.dart`).
- **Luz:** el forjado da techo y suelo a los recintos que cubre. El volumen bloquea y rebota.
- **3D:** `slabs` y `volumes` en el JSON, construidos con `ExtrudeGeometry` y material por cara.

*Hecho en parte (2026-11-22, rama `plan/motor-arquitectonico`, sin publicar). Cómo quedó:*
- `arch/arch_solid.dart`: forjado (`RigType.slab`: cota de arriba y grosor) y volumen (`RigType.volume`: alto), con el contorno en metros respecto a su centro, giro, material de la biblioteca y `uid`. Una versión anterior de IRIS los lee como un atrezzo cualquiera.
- Herramientas «Forjado» y «Volumen» en la paleta: un rectángulo de esquina a esquina, con su ancho y su fondo mientras se dibuja. Se cogen tocando dentro.
- Panel: ancho, fondo, alto o cota y grosor, material y área. El empujar/tirar va por ahora con el control de alto; falta el asa en la planta y en el 3D.
- Planta: relleno del color de su material, debajo de todo; un forjado por encima de 2 m (entreplanta) va a trazos. Clase AR.1 «Arquitectura», capa DXF `VOLUMENES` y alzado de su cota de abajo a la de arriba.
- Luz: cada lado tapa de su cota de abajo a la de arriba; bajo una entreplanta pasa la luz. **Falta:** que el forjado dé techo y suelo a los recintos, que el volumen rebote y que una tarima suba a quien está encima.
- 3D y Unreal: lista `solids` (contorno, `z0`, `z1`, material) extruida con textura a escala; va al GLB como pieza propia.
- Corregido de paso: los truss, motores, pilares y naves salían además como cajas «Rectángulo» en el 3D.
- Los materiales de siempre ya no pierden el color de su textura: el tinte solo ajusta el brillo.
- Falta: polígonos de más de cuatro lados y huecos (dibujar punto a punto), y crear un forjado desde paredes que cierran.

**AM.3 · Cubiertas para cualquier contorno**
- Se sacan `HallRoof` y `roofGrid` de la nave a un `ArchRoof` común: plana, a un agua, a dos aguas, a cuatro aguas, en bóveda y de lona. Con alero, pendiente o altura de cumbrera, y material.
- Se aplica a una nave, a un volumen o a un recinto cerrado.
- La luz ya entiende las cubiertas a través de la altura de techo. Se amplía a cubiertas inclinadas con la altura en cada punto.

*Hecho en parte (2026-11-22, rama `plan/motor-arquitectonico`, sin publicar). Cómo quedó:*
- `arch/arch_roof.dart`: `ArchRoof` común (plana, un agua, dos aguas, cuatro aguas y bóveda) sobre cualquier contorno, con subida, dirección de la cumbrera y material. Da la altura sobre el alero en cada punto, la cumbrera (acortada en cuatro aguas) y la malla de cubierta y hastiales.
- La nave gana un agua, cuatro aguas y bóveda (elegidas con fichas en su hoja); la de lona sigue como estaba.
- Un volumen puede llevar cubierta: fichas de forma, subida, «Girar la cumbrera» (o la caída) y material propio. El alto pasa a ser «Alto al alero».
- Planta: cumbrera a trazos y limatesas en cuatro aguas. Alzado y DXF: la silueta real (el hastial en pico visto de lado). Hoja de luz: la misma silueta.
- Luz: cada lado tapa hasta la altura de la cubierta en su punto medio (los hastiales más que los aleros).
- 3D y Unreal: el volumen se extruye hasta el alero y encima van la cubierta y los hastiales, cada uno con su material; viaja al GLB con la pieza.
- Falta: cubierta sobre un recinto cerrado de paredes; el vuelo del alero (se guarda pero no se dibuja); la flecha de caída de la cubierta a un agua en la planta; y la lona en volúmenes.

**AM.4 · Muros de verdad**
- Grosor visible en 2D y esquinas unidas, en 2D y en 3D.
- Perfil vertical: hastial (muro con pico) y altura distinta en cada extremo.
- Huecos en arco (medio punto, rebajado).
- Muros compuestos de varias capas (enlucido + ladrillo), con un material en cada cara.
- Se corrige el giro de los pilares cuadrados y se exportan a 3D las piezas de muro antiguas.

**AM.5 · Barridos: un perfil a lo largo de un camino**
- Un perfil 2D (biblioteca o dibujado) recorre una línea, recta o curva. Con esto salen:
  - barandillas, bordillos, cornisas, molduras y zócalos;
  - vías de tren (carril + traviesas, en repetición);
  - catenaria, arcos y tableros de puente;
  - el casco de un vagón.
- Repetición a lo largo del camino para farolas, traviesas, columnas y asientos: el patrón que ya usa `lampEveryM`.

**AM.6 · Escaleras, rampas y niveles** (absorbe AR.3 y AR.6)
- Escalera paramétrica (recta, en L, en U, de caracol), con huella, contrahuella, barandilla y material. Rampa.
- Niveles de una localización: planta baja, entreplanta, planta 1… Cada uno con su altura y un forjado. La planta enseña un nivel y los demás atenuados.
- Las luces y las cámaras se miden desde su nivel; esto ya existe con `levelM`.
- **Vista de sección** por una línea, en la planta y en la hoja (`plan_elevation.dart`).

**AM.7 · Terreno y agua en 3D**
- Terreno por alturas: una rejilla como la de `roofGrid`, con pinceles para subir, bajar, alisar y aplanar, y capas de material pintadas (arena, hierba, roca, tierra).
- Las colinas y desniveles de hoy se convierten a este terreno.
- **Agua:** nivel del mar u orilla, con material de agua (ya planificado como «mar y costa» en P2).
- **Luz:** `groundAt` y los bloqueos salen del terreno.
- **Unreal:** se exporta como malla.

**AM.8 · Recetas por lugar** (generalizan `HallRecipe`; cada una construye con AM.1–AM.7)
- **Casa e interiores:**
  - casa por plantas, que reparte el contorno en habitaciones, con tabiques, puertas, forjados, tejado y escalera;
  - habitaciones tipo (dormitorio, cocina, baño, salón, bar), con muebles de la biblioteca (`PropBox` y packs CC0).
- **Edificio y calle:**
  - edificio de n plantas con fachada modular (ventanas o balcones por módulo, bajo comercial) y cubierta;
  - la calle existente se puebla con fachadas de edificio;
  - puente, de tablero + pilas o de arco.
- **Estación y vagón:**
  - estación: andén a su altura, vías con barrido, marquesina (cubierta sobre pilares) y paso subterráneo con escalera;
  - vagón: casco con barrido de perfil, ventanas en serie, filas de asientos por módulo, pasillo y puertas.
- **Naturaleza:**
  - montaña: terreno con pinceles y material por altura;
  - playa: terreno, agua, arena y paseo con barandilla.
- Las recetas aparecen en «Nuevo set» y en la paleta como **recintos tipo**, como ya hacen las plantillas de nave y de calle.

### Unreal, Fab, Megascans y escaneos (pedido de Daniel, 2026-11-22)

Todo lo que se construye con el motor tiene que leerse en Unreal con facilidad. También tiene que poder **sustituirse por meshes reales** y **nacer de un escaneo** del móvil (LiDAR o cámara). Esto no es una fase aparte: está en el contrato de cada pieza (principio 2) y en estos pasos.

**AM.U1 · Cada pieza llega a Unreal como un actor propio, con nombre y datos**
- El GLB de estructura deja de ser un bloque: un nodo por pieza.
- Nombre del nodo: `IRIS_<clase>_<uid>`.
- `extras` de glTF por nodo: `uid`, clase de AR.1, receta, nivel, material, medidas y parámetros de la receta.
- `iris_stage_link.py` crea un StaticMeshActor por pieza, en carpetas por clase y nivel, con etiquetas (`Tags`). Al reimportar sustituye por `uid`, sin duplicar.
- Las piezas que se repiten (asientos, traviesas, farolas, ventanas de un módulo) van como **instancias**: `EXT_mesh_gpu_instancing` → Instanced Static Mesh. Es lo que hace SketchUp con los componentes y lo que Unreal necesita para que sea ligero.

*Hecho en parte (2026-11-22, con AM.1):* el GLB de estructura lleva un nodo por pieza, `IRIS_<clase>_<id>`, con `uid`, clase, material y nombre en los `extras`, y materiales PBR con sus texturas (si el WebView no deja leerlas, sale sin texturas y con el color medio). `iris_stage_link.py` pone cada pieza como actor propio en `IRIS/Estructura/<Clase>` con etiquetas `IRIS_cls:` e `IRIS_piece:`. Faltan las instancias y comprobarlo en Unreal en el PC de Daniel.

**AM.U2 · Vincular cualquier pieza o material con un asset de Unreal (Fab, Megascans, proyecto)**
- Se amplía lo que ya existe: `UnrealAssetRef` en `props['unreal']` (`lib/features/unreal_link/unreal_asset_ref.dart`), hoy solo en muebles y algunos tramos.
- **Por pieza:** una puerta, una ventana, un asiento de vagón, un banco, una farola o un tramo de barandilla pueden decir «en Unreal, este mesh».
  - En IRIS se sigue viendo la pieza paramétrica, con la miniatura del asset (`unreal_thumbs.dart`).
  - En Unreal se coloca el asset ajustado a las medidas de la pieza.
- **Por material:** cada `ArchMaterial` puede llevar su equivalente en Megascans o Fab (`surfaceRef`). En Unreal se usa ese material. En IRIS, la textura CC0 parecida o el color medio de la miniatura (F6.23.4).
- **Por receta:** una receta puede proponer sus vínculos, por ejemplo vagón → «asiento de tren» de Fab. Se eligen una vez por proyecto, en la biblioteca de Unreal que ya existe (`unreal_library.dart`).
- **Licencias:** el modelo de Fab o Megascans nunca sale de Unreal (como hoy). IRIS solo guarda la referencia y la miniatura.

**AM.U3 · Del escaneo al motor** (une ES y F6.20 con AM)
- Hoy el escaneo da muros, huecos, objetos y la altura de techo (`scan_structure.dart` → `scan_review.dart`). Con el motor dará piezas completas:
  - suelo y techo del escaneo → **forjados** de AM.2, con su cota;
  - varias alturas de suelo → **niveles** de AM.6; escalón o rampa detectados → escalera o rampa;
  - objetos del escaneo → **volúmenes** de AM.2, o vínculo a un asset de Unreal por su tipo (ES.5): «sofá» → sofá de Fab;
  - exterior (calle de noche, ES.1b/2b) → calle con perfil, fachadas y bordillos (lo que falta de ES.2b);
  - escaneo con cámara, sin LiDAR (F6.20 E y RealityScan) → el mismo camino: se proponen piezas sobre la malla y se pegan a ella (ES.3).
- **Material desde el escaneo:**
  - Se mide el color medio de cada cara escaneada y se propone el `ArchMaterial` más parecido.
  - Más adelante, la textura real proyectada en la pieza (ES.4) viaja como material propio a Unreal.
- La malla del escaneo sigue siendo solo la piel, a elegir (decisión ES 2026-11-03). La pieza paramétrica es la que manda y la que se edita.

**AM.U4 · Formatos de intercambio**
- **glTF/GLB con `extras`:** el formato principal, para Unreal, Capture y Blender.
- **USD/USDZ:** ya se lee para los escaneos (`scan_usdz.dart`). Exportar USD del set queda como opción para Unreal 5 y Omniverse, cuando AM.U1 esté estable.
- **MVR:** la estructura va como `SceneObject` con su glTF (LZ.8.1).
- **Importar de SketchUp, Blender o Revit:** por glTF o DXF. Lo importado entra como volumen o mesh de referencia (calco 3D) y se puede vincular igual que un asset (AR.7 lo amplía de DXF a glTF).

**Comprobación de Unreal en cada fase:** un `.irisstage` de prueba con piezas nombradas, materiales y, desde AM.U2, al menos una pieza vinculada a un asset de Fab o Megascans. Daniel lo abre en su PC.

### Orden

AM.0 → AM.1 (con AM.U1, porque ya cambia el GLB) → AM.2 → AM.3 → AM.4 → AM.U2 → AM.6 → AM.5 → AM.U3 → AM.7 → AM.8. AM.U4 se va haciendo con cada formato.

Las recetas salen por grupos según tengan ya sus piezas:
- **Casa e interiores:** tras AM.6.
- **Edificio y calle:** tras AM.4.
- **Estación y vagón:** tras AM.5.
- **Naturaleza:** tras AM.7.

AR.5 (puntos de enfoque) y AR.7 (DXF del arquitecto) siguen en AR.

### Dónde se toca (patrón por pieza)

| Parte | Archivos |
|---|---|
| Modelo y recetas | nuevo `lib/features/camera_plan/arch/` (`arch_material`, `arch_slab`, `arch_volume`, `arch_roof`, `arch_sweep`, `arch_stair`, `arch_terrain`, `arch_recipes`), siguiendo `rig/plan_hall.dart` |
| 2D | `camera_plan_painter.dart`, con el dibujo nuevo en archivos aparte, como `plan_terrain_painter.dart` |
| Luz | `light/light_scene.dart` (`blockersOf` :946, recintos :563–590 y :814, rebote :1961) y `light/surfaces.dart` |
| 3D | `rig/plan_scene3d.dart` (listas nuevas, `version` :44, `structureKey` :245) y `assets/viewer3d/viewer.js` (`load` ~:1342, `LAYERS` :96, `structureGlb` / `exportGlb` :2013 y :2040) |
| Unreal | `tools/unreal/iris_stage/Content/Python/iris_stage_link.py` (`_apply_structure` :728, materiales :750) |
| CAD y hojas | `plan_cad_export.dart` (capas DXF) y `plan_elevation.dart` + `rig_sheet_pdf.dart` |
| Editor | herramientas y panel nuevos en archivos aparte (`camera_plan_editor.dart` ya pasa de 7.000 líneas) |
| Documentación | `docs/PLAN_ARQUITECTURA.md` (el plan AM pasa a ser su segunda parte), `PLAN_F6_3D_PREVIS.md` (F6.1.2, F6.2, F6.14 y F6.23.4 remiten a AM) y `PLAN_MAESTRO.md` (añadir AR/AM) |

### Comprobación

- **En cada fase:**
  - pruebas con datos inventados de la pieza nueva en su contrato completo: 2D, luz, JSON 3D, DXF y alzado;
  - `flutter test` completo, `dart run tool/check_architecture.dart` y `flutter analyze` sin errores nuevos.
- **A la vista:** capturas de la planta (`saveSnapshot`) y de la hoja en PDF → PNG (`scratchpad/pdf2png.swift`). En el 3D, la app en el Mac con una copia de la base en el scratchpad, solo en lectura. Se mandan las imágenes a Daniel.
- **Unreal:** un `.irisstage` de prueba por fase con materiales, que Daniel abre en su PC.
- **Al terminar cada grupo de recetas:** un set de ejemplo (casa, calle con edificios, estación con vagón y playa) construido solo con el motor.
- **Sin publicar:** todo en `plan/autoria` o en una rama `plan/motor-arquitectonico` desde ella. Se publica por paquetes y solo con el visto bueno de Daniel.
