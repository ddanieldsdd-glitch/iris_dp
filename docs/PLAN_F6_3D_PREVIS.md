# F6 · IRIS como herramienta de previsualización: planta 2D y 3D en un solo sistema

Plan vivo. Cada punto tiene un identificador (`F6.x.y`) para poder cambiarlo, quitarlo o reordenarlo sin tocar el resto. Estado de cada punto: **pendiente**, **en curso**, **hecho (PR)**, **descartado**.

## Para qué

Hoy Daniel compone los planos y prueba la luz en Unreal Engine y Cine Tracer, y lleva el resultado a mano a IRIS. El objetivo de F6 es hacer ese trabajo dentro de IRIS:

- montar el set;
- iluminarlo con los aparatos reales y una luz que cuadre con el fotómetro;
- poner la cámara con su sensor, su óptica y su soporte;
- moverse por el set y pilotar la cámara;
- ensayar el movimiento del plano y sacar los fotogramas del storyboard.

Y, cuando haga falta la excelencia de un motor, llevarlo todo a Unreal (con ARRI Luka), a consolas (MVR/GDTF) y a CAD (DXF) **sin perder nada por el camino**.

## Reglas que valen para todo el plan

1. **Un solo modelo.** La planta v2 (`PlanElement` + `props`, `floor_plan_json.dart`) es la única verdad. El 3D, las hojas y las exportaciones salen de `PlanScene3d` (`lib/features/camera_plan/rig/plan_scene3d.dart`). Nada se guarda solo en el 3D.
2. **Paridad total.** Todo tipo que exista en la planta tiene versión 3D, y todo lo que se cambia en 3D vuelve a la planta (`moveBy`, `aimAt` y siguientes). Una prueba lo vigila (F6.0.4).
3. **Compatibilidad hacia atrás.** Lo nuevo viaja como `props` o como `label` nuevos. Una versión anterior de IRIS lo conserva al guardar.
4. **Sin red.** El visor y sus bibliotecas van empaquetados en `assets/viewer3d/`. La única excepción son los packs de la biblioteca (F6.15): se descargan una vez y luego funcionan sin red.
5. **Por dispositivo.**

   | Dispositivo | Qué se hace |
   |---|---|
   | Mac | Todo: editar, pilotar, calidad alta, capturas, exportaciones |
   | iPad | Ver, mover y apuntar, pilotar con el giroscopio o joysticks en pantalla, calidad media |
   | Móvil | Ver y recorrer el set, calidad ligera |
   | PC (Windows, NVIDIA) | Todo lo del Mac, calidad más alta y estación de render con Unreal (F6.19) |

   Cada punto dice en qué dispositivos va.
6. **La luz del 3D es la de IRIS.** Lo que da el fotómetro en la planta lo da el 3D en el mismo punto (F6.3.1).
7. **Cada fase termina en la app de prueba del Mac.** El iPad solo cuando Daniel lo pida.
8. **Todo nace exportable a Unreal.** Cada punto que crea algo nuevo en la escena incluye su correspondencia en Unreal en el mismo PR (contrato del paquete y plugin, F6.16), o enlaza el punto F6.16 que la cubre. Así la compatibilidad no se queda para el final.
9. **Dos puertas al 3D.** El panel 3D de la planta de cámara y luz es el atajo para mirar y retocar. La herramienta completa es **IRIS Stage** (F6.13), la pantalla que hoy se llama «Unreal / Luka bridge».

## Límites honestos: RTX y DLSS

- **RTX y DLSS son de NVIDIA.** Solo existen en Windows (y en parte en Linux) con tarjetas NVIDIA, a través de DirectX o Vulkan. Ni el Mac ni el iPad tienen GPU NVIDIA, así que en IRIS para Mac e iPad no son posibles.
- **«DLSS 6»:** no consta que exista. La última versión conocida al escribir esto es DLSS 4.
- **Un navegador no los expone.** El 3D de IRIS va en un WebView (WebGL o WebGPU). Aunque corriera en un PC con RTX, la API web no da acceso a DLSS ni a los núcleos RT.
- **Lo que sí usa IRIS en Mac e iPad:**
  - **WebGPU** sobre la GPU de Apple (Metal): más luces, mejores sombras y posproceso (F6.0.1b).
  - **Path tracing progresivo** al capturar fotogramas de storyboard: iluminación global, sombras blandas, reflejos y niebla, refinados en unos segundos (F6.10.1b).
- **Lo que quedaría para un renderizador nativo** (fuera de esta fase, F6.17): MetalFX, el reescalado de Apple y lo más parecido a DLSS, y el trazado de rayos por hardware de los chips M3 o posteriores.
- **Dónde sí se usan RTX y DLSS:** en Unreal, en un PC con NVIDIA. Por eso la exportación tiene que ser al 100 % (F6.16). IRIS prepara la escena y Unreal la renderiza con Lumen, ray tracing por hardware y DLSS.
- **Con el PC de NVIDIA de Daniel:** el bloque F6.19 lo aprovecha de tres formas:
  1. IRIS para Windows, con más potencia;
  2. IRIS conectado en vivo a Unreal en el PC, viendo dentro de IRIS (también en el iPad) la imagen renderizada con RTX y DLSS;
  3. a largo plazo, un render RTX propio, solo si las otras dos no bastan.

## Qué emulamos de cada programa

| Función | Unreal Engine | Cine Tracer | En IRIS |
|---|---|---|---|
| Construir el set | Level editor, Modeling | Set Builder | F6.2 |
| Materiales y texturas | Material editor, Megascans | Biblioteca de materiales | F6.2.3 |
| Atrezzo y vehículos | Content Browser | Props | F6.1.5, F6.2.6 |
| Luces con unidades reales | Lux/cd/EV, IES, temperatura | Catálogo de aparatos | F6.3 |
| Grip (banderas, marcos, rebotes) | — | Grip completo | F6.1.7 |
| Soportes de luz | — | C-stand, combo, wind-up | F6.1.6 |
| Cámara de cine | CineCameraActor | Cuerpos y ópticas | F6.4 |
| Soportes de cámara | Camera Rig Rail y Crane | Dolly, grúa, Steadicam, gimbal, dron | F6.5 |
| Actores y poses | MetaHuman, animación | Maniquíes y poses | F6.6 |
| Secuenciador y ensayo | Sequencer | Grabación de movimientos | F6.7 |
| Navegación del visor | WASD, F, marcadores | Primera persona | F6.8 |
| Cámara virtual con tableta | VCam en el iPad | — | F6.8.4 |
| Atmósfera y aspecto | Niebla, volumétricas, LUT | Humo, hora del día | F6.9 |
| Render y salida | Movie Render Queue | Capturas, storyboard | F6.10 |
| DMX, MVR y GDTF | Plugin DMX | — | F6.11.4 |
| Escaneos | Splats, Reality Capture | — | F6.12 |
| Edificios, vías, ciudad | Modeling, PCG | Set Builder | F6.14.1–14.3 |
| Terreno | Landscape | Terreno | F6.14.4 |
| Agua (lago, río, mar) | Water System | — | F6.14.5 |
| Vegetación | Foliage, PCG | Árboles | F6.14.6 |
| Humo y niebla | Height Fog, Local Fog Volume, Niagara | Humo | F6.9 |
| Biblioteca de contenido | Fab, Megascans | Contenido incluido | F6.15 |
| Fixtures con fotometría y DMX | ARRI Luka | — | F6.3, F6.16.12 |
| Ida y vuelta con el motor | Plugin propio, Interchange | — | F6.16 |

---

## F6.0 · Base técnica

**F6.0.1 Visor moderno empaquetado** · Mac, iPad, móvil
- **Qué:** pasar de three.js r147 (UMD) a una versión actual escrita como módulos y empaquetada con esbuild en un único `viewer.js`. El código del visor pasa a módulos (`scene/`, `build/`, `tools/`, `bridge/`) en `tools/viewer3d_src/`, y un script genera `assets/viewer3d/viewer.js`.
- **Por qué:** luces físicas, posproceso (profundidad de campo, bloom, LUT), splats con Spark y mejor rendimiento.
- **Hecho cuando:** el visor actual funciona igual con la versión nueva y el archivo empaquetado ocupa menos de 2 MB.

**F6.0.1b WebGPU primero** · Mac, iPad
- **Qué:** el visor moderno usa WebGPU donde exista (Mac e iPad con el sistema actual) y WebGL 2 si no.
- **Por qué:** más luces reales, sombras de calidad y posproceso sobre la GPU de Apple.
- **Hecho cuando:** el visor dice qué motor usa y la caseta de prueba va igual de bien o mejor que con WebGL.

**F6.0.2 Perfiles de calidad** · todos
- **Qué:** `iris.set({quality: 'high'|'medium'|'low'})`, que Dart elige por plataforma y por el ajuste del usuario. Cada perfil fija cuántas luces reales, la resolución de sombras, el posproceso y el ratio de píxeles.
- **Hecho cuando:** el móvil mantiene 30 fps con la caseta de prueba y el Mac 60 fps.

**F6.0.3 Contrato de escena v2** · todos
- **Qué:** `iris.scene3d` versión 2, con un `kind` por pieza y su `style` (material, color, modelo). Quedan documentados todos los campos. El visor acepta la v1.
- **Hecho cuando:** el contrato está escrito en `docs/scene3d_v2.md` y Dart y JS lo cumplen (prueba que valida el JSON).

**F6.0.4 Prueba de paridad** · —
- **Qué:** una prueba recorre `ElementType`, `PropType`, `ArchitectureType`, `LightType`, los tipos de tramo (`PlanSegment.kind`) y `RigType`. Falla si alguno no produce algo en `PlanScene3d.build` o no tiene representación en el visor (el visor publica su lista de `kind`).
- **Hecho cuando:** la prueba está en verde y un tipo nuevo sin 3D la pone en rojo.

**F6.0.5 Cambios incrementales** · todos
- **Qué:** `iris.patch({upsert: [...], remove: [...]})` para que mover una luz no rehaga la nave. Dart compara con la escena anterior por `id`.
- **Hecho cuando:** arrastrar en la planta con 200 elementos no baja de 30 fps en el 3D del Mac.

**F6.0.6 Deshacer compartido** · todos
- **Qué:** todo cambio hecho en el 3D entra en el historial del editor como un paso (ya pasa al guardar; se revisa para los gestos largos). ⌘Z funciona con el 3D delante.

