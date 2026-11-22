# Plan GF · IRIS para el gaffer (2026-11-22)

Daniel suele trabajar como director de foto, y ahora tiene una película grande como **gaffer**. Quiere usar IRIS sobre todo como gaffer:
- plantas de luz;
- saber qué material tenemos;
- que los eléctricos vean plantas y material;
- diseñar la caseta de feria para prever los cambios de luz;
- sacar hojas de planta, alzado y perfil de cada esquema, como las de *Dune II* (WYSIWYG o Vectorworks: el plató con sus luces, fáciles de identificar).

## Decisiones de Daniel

- **Pantalla inicial por papel:** una página con los proyectos de director de foto. Al pasar de página, los de gaffer; después, los de 1.º ayudante. De momento todas con las mismas funciones; más adelante se verá qué sobra en cada una.
- **Eléctricos: solo ver.** Ven las plantas de luz, el material de cada jornada y sus vatios.
- **Horas extra:** se apuntan las de cada persona y cada jornada, para negociarlas después con la productora.
- **Material:** sale de la casa de alquiler (importar el pedido) y se completa a mano.
- **Lo primero son las hojas de planta, alzado y perfil.**

## Lo que ya hay y se aprovecha

| Pieza | Dónde | Estado |
|---|---|---|
| **Hoja A3** al estilo WYSIWYG o Halfway: planta, alzado y perfil a escala, leyenda con vatios y amperios, estructura y cajetín | `shared/pdf_export/rig_sheet_pdf.dart` | Escondida: solo se llega desde Alzados, y sale una hoja de toda la planta |
| **Alzado y perfil** en pantalla, y export DXF y MVR | `camera_plan/plan_elevation_screen.dart`, `plan_cad_export.dart` | Funciona |
| **Reparto eléctrico:** circuitos, carga y grupo | `camera_plan/plan_power_sheet.dart` | Funciona por esquema |
| **Naves, casetas, rejilla, truss y telas** | `camera_plan/rig/` (`plan_hall`, `plan_rig`, `plan_drape`) | Funciona |
| **Luces por plano y luz en caliente** (posiciones 1, 2, 3) | plan JP | v1.12.0 |
| **Reservas y material por jornada** | `shoot_day_material.dart`, reservas RC | Funciona; la lista maestra (DR.7) está pendiente |
| **Papeles por proyecto, invitaciones y autoría** | 019, 020, 021 | v1.16.0, y autoría en `plan/autoria` |

## Fases

### GF.1 · Hojas de luz: planta, alzado y perfil (lo primero)

**Qué:** una hoja por **esquema de luz** (o por set): planta, alzado frontal y perfil a escala, sobre papel blanco y lista para imprimir o mandar. Cada foco lleva número y nombre corto en las tres vistas, junto con lo que ilumina y lo que hace en el plano.

**Detalles:**
- **Numeración estable de focos** por esquema: «1 · SkyPanel S60», «2 · M18». El número es el mismo en la planta, el alzado, el perfil, la leyenda, la hoja del gaffer y la lista de material. Se puede renumerar a mano.
- **Rótulos** junto al foco o al margen con línea guía, como en la planta limpia. En los tres alzados no se pisan.
- **Haz contorneado** con su apertura y dirección en planta y en alzado. Altura de cada foco en el alzado y el perfil (soporte, altura en metros y ángulo).
- **Leyenda:** número, aparato, accesorios (difusor, gelatina, rejilla), potencia, circuito y DMX cuando lo haya, y cantidad.
- **Cajetín:** proyecto, set, esquema, escena o planos, jornada, escala, fecha, autor y versión.
- **Desde dónde se saca:**
  - en Plantas, «Hoja de luz» del esquema activo;
  - en el centro de exportación, «Hojas de luz» de varios esquemas o de una jornada (un PDF con una hoja por esquema).
- **Tamaño A3 o A4**, y escala elegida o automática.
- **Hecho cuando:** con el esquema de una escena de KEBAB, la hoja permite identificar cada foco en planta, alzado y perfil sin mirar la app.

**Pendiente:** si Daniel encuentra las imágenes de *Dune II*, las pondremos al lado para ajustar el aspecto.

### GF.2 · Proyectos por papel en la pantalla inicial

- Cada proyecto guarda **tu papel en él**: director de foto, gaffer o 1.º ayudante de cámara. Es una columna local nueva, sin cambio en la nube, y los proyectos donde te invitaron lo toman de `project_members`.
- **Pantalla de proyectos** con páginas por papel (Director de foto · Gaffer · 1.º ayudante) que se pasan con el dedo o con pestañas arriba. Recuerda la última página abierta.
- Al crear un proyecto se elige el papel, que se puede cambiar después.
- **Mismas funciones** en todas las páginas por ahora.

### GF.3 · Eléctricos de solo consulta

- **Papeles nuevos** en la nube (`best_boy` y `electrician`), de solo consulta (`can_edit = false`), con ampliación de 019 y 020.
- **Vista de consulta:** plantas de luz por jornada, la hoja de luz de cada esquema, el material del día con sus vatios y la hoja del gaffer. Pensada para el móvil.
- Se invitan con «Equipo e invitaciones», como el resto.

### GF.4 · Material de luz: lo que tenemos y lo que pide cada jornada

- **Importar el pedido de la casa de alquiler** (PDF o Excel) al inventario del proyecto, enlazado al catálogo. Ya existe el importador de reservas (RC · E2).
- **Por jornada:** lo que piden sus plantas (focos, accesorios, cable y distribución) frente a lo que hay. Muestra lo que falta, lo que sobra, los vatios y amperios totales y por grupo o línea.
- Es la «lista maestra de material» (DR.7) vista desde el gaffer.

### GF.5 · Horas extra del equipo

- Por jornada y persona: hora de citación, fin y horas extra (calculadas desde la jornada pactada, con ajuste a mano), y notas.
- Resumen por persona y semana. Exportar a PDF o Excel para la productora.
- Lo rellena el gaffer o el best boy. Los eléctricos ven las suyas.

### GF.6 · Caseta de feria y cambios de luz

- Diseñar la caseta con el constructor de naves: estructura, rejilla, telas, aberturas y techo. Se ve en planta, 3D, alzado y en la hoja de luz.
- **Cambios de luz** por plano o escena: qué se enciende, apaga, mueve o cambia de valor de un plano al siguiente, usando las luces por plano y las posiciones del plan JP.
- **Lista de cambios** para el set: «6/1 → 6/2: apagar 3, bajar 5 al 50 %, mover 7 a la posición 2». Sale en la hoja del gaffer.

### GF.7 · Hoja del gaffer por jornada, carga y DMX (después)

- **Hoja del gaffer:** plantas del día, focos con número, circuitos, DMX, cambios de luz y notas, en un PDF.
- **Carga:** consumo real por aparato (hoy el catálogo solo trae `powerW`), y reparto por circuito, grupo y línea.
- **DMX:** universo, dirección y modo de cada aparato, y la hoja de patch.

## Orden y forma de trabajo

GF.1 → GF.2 → GF.3 → GF.4 → GF.5 → GF.6 → GF.7.
- Cada fase lleva su rama y sus tests. Las pruebas usan datos inventados.
- Se publica por paquetes, con versión de prueba antes, y solo con el visto bueno de Daniel.
- **Cambios de esquema:** GF.2 (papel del proyecto), GF.5 (horas) y quizá GF.4. Las migraciones de la nube van numeradas a partir de la 022.
