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

- **Números de foco estables.** Cada foco guarda su número en `props` y lo conserva aunque se borren otros. Los focos nuevos toman el siguiente libre, y se puede renumerar el esquema. Si un foco no tiene número, se le asigna el que tiene hoy.
- **Nombre junto al foco** en la planta, el alzado y el perfil: «3 · SkyPanel S60», con línea guía al margen cuando no cabe, igual que en la planta limpia. Altura y ángulo en el alzado.
- **Leyenda por foco**, no solo por modelo: número, aparato, accesorios (difusor, gelatina, rejilla), vatios, circuito y canal DMX si lo hay. Si no cabe, sigue en una segunda hoja.
- **Cajetín** con proyecto, set, esquema de luz, escena o planos, jornada, escala, fecha, gaffer, versión y página.
- **A3 o A4**, con escala automática o elegida.
- **Desde dónde se saca:**
  - en Plantas, «Hoja de luz» del esquema o set activo;
  - en el centro de exportación, «Hojas de luz» por sets, esquemas o jornada, en un solo PDF con una hoja por esquema.
- **Hecho cuando:** con un esquema de KEBAB, cada foco se identifica en planta, alzado y perfil solo con la hoja.

**Pendiente:** si aparecen las imágenes de *Dune II*, se ponen al lado para ajustar el aspecto.

### LZ.2 · Proyectos por papel en la pantalla inicial

- Cada proyecto guarda tu papel en él: director de foto, gaffer o 1.º ayudante de cámara. Es una columna local, con cambio de esquema en la app pero no en la nube. En los proyectos a los que te invitaron, sale de `project_members`.
- **Pantalla de proyectos** con páginas por papel, que se pasan con el dedo o con pestañas. Recuerda la última página abierta.
- El papel se elige al crear el proyecto y se puede cambiar después.

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