**F6.0.7 Selección compartida** · todos
- **Qué:** selección múltiple en el 3D (Mayúsculas), resaltado en la planta y al revés, y caja de selección en la vista cenital.

---

## F6.1 · Paridad 2D → 3D (todo lo de la planta, en 3D)

**F6.1.1 Terreno** · todos
- **Qué:** calle con asfalto, bordillo y marcas viales; talud con su altura y su cara; colinas con relieve (`PlanTerrainPainter`, `LightScene.hillStretch`, rugosidad y semilla). Lo que está encima de una colina sube a su cota (`groundM`).
- **Hecho cuando:** una calle con talud y colina se ve igual de proporcionada en planta y en 3D, y una persona sobre la colina queda a la cota correcta.

**F6.1.2 Materiales de pared y suelo** · todos
- **Qué:** texturas generadas por código para cada material de `kWallMaterials` y `kFloorMaterials` (`light/surfaces.dart`), con su reflectancia y su tinte: el color del 3D sale del mismo número que usa el motor de luz.
- **Hecho cuando:** cambiar el material de una pared en el inspector cambia su aspecto en 3D y lo que rebota.

**F6.1.3 Puertas, ventanas, huecos y rejas** · todos
- **Qué:** hoja de puerta abierta a su ángulo (`PlanOpening.leaves`), batientes, puerta doble, ventana con cristal, contraventana maciza, cortina con su tela y su lado, filtros en cristal o en marco, rejas.

**F6.1.4 Recintos y techos** · todos
- **Qué:** los recintos con techo de `PlanRooms` y su altura (`RoomSetting.ceilingM`) se cierran en 3D; el patio queda abierto.

**F6.1.5 Atrezzo de la planta** · todos
- **Qué:** mesa, silla, sofá, cama, vehículo, árbol (copa que filtra la luz), roca, rectángulo genérico con su tamaño y su altura (`LightScene.propSizeM` y `propHeightM`).

**F6.1.5b Atrezzo con medidas y forma** · todos
- **Qué:** todo el atrezzo se edita como una pieza de verdad:
  - forma: rectangular, cuadrada, redonda u ovalada;
  - ancho, fondo y alto en centímetros;
  - giro.
- **Por tipo:**
  - mesa: alto de la tabla (75 cm de comedor, 45 de centro, 110 de barra);
  - silla y taburete: alto del asiento y del respaldo;
  - sofá: plazas (1 a 4), con o sin chaise;
  - cama: individual, de matrimonio o *king*.
- **Asas:** en la planta se estira desde las asas de sus lados, como un truss. En el 3D se ve a sus medidas.
- **Guardado:** las medidas van en `props` (`widthM`, `depthM`, `heightM`, `shape`). Si faltan se usan las de hoy, y una versión anterior de IRIS dibuja la pieza como siempre.
- **Hecho cuando:** una mesa redonda de 120 cm o una rectangular de 180 × 90 se dibujan a escala en la planta, el 3D, el alzado y la hoja A3.

**F6.1.6 Soportes de luz** · todos
- **Qué:** tipos nuevos de soporte en la luz (`props['stand']`), cada uno con altura mínima y máxima, huella y peso de lastre:
  - C-stand;
  - combo stand;
  - wind-up;
  - ceferino (trípode de luz de manivela, como el wind-up);
  - rodante (high roller);
  - baby y junior;
  - mini (low boy).
- **En 3D:** el soporte dibujado a escala bajo el foco.
- **En la planta:** su huella.
- **Altura:** la del foco queda dentro de lo que da el soporte, con aviso si se pasa.
- **Lista de material:** suma soportes y sacos.
- **Hecho cuando:** cambiar el soporte limita la altura en el inspector y aparece en la lista de material.

**F6.1.7 Grip completo** · todos
- **Qué:** bandera, cortador, rebote con su material (`kBounceMaterials`), marco de difusión con su tela, red, gelatina. Cada uno con su tamaño (18×24, 24×36, 4×4, 6×6, 8×8, 12×12, 20×20) y su soporte. En 3D tapan, filtran y rebotan como en el cálculo.

**F6.1.8 Modificadores en el aparato** · todos
- **Qué:** difusión, rejilla, softbox o chimera delante del foco (`light/modifiers.dart`). En 3D se ve el accesorio, y el cono se abre y se suaviza.

**F6.1.9 Personas** · todos
- **Qué:** maniquí con su postura (de pie, sentado o tumbado, `PlanMarks.poseKey`), su altura, el color de su personaje (`actorColor`) y hacia dónde mira. Sus marcas numeradas en el suelo.

**F6.1.9b Sentarse en sillas, sofás y camas** · todos
- **Qué:** al soltar a un actor (o una de sus marcas) sobre una silla, un taburete, un sofá o una cama, se engancha como las luces al truss:
  - toma la postura «sentado» (o «tumbado» en la cama) a la altura de ese asiento;
  - mira hacia donde mira el mueble;
  - en un sofá ocupa la plaza libre más cercana.
- **Al mover el mueble,** la persona se mueve con él. Al apartarla, vuelve a estar de pie.
- **La altura de los ojos** sale del asiento, y la usan el fotómetro, el eje de mirada y la cámara.
- **Guardado:** `props['seat'] = {uid del mueble, plaza}`, como el `rig` de las luces.
- **Hecho cuando:** dos personajes sentados a una mesa salen sentados en planta, 3D, alzado y fotómetro, y siguen la mesa al moverla.

**F6.1.10 Cámaras de la planta** · todos
- **Qué:** cuerpo de cámara con su altura, su eje, el cono de su encuadre y sus marcas con recorrido (`PlanMarks`, `pathPoints`).

**F6.1.11 Imágenes y bocetos** · todos
- **Qué:** el plano o la foto de fondo (`FloorPlanUnderlay`, `plan_images.dart`) en el suelo del 3D a su escala, y los bocetos (`plan_sketch.dart`) como líneas en el suelo.

**F6.1.12 Capas y sets** · todos
- **Qué:** entorno, set, luz y cámara como capas del 3D, que se ocultan igual que en la planta. La zona del set (`SetZone`) se marca en el suelo.

**F6.1.13 Planos secuencia** · todos
- **Qué:** los tramos de `ShotRoute` se ven seguidos, cada uno con su set y su esquema de luz.

---

## F6.2 · Constructor de sets (lo que hace el Set Builder de Cine Tracer)

**F6.2.1 Dibujar en 3D** · Mac, iPad
- **Qué:** las herramientas de la planta (pared, tela, truss, calle, relieve) también en la vista cenital del 3D y sobre el suelo en perspectiva, con imán a los extremos y a la rejilla.

**F6.2.2 Alturas por pared** · todos
- **Qué:** cada pared con su altura propia (`props['heightM']`, ya usado por la nave). Los recintos toman la más baja como techo.

**F6.2.3 Biblioteca de materiales** · todos
- **Qué:** además de los de luz (F6.1.2):
  - ladrillo visto;
  - azulejo;
  - madera de tarima;
  - moqueta;
  - hormigón pulido;
  - chapa;
  - lona a rayas;
  - cristal;
  - espejo;
  - croma verde o azul;
  - ciclorama blanco.

  Cada uno con su reflectancia para el motor de luz. El ciclorama lleva escocia curva.

**F6.2.4 Escaleras, tarimas y desniveles** · Mac, iPad
- **Qué:** tarima con su cota (usa `PlanLevel`), escalera entre cotas y rampa. Las personas y las luces suben con su cota.

**F6.2.5 Repetir y alinear** · Mac
- **Qué:** duplicar en fila o en rejilla (luces en una línea de truss, sillas, mesas), alinear y repartir.

**F6.2.6 Biblioteca de atrezzo ampliada** · todos
- **Qué:** piezas dibujadas por código, con tamaño editable:
  - farola de calle, que alumbra como práctica (tipo nuevo, F6.3.6);
  - semáforo;
  - banco;
  - barra de bar y taburete;
  - mostrador;
  - estantería;
  - puerta de garaje;
  - coche, furgoneta y moto;
  - camión de luces y generador grande;
  - mesa de catering;
  - monitor de vídeo;
  - silla de director.
- **Más adelante:** importar piezas glTF propias a la biblioteca del proyecto.

**F6.2.7 Plantillas de set** · todos
- **Qué:** igual que las plantillas de nave: salón, cocina, bar, oficina, habitación de hotel, coche por dentro (para planos en coche), calle con aceras, plató con ciclorama.


**F6.2.8 Estructura de la nave por separado** · todos
- **Qué:** en la receta de la nave, la estructura de la caseta (pórticos, pilares, cubierta) y la rejilla de truss son opciones independientes:
  - sin rejilla (hoy ya se puede apagar con `grid`);
  - rejilla interior bajo la cubierta (lo de hoy);
  - **rejilla por encima de la cubierta**, sobre su propia estructura (torres de ground support o pórticos exteriores);
  - las dos.
- **Hecho cuando:** una caseta solo con su estructura, y otra con la rejilla por encima del techo, se ven bien en planta, 3D, alzado y hoja A3, y la lista de rigging cuenta lo que toca.

**F6.2.9 Huecos en la cubierta** · todos
- **Qué:** abrir huecos en la lona o el techo, rectangulares o a lo largo de la cumbrera, para iluminar el interior desde los truss de arriba.
- **Efectos:** el hueco corta la cubierta en 3D, deja pasar la luz en el cálculo y sale en la hoja A3.

**F6.2.10 Cómo iluminar la nave: decisión abierta** · todos
- **Qué:** desde dentro, desde arriba por los huecos o a través de la lona. Las tres opciones conviven en la receta para compararlas con el fotómetro y en capturas. Se decide más adelante.

---

## F6.3 · Luz 3D fiel a IRIS (lo que hacen las luces de Unreal, pero con la fotometría de IRIS)

**F6.3.1 Una luz, los mismos números** · todos
- **Qué:** la intensidad de cada luz 3D sale de `PlanLight` (`source.candela`, haz, campo, regulación, modificadores) en unidades físicas. La exposición del visor sale de la cámara (F6.4.6).
- **Hecho cuando:** una prueba compara, en 20 puntos de una escena, los lux de `LightScene.luxAt` con los que mide el visor (fotómetro F6.3.8). Deben quedar dentro de ±1/3 de stop.

**F6.3.2 Forma de la fuente** · todos
- **Qué:**
  - fresnel, PAR, recorte y HMI: luces de foco con su haz y su campo;
  - paneles, tubos y softbox: luces rectangulares con su tamaño real (`PlanLight.sizeKey`), que dan sombra blanda;
  - prácticas y globos: puntuales.

