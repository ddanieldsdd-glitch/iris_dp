# Prueba de IRIS Stage con Unreal (PR #50)

Lista para probar en el PC lo nuevo del 3D con Unreal: los pasos 1 a 5 de F6.19 y un mundo por set. Usa una planta de prueba, no una de un rodaje real: los cambios que vienen de Unreal se guardan en la planta.

## Antes de empezar

### Con un botón (recomendado)

- [ ] El menú del proyecto dice **IRIS Stage** (antes «Unreal / LUKA Bridge»).
- [ ] IRIS Stage → **Abrir en Unreal**, con Unreal cerrado. Va diciendo lo que hace (preparando, abriendo, conectando) y acaba en «Conectado con Unreal 5.5».
- [ ] Se ha creado `Documentos\Unreal Projects\IRIS<Proyecto>\IRIS<Proyecto>.uproject`.
- [ ] Debajo del botón pone ese proyecto; la segunda vez abre el mismo, no crea otro.
- [ ] Con Unreal ya abierto, **Abrir en Unreal** solo conecta.
- [ ] **Usar otro proyecto de Unreal…** prepara y abre uno tuyo.
- [ ] En el 3D de la planta, el diálogo de Unreal tiene el mismo botón **Abrir en Unreal**.
- [ ] Otro proyecto de IRIS → su propio proyecto de Unreal.

### Con el tutorial de la app

- [ ] **Ajustes → IRIS con Unreal** abre el tutorial (7 pasos). También desde el diálogo de Unreal del 3D («Tutorial: cómo prepararlo») y desde Render RTX cuando no responde.
- [ ] Paso «Preparar el proyecto»: elegir el `.uproject` (con Unreal cerrado). Salen en verde:
  - plugins activados;
  - IRIS Stage Link copiado;
  - `init_unreal.py`;
  - Lumen con trazado de rayos;
  - lanzador creado.
- [ ] Repetirlo con el mismo proyecto: todo sale como «ya estaba», sin duplicar nada.
- [ ] Junto al proyecto hay «Abrir <proyecto> con IRIS Stage.bat» y copias `.antes-de-iris`.
- [ ] Paso «Abrir Unreal»: **Abrir Unreal ahora** abre el proyecto. La primera vez tarda (sombreadores).
- [ ] Paso «Conectar»: **Probar conexión** dice «Conectado con Unreal 5.5». El tutorial enseña la IP de este equipo para el Mac o el iPad.
- [ ] Paso «Render RTX»: **Probar Pixel Streaming** dice que responde.
- [ ] Pasos «Cómo se trabaja» y «Si algo falla»: se entienden sin haber leído esta lista.

### A mano (si no se usa el tutorial)


- [ ] Cerrar cualquier otro IRIS de desarrollo: comparten la base de datos.
- [ ] Proyecto de Unreal preparado según `tools/unreal/iris_stage/README.md`: plugins, `Content/Python` y `Config/DefaultEngine.ini`.
- [ ] Abrir el proyecto con `Abrir con IRIS Stage.bat`. El Output Log dice `[IRIS Stage] Link v1 listo`.
- [ ] Añadir en Unreal un suelo (Add → Shapes → Plane, escalado), para ver la luz.

## 1. Conectar

- [ ] En IRIS, planta de cámara y luz → panel 3D → botón de Unreal → `127.0.0.1`, puerto `30010` → **Conectar**: dice «Conectado con Unreal 5.5».
- [ ] Con Unreal cerrado, **Conectar** explica que Unreal no contesta.
- [ ] Con un proyecto de Unreal sin `Content/Python`, **Conectar** explica que falta IRIS Stage Link.
- [ ] **Desconectar** y volver a conectar: la escena entera vuelve a llegar.
- [ ] Cerrar y abrir IRIS: recuerda el equipo y el puerto.

## 2. De IRIS a Unreal

- [ ] Al conectar aparece la carpeta «IRIS» en el World Outliner, con un actor por foco y por cámara, más el sol, el cielo y la atmósfera si el esquema tiene sol.
- [ ] Mover un foco en la planta lo mueve en Unreal. El diálogo de conexión dice el tiempo del último cambio: debe ser menos de medio segundo.
- [ ] Cambiar su altura y, si cuelga, su inclinación.
- [ ] La regulación cambia su intensidad en Unreal: menos candelas, en Details → Intensity.
- [ ] Apagar y encender un foco.
- [ ] La temperatura de color cambia el color en Unreal.
- [ ] Una gelatina o una difusión: baja la intensidad y cambia el color, igual que el fotómetro.
- [ ] Tipos de luz:
  - [ ] un fresnel o un PAR es un SpotLight;
  - [ ] un panel o un softbox es un RectLight de su tamaño;
  - [ ] una práctica es un PointLight.
