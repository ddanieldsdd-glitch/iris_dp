# IRIS Stage para Unreal

Con esto IRIS y Unreal trabajan juntos en vivo (F6.19, en `docs/PLAN_F6_3D_PREVIS.md`):

1. **De IRIS a Unreal:** lo que cambias en la planta (luces, cámaras, atrezzo, sol y cielo) se aplica al momento en Unreal.
2. **De Unreal a IRIS:** lo que mueves, giras, regulas o cambias de color en Unreal vuelve a la planta y se guarda.
3. **Render RTX:** la imagen de Unreal, con Lumen y el trazado de rayos de la tarjeta, se ve dentro de IRIS por Pixel Streaming, también por la cámara de un plano.
4. **Capturar con RTX:** una foto en alta por la cámara del plano va a su storyboard.
5. **Assets de Fab y Megascans:** cualquier elemento de IRIS puede tener su asset de Unreal (malla, Blueprint o personaje):
   - el atrezzo se ve con ese modelo, y en IRIS la pieza toma sus medidas;
   - focos y cámaras llevan el cuerpo del aparato o el rig unido a la luz o a la cámara de Unreal;
   - paredes, puertas y ventanas lo llevan en el centro del tramo y orientado con él;
   - actores (Manny, Quinn o MetaHuman), grip y rigging, en su sitio.
   Sin asset, el atrezzo va como bloque y lo demás (salvo focos y cámaras) no sale en Unreal.
6. **Un mundo por set:** cada set de rodaje es un nivel propio de Unreal.

## Mundos: cómo se reparte el proyecto

| IRIS | Unreal |
|---|---|
| Proyecto | Un proyecto de Unreal |
| Set de rodaje | Un nivel: `/Game/IRIS/<localización>/<set>_set<id>` |
| Plano maestro de una localización | Un nivel en la misma carpeta: `<localización>_site<id>` |
| Escena y plano | Comparten el nivel de su set. Lo propio de cada plano (luces del plano, cámara) se aplica al abrir su planta en IRIS |

Al abrir en IRIS la planta de otro set, Unreal guarda el nivel de IRIS que tenía abierto y abre el del set nuevo. Si no existe, lo crea con un suelo. Lo que añadas a mano en ese nivel (decorado, assets, Megascans) se queda en él para todas las escenas de ese set.

Si el nivel abierto en Unreal no es de IRIS y tiene cambios sin guardar, IRIS no lo cierra: avisa para que lo guardes. Un nivel sin título (*Untitled*) sí se cierra sin guardar.

## Instalar (una vez por proyecto de Unreal)

**Lo más fácil de todo:** en IRIS, abre el proyecto → **IRIS Stage** → **Abrir en Unreal**. IRIS crea el proyecto de Unreal de ese proyecto (en Documentos\Unreal Projects), lo prepara, abre Unreal y se conecta. No hay que hacer nada en Unreal.

**También desde el tutorial.** En **Ajustes → IRIS con Unreal** (o «Tutorial: cómo prepararlo» en el diálogo de Unreal del 3D) hay un tutorial paso a paso. En su paso «Preparar el proyecto» eliges el `.uproject` e IRIS hace los pasos de abajo:
- activa los plugins;
- copia el script y añade la configuración RTX;
- crea junto al proyecto el lanzador «Abrir <proyecto> con IRIS Stage».

No borra nada y guarda una copia `.antes-de-iris` de cada archivo que cambia. Después, el tutorial prueba la conexión y Pixel Streaming.

A mano, si lo prefieres:


1. En Unreal 5.5, **Edit → Plugins**, activa:
   - Python Editor Script Plugin;
   - Remote Control API;
   - Editor Scripting Utilities;
   - Pixel Streaming 2.

   Reinicia el editor.
2. Copia la carpeta `Content/Python` de aquí dentro de la carpeta `Content` del proyecto. Si el proyecto ya tiene un `init_unreal.py`, añádele la línea `import iris_stage_link`.
3. Para la calidad RTX, añade el contenido de `Config/DefaultEngine.ini` al `Config/DefaultEngine.ini` del proyecto. Activa Lumen con trazado de rayos por hardware. La primera vez Unreal compila sombreadores durante un rato.
4. Abre el proyecto arrastrando su `.uproject` encima de **`Abrir con IRIS Stage.bat`**. Así Pixel Streaming empieza a emitir el visor nada más abrirse.

   Si lo abres de otra forma, ponlo en marcha a mano desde el botón **Pixel Streaming** de la barra de Unreal: **Stream Level Editor**.
5. En el **Output Log** debe salir:
   `[IRIS Stage] Link v1 listo en /Game/Python/iris_stage_link_PY.Default__IrisStageLink`.

## Usarlo desde IRIS

1. Abre la planta de cámara y luz y el panel 3D.
2. Pulsa el botón de Unreal de la barra del 3D (o «Unreal en vivo» a pantalla entera).
3. Escribe el equipo:
   - `127.0.0.1` si Unreal está en el mismo PC;
   - si no, la IP del PC en la red local.

   El puerto es 30010.