**F6.3.3 Curvas fotométricas** · todos
- **Qué:** con `photometryCurve` o una curva del fabricante, el reparto de luz del foco como un perfil IES. Es lo que usa Unreal para que un fresnel no sea un cono plano.

**F6.3.4 Color de la luz** · todos
- **Qué:** temperatura de color, verde y magenta, y gelatinas LEE/Rosco con su tinte y su transmisión (catálogo de `modifiers.dart`). En el inspector, un selector como el de las mesas de luz.

**F6.3.5 Sol y cielo por hora y lugar** · todos
- **Qué:** el sol desde la fecha, la hora y la posición de la localización (cuando la localización tenga coordenadas), con el cielo, su color y la luz de luna (`PlanAmbient`). Se puede deslizar la hora para ver cómo se mueve la sombra durante la jornada.

**F6.3.6 Prácticas y farolas** · todos
- **Qué:** lámparas de mesa, apliques, neones, pantallas encendidas y farolas como luces con su bombilla y su temperatura, encendidas o apagadas por plano.

**F6.3.7 Mesa de luces** · Mac, iPad
- **Qué:** una lista de todas las luces con regulación, color, encendido y «solo», como la Light Mixer de Unreal o una consola. Al mover un regulador cambian la planta, el 3D y el fotómetro.

**F6.3.8 Fotómetro y falso color** · todos
- **Qué:** tocar un punto (o una cara) da lux, stop a la sensibilidad de la cámara y contraste respecto al tono clave. La vista en falso color usa la escala de exposición de IRIS (`PlanLightMap.exposedBrightness`).

**F6.3.9 Esquemas y estados** · todos
- **Qué:** guardar estados de luz por plano (ya existe `LightOverrides` por plano) y pasar de uno a otro en el 3D, como cues.

**F6.3.10 Unidad y canal DMX** · Mac
- **Qué:** unidad, universo y canal por aparato, para MVR y la consola (F6.11.4).

---

**F6.3.11 Materiales PBR** · todos
- **Qué:** todos los materiales con color, rugosidad, metal, normal y oclusión (de los packs, F6.15). La reflectancia que usa el motor de luz de IRIS se calcula a partir de ellos, para que el cálculo y la imagen coincidan.

---

## F6.4 · La cámara de cine (lo que hace la CineCameraActor de Unreal y la cámara de Cine Tracer)

**F6.4.1 Cuerpo y sensor** · todos
- **Qué:** la cámara del plano toma su cuerpo del equipo del proyecto (`ProjectGear`, `Cameras.sensorWidthMm`) y su modo de grabación de `assets/catalog/phfx_camera_formats.json` (tamaño del área activa, relación de aspecto, círculo de imagen).

**F6.4.2 Ópticas** · todos
- **Qué:** focal de los juegos de ópticas del proyecto (`lensName`, `lenses.json`), esféricas o anamórficas con su factor, T-stop máximo y distancia mínima de enfoque.

**F6.4.3 Encuadre y líneas** · todos
- **Qué:** las líneas de encuadre del Optics Lab (`optics_lab/frame_line_geometry.dart`) dentro del 3D, con zonas seguras, tercios y centro. El encuadre del 3D es el mismo que el de esa pantalla.

**F6.4.4 Posición completa** · todos
- **Qué:** altura del objetivo, inclinación, alabeo (holandés) y giro, como `props` nuevas de la cámara (`tilt`, `roll`). Se editan en el inspector y pilotando (F6.8.3).

**F6.4.5 Foco y profundidad de campo** · Mac (iPad en calidad media)
- **Qué:** distancia de foco (tocar algo para enfocarlo), T-stop y desenfoque real con el círculo de confusión del sensor (`optics_lab/optics_calculator.dart`). Lectura de la profundidad de campo cerca y lejos.

**F6.4.6 Exposición** · todos
- **Qué:** ISO, obturador, fps, ND y T-stop de la cámara (`PlanCameraExposureControls`, `ExposureSettings`) fijan la exposición del 3D. Lo que está sobreexpuesto se quema, como en el monitor.

**F6.4.7 Visor de director** · todos
- **Qué:** elegir focal mirando: un modo que enseña a la vez los encuadres de varias ópticas del juego, como un visor de director o el de Cine Tracer.

**F6.4.8 Monitor** · todos
- **Qué:** la vista de cada cámara en una ventana aparte o en un panel, con el aspecto del monitor de vídeo y sus guías. Varias cámaras a la vez en multicámara.

---

## F6.5 · Soportes de cámara y movimientos (lo que hace Cine Tracer con su grip de cámara)

**F6.5.1 Soportes** · todos
- **Qué:** trípode, hi-hat, mano, hombro, Easyrig, Steadicam, gimbal, slider, dolly sobre vía, grúa (jib), Technocrane, cabeza remota, coche de cámara, dron. Ya existe `stabilization` en la cámara: se convierte en el soporte con su modelo 3D y sus límites (alcance de la grúa, largo de la vía, altura del trípode).

**F6.5.2 Vía de dolly** · Mac, iPad
- **Qué:** dibujar la vía en la planta (recta o curva, con tramos de 1,2 m), poner la dolly en ella y su columna. La cámara solo se mueve sobre la vía.

**F6.5.3 Grúa y Technocrane** · Mac, iPad
- **Qué:** base, brazo con su largo, giro y elevación. La cámara se coloca moviendo el brazo, con aviso si no llega.

**F6.5.4 Movimientos con carácter** · todos
- **Qué:** temblor de cámara en mano, el flote de una Steadicam y la suavidad de un gimbal como patrones aplicados al recorrido.

**F6.5.5 Lista de material de cámara** · todos
- **Qué:** el soporte y sus piezas (tramos de vía, contrapesos, cabezas) suman en la lista de material, igual que el rigging.

---

## F6.6 · Actores (lo que hacen los maniquíes de Cine Tracer y Unreal)

**F6.6.1 Maniquí con proporciones** · todos
- **Qué:** altura del personaje (del reparto, `PlanCast`), complexión y color de vestuario.

**F6.6.2 Biblioteca de poses** · todos
- **Qué:** de pie, andando, sentado, tumbado, apoyado, de rodillas, hablando, mirando el móvil, conduciendo, bailando. Cada pose cambia la altura de los ojos y la silueta.

**F6.6.3 Mirada y eje** · todos
- **Qué:** hacia dónde mira cada personaje y la línea de 180° entre dos personajes. Aviso si una cámara salta el eje.

**F6.6.4 Recorrido con tiempos** · todos
- **Qué:** las marcas del actor con el tiempo de llegada a cada una y si anda o se para. Lo usa el secuenciador (F6.7).

**F6.6.5 Dobles de luz** · todos
- **Qué:** marcar un maniquí como doble de luz para medirle en la cara (fotómetro F6.3.8 a la altura de los ojos).

---

## F6.7 · Secuenciador y ensayo del plano (lo que hacen el Sequencer de Unreal y la grabación de Cine Tracer)

**F6.7.1 Línea de tiempo por plano** · Mac, iPad
- **Qué:** duración del plano en segundos o fotogramas (fps del proyecto), con pistas para la cámara, cada actor y las luces que cambian. Se guarda en el plano (`Shots`), no en la planta.

**F6.7.2 Claves desde las marcas** · todos
- **Qué:** las marcas de cámara y actores ya son claves. Se les da el tiempo y la curva (lineal o suave), y el recorrido entre marcas sigue la trayectoria de la planta.

**F6.7.3 Grabar pilotando** · Mac, iPad
- **Qué:** grabar en tiempo real el movimiento de la cámara mientras se pilota (F6.8.3) o con el iPad como cámara virtual (F6.8.4). Lo grabado se convierte en marcas.

**F6.7.4 Reproducir, ir a un tiempo y repetir** · todos
- **Qué:** reproducir el plano en el 3D, ir a cualquier punto y repetir en bucle. Funciona también en el móvil para enseñar el plano en el set.

**F6.7.5 Cambios de luz en el tiempo** · Mac
- **Qué:** una luz que se enciende, un regulador que baja, una puerta que se abre durante el plano.

**F6.7.6 Plano secuencia** · todos
- **Qué:** reproducir los tramos de `ShotRoute` seguidos, cambiando de set y de esquema de luz en su punto.

**F6.7.7 Tomas** · Mac
- **Qué:** guardar variantes del movimiento (toma 1, toma 2) y compararlas.

---

## F6.8 · Moverse por el set (navegación de Unreal y cámara virtual)

**F6.8.1 Navegación del Mac** · Mac
- **Qué:** como en el visor de Unreal:
  - botón derecho + WASD para volar;
  - Q y E para bajar y subir;
  - la rueda con el botón derecho cambia la velocidad;
  - Mayúsculas para ir rápido;
  - F para encuadrar lo seleccionado;
  - Alt + arrastrar para orbitar;
  - botón central para desplazar.

  Lleva una ayuda de teclas en pantalla.

**F6.8.2 Puntos de vista guardados** · todos
- **Qué:** ⌘1–⌘9 guarda y llama vistas, como los marcadores de Unreal. Se guardan en la planta.

**F6.8.3 Pilotar la cámara** · Mac, iPad
- **Qué:** la vista se convierte en la cámara del plano. Lo que se navega se guarda en su posición, altura, giro, inclinación y alabeo, respetando el soporte (sobre la vía, al alcance de la grúa).

**F6.8.3b Operar a la altura de verdad** · Mac, iPad
- **Qué:** al pilotar, la cámara se queda a la altura de cómo se opera. Estas alturas son de partida y se ajustan con un deslizador fino que también se guarda:

  | Postura | Altura del objetivo |
  |---|---|
  | Al hombro | unos 1,55 m, según la altura del operador del proyecto |
  | De pie en trípode | 1,50–1,70 m |
  | De rodillas | unos 0,95 m |
  | Sentado o en carro | unos 1,10 m |
  | Hi-hat en el suelo | unos 0,25 m |
  | Low mode de gimbal | unos 0,50 m |
  | Grúa o Technocrane | libre, dentro de su alcance |

- **Al moverte,** con WASD o los joysticks, la altura no cambia. Q y E solo funcionan en grúa, dron o «libre».
- **Lo que se guarda:** la postura elegida va en la cámara (`props['operate']`) junto con la altura. Cambia el soporte de la lista de material (hi-hat, trípode, Easyrig) y el icono de la cámara en la planta.
- **Movimiento:** al hombro y en mano llevan el temblor de F6.5.4, que se puede quitar.
- **Hecho cuando:** elegir «De rodillas» deja el objetivo a 0,95 m mientras te mueves por el set, y la altura queda guardada en el plano.