- [ ] Borrar un foco en la planta lo borra en Unreal.
- [ ] Cámara de la planta: un CineCameraActor a la altura del objetivo, con la focal del plano (Details → Current Focal Length).
- [ ] Cambiar la óptica de la cámara en IRIS cambia la focal en Unreal.
- [ ] Sol: cambiar la hora o el acimut en el esquema de luz mueve el sol en Unreal; día y noche.
- [ ] Nada que no sea de IRIS se toca en el nivel.

## 3. De Unreal a IRIS

- [ ] Mover un foco IRIS_… en Unreal: en menos de un segundo se mueve en la planta y en el 3D de IRIS.
- [ ] Subirlo o bajarlo: cambia su altura en IRIS.
- [ ] Girarlo: cambia hacia dónde apunta en la planta (y la inclinación si cuelga).
- [ ] Bajar su Intensity en Unreal: baja su regulación en IRIS. A 0 queda apagado.
- [ ] Cambiar su Temperature en Unreal: cambia su color en IRIS.
- [ ] Mover y girar una cámara IRIS_Cam_… en Unreal: se mueve y gira en la planta.
- [ ] Lo cambiado en Unreal queda guardado: cerrar la planta, volver a abrirla y sigue igual.
- [ ] Con el 3D abierto en el panel y a pantalla entera a la vez, un cambio en Unreal se aplica una sola vez, sin moverse el doble.
- [ ] Después de un cambio en Unreal, no se queda temblando entre IRIS y Unreal.
- [ ] Deshacer en la planta (Ctrl+Z) un cambio que vino de Unreal: vuelve en la planta y en Unreal.

## 4. Render RTX

- [ ] Con la conexión activa aparece el icono de la tele en la barra del 3D. A pantalla entera: «Render RTX: ver Unreal aquí».
- [ ] Se abre la imagen del visor de Unreal sin los controles del reproductor.
- [ ] Mover un foco en IRIS se ve en la imagen al momento.
- [ ] «Ver por la cámara…»: el visor de Unreal pasa a mirar por esa cámara, con su encuadre.
- [ ] Moverse por Unreal desde la imagen, con ratón y teclado, mueve la cámara; al volver a la planta se ha movido también allí.
- [ ] Con Unreal cerrado, la pantalla explica qué falta.
- [ ] Botón de volver a cargar y cambio de puerto.
- [ ] Calidad: Lumen con sombras y rebotes. Si se ve plano, revisar `DefaultEngine.ini`.

## 5. Capturar con RTX

- [ ] En la planta de un plano, en Render RTX, aparece **Capturar con RTX**. En la planta de un set o de una localización no aparece.
- [ ] Elegir la cámara y capturar: dice «Captura RTX guardada en el storyboard del plano N».
- [ ] La imagen está en el storyboard y en la hoja de ese plano, marcada como render de Unreal.
- [ ] Con varias cámaras, sin elegir ninguna, el botón está apagado.
- [ ] La primera captura tarda más, unos 20 s; las siguientes, unos segundos.

## 6. Assets de Fab y Megascans

- [ ] Añadir en Unreal algo de Fab o Megascans (un sofá, una silla).
- [ ] En IRIS, 3D a pantalla entera, seleccionar un sofá de la planta → **Elegir asset de Unreal…** → buscar «sofa» → aparece con sus medidas.
- [ ] Elegirlo: en Unreal el bloque pasa a ser el sofá de Fab, y en la planta de IRIS la pieza toma sus medidas.
- [ ] **Sin asset (bloque)** lo devuelve al bloque.
- [ ] Mover y girar el sofá en Unreal: se mueve y gira en la planta.
- [ ] Sin conexión, el botón lo explica.

## 7. Un mundo por set

- [ ] Abrir la planta del set A: en Unreal se abre (o se crea) `/Game/IRIS/<localización>/<set A>_set<id>`, con un suelo.
- [ ] Abrir la planta de un plano del set A: es el mismo nivel.
- [ ] Abrir la planta del set B: Unreal guarda el A y abre o crea el B. Las luces del A no están en el B.
- [ ] Volver al set A: está como se dejó, también lo añadido a mano en Unreal (decorado de Megascans).
- [ ] Un set con tildes o eñes en el nombre: la ruta las quita (Salón → Salon).
- [ ] Con un nivel tuyo abierto y sin guardar en Unreal, conectar: IRIS avisa de que lo guardes y no lo cierra.

## 8. Desde otro equipo (cuando se pueda)

- [ ] En el Mac, en la misma red: conectar con la IP del PC. Mover un foco y ver la imagen RTX.
- [ ] En el iPad: lo mismo. La primera vez pide permiso de red local.

## Qué apuntar si algo falla

- Qué hiciste, en IRIS o en Unreal.
- El mensaje del diálogo de conexión.
- Las últimas líneas del Output Log de Unreal que empiecen por `[IRIS Stage]`.
