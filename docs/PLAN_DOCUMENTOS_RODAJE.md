# Plan DR · Documentos de rodaje (noviembre 2026)

Estado de cada punto: **pendiente** salvo que se indique. Al terminar uno, anotar aquí «hecho (commit)».

## Contexto

Daniel quiere perfeccionar la pantalla de Documentos de rodaje: calendario editable al estilo Google Calendar, importar planes de rodaje (PDF, Excel y Word), listas de material, y los documentos que se llevan al set (guion técnico, plantas, storyboard). Pide poder usar lo máximo posible **en el rodaje del 13 al 16-11** y que todo funcione también **en Windows**.

Decisión de Daniel (2026-11-10): **el desarrollo de este plan sigue en el PC con Windows**. Cómo retomarlo allí: [CONTINUAR_EN_WINDOWS.md](CONTINUAR_EN_WINDOWS.md).

Código revisado: `main` v1.8.0 (schema 63), en `iris_dp_release`.

## Lo que hay y dónde flojea

| Área | Hallazgo | Dónde |
|---|---|---|
| Sync | Todos los documentos de rodaje se mezclan como un bloque: si se marca En set en el iPhone y se toca el plan en el Mac, un lado se pierde entero | `core/sync/bundle_merge.dart:145, 451-472` |
| Sync | Jornadas y bloques no tienen `uid`; cada descarga los borra y recrea con ids nuevos (pantalla de jornada colgada, deshacer roto) | `project_content_bundle.dart:317, 2010-2060` |
| Calendario | Solo lectura: sin arrastrar, estirar ni crear; sin vista de día; no muestra las horas de escena; las franjas de madrugada caen en el día equivocado | `shoot_calendar_screen.dart:405-576`, `shoot_calendar.dart:51` |
| Importar | No existe importación de planes de rodaje en ningún formato | — |
| Documentos | No hay orden del día, ni pack por jornada, ni `.ics`; «Exportar» del tablero abre la planta, no un horario | `export_selection.dart:6`, `shoot_days_board.dart:77` |
| Documentos | Plantas solo con fondo oscuro y tintas fijas; sin leyenda, escala ni lista de focos; la hoja A3 blanca y a escala existe pero solo se llega desde alzados | `camera_plan_painter.dart:38-46, 1689`, `rig_sheet_pdf.dart` |
| Documentos | Guion técnico sin cabecera ni número de página; ningún archivo lleva fecha o versión; storyboard con rótulos en inglés; exportar corre en el hilo de la interfaz | `technical_script_pdf.dart`, `storyboard_pdf.dart:385` |
| Material | Tres listas que no se conocen: reservas importadas, equipo del proyecto (sin cantidad) y lista de la planta (sin guardar). Nada compara lo que piden las plantas con lo reservado ni con las jornadas | `rentals/`, `tables.dart:541`, `plan_gear_list.dart` |
| Material | No se pueden añadir ni editar líneas, ni fechas tras importar; solo PDF tipo ESCAC; sin exportar | `rentals_tab.dart`, `rental_list_formats.dart:16` |
| Material | Asignar equipo desde Equipo no marca el proyecto para subir; reserva sin número se duplica al reimportar | `equipment_screen.dart:625-652`, `rental_import_service.dart:20` |
| Deshacer | El tablero comparte historial con el guion técnico; fecha, franjas, horas y jornadas nuevas no se deshacen | `edit_history.dart:68`, `shoot_plan.dart:118` |
| Fallos | La tarjeta «Documento activo hoy» abre el editor libre aunque sea una jornada; En set muestra las franjas arriba y no en su sitio | `project_hub_screen.dart:243`, `shoot_day_on_set.dart:377` |

## Tanda 1 · antes del rodaje (publicar el 12-11 por la mañana)

**Estado (11-11, desde el Mac):** Tanda 1 entera hecha en la rama `plan/dr-documentos-rodaje`, sin publicar.

