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
4. **Sin red.** El visor y sus bibliotecas van empaquetados en `assets/viewer3d/`.
5. **Por dispositivo.**

   | Dispositivo | Qué se hace |
   |---|---|
   | Mac | Todo: editar, pilotar, calidad alta, capturas, exportaciones |
   | iPad | Ver, mover y apuntar, pilotar con el giroscopio o joysticks en pantalla, calidad media |
   | Móvil | Ver y recorrer el set, calidad ligera |

   Cada punto dice en qué dispositivos va.
6. **La luz del 3D es la de IRIS.** Lo que da el fotómetro en la planta lo da el 3D en el mismo punto (F6.3.1).
7. **Cada fase termina en la app de prueba del Mac.** El iPad solo cuando Daniel lo pida.

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

---

## F6.0 · Base técnica

**F6.0.1 Visor moderno empaquetado** · Mac, iPad, móvil
- **Qué:** pasar de three.js r147 (UMD) a una versión actual escrita como módulos y empaquetada con esbuild en un único `viewer.js`. El código del visor pasa a módulos (`scene/`, `build/`, `tools/`, `bridge/`) en `tools/viewer3d_src/`, y un script genera `assets/viewer3d/viewer.js`.
- **Por qué:** luces físicas, posproceso (profundidad de campo, bloom, LUT), splats con Spark y mejor rendimiento.
- **Hecho cuando:** el visor actual funciona igual con la versión nueva y el archivo empaquetado ocupa menos de 2 MB.

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

**F6.9.1 Humo y niebla** · Mac, iPad
- **Qué:** humo de máquina en el set (densidad por zona) que hace visibles los haces como luz volumétrica, y niebla exterior.

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
- **Qué:** un paquete con:
  - el glb;
  - el JSON de escena (`IrisDpExportService` ampliado: luces con fixture Luka, cámaras con su perfil, marcas y tiempos del secuenciador);
  - un script de Python de editor de Unreal, guardado en la app como texto y escrito junto al paquete, que importa el glb, pone cada fixture de Luka en su nodo (`luka_light_mapping.dart`), crea las CineCameraActor con su filmback y su óptica, y crea un Level Sequence con las claves de F6.7.
- **Hecho cuando:** un proyecto de Unreal vacío queda montado con un clic en el script.

**F6.11.3 De Unreal a IRIS** · Mac
- **Qué:** importar los renders (ya existe) y también las cámaras cambiadas en Unreal (JSON que escribe el mismo script). Vuelven a la planta como posición, altura, giro y focal.

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

**F6.12.3 Del escaneo a la planta** · Mac
- **Qué:** vista cenital y corte a 1 m como fondo de la planta para calcar, y propuesta de paredes detectadas.

**F6.12.4 Luz sobre el escaneo** · Mac
- **Qué:** una malla de colisión simplificada del escaneo para que las luces de IRIS lo iluminen y den sombra.

**F6.12.5 Sincronizar escaneos** · todos
- **Qué:** los escaneos viajan con los medios del proyecto (como las imágenes de la planta) y están en el iPad.

**F6.12.6 Localizaciones con coordenadas** · todos
- **Qué:** cada localización con latitud, longitud y norte, para el sol real (F6.3.5) y para orientar el escaneo.

---

## Orden propuesto y dependencias

1. **F6.0** completa: 0.1, 0.3 y 0.4 primero.
2. **F6.1:** paridad, empezando por 1.5b (atrezzo con medidas), 1.9b (sentarse), 1.6 (soportes), 1.7 (grip), 1.1 (terreno) y 1.2 (materiales).
3. **F6.4** (cámara) y **F6.8** (navegación y pilotar, con 8.3b: operar a la altura de verdad). Es lo que sustituye a Cine Tracer para componer.
4. **F6.10.1–10.2:** capturas al storyboard.
5. **F6.3:** luz fiel, mesa de luces y fotómetro.
6. **F6.6** (actores) y **F6.7** (secuenciador).
7. **F6.5:** soportes de cámara y movimientos.
8. **F6.2** (constructor) y **F6.9** (atmósfera).
9. **F6.11** (interoperabilidad) y **F6.12** (escaneos).

Dependencias principales:

| Punto | Necesita |
|---|---|
| F6.3.1 | F6.0.1 (luces físicas) |
| F6.4.5 | F6.0.1 (posproceso) |
| F6.12.1 | F6.0.1 |
| F6.7 | F6.6.4 y F6.4.4 |
| F6.11.2 | F6.7 (claves) y F6.4 (cámaras) |
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