4. Pulsa **Conectar**. Desde ese momento:
   - los cambios de la planta llegan a Unreal en unos milisegundos;
   - IRIS mira cada medio segundo si en Unreal se ha tocado alguna pieza suya y se trae el cambio.
5. Para ver Unreal dentro de IRIS, pulsa **Render RTX** (el icono de la tele). En «Ver por la cámara…» elige una cámara de la planta, y el visor de Unreal pasa a mirar por ella con su focal y su sensor. El reproductor está en el puerto 80; si en Unreal usas otro, cámbialo con el icono de red de esa pantalla.
6. En la planta de un plano, **Capturar con RTX** saca una foto de 1920 × 1080 por la cámara elegida y la guarda en el storyboard de ese plano, como un render de Unreal. La primera tarda unos segundos más.
7. Para darle a un elemento su asset, selecciónalo (en la planta o en el 3D a pantalla entera) y, en su ficha, pulsa **Elegir asset de Unreal…**. Aparece lo del proyecto de Unreal: lo que hayas añadido de Fab o Megascans, o lo tuyo, con su origen. A los actores se les ofrecen personajes; a lo demás, mallas y Blueprints. Una pieza de atrezzo toma además las medidas del asset (huella y alto).

## Assets de Fab y Megascans

**Miniaturas.** Al elegir un asset, Unreal le hace dos fotos (desde arriba con fondo transparente, y en 3/4) y IRIS las guarda en el proyecto y las sube a la nube, así que también se ven en el Mac y el iPad aunque allí no haya Unreal. Son un render tuyo, no el modelo. Con el icono de imagen de la barra de la planta («Vista de assets»), lo que tiene asset se dibuja con su foto desde arriba, a escala; en el 3D se ve como un cartel con la foto en 3/4; y en la ficha, la 3/4. «Volver a hacer las miniaturas» las repite.

- **Licencia:** los assets de Fab y Megascans con licencia de Unreal solo se pueden usar dentro de Unreal. Por eso IRIS no los copia: guarda la ruta del asset (`/Game/Fab/…`), y en la planta y el visor de IRIS queda la pieza con sus medidas.
- **Añadirlos:** desde Fab, en el propio Unreal (Window → Fab), o con Bridge para Megascans. Quedan en `/Game/Fab` o `/Game/Megascans`, y la búsqueda de IRIS los encuentra por nombre o carpeta.
- **Sin asset**, la pieza va a Unreal como un bloque con sus medidas, para encuadrar y medir la luz.

Las piezas de IRIS van en la carpeta «IRIS» del World Outliner, con la etiqueta `iris:<id>`. IRIS no toca nada más del nivel. Si borras una en Unreal, en IRIS no se borra: vuelve a aparecer en el siguiente cambio.

## Qué se manda

| IRIS | Unreal |
|---|---|
| Foco pequeño (fresnel, PAR, recorte) | SpotLight. El haz de IRIS cae entre el cono interior y el exterior |
| Panel, tubo o softbox (desde 25 cm) | RectLight del tamaño de la fuente |
| Luz omni (práctica, globo) | PointLight |
| Intensidad | Candelas en el eje, con regulación, difusiones y gelatinas aplicadas. Son los mismos números que el fotómetro de IRIS |
| Color | Temperatura en kelvin |
| Cámara de la planta | CineCameraActor a la altura del objetivo, con la focal y el sensor del plano |
| Atrezzo (mesa, silla, sofá, cama, árbol, roca, vehículo, pieza) | Su asset de Unreal o un bloque con sus medidas |
| Sol del esquema | DirectionalLight en lux, con SkyAtmosphere y SkyLight |

## Qué vuelve de Unreal

| En Unreal | En la planta |
|---|---|
| Mover un foco o una cámara | Su posición y su altura |
| Girar un foco | Hacia dónde apunta: giro e inclinación si cuelga |
| Girar una cámara | Hacia dónde mira |
| Mover o girar una pieza de atrezzo | Su posición y su giro |
| Intensidad de un foco | Su regulación (de 1 a 100 %). A 0, apagado |
| Temperatura de un foco | Su color. Las gelatinas siguen delante |

## Seguridad

Remote Control y Pixel Streaming escuchan en toda la red local sin contraseña. IRIS Stage Link solo deja hacer lo de las tablas: no hace falta activar «Enable Remote Python Execution». Si el PC está en una red compartida, pon una contraseña en **Project Settings → Remote Control → Security** y escríbela en IRIS al conectar.

## Para después

- **Niebla y humo** (F6.9 y F6.16.5): cuando existan en la planta.
- **Exposición de la cámara** (F6.4.6): con intensidades físicas, la exposición automática de Unreal se adapta. Para comparar con el fotómetro conviene fijarla a mano.
- **DLSS:** es un plugin aparte de NVIDIA. Sin él, Unreal usa su propio reescalado.