**F6.8.4 El iPad como cámara virtual** · iPad
- **Qué:** con el giroscopio y la cámara del iPad (seguimiento de movimiento), el iPad se mueve por el set como un visor, igual que la app VCam de Unreal. Se graba el movimiento (F6.7.3).

**F6.8.5 Táctil** · iPad, móvil
- **Qué:** órbita con un dedo, pellizco, dos dedos para desplazar, doble toque para ir a un punto, y modo paseo con dos joysticks en pantalla.

**F6.8.6 A la altura de los ojos** · todos
- **Qué:** un modo paseo a 1,65 m que no atraviesa paredes, para recorrer el set como en una localización.

---

## F6.9 · Atmósfera y aspecto

**F6.9.1 Niebla de ambiente** · todos (volumétrica en Mac e iPad)
- **Qué:** niebla global por densidad, altura (niebla baja en un valle o sobre un río) y color.
- **Luz volumétrica:** los haces y el sol se ven a través de ella.
- **Cálculo:** quita contraste y alcance en el cálculo de luz como dato orientativo.
- **Unreal:** ExponentialHeightFog con niebla volumétrica (F6.16.5).

**F6.9.1b Fuentes de humo** · todos (partículas con volumen en Mac e iPad)
- **Qué:** emisores colocados en la planta, con caudal, color, dirección del viento y altura:
  - máquina de humo, hazer y fogger;
  - chimenea;
  - locomotora de vapor, con el humo pegado a su chimenea;
  - hoguera, vapor de alcantarilla, tubo de escape.
- **En 3D:** partículas con volumen. **En la planta:** su símbolo y la mancha por donde se reparte con el viento.
- **Unreal:** sistemas Niagara del plugin con sus parámetros (F6.16.5).

**F6.9.1c Volúmenes locales de niebla** · todos
- **Qué:** cajas o esferas de niebla densa en una zona del set (una habitación ahumada, un túnel).
- **Unreal:** Local Fog Volume.

**F6.9.1d Viento** · todos
- **Qué:** dirección y fuerza en la escena. Mueve el humo, las telas (que ya cuelgan en catenaria), la vegetación y el agua.

**F6.9.2 Aspecto del proyecto** · todos
- **Qué:** la LUT o el aspecto de la biblia visual (`look_bible`) aplicada al visor, con un botón para verlo con y sin LUT.

**F6.9.3 Tiempo** · Mac
- **Qué:** cielo cubierto, atardecer y noche (`SkyCondition`), y lluvia como efecto visual en exterior.

**F6.9.4 Reflejos y brillos** · Mac
- **Qué:** suelos brillantes, cristales y espejos que reflejan, con un aviso de reflejo de cámara o de foco en un espejo.

---

## F6.10 · Render y salida (lo que hace la Movie Render Queue)

**F6.10.1 Captura del encuadre** · todos
- **Qué:** captura a la resolución del formato del plano, con o sin líneas, guardada como fotograma del plano por la misma vía que los renders de Unreal (`unreal_render_import.dart`, nombre `iris_dp_s{escena}_p{plano}.png`).
- **Hecho cuando:** la captura aparece en el storyboard y en la hoja de plano sin pasos manuales.

**F6.10.1b Captura de calidad (path tracing)** · Mac, iPad
- **Qué:** al capturar un fotograma, IRIS lo calcula con trazado de rayos progresivo:
  - iluminación global;
  - sombras blandas reales;
  - reflejos;
  - niebla con luz volumétrica;
  - profundidad de campo de la óptica.
- **Por dispositivo:** en el Mac en segundos; en el iPad en más tiempo y a menos resolución.
- **Hecho cuando:** la imagen se refina en pantalla y se guarda en el plano a la resolución de su formato, con calidad para usarse como referencia de storyboard.

**F6.10.2 Fotogramas clave del movimiento** · todos
- **Qué:** un fotograma por marca, o cada N segundos, para el storyboard de un plano con movimiento.

**F6.10.3 Animática** · Mac
- **Qué:** el plano reproducido como secuencia de imágenes y, si se puede sin dependencias pesadas, como vídeo MP4 (el codificador del sistema por canal nativo).

**F6.10.4 Vistas técnicas** · todos
- **Qué:** planta con los conos de cámara, alzado y perfil (ya existen) y la hoja A3 (`rig_sheet_pdf.dart`) con una vista 3D isométrica añadida.

**F6.10.5 Hoja de plano** · todos
- **Qué:** por plano, el fotograma, la planta, la óptica, la altura, el soporte, el movimiento y la luz, para el PDF diario (`daily_pdf`) y el guion técnico.

---

## F6.11 · Interoperabilidad (llevar y traer sin perder nada)

**F6.11.1 glTF completo** · Mac
- **Qué:**
  - toda la escena con nombres por `uid`;
  - luces `KHR_lights_punctual` con unidades;
  - cámaras glTF con focal y sensor en `extras`;
  - materiales PBR;
  - marcas como nodos vacíos.
- **Hecho cuando:** Blender y Unreal abren el archivo con las cámaras y las luces en su sitio.

**F6.11.2 Unreal y ARRI Luka** · Mac
- **Qué:** pasa al bloque F6.16 (Unreal al 100 %): paquete `.irisstage`, plugin de Unreal y pruebas de ida y vuelta.

**F6.11.3 De Unreal a IRIS** · Mac
- **Qué:** pasa a F6.16.9 (renders de vuelta) y F6.16.10 (cambios de vuelta).

**F6.11.4 MVR y GDTF** · Mac
- **Qué:** fixtures con su GDTF del catálogo cuando lo haya, unidad y DMX (F6.3.10), truss como `Truss`, motores y torres como `Support`, la nave como `SceneObject` (ya hecho). Importar un MVR de una consola o de Vectorworks a la planta.

**F6.11.5 USDZ** · iPad, móvil
- **Qué:** exportar el set a USDZ para verlo en realidad aumentada con AR Quick Look, a escala, en la propia localización.

**F6.11.6 Cine Tracer** · Mac
- **Qué:** Cine Tracer no importa escenas, así que la meta es no necesitarlo. Se mantienen los vínculos (`PlanElementExternalMapping.cinetracerType`) y se exporta la vista cenital, la lista de aparatos y la de piezas para montarlo a mano si hiciera falta.

**F6.11.7 DXF y PDF** · todos
- **Qué:** DXF con todas las capas nuevas (soportes, grip, cámaras con su encuadre). Hoja A3 con cajetín editable (gaffer, localización).

---

## F6.12 · Escaneos y localizaciones

**F6.12.1 Splats de verdad** · Mac, iPad
- **Qué:** gaussian splats (PLY, SPLAT, SPZ) con Spark, sobre el visor moderno de F6.0.1.

**F6.12.2 Recortar y limpiar** · Mac
- **Qué:** caja de recorte y borrador del escaneo, guardados con el escaneo.

**F6.12.3 Del escaneo a la planta** · Mac · **en curso** (`plan/f6-12-escaneos-rodaje`: cenital a escala como fondo de la planta; falta proponer paredes)
- **Qué:** vista cenital y corte a 1 m como fondo de la planta para calcar, y propuesta de paredes detectadas.

**F6.12.4 Luz sobre el escaneo** · Mac · **en curso** (`plan/f6-12-escaneos-rodaje`: con un escaneo, cuatro focos dan sombra y el escaneo la recibe; sin malla simplificada todavía)
- **Qué:** una malla de colisión simplificada del escaneo para que las luces de IRIS lo iluminen y den sombra.

**F6.12.5 Sincronizar escaneos** · todos · **hecho** (`plan/f6-12-escaneos-rodaje`: `PlanScanStore`, como archivo por la nube, hasta 50 MB)
- **Qué:** los escaneos viajan con los medios del proyecto (como las imágenes de la planta) y están en el iPad.

**F6.12.6 Localizaciones con coordenadas** · todos
- **Qué:** cada localización con latitud, longitud y norte, para el sol real (F6.3.5) y para orientar el escaneo.

---

## F6.13 · IRIS Stage (la herramienta 3D completa)

**F6.13.1 Renombrar y reconvertir la pantalla** · todos
- **Qué:** la pantalla «Unreal / Luka bridge» (`luka_export/luka_bridge_screen.dart`) pasa a llamarse **IRIS Stage** en menús, títulos y rutas.
- **Qué es:** deja de ser solo un exportador. Es el espacio 3D del proyecto, con todas las localizaciones, sets, escenas y planos, y con el constructor de mundos (F6.14), luz, cámara, secuenciador y salida.
- **Exportar:** la exportación a Unreal y Luka queda como un apartado dentro (F6.16).
- **Se reaprovecha:** `iris_dp_export_service.dart`, `luka_export_preview.dart`, `luka_compatibility_service.dart` y `luka_fixture_picker.dart`.
- **Hecho cuando:** en la app no queda «Unreal / Luka bridge» y IRIS Stage abre el set del proyecto en 3D.
- **Estado:** hecho (`plan/f6-3d-pc`).
  - La pantalla se llama IRIS Stage (`lib/features/iris_stage/iris_stage_screen.dart`); el identificador interno del destino sigue siendo `lukaBridge` para no romper lo guardado.
  - Arriba, «Unreal en vivo» con un botón, **Abrir en Unreal**, que busca Unreal 5.5 o posterior, crea el proyecto de Unreal del proyecto de IRIS en Documentos\Unreal Projects si no existe, lo prepara, abre Unreal con Pixel Streaming y se conecta.
  - El mismo botón está en el diálogo de Unreal del 3D de la planta. La exportación de archivos para Unreal y LUKA queda debajo.

**F6.13.2 El 3D de la planta como atajo** · todos
- **Qué:** el panel 3D de la planta de cámara y luz (`rig/plan_3d_view.dart`) se queda como vista rápida: mirar, mover, apuntar y ver por la cámara.
- **Salto:** un botón «Abrir en IRIS Stage» lleva a la misma escena con todas las herramientas.

**F6.13.3 Del proyecto a Stage y vuelta** · todos
- **Qué:** desde una escena o un plano (`scenes`, `shots`) se abre IRIS Stage en su set y con su cámara. Desde Stage se vuelve al plano con la captura hecha (F6.10.1).

