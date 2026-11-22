# Plan LZ · Luz, material y eléctricos en la base de IRIS (2026-11-22)

Daniel suele trabajar como director de foto, y ahora tiene una película grande como **gaffer**. Quiere usar IRIS para:
- crear plantas de luz;
- saber qué material de luz tenemos;
- que los eléctricos vean plantas y material;
- diseñar la caseta de feria y prever los cambios de luz;
- sacar hojas de planta, alzado y perfil de cada esquema, como las de *Dune II*.

**Todo esto va en la base de la app, no en un «modo gaffer».** Cualquier proyecto, sea cual sea tu papel en él, tiene hojas de luz, material, cambios de luz, horas extra y eléctricos. El papel solo sirve para ordenar los proyectos en la pantalla inicial.

## Decisiones de Daniel

- **Pantalla inicial por papel:** una página con los proyectos de director de foto, otra con los de gaffer y otra con los de 1.º ayudante. Se pasa de una a otra con el dedo, y todas tienen las mismas funciones.
- **Eléctricos: solo ver.** Las plantas de luz, el material de cada jornada y sus vatios.
- **Horas extra** de cada persona por jornada, para negociarlas con la productora.
- **El material** sale del pedido de la casa de alquiler, y se completa a mano.
- **Lo primero son las hojas de planta, alzado y perfil.**

## Lo que ya hay (revisado en el código el 2026-11-22)

| Pieza | Dónde | Qué hace | Qué le falta |
|---|---|---|---|
| **Hoja A3** al estilo WYSIWYG o Halfway | `shared/pdf_export/rig_sheet_pdf.dart` | Planta, alzado frontal y perfil a escala; leyenda por modelo con unidades (U1–U6), vatios y lúmenes; estructura, avisos de rigging y cajetín | Solo se llega desde Alzados y sale una hoja de toda la planta. La leyenda corta a los 10 modelos. En las vistas no sale el nombre del foco. Sin A4. Sin escena ni jornada en el cajetín |
| **Números de unidad** U1, U2… | `plan_gear_list.dart` (`lightUnitNumbers`) | Los usan la planta, la hoja, el reparto y el DXF | Siguen el orden de la planta: si se borra un foco, cambian los números de los demás. Cada luz ya tiene un uid estable (`LightOverrides`) en el que apoyarse |
| **Alzado y perfil** en pantalla; DXF y MVR | `plan_elevation_screen.dart`, `plan_cad_export.dart` | Funcionan | — |
| **Reparto eléctrico** | `plan_power.dart`, `plan_power_sheet.dart` | Circuitos con carga al 80 %, grupo electrógeno en kVA y unidades sin circuito | Es por esquema, no por jornada. Sin DMX |
| **Material de la jornada** | `shoot_day_material.dart` | Focos de los sets y lo que piden los planos, cruzado con las reservas del día: falta, corto o de sobra | Solo va dentro del PDF. Sin vatios del día, sin accesorios, cable ni distribución |
| **Importar pedidos de alquiler** | `features/equipment/rentals/` | Lee PDF y Excel de varias casas y los revisa antes de guardar | — |
| **Naves y casetas** | `camera_plan/rig/plan_hall.dart`, `plan_rig.dart` | Perímetro libre, altura, cubierta, pilares, rejilla de truss, telas y plantillas | Sin plantilla de caseta de feria |
| **Luces por plano y luz en caliente** | `light_overrides.dart`, `plan_marks.dart` (plan JP) | Cada plano usa unos focos con sus ajustes, y hay posiciones 1, 2 y 3 | Ninguna pantalla ni hoja dice qué cambia de un plano al siguiente |
| **Papeles, invitaciones y autoría** | 019, 020, 021 | Todos los papeles editan salvo «solo consulta» | Faltan best boy y eléctrico |

## Fases

### LZ.1 · Hojas de luz: planta, alzado y perfil (lo primero)

**Estado 2026-11-22, rama `plan/autoria`.**
- **Hecho:**
  - números de foco estables;
  - hoja al estilo *Dune II* con dibujo y color por modelo, localización en gris, decorado pálido, haces, cotas rojas y rótulos de marcos;
  - leyenda con dos dibujos por modelo, que sigue en una hoja propia si no cabe;
  - planta y alzados en hojas aparte o todo en una;
  - A3 o A4;
  - cajetín con set, esquema, escenas, jornada, gaffer y hoja n/m;
  - se saca desde Plantas (botón de alzado → «Hoja de luz (PDF)») y desde Alzado y perfil, con una ventana de opciones;
  - «Renumerar focos» en el mismo menú;
  - hoja «Lista de focos» (se puede quitar) con cada foco: aparato, accesorios, montaje, altura, circuito y vatios;
  - «Hojas de luz» en el centro de exportación: una por esquema usado en las escenas o jornadas elegidas, en un solo PDF, con escenas y jornada en el cajetín;
  - prueba con una caseta inventada (`test/shared/rig_sheet_pdf_test.dart`; `IRIS_RIG_SHEET_OUT=carpeta` guarda los PDF) y con tres esquemas reales de KEBAB (14, 16 y 30 focos) sobre una copia de la base, sin guardar nada en el repo.