| Punto | Commit | Notas |
|---|---|---|
| DR.4 Importar plan | a9b1399 | Lee el plan escrito («DÍA 1 - 13 NOVIEMBRE (7:30 - 17:00)», horas, planos «13b.5», duraciones «(35 min)», madrugada) desde texto pegado, .txt, Word, Excel y PDF con texto. Revisión antes de guardar, «Deshacer» propio (no `saveImportSnapshot`, que pierde datos), conserva las marcas de En set. Cada plano guarda su hora y su apunte (`shotTime`) y se ven en la jornada, el tablero y En set. Probado con el plan tentativo de Kebab Khaled (`test/fixtures/shoot_plan/`, nombres del equipo cambiados). |
| DR.1 Calendario editable | 652adcb | Día, Semana, Mes (y Lista/Día en iPhone). Mover, estirar, dibujar para crear (franja en la jornada, o jornada nueva), escenas con hora y panel «Sin hora», jornadas arrastrables en el mes, ⌘Z/Ctrl+Z, línea de «ahora». Con el dedo se arrastra tras mantener pulsado. |
| DR.2 Marcas de En set | d8132f3 | Las marcas guardan `at`; la mezcla las conserva emparejando por jornada (nombre+fecha, o nombre) y plano. |
| DR.3 Orden del día e .ics | 2557bd5 | PDF A4 por jornada desde la jornada, el tablero (todas o una) y el calendario. `.ics` desde el calendario. No se añadió al centro de exportación (pendiente). |
| DR.5 Arreglos rápidos | 7960fac | Todo lo previsto. Las líneas propias de una reserva llevan uid `manual-…` y reimportar no las toca. |

Pendiente de la Tanda 1: el orden del día dentro del centro de exportación; probar con dedo en iPad e iPhone; el lector de PDF solo se ha probado con texto (sin muestra real en PDF).

Regla: **sin subir el esquema y sin cambiar el formato de sincronización**. Todo usa campos que ya existen (`contentOverridesJson`, `shootDate`, `shootFromTime/ToTime`). Orden de prioridad; lo último es lo primero que se recorta si no llega en verde.

**DR.1 Calendario editable.**
- Lógica pura nueva `shoot_documents/shoot_calendar_edit.dart`: minutos ↔ píxeles, imán a 5/15 min, mover y estirar, cruce de medianoche. Con pruebas.
- Rejilla extraída de `_WeekGrid` a `shoot_calendar_grid.dart` y usada por **Día** (nueva), **Semana** y, en iPhone, Día al tocar la agenda.
- Gestos sobre el `Stack` actual: arrastrar para mover, borde inferior/superior para cambiar duración, arrastrar en hueco para crear. Ratón en Windows y Mac, dedo en iPad, mantener pulsado en iPhone.
- Qué se edita: ventana de la jornada, franjas (`ShootDayScheduleService.updateStrip/addStrip`), horas de escena (`setSceneSchedule`, hoy no salen en el calendario: se añaden como tipo `scene`). En un día sin jornada, crear abre «Nueva jornada» con esa fecha y hora (`ShootPlanService.addDay`).
- Mes: arrastrar una jornada a otro día cambia su fecha.
- Panel «Sin hora» con las escenas de la jornada sin horario, para soltarlas en la rejilla.
- Deshacer y rehacer con un `EditHistory` propio de la pantalla y ⌘Z / Ctrl+Z (patrón de `technical_script_screen.dart:424`); se vacía al salir.
- Arreglos: franjas de madrugada en su día real, recolocar al cambiar de semana, `StableStreamBuilder` en vez de streams en `build`.

**DR.2 Las marcas de En set no se pierden.** En `bundle_merge.dart`, cuando los dos lados cambiaron «documentos de rodaje», el ganador conserva además las marcas `onSet` del otro lado (emparejadas por jornada nombre+fecha y `uid` de plano o escena, como `resolveOpenShootDay`). Las marcas nuevas guardan hora dentro del JSON para decidir entre dos distintas. Es la única pieza que toca la mezcla: va con pruebas propias en `test/sync/` y no cambia el formato.

**DR.3 Orden del día y calendario exportable.**
- `shared/pdf_export/shoot_day_order_pdf.dart`: una hoja por jornada con fecha, «día X de N», ventana, localización, tiempo y el horario completo (franjas y escenas como filas, con notas y lugar de cada franja), desde `buildShootDayEntries`. Botón en la tarjeta de jornada y tipo nuevo en el centro de exportación.
- `shoot_calendar_ics.dart`: `.ics` con jornadas, franjas, recogidas y devoluciones; identificador estable (proyecto + nombre + fecha, no ids locales). Se guarda o comparte con `ExportRunner.save`.