**F6.13.4 Por dispositivo** · —
- **Mac:** IRIS Stage completo.
- **iPad:** abrir, mirar, pilotar con el giroscopio, retoques ligeros y capturas.
- **Móvil:** ver y recorrer.

---

## F6.14 · Constructor de mundos (cualquier interior o exterior)

Toda pieza tiene su forma 2D en la planta y su 3D, y entra en la prueba de paridad (F6.0.4). Ejemplo guía: una estación de tren de los años 50, primero el mapa 2D y luego el 3D, con su edificio, vías, tren, andenes, árboles y plantas.

**F6.14.1 Edificios por planta y alturas** · Mac, iPad
- **Qué:** se dibuja la huella (como el perímetro de la nave) y se fijan:
  - las plantas y la altura entre ellas;
  - la cubierta: plana, a dos aguas, mansarda o marquesina;
  - el estilo de fachada: ladrillo, piedra, revoco, hierro y cristal;
  - los huecos por fachada y la cornisa.
- **Por dentro:** se puede entrar, tiene suelos por planta (`PlanLevel`) y admite distribución interior con paredes.
- **Base:** se apoya en `HallRecipe` (`rig/plan_hall.dart`), que pasa a ser «Receta de construcción».
- **Unreal:** malla por Interchange con materiales PBR (F6.16.3).

**F6.14.2 Vías de tren** · Mac, iPad
- **Qué:** la vía se dibuja como una curva, con:
  - ancho ibérico o internacional;
  - traviesas y balasto;
  - cambios de agujas;
  - andenes con su altura y bordillo;
  - catenaria opcional.
- **Material móvil:** locomotoras y vagones (vapor de los años 50, diésel, eléctrico, mercancías) se colocan en la vía y se deslizan por ella, como un motor en su truss.
- **Unreal:** spline de vía y mallas del tren (F6.16.3, F6.16.6).

**F6.14.3 Calles y ciudad** · todos
- **Qué:** calle con aceras, bordillo, pasos de cebra, alcorques y adoquín o asfalto según época. Farolas de época (F6.3.6), bancos, quioscos, vallas y señales.

**F6.14.4 Terreno esculpible** · Mac, iPad
- **Qué:** un relieve por rejilla de alturas, con pinceles para subir, bajar, alisar y aplanar, y curvas de nivel en la planta.
- **Lo de hoy:** colinas, montañas y taludes pasan a este relieve. Lo que hay encima se apoya en él (`groundM`).
- **Materiales pintados:** hierba, tierra, roca, arena, nieve y barro.
- **Unreal:** Landscape desde el mapa de altura, con capas de material (F6.16.6).

**F6.14.5 Agua** · todos (reflejos en Mac e iPad)
- **Lago:** un polígono con su nivel.
- **Río:** una curva con ancho, caudal y dirección.
- **Mar:** línea de costa con playa (pendiente de arena), oleaje y espuma en la orilla.
- **En 2D** se dibujan como en un mapa. **En 3D** el agua refleja el cielo y las luces y tiene profundidad y transparencia.
- **Unreal:** Water Body Lake, River y Ocean del plugin Water (F6.16.6).

**F6.14.6 Vegetación** · todos
- **Qué:** árboles y plantas por especie (pino, encina, olivo, chopo, palmera, setos, hierba alta, cañas, flores), uno a uno o esparcidos con pincel por densidad.
- **En la planta:** su símbolo y su copa. **Con la luz:** las copas filtran la luz como el árbol de hoy (`treeTransmission`).
- **Unreal:** instancias de Foliage o PCG (F6.16.6).

**F6.14.7 Cielo y entorno** · todos
- **Qué:** cielo físico con sol y luna (F6.3.5), nubes por cantidad y fondos HDRI de los packs para iluminación y reflejos.
- **Unreal:** SkyAtmosphere, SkyLight y la posición del sol (F6.16.4).

**F6.14.8 Plantillas de mundo** · todos
- **Qué:** estación de tren de los años 50, calle de pueblo, playa con paseo, lago de montaña, bosque, río con puente, nave industrial y plató.
- **Cómo:** cada plantilla es una receta editable, no una escena cerrada.

**F6.14.9 Época** · todos
- **Qué:** un ajuste de época en la escena (años 20, 50, 70, actual) que elige el aspecto de farolas, vehículos, señales y materiales de los packs.

---

## F6.15 · Biblioteca y packs

**F6.15.1 Gestor de packs** · todos
- **Qué:** packs descargables que, una vez bajados, funcionan sin red:
  - Naturaleza;
  - Ciudad;
  - Años 50;
  - Ferrocarril;
  - Plató y cine (grip, soportes, cámaras);
  - Cielos HDRI;
  - Materiales PBR.
- **Cómo:** se guardan en la carpeta de la app, como los escaneos (`rig/scan_store.dart`). Cada pack muestra tamaño, versión y licencia, y se puede borrar.
- **Lo básico va dentro de la app:** formas y materiales generados por código.

**F6.15.2 Fuentes libres** · —
- **Qué:** Poly Haven y ambientCG (CC0) para texturas PBR, HDRI y modelos; Kenney y similares (CC0) para piezas sencillas.
- **Licencia:** cada asset guarda su licencia y su origen en el manifiesto del pack. La hoja de créditos se genera sola.

**F6.15.3 Importar lo propio** · Mac, iPad
- **Qué:** modelos glTF, OBJ o USDZ y texturas propias a la biblioteca del proyecto, con miniatura y medidas.
- **De vuelta:** lo que venga de Unreal o de Sketchfab se reconoce por nombre al volver (F6.16.10).

**F6.15.4 Equivalencias con Unreal** · Mac
- **Qué:** cada asset de pack lleva su equivalente en Unreal (un asset de Fab o Megascans, o contenido de muestra). Al exportar se elige entre el modelo de IRIS y el de Unreal.

---

## F6.16 · Unreal al 100 %

Lo creado en IRIS Stage tiene en Unreal el mismo aspecto, la misma luz, la misma niebla, la misma cámara y los mismos planos. Se consigue con un **paquete de proyecto IRIS** y un **plugin de Unreal** que lo interpreta.

**F6.16.1 Paquete de proyecto IRIS (`.irisstage`)** · Mac
- **Qué:** un zip con:
  - el glTF de cada set;
  - las texturas PBR;
  - los mapas de altura del terreno (PNG de 16 bits);
  - las curvas de agua y vegetación;
  - los perfiles IES de los aparatos;
  - un manifiesto JSON versionado con lo que glTF no cubre: cámaras de cine, secuencias, niebla, humo, DMX, Luka y packs usados.
- **Base:** amplía `IrisDpExportService` y el manifiesto Luka (`luka_manifest_models.dart`).
- **Hecho cuando:** el manifiesto tiene su esquema escrito en `docs/` y una prueba lo valida.

**F6.16.2 Plugin «IRIS Stage for Unreal»** · Mac
- **Qué:** plugin de Unreal 5 en Python con Editor Utility Widgets. Va dentro de la app como recurso y se escribe junto al paquete con instrucciones de instalación. Lee el paquete y monta el nivel.
- **Hecho cuando:** un proyecto de Unreal vacío queda montado en un paso con los sets, las luces, la niebla, las cámaras y los planos.

**F6.16.3 Geometría y materiales** · Mac
- **Qué:** las mallas entran por Interchange (glTF) y los materiales PBR pasan a instancias de material. Si el pack tiene equivalente en Fab o Megascans (F6.15.4), el plugin lo puede sustituir.

**F6.16.4 Luz** · Mac
- **Qué:** cada aparato pasa a la luz de Unreal que corresponde:
  - Spot, Rect o Point;
  - intensidad en candela o lux, con las mismas unidades que IRIS (F6.3.1);
  - temperatura de color, perfil IES, tamaño de la fuente y difusión;
  - canales de luz.
- **Con Luka:** si el aparato tiene fixture de Luka (`luka_light_mapping.dart`), se usa el de Luka con su unidad DMX.
- **Sol y cielo:** DirectionalLight, SkyAtmosphere y SkyLight con la posición del sol (fecha, hora y coordenadas).

**F6.16.5 Niebla y humo** · Mac
- **Qué:**
  - niebla de ambiente a ExponentialHeightFog con niebla volumétrica;
  - volúmenes locales a Local Fog Volume;
  - fuentes de humo a sistemas Niagara del plugin (máquina de humo, chimenea, vapor de locomotora), con sus parámetros de caudal y viento.

**F6.16.6 Terreno, agua y vegetación** · Mac
- **Qué:**
  - relieve a Landscape desde el mapa de altura, con capas de material pintadas;
  - lagos, ríos y mar a Water Body Lake, River y Ocean;
  - vegetación a instancias de Foliage o PCG.

**F6.16.7 Cámaras y planos** · Mac
- **Qué:**
  - cada cámara pasa a una CineCameraActor con filmback (sensor del modo de grabación), óptica, enfoque, apertura y exposición;
  - cada plano pasa a un Level Sequence con sus claves de cámara, actores y luz (F6.7);
  - la escena pasa a una secuencia maestra con los cortes;
  - las líneas de encuadre pasan a un overlay.

**F6.16.8 Actores** · Mac
- **Qué:** el maniquí de Unreal (Manny o Quinn) con la postura y el recorrido de cada personaje.

**F6.16.9 Renders de vuelta** · Mac
- **Qué:** el plugin lanza la Movie Render Queue con los ajustes del plano (resolución del formato, DLSS si hay RTX) y nombra los fotogramas como espera IRIS (`iris_dp_s{escena}_p{plano}.png`, `unreal_render_import.dart`). IRIS los importa al storyboard.

**F6.16.10 Cambios de vuelta a IRIS** · Mac
- **Qué:** el plugin exporta un JSON de diferencias (cámaras movidas, luces cambiadas, piezas añadidas) que IRIS aplica a la planta, con una lista para aceptar o rechazar cada cambio.

**F6.16.11 Pruebas de ida y vuelta** · Mac
- **Qué:** una escena de referencia (estación de los 50 con niebla, sol de tarde y un plano con dolly) se exporta y se monta en Unreal. Se comparan:
  - las posiciones (±1 cm);
  - la cámara (focal, sensor, enfoque);
  - la intensidad de luz (±1/3 de stop con un fotómetro virtual a los dos lados);
  - la niebla.
- **Registro:** una lista de comprobación en `docs/` recoge el resultado de cada versión.

