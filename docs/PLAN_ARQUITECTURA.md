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
| AR.4 | Posiciones de cuelgue con nombre y focos pegados | LZ.1 |
| AR.5 | Puntos de enfoque | AR.4 |
| AR.6 | Niveles por localización | AR.2 |
| AR.7 | Calco e importación de DXF del arquitecto | LZ.8.3 |

**Orden propuesto:** AR.1 → AR.4 → AR.5 (lo que más mejora la hoja de luz) → AR.2 → AR.3 → AR.6 → AR.7.

**AR.1, cómo quedó:** `PlanClass` (`plan_classes.dart`) da a cada elemento su clase: arquitectura, decorado, aparatos de luz, grip, rigging, personas o cámaras.
- En la planta, el menú de vista (paleta) enseña u oculta cada clase. Se guarda por separado para la planta de cámara y la de luz; la de luz parte sin personas ni cámaras.
- Lo oculto no se dibuja ni se coge con el dedo, pero sigue dando luz y sombra, y cuenta para el material.
- El 3D oculta las mismas clases, salvo los aparatos: sin ellos no habría luz.
- Cotas y manchas quedan para cuando la planta las dibuje como hoja (AR.4).

**Esquema:** AR.1, AR.4 y AR.5 caben en `props` de los elementos, sin columnas nuevas. AR.6 necesita decidir si el nivel va en el elemento o en el set.

**Unreal:** cada objeto de arquitectura sale ya en el glTF del set (F6.21.3). Las posiciones de cuelgue salen como `Truss` en el MVR (LZ.8.1).

## Por decidir con Daniel

- ¿Qué recintos tipo hacen falta primero? Propuesta: bar, calle, piso, nave y plató.
- ¿Niveles ya, o cuando haya un rodaje con entreplanta?
- En la planta de cámara, ¿también se ocultan conos y manchas por defecto, o solo en la hoja de luz?