**DR.4 Importar plan de rodaje (Excel y Word; PDF con el archivo real).**
- `shoot_documents/import/`: modelo `ParsedShootPlan` (días con fecha, ventana, lugar y filas: escena o franja con horas y nota) y registro de formatos como `rentalListFormats`.
- Lectores: Excel con `excel` (ya es dependencia; se extraen los ayudantes de cabecera de `equipment_spreadsheet_service.dart:1195`), Word reutilizando la lectura de tablas de `DocxTechnicalScriptReader`, PDF con `readPdfGlyphs` reconstruyendo filas. Columnas por texto de cabecera (día, fecha, esc., hora, localización, descripción), no por posición.
- Revisión antes de guardar: días detectados, escenas emparejadas por número y letra, escenas sin pareja, y si sustituye o añade a las jornadas existentes. Aplicar con `ShootPlanService`; antes, `saveImportSnapshot` para «Deshacer».
- Soltar el archivo sobre la pantalla (`desktop_drop`) o botón «Importar plan».
- **Necesito el plan de rodaje real de Kebab Khaled** (y cualquier otro de muestra) para que el lector de PDF sea fiable; sin muestra, antes del rodaje solo entran Excel y Word.

**DR.5 Arreglos rápidos.** Tarjeta «activo hoy» abre la jornada; franjas en su sitio en En set; borrar y duplicar jornada en el tablero; en reservas, editar fechas y notas y añadir líneas propias (campos que ya existen); `touchProjectContent` al asignar equipo.

## Tanda 2 · después del 18-11

- **DR.6 Identidad y mezcla por elemento (schema 64).** `uid` en `ShootDocuments` y `ShootDocumentBlocks`, mezcla por fila y por campo como las reservas (`bundle_merge.dart:75-79`), y la descarga deja de borrar y recrear. Con instantánea `drift_schema_v64.json`.
- **DR.7 Lista maestra de material.** Una vista que junta reservas, líneas propias y lo que piden las plantas (día → bloques → plano → set → elementos), con «falta por reservar» y «reserva que no cubre el día» por jornada, y avisos en el calendario. Importar listas en Excel/CSV añadiendo un lector a `rentalListFormats`; exportar a PDF y Excel, también desde el centro de exportación. Enlace al catálogo por `catalogRef`.
- **DR.8 Pack por jornada.** Un PDF con portada, orden del día, guion técnico, plantas y storyboard del día: los generadores exponen sus páginas para componerlas en un documento.
- **DR.9 Plantas en blanco.** Tintas de papel en `_CanvasColors`, leyenda, barra de escala y lista de focos (se reaprovecha `RigSheetPdf`), A3 y bloques por página a elegir; la celda PLANTA del guion técnico pasa a usar `PlanRenderer`.
- **DR.10 Acabado común.** Cabecera, pie con página y «generado el», rótulos en español en storyboard, ajustes con nombre, recordar la selección, exportación fuera del hilo de la interfaz y progreso por archivo.
- **DR.11** Recordatorios de citación reutilizando `core/notifications/`; importar `.ics`.

## Cómo se trabaja en el PC

- Una sola rama, `plan/dr-documentos-rodaje`; cada DR con su commit y `git push`, para que el CI compile Mac, iOS y Windows.
- Los gestos del calendario se prueban primero con ratón en la propia app de Windows (`flutter run -d windows`).
- Publicar la Tanda 1 como v1.9.0 solo con el OK de Daniel; el Mac y los móviles se actualizan solos al coincidir encendidos.

## Comprobación

- `flutter analyze`, `flutter test` completo, `dart run tool/check_architecture.dart`, `flutter build macos` e iOS sin firma, leyendo los resultados antes de dar nada por bueno.
- Pruebas nuevas: lógica de arrastre y medianoche; widget del calendario (mover, estirar, crear, deshacer); mezcla que conserva marcas de En set en ambos sentidos; lectores con archivos de ejemplo (xlsx, docx y el PDF real); orden del día e `.ics`.
- Windows: el CI compila y abre la app en `windows-latest`; las pruebas del calendario corren también allí.
- En el Mac, con copia de la base real: mover una franja, crear una jornada, importar el plan real, exportar orden del día e `.ics` y abrirlo en Calendario.
- Sin probar hasta que Daniel lo use: arrastre con dedo en iPad e iPhone y con ratón en su PC.