**F6.16.12 Sustituir a ARRI Luka** · Mac, iPad
- **Qué:** lo que hoy se hace en Unreal con Luka (fixtures con fotometría, DMX y control desde consola) se hace en IRIS Stage, con el catálogo de fixtures, la mesa de luces (F6.3.7) y el DMX (F6.3.10).
- **Luka:** queda como destino compatible. Si un aparato tiene fixture de Luka, el paquete lo lleva.

---

## F6.17 · Opciones futuras de render (solo estudio, fuera de esta fase)

**F6.17.1 Renderizador nativo en Metal para el Mac**
- Trazado de rayos por hardware (M3 o posterior) y MetalFX.

**F6.17.2 IRIS para Windows con RTX**
- Pasa al bloque F6.19, que lo aborda por pasos: primero la app en Windows (F6.19.1), luego la conexión en vivo con Unreal (F6.19.3–19.5) y, solo si hace falta, un render nativo (F6.19.7).

**F6.17.3 Render remoto**
- Render en la nube o en el PC de Unreal lanzado desde IRIS (F6.16.9).

**F6.17.4 Viabilidad**
- Estudio de las tres opciones (coste, plataformas, mantenimiento) antes de decidir nada.

---

## F6.18 · Platós

**F6.18.1 Localización de tipo plató** · todos
- **Qué:** en `locations`, el tipo «plató» con su ficha:
  - medidas útiles y altura libre;
  - parrilla: sí o no, su altura, su retícula, carga por punto, motorizada o fija;
  - ciclorama: sí o no, y sus lados;
  - puertas de carga y su tamaño;
  - suelo pintable o no;
  - insonorización y climatización.
- **Al crear la planta** de una localización plató, IRIS la reconoce y monta la base sola con la receta de construcción: techo plano, parrilla como rejilla de truss y ciclorama.
- **Hecho cuando:** crear la planta de un plató con parrilla a 7 m deja la parrilla, el ciclorama y las tomas colocados.

**F6.18.2 Tomas de corriente** · todos
- **Qué:** un tipo nuevo de elemento, «toma de corriente», con:
  - conector: Schuko 16 A, CEE 16 A y 32 A mono o tri, CEE 63 A y 125 A, Powerlock;
  - fases y amperios;
  - situación en pared, en la parrilla o en una caja de suelo.
- **Plantilla:** la del plató las coloca según su ficha.

**F6.18.3 Reparto de corriente** · Mac, iPad
- **Qué:** cada luz se conecta a una toma o a un generador, con su tirada de cable y su caja de distribución.
- **Avisos:** IRIS suma por toma y por fase y avisa de sobrecarga y desequilibrio. Lleva `GearList.powerLines()` a cada circuito.
- **Salida:** lista de cable y material eléctrico, y una hoja de corriente en PDF.

**F6.18.4 Zonas de logística** · todos
- **Qué:** vestuarios, maquillaje, zona de cámara, catering y parking de camiones como zonas marcadas en la planta del plató.

---

## F6.19 · Trabajar con el PC de NVIDIA (RTX y DLSS)

Daniel tiene también un PC con tarjeta NVIDIA. El objetivo es que la calidad RTX y DLSS llegue a IRIS sin escribir un motor de render propio: el PC hace de **estación de render**, y IRIS (Mac, iPad o el propio PC) sigue siendo donde se trabaja.

**F6.19.1 IRIS para Windows** · PC
- **Qué:** compilar y publicar IRIS en Windows (ya existe `windows/runner`). El WebView de Windows es WebView2 (Chromium), con WebGPU sobre la tarjeta NVIDIA, y `flutter_inappwebview` ya lo soporta.
- **Lo que gana:** el perfil de calidad «ultra», más luces reales, sombras más finas y el path tracing de las capturas (F6.10.1b) mucho más rápido.
- **Lo que no gana:** DLSS y los núcleos RT, porque el navegador no los expone.
- **Hay que comprobar:** que todas las dependencias de IRIS compilan en Windows (base de datos, PDF, selector de archivos, actualizaciones) y cómo se instala y se actualiza ahí.
- **Hecho cuando:** IRIS abre en el PC un proyecto sincronizado y IRIS Stage funciona con la caseta de prueba.

**F6.19.2 El mismo proyecto en Mac, iPad y PC** · todos
- **Qué:** la sincronización con la nube que ya existe lleva también lo nuevo del 3D: recetas, escaneos (F6.12.5), packs usados (cada máquina los descarga) y capturas.
- **Hecho cuando:** un cambio hecho en el iPad aparece en el PC, y al revés.

**F6.19.3 IRIS Live Link con Unreal** · Mac, iPad y PC (Unreal en el PC)
- **Qué:** una conexión en vivo entre IRIS y Unreal, abierto en el PC con el plugin de F6.16.2. Cada cambio en la planta o en IRIS Stage (mover una luz, regularla, cambiar la niebla, mover la cámara, cambiar de plano) se aplica en Unreal al momento.
- **Cómo:** la Remote Control API de Unreal (WebSocket) y los mismos cambios incrementales que usa el visor (`iris.patch`, F6.0.5), traducidos por el plugin.
- **Red:** solo red local, con un código de emparejamiento que muestra el PC. Nada pasa por internet.
- **Hecho cuando:** mover un foco en el iPad lo mueve en Unreal en menos de medio segundo.

**F6.19.4 Ver el render RTX dentro de IRIS** · Mac, iPad y PC
- **Qué:** una ventana «Render RTX» en IRIS Stage y en el panel 3D que enseña la imagen de la cámara del plano renderizada en el PC con Lumen, ray tracing por hardware y DLSS.
- **Cómo:** Pixel Streaming de Unreal (vídeo por WebRTC), que el WebView de IRIS reproduce.
- **Uso:** se compone y se ilumina en IRIS, y se mira el resultado con calidad de motor en el iPad, en el set.
- **Hecho cuando:** en el iPad se ve el plano renderizado en el PC a 30 fps con DLSS, y los cambios hechos en IRIS se reflejan.

**F6.19.5 Capturas RTX al storyboard** · Mac, iPad y PC
- **Qué:** desde IRIS, «Capturar con RTX» pide al PC un fotograma del plano, con la Movie Render Queue o el path tracer de Unreal, y lo guarda en el plano como cualquier captura (F6.10.1, F6.16.9).
- **Cola:** se pueden mandar todos los planos de una escena y recibirlos mientras se trabaja en otra cosa.

**F6.19.6 Estación de render compartida** · PC
- **Qué:** el PC se registra como estación de render del proyecto. Cualquier dispositivo de Daniel en la misma red la encuentra, ve si está libre y le manda trabajo.
- **Para después:** acceso remoto fuera de la red local, por un túnel seguro.

**F6.19.7 Render RTX propio en IRIS para Windows (solo estudio)** · PC
- **Qué:** si Live Link y Pixel Streaming no bastan, un renderizador nativo dentro de IRIS para Windows: Vulkan con ray tracing y DLSS mediante el SDK Streamline de NVIDIA, como plugin de Flutter que comparte la textura con la interfaz.
- **Coste:** muy alto (un motor propio que mantener). Se decide solo con datos de F6.19.3–19.5 en uso real.

**F6.19.8 Rendimiento con NVIDIA** · PC
- **Qué:** medir fotogramas por segundo del visor de IRIS y de Pixel Streaming, la latencia de Live Link y el tiempo de una captura RTX en el PC. Sale de PC.5.2.

**Recomendación:** F6.19.3 a F6.19.5 dan la calidad RTX y DLSS en IRIS, también en el iPad, aprovechando Unreal en lugar de reescribirlo. F6.19.1 suma un IRIS más potente en el PC. F6.19.7 queda como último recurso.

### F6.19 · Estado y orden de trabajo (2026-10-26)