- **LZ.1 cerrado.** Pendiente para más adelante: canal DMX en la lista y nombre corto junto al foco en la planta (hoy va solo el número, con la leyenda al lado).

- **Números de foco estables.** Cada foco guarda su número en `props` y lo conserva aunque se borren otros. Los focos nuevos toman el siguiente libre, y se puede renumerar el esquema. Si un foco no tiene número, se le asigna el que tiene hoy.
- **Nombre junto al foco** en la planta, el alzado y el perfil: «3 · SkyPanel S60», con línea guía al margen cuando no cabe, igual que en la planta limpia. Altura y ángulo en el alzado.
- **Leyenda por foco**, no solo por modelo: número, aparato, accesorios (difusor, gelatina, rejilla), vatios, circuito y canal DMX si lo hay. Si no cabe, sigue en una segunda hoja.
- **Cajetín** con proyecto, set, esquema de luz, escena o planos, jornada, escala, fecha, gaffer, versión y página.
- **A3 o A4**, con escala automática o elegida.
- **Desde dónde se saca:**
  - en Plantas, «Hoja de luz» del esquema o set activo;
  - en el centro de exportación, «Hojas de luz» por sets, esquemas o jornada, en un solo PDF con una hoja por esquema.
- **Hecho cuando:** con un esquema de KEBAB, cada foco se identifica en planta, alzado y perfil solo con la hoja.

**Estilo de referencia: las hojas de *Dune II*** (American Cinematographer). Daniel las pasó el 2026-11-22. Lo que hace que se lean, y cómo está hoy nuestra hoja:

| En *Dune II* | Hoy en `rig_sheet_pdf.dart` | Cambio |
|---|---|---|
| **Cada modelo tiene su símbolo y su color:** el ArriMax como tulipa rosa, el Vortex8 como rectángulo verde, el Vortex4 como cuadrado rosa, el Eclipse como placa naranja y el Aperture como recorte gris. El color dice qué aparato es, no qué luz da | Todos los focos son un círculo pintado con el color de su luz | **Símbolo por familia** (fresnel o HMI, panel, tubo, recorte, globo, par, *spacelight*), con medidas reales a escala y orientado hacia donde apunta. **Color fijo por modelo**, de una paleta de 10–12 colores que se distinguen en papel. La temperatura de color pasa a la leyenda |
| **La leyenda lleva dos símbolos por modelo** (visto desde arriba y de lado), el modelo, cuántos hay y los vatios de cada uno | Un círculo, «U1–U6», el nombre, vatios y lúmenes, y como mucho 10 filas | Símbolo de planta y de alzado, modelo, cantidad y vatios por unidad. Al final, el total de unidades y de vatios. Si no cabe, sigue en otra hoja |
| **La estructura de la localización va en gris claro y fino:** muros, cerchas, pilares y la rejilla de la cubierta | Muros y pilares en negro. La nave del constructor solo sale si hay truss | El edificio (muros, pilares, vigas de cubierta y huecos) en gris claro, de fondo. El rigging en negro por encima: truss con celosía, motores y torres |
| **El decorado va en rosa pálido** debajo de todo, como un fantasma | No sale | La huella del set (mobiliario, elementos del decorado y telas) en un tono muy claro, para que se vea dónde está la luz respecto a lo que se rueda |
| **Alzado y perfil con el mismo símbolo** colgado a su altura y girado hacia donde apunta. Pies de suelo dibujados, con sus patas | Un círculo con un cono | El símbolo de lado, girado según el *tilt*. Los pies o *stands* con mástil y patas hasta el suelo, y la pinza o yugo en el truss |
| **Los haces en rosa muy claro**, que se ven atravesando el decorado | Cono al 15 % con el color de la luz | Cono con su apertura real en un tono neutro muy claro, que no compite con los símbolos. En planta, el haz recortado también |
| **Cotas en rojo** con flechas: alturas de cada nivel de truss, distancias entre estructuras y luces de las cerchas | Solo una raya y «+3,50» por nivel | Cotas en rojo con flecha: altura de cada truss, de cada foco suelto y de la cubierta. Anchos principales del set y de la nave. En planta, distancias entre las estructuras de luz |
| **Rótulos sobre la estructura** («20 × 20 lighting frames w/ ultra bounce») | No hay | Las telas, marcos y rebotes llevan su rótulo (medida y tela) junto a ellos |
| Sin números de foco: con cientos de aparatos iguales, basta el modelo | Números U1… por posición | Lo dos: **el color y el símbolo dicen el modelo**, y el número estable se ve con pocos focos o al ampliar. Con muchos iguales se puede ocultar (opción «Números: sí, no o solo los sueltos») |