**F6.19.1 IRIS para Windows:** compila e instala (PR #49). Lo pendiente del PC que no es 3D se aplaza (ver `PLAN_IRIS_PC.md`).

**El PC de Daniel:**
- RTX 3060 Ti.
- Unreal 5.5 en `C:\Program Files\Epic Games\UE_5.5`, con los plugins RemoteControl, RemoteControlWebInterface, PixelStreaming y PixelStreaming2, y LiveLinkCamera. También RealityCapture.
- DLSS no viene con el motor: es un plugin aparte de NVIDIA.

**Orden acordado con Daniel** (un PR por paso):
1. **Plugin de Unreal y puente en vivo IRIS → Unreal** (F6.16.2 y F6.19.3): luces (posición, intensidad y temperatura), sol y niebla, en menos de 0,5 s. Por la Remote Control API (puertos 30010 y 30020), solo en red local.
   - **Estado:** hecho, salvo la niebla (`plan/f6-3d-pc`). Está en `tools/unreal/iris_stage` y `lib/features/unreal_link/`. Probado con Unreal 5.5 en el PC: unos 40 ms la escena entera y unos 10 ms cada cambio. La niebla espera a F6.9.1, porque la planta aún no la tiene.
2. **Vuelta Unreal → IRIS** (F6.16.10): IRIS consulta Remote Control cada pocos instantes, así que no hace falta un servidor en el iPad.
   - **Estado:** hecho (`plan/f6-3d-pc`). IRIS consulta `Snapshot()` cada 0,5 s. Lo que se mueve, gira, regula o cambia de color en Unreal (focos y cámaras) vuelve a la planta y se guarda. Probado con Unreal 5.5: no rebota.
   - **Diferencias con la ficha original:** se aplica directamente, sin la lista para aceptar o rechazar, que queda para el paquete `.irisstage`. Borrar en Unreal no borra en IRIS. El sol de Unreal no vuelve todavía.
3. **Ventana «Render RTX»** (F6.19.4): Pixel Streaming dentro del WebView de IRIS.
   - **Estado:** hecho (`plan/f6-3d-pc`). Pixel Streaming 2 emite el visor del editor (`Abrir con IRIS Stage.bat`), e IRIS lo muestra sin la interfaz del reproductor. Las cámaras de la planta pasan a Unreal como CineCameraActor, y «Ver por la cámara» pone el visor en una de ellas. Probado con Unreal 5.5 en el PC.
4. **«Capturar con RTX»** (F6.19.5 y F6.16.9): los fotogramas van al storyboard con el nombre `iris_dp_s{escena}_p{plano}.png` (`unreal_render_import.dart`).
   - **Estado:** hecho (`plan/f6-3d-pc`). `Capture()` hace una foto en alta (1920 × 1080) por la cámara elegida, y IRIS la guarda en el storyboard del plano por `importShotReferenceImage`, como un render de Unreal. Probado con Unreal 5.5: unos 17 s la primera vez y menos de 2 s las siguientes.
   - **Para después:** la cola de todos los planos de una escena y la Movie Render Queue o el path tracer para la calidad final.
5. **Assets gratuitos de Fab y Megascans** (F6.15.4): **por licencia, solo se usan dentro de Unreal.** No se copian al visor de IRIS: se ven por Pixel Streaming, y en la planta y el visor queda un sustituto con las mismas medidas.
   - **Estado:** hecho (`plan/f6-3d-pc`).
     - El atrezzo con cuerpo pasa a Unreal: mesa, silla, sofá, cama, árbol, roca, vehículo y pieza genérica.
     - Desde el 3D de IRIS se busca una malla del proyecto de Unreal (`FindAssets`) y se asigna a la pieza (`props['unrealAsset']`), que toma sus medidas.
     - Sin asset, va un bloque con las medidas.
     - Mover o girar la pieza en Unreal vuelve a la planta.

**F6.19.9 Un mundo por set** · Mac, iPad y PC (Unreal en el PC)
- **Qué:** cada set de rodaje es un nivel propio de Unreal (`/Game/IRIS/<localización>/<set>_set<id>`), y el plano maestro de una localización otro. Las escenas y los planos de un set comparten su nivel; lo propio de cada plano se aplica al abrir su planta.
- **Cómo:** al cambiar de set en IRIS, Unreal guarda el nivel de IRIS abierto y abre o crea el del nuevo set. Un nivel ajeno con cambios sin guardar no se cierra: IRIS avisa.
- **Por qué así:**
  - Con un mundo por escena, cada escena del mismo set lo duplicaría y un cambio de decorado no llegaría a las demás.
  - Con un mundo único, las luces de sets distintos se mezclarían.
- **Más adelante:** unir en un nivel con World Partition o niveles en streaming los sets de una misma localización (una casa con cocina y salón), y la secuencia de cada escena dentro de su nivel (F6.16.7).
- **Estado:** hecho (`plan/f6-3d-pc`). Probado con Unreal 5.5: crea, guarda y vuelve a abrir el nivel de cada set.

**Ya existe:** `lib/features/luka_export/` (`iris_dp_export_service`, `luka_light_mapping`, `unreal_coords`, `unreal_render_import`, `luka_bridge_screen`) y `tools/unreal/iris_dp_import.py`, que importa en un solo sentido.

---

## F6.20 · Identidad de cada elemento, assets de Unreal y escaneos (base de IRIS Stage)

Plan aprobado por Daniel el 2026-10-27. Un PR por fase, en ramas que salen de `plan/f6-3d-pc`.

| Fase | Qué | Estado |
|---|---|---|
| A1 | `uid` estable para todos los elementos (al cargar se guarda una vez; las copias estrenan el suyo y rehacen sus referencias) | en curso (PR 1) |
| A2 | Nombre libre (`props['name']`) para cualquier elemento, en la ficha 2D y en el 3D, y que llegue a Unreal | en curso (PR 1) |
| A5 | Atrezzo visible en el visor 3D (formas por tipo, a sus medidas, seleccionable y movible), etiquetas con el nombre («Nombres»; la del seleccionado, siempre) y color por categoría (`PlanCategory`, el mismo para 2D y 3D) | en curso (PR 2) |
| A3–A4 | Planta 2D: «Colorear por tipo» (halo o franja del color de su categoría, y leyenda de los tipos presentes), «Nombres» (etiqueta encima de cada elemento), distintivo «UE»; lista de elementos agrupada por categoría, con buscador, «UE» y ojo para ocultar. En el 3D, etiquetas de tamaño fijo en pantalla y nombres largos recortados | en curso (PR 3) |
| B1–B2 | Un solo modelo `props['unreal']` (`UnrealAssetRef`; lee también `unrealAsset` y un `unrealMeshPath` propio) y asset para cualquier elemento: el cuerpo de focos y cámaras unido a ellos, el atrezzo, y paredes, actores, grip y rigging en la lista `assets`. Selector en la ficha 2D y en el 3D; `FindAssets` busca mallas, Blueprints y personajes, con su origen | en curso (PR 4) |
| B3–B4 | Miniaturas que renderiza Unreal (`AssetPreview`: cenital ortográfica con transparencia y 3/4, PNG de 512 px, lejos del set y con luces propias) guardadas con `UnrealThumbStore` (#56, viajan por la nube); «Vista de assets» en la planta (la cenital a escala y girada), cartel con la 3/4 en el 3D y miniatura en la ficha | en curso (PR 5) |
| B5 | Biblioteca de Unreal (`UnrealLibrary`): lo usado y lo encontrado, con miniatura, origen y medidas; favoritos; búsqueda sin Unreal; «Buscar en Unreal» y «Hacer las miniaturas que faltan»; «Poner en la planta» crea el elemento del tipo que dice el nombre (o un actor si es un personaje) con medidas y asset. Viaja con `user_settings`. En IRIS Stage y en la barra de la planta | en curso (PR 6) |
| C1–C4 | IRIS Stage como lista de seis pasos, tutorial y guía | en curso (`plan/pulido-rodaje`): la guía de seis pasos con su estado y botón (`unreal_stage_steps.dart`) y quitar de la biblioteca con constancia. Falta la miniatura del esquema de luz con colores y nombres |
| D1–D4 | Buscar en Fab y Quixel desde IRIS, recogida automática, tejidos y packs de partida | en curso (`plan/f6-20-d-fab-quixel`): D1 «Buscar en Fab» y «Megascans» abren la búsqueda en el navegador (Fab no tiene API pública); D2 `FindFabAssets` recoge lo bajado a `/Game/Fab` y `/Game/Megascans` al abrir la biblioteca, al volver a IRIS y con «Recoger de Fab»; D4 «Packs de partida» (búsquedas para vestir un set). Falta D3: tejidos y superficies de Fab en paredes y suelo |
| E1–E5 | RealityScan/RealityCapture sin interfaz: de vídeo a malla, ortofoto y paredes propuestas, con ida y vuelta | en curso: el escaneo exportado (GLB/OBJ) se importa, viaja por la nube, da la cenital de fondo, recibe sombras y llega a Unreal (`scans` en IRIS Stage, importado a `/Game/IRIS/Scans`). Falta la captura sin interfaz y las paredes propuestas |

## F6.21 · Ensayos de luz fieles en IRIS y en Unreal

Pedido por Daniel el 2026-10-31. Objetivo: que un esquema de luz ensayado en IRIS se vea y se mida igual en Unreal, con el set, la luz y la atmósfera a escala, para que el ensayo sirva de verdad en el rodaje.

### Lo que hay hoy (revisado el 2026-10-31)

- **Lo que llega a Unreal:**
  - focos, cámaras, sol y cielo, escaneos y lo que tiene asset;
  - el atrezzo sin asset llega como un bloque cuadrado: ancho = fondo = `LightScene.propSizeM`, más su alto (`iris_stage_link.py`, `_apply_prop`);
  - **las paredes, puertas, ventanas, telas, pilares, truss y la nave no llegan** si no tienen asset de Unreal. Por eso el set no se ve con sus proporciones.
- **Intensidad:** Unreal recibe las candelas de IRIS (`source.cd`, con regulación, difusiones y gelatinas) en unidades de candela. Pero:
  - Unreal tiene la **autoexposición** activa, y la autoexposición iguala los niveles: un foco al 50 % se ve casi como al 100 %;
  - el **visor 3D de IRIS no usa las candelas**: su intensidad es `0.6 + vatios/1600` (`viewer.js`), así que la regulación no se nota en el 3D.
- **Altura e inclinación:**
  - la altura existe para todos los focos (`PlanLight.heightKey`, 3 m por defecto);
  - la **inclinación** solo existe para los colgados del techo (`tiltKey`, de 0 a 80° desde la vertical);
  - los de trípode apuntan siempre unos 8,5° hacia abajo (`plan_scene3d.dart`, `dz = -0.15`);
  - el paneo es el giro en planta;
  - desde Unreal vuelven la altura y la dirección (`unreal_return.dart`, `aimAt`), pero en un trípode la inclinación se pierde.
- **Entorno y niebla:**
  - cada set es un nivel de Unreal (`/Game/IRIS/<localización>/<set>`), con suelo, sol y cielo físico si hay sol;
  - no se elige si es plató o exterior;
  - la niebla está pendiente (F6.9.1).

### F6.21.1 · Tipo de entorno al crear el set · todos

- **Qué:**
  - al crear un set (o en su ficha), y en el diálogo «Abrir en Unreal», se elige **Plató** o **Exterior (naturaleza)**;
  - después se puede cambiar; se guarda en el set (`props` de la planta del set) y viaja con el proyecto.
- **Plató:**
  - sin sol ni cielo, el ciclorama o las paredes del plató (F6.18) y el suelo neutro;
  - SkyLight a 0 y la exposición fija de F6.21.4: solo alumbran los focos.
- **Exterior:**
  - SkyAtmosphere, sol de la posición y la hora reales (F6.3.5), SkyLight;
  - suelo de terreno (hierba, tierra, asfalto) con su reflectancia;
  - nubes volumétricas opcionales.
- **En IRIS:** el visor 3D aplica lo mismo (fondo negro o gris en plató; cielo y sol fuera) y el motor de luz quita el cielo y el sol en plató.
- **Hecho cuando:** crear un set de plató y otro de exterior y abrir los dos en Unreal da dos niveles distintos, y la lectura del fotómetro en plató solo depende de los focos.

### F6.21.2 · Niebla y humo, con cantidad · todos (cierra F6.9.1 y F6.9.1b)

- **Qué:**
  - en el esquema de luz, un control **«Niebla»** de 0 a 100 %, más el tipo:
    - bruma de ambiente (*haze*);
    - humo (más denso, cerca del suelo);
    - niebla exterior (por distancia);
  - se guarda en el esquema de luz, porque cada esquema puede llevar su humo.
- **En Unreal:**
  - ExponentialHeightFog con niebla volumétrica;
  - el humo es un LocalFogVolume a la altura indicada;
  - los focos dan **haces visibles** (`volumetric_scattering_intensity`) que crecen con la niebla.
- **En IRIS:** niebla en el visor (FogExp2, con los conos de luz más o menos visibles) y aviso en el fotómetro de la pérdida de luz por la bruma, si se activa.
- **Hecho cuando:** subir la niebla en IRIS espesa la escena y los haces en IRIS y en Unreal a la vez, y 0 % la quita.

### F6.21.3 · El set a escala en Unreal: paredes, aberturas y atrezzo con sus medidas · todos

- **Qué:**
  - **todo** lo de la planta llega a Unreal con su geometría real, aunque no tenga asset:
    - paredes con su largo, grosor y alto, y sus huecos de puerta y ventana;
    - suelo y techos de los recintos (`PlanRooms`);
    - telas, pilares, truss y la nave;
  - el atrezzo sin asset llega con **ancho, fondo y alto** propios (F6.1.5b: `widthM`, `depthM`, `heightM`, forma), no como un cubo cuadrado.
- **Cómo:**
  - el visor ya construye toda esa geometría (la exporta como glTF para el MVR: `iris.exportGlb({structure: true})`);
  - IRIS manda esa estructura a Unreal como malla (importada como los escaneos, a `/Game/IRIS/Sets/…`), se rehace solo cuando cambia la estructura (no al mover un foco) y lleva los materiales de pared y suelo (`kWallMaterials`, `kFloorMaterials`) con su color y reflectancia;
  - lo que tiene asset de Unreal sigue sustituyendo a su pieza.
- **Hecho cuando:** una habitación de 4 × 3 m con una puerta y una ventana mide en Unreal lo mismo que en la planta (comprobado con la regla de Unreal), y una mesa de 160 × 90 × 75 cm llega con esas medidas.

### F6.21.4 · La luz con la misma intensidad en IRIS y en Unreal · todos

**Estado:** en curso (`plan/pulido-rodaje`).
- **Hecho:**
  - la escena lleva la exposición de la cámara del plano: ISO, obturador, ND y diafragma de trabajo, con su EV100 (`PlanScene3d.exposureOf`);
  - Unreal pone un PostProcessVolume del nivel con exposición manual y cámara física, sin viñeta, y activa `ExtendDefaultLuminanceRange`;
  - el visor de IRIS, con «Luz real», usa candelas y lux con la misma escala que el fotómetro; sin luces encendidas, o con «Luz de trabajo», se ve como antes.
- **Falta:**
  - la comparación de lux IRIS/Unreal en un punto. Necesita calibrar la captura HDR de Unreal en el PC, y no se hace a ciegas para no dar números falsos;
  - el visor solo enciende 14 focos de verdad.

- **Qué:**
  - el **porcentaje de regulación** (y las difusiones, las gelatinas y la distancia) da la misma luz en el fotómetro de IRIS, en el visor 3D de IRIS y en Unreal.
- **Unreal:**
  - **exposición fija**: un PostProcessVolume del set con exposición manual, calculada con la cámara de IRIS (ISO, diafragma T, obturador, `exposure.dart`), y sin autoexposición, sin *bloom* exagerado ni oscurecimiento de bordes;
  - los focos siguen en candelas, con el cono interior y exterior ajustados al haz y al campo de IRIS, y con un radio de alcance que no corte la luz;
  - los paneles (RectLight) y los fresnel (SpotLight) con el tamaño de su fuente, para que la sombra sea igual de dura o suave;
  - el sol en lux y el cielo en cd/m² con las unidades físicas de Unreal.
- **Visor de IRIS:** las luces del 3D pasan a unidades físicas (candelas) con la misma exposición, en vez de la fórmula por vatios. El 50 % se ve como el 50 %.
- **Comprobación:**
  - IRIS manda a Unreal un **punto de medida** por cada lectura del fotómetro, y Unreal devuelve los lux que calcula ahí, con una sonda de iluminación en ese punto;
  - IRIS los enseña junto a los suyos: «IRIS 820 lx · Unreal 790 lx».
- **Hecho cuando:**
  - un foco al 100 % y al 50 % da en Unreal la mitad de lux en el mismo punto, con menos de un 10 % de diferencia con IRIS;
  - la imagen de Unreal a la exposición de la cámara del plano se ve como dice el fotómetro: medio stop por debajo se ve medio stop más oscura.

### F6.21.5 · Altura, paneo e inclinación de los focos, en IRIS y en Unreal · todos

**Estado:** en curso (`plan/pulido-rodaje`).
- **Hecho:**
  - `PlanLight.tiltDegKey` / `elevationOf` / `setElevation`, que leen lo de antes;
  - altura, paneo e inclinación de −90 a +90 en la ficha 2D y en el panel 3D, para cualquier montaje;
  - el 3D y Unreal apuntan con la inclinación; desde Unreal vuelven la altura y la inclinación (`aimAt`);
  - el fotómetro calcula en 3D un trípode con altura o inclinación propias;
  - el alzado dibuja el ángulo.
- **Falta:**
  - arrastrar la altura en el alzado y en el 3D;
  - el haz de la planta 2D, que no se acorta con la inclinación;
  - el *roll* de los paneles.

- **Qué:**
  - cada foco, sea de techo, de trípode o de suelo, tiene:
    - **altura** (de 0 a 12 m, o hasta el techo o la parrilla si cuelga);
    - **paneo** horizontal (de 0 a 360°, el giro en planta);
    - **inclinación** vertical, de −90° (apunta al suelo) a +90° (apunta arriba);
    - opcionalmente **giro sobre su eje** (*roll*) para los paneles.
  - Hoy los de trípode van fijos a −8,5°; el valor nuevo se guarda en `props['tiltDeg']`. Los colgados de antes (`tilt` desde la vertical) se leen con su ángulo equivalente.
- **En la planta:**
  - en la ficha del foco: altura, paneo e inclinación con deslizadores y número;
  - en la planta: el haz dibujado se acorta con la inclinación;
  - en el alzado (`plan_elevation_screen`): el foco se ve a su altura, con su ángulo, y se arrastra.
- **En el 3D de IRIS:** las asas de apuntar (`aimAt`) cambian también la inclinación de los de trípode, y la altura se sube y baja arrastrando.
- **En Unreal:**
  - mover, subir o girar el foco en el editor (pitch y yaw) vuelve a IRIS con su altura, paneo e inclinación;
  - el *roll* vuelve en los paneles.
- **Motor de luz:** el fotómetro y el mapa de luz usan la dirección real del haz con su inclinación, también en los de trípode.
- **Hecho cuando:**
  - subir un foco de trípode a 2,5 m e inclinarlo −30° en IRIS lo deja igual en Unreal;
  - inclinarlo a −45° en Unreal lo deja a −45° en la ficha de IRIS;
  - el fotómetro cambia con el ángulo.

### Orden propuesto

1. **F6.21.5 · altura e inclinación:** es la base para apuntar bien y la más pedida para ensayar.
2. **F6.21.4 · intensidad igual:** exposición fija en Unreal, el visor en candelas y la comprobación de lux.
3. **F6.21.3 · el set a escala**, empezando por paredes y atrezzo con medidas.
4. **F6.21.1 · plató o exterior.**
5. **F6.21.2 · niebla y humo.**

Cada punto con su prueba de Dart (contrato del paquete y conversión de unidades), y su prueba en el PC con Unreal 5.5 en `docs/PRUEBA_IRIS_STAGE.md`.

## Orden propuesto y dependencias

0. **F6.21** (ensayos de luz fieles, pedido el 2026-10-31): va antes que el resto, en su propio orden.
1. **F6.0** (con 0.1b WebGPU), **F6.13.1–13.2** (IRIS Stage como contenedor) y **F6.16.1** (paquete versionado desde el principio, para que cada pieza nueva nazca exportable).
2. **F6.1:** paridad (1.5b, 1.9b, 1.6, 1.7, 1.1, 1.2), **F6.2.8–2.10** (caseta) y **F6.18.1–18.2** (plató y tomas).
3. **F6.4** y **F6.8** (cámara y pilotar, con 8.3b) y **F6.10.1–10.2** (capturas). Es lo que sustituye a Cine Tracer para componer.
4. **F6.15** (packs) y **F6.14** (mundos: edificios, vías, terreno, agua, vegetación y plantillas).
5. **F6.3** (luz fiel, materiales PBR), **F6.9** (niebla y humo) y **F6.10.1b** (captura de calidad).
6. **F6.6** y **F6.7** (actores y secuenciador) y **F6.5** (soportes de cámara).
7. **F6.16.2–16.12** (plugin de Unreal e ida y vuelta), **F6.19.3–19.5** (Live Link, render RTX en IRIS y capturas RTX), **F6.11** (resto de formatos), **F6.12** (escaneos) y **F6.18.3–18.4** (corriente y logística).
7b. **F6.19.1–19.2** (IRIS para Windows y sincronización con el PC) en paralelo a cualquier fase, cuando convenga probar en el PC.
8. **F6.17** solo como estudio.

Dependencias principales:

| Punto | Necesita |
|---|---|
| F6.3.1 | F6.0.1 (luces físicas) |
| F6.4.5 | F6.0.1 (posproceso) |
| F6.12.1 | F6.0.1 |
| F6.7 | F6.6.4 y F6.4.4 |
| F6.16.7 | F6.7 (claves) y F6.4 (cámaras) |
| F6.10.1b | F6.0.1b (WebGPU) y F6.3.11 (materiales PBR) |
| F6.14 | F6.15.1 (packs) y F6.0.3 (contrato v2) |
| F6.16.2–16.12 | F6.16.1 (paquete) |
| F6.18.1 | F6.2.8 (receta con parrilla) |
| F6.19.3 | F6.16.2 (plugin) y F6.0.5 (cambios incrementales) |
| F6.19.4–19.5 | F6.19.3 |
| F6.8.4 | F6.8.3 |

## Verificación común a todos los puntos

- Pruebas Dart en `test/camera_plan_rig_test.dart` (o un archivo nuevo por fase) para el modelo y la conversión.
- Prueba de paridad (F6.0.4) y prueba de equivalencia de lux (F6.3.1).
- Escena de prueba en el navegador interno del visor antes de compilar.
- `flutter build macos --debug` y prueba de Daniel en la app de prueba, en una planta de usar y tirar.
- Formatear solo archivos nuevos: `dart format` reescribe enteros los existentes.

## Hecho hasta ahora (F4 y F5)

| Bloque | PR |
|---|---|
| Modelo | #38 |
| Constructor de nave | #39 |
| Tela | #40 |
| Truss e imán | #41 |
| Visor 3D | #42 |
| Editar desde el 3D | #43 |
| Rigging | #44 |
| Planta 2D completa | #45 |
| Hoja A3 | #46 |
| Ver como en rodaje | #47 |
| Escaneos y MVR | #48 |