**Composición:**
- Por defecto, la planta en una hoja y el alzado y el perfil en otra, como en *Dune II*, con más tamaño cada vista.
- La opción «Todo en una hoja» deja la A3 compacta que hay hoy.
- Leyenda abajo a la derecha, en recuadro, en las dos hojas.

**Para probarlo:** un esquema inventado tipo caseta, con truss a dos alturas, 4 modelos, pies de suelo y un marco 20 × 20, guardado como prueba de oro (PDF a PNG) para ver los cambios.

### LZ.2 · Proyectos por papel en la pantalla inicial

- Cada proyecto guarda tu papel en él: director de foto, gaffer o 1.º ayudante de cámara. Es una columna local, con cambio de esquema en la app pero no en la nube. En los proyectos a los que te invitaron, sale de `project_members`.
- **Pantalla de proyectos** con páginas por papel, que se pasan con el dedo o con pestañas. Recuerda la última página abierta.
- El papel se elige al crear el proyecto y se puede cambiar después.
- **Hecho (2026-11-22, rama `plan/autoria`):**
  - columna local `myRole` en `projects` (esquema 66, no se sube; cambiarla no toca `updatedAt`);
  - pestañas «Foto», «Gaffer» y «1.º AC» con el número de proyectos, que se pasan con el dedo y recuerdan la última;
  - «Tu papel» en Nuevo y Editar proyecto; un proyecto nuevo toma el papel de la página abierta;
  - los proyectos a los que te invitaron toman el papel de `project_members` si no tienen uno;
  - duplicar conserva el papel; los grupos salen en las páginas donde tienen proyectos (y los vacíos, en todas).

### LZ.3 · Eléctricos

- **Papeles nuevos** `best_boy` y `electrician`, de solo consulta, en la migración 022. En la app aparecen en el selector de papeles para cualquier proyecto.
- **Vista de consulta**, pensada para el móvil, con lo que se ve en un proyecto sin permiso de edición:
  - las plantas de luz por jornada;
  - las hojas de luz;
  - el material del día con sus vatios.

### LZ.4 · Material de luz por jornada, en pantalla

- Llevar `ShootDayMaterial` a una pantalla viva dentro de la jornada: lo que piden las plantas frente a lo reservado, con lo que falta, lo que sobra y lo justo.
- **Vatios y amperios** del día, por set y en total, con el grupo electrógeno que haría falta (de `PowerPlan`).
- **Accesorios, cable y distribución** como líneas propias del material.
- **Inventario del proyecto:** el pedido de la casa de alquiler, importado, frente a lo que piden todas las jornadas. Es la lista maestra (DR.7).

### LZ.5 · Horas extra

- En cada jornada: el equipo con su citación, el fin, las horas extra calculadas desde la jornada pactada (con ajuste a mano) y notas.
- Resumen por persona y semana, en PDF o Excel para la productora.
- Lo rellena quien edita el proyecto. Los eléctricos lo ven.

### LZ.6 · Caseta de feria y cambios de luz

- **Plantilla «caseta de feria»** en el constructor de naves: estructura, techo, frentes abiertos y rejilla. Se ve en planta, 3D, alzado y en la hoja de luz.
- **Cambios de luz:** comparando los focos de cada plano con los del anterior, una lista del tipo «6/1 → 6/2: apagar 3 · bajar 5 al 50 % · mover 7 a la posición 2». Se ve en la planta del plano, en la jornada y en la hoja de luz.

### LZ.7 · Después

- **Hoja del gaffer por jornada:** plantas, focos, circuitos, DMX, cambios y notas.
- **Consumo real** de cada aparato (hoy el catálogo solo trae `powerW`).
- **DMX:** universo, dirección, modo y hoja de patch.

## Orden y forma de trabajo

LZ.1 → LZ.2 → LZ.3 → LZ.4 → LZ.5 → LZ.6 → LZ.7.

- Va en la rama `plan/autoria`, junto con la autoría, para publicarlo como un solo paquete.
- Tests con datos inventados.
- Antes de publicar, una versión de prueba, y se publica solo con el visto bueno de Daniel.
