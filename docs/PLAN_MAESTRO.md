# Iris · Plan maestro

Plan generado en el iPhone el 2026-11-20 a partir de GitHub (main v1.13.1, `docs/`, `BACKLOG.md`, el plan de colaboración y las ramas). **Complementado en el Mac el 2026-11-22** con lo que GitHub no tenía: los planes de `~/.claude/plans`, las notas de las sesiones y el estado real de cada worktree. Lo añadido o corregido en el Mac lleva **[Mac]**.

Cada punto lleva entre corchetes el plan del que sale. El detalle técnico sigue en cada plan de origen; al cerrar un punto aquí, se marca también allí.

Prioridades:
- **P0:** bases, sin coste.
- **P1:** pruebas reales: un amigo director de foto, un equipo completo y la película de Daniel como gaffer.
- **P2:** mejora continua en paralelo; Unreal, al final.
- **P3:** lanzar al público, sin fecha.

## Estado del Mac [Mac]

- **Todo el trabajo del Mac está en GitHub.** Los 50 worktrees están limpios: sin cambios sin commit ni commits sin subir.
- La única excepción es `plan/bocetos-planta-nube`: 1 commit local, que se dejó fuera a propósito en la integración del 2026-10-19 (su arreglo lo cubre D5). Se puede borrar.
- **Ya está en main desde que se escribió el plan:**
  - **v1.12.0 y v1.12.1, plan JP · jornada, PDF de planta y plantas:**
    - en la jornada: paradas del día con mapa numerado y «Cambiar punto», y miniaturas que se amplían;
    - en el PDF de planta: índice en una hoja, planta de luz legible, viñetas por tramo y material de la jornada cruzado con las reservas;
    - en las plantas: focos por plano, luz en caliente por posiciones, actores que siguen al plano anterior y ⌥ arrastrar para sacar una posición nueva.
  - **v1.13.0, plan R · jornadas seguras (DR.6):** uid en jornadas y bloques (esquema 64), mezcla elemento a elemento y bajada en su sitio.
  - **v1.13.1:** la base espera hasta 10 s si otro proceso la tiene ocupada. Dos actualizaciones seguidas dejaron la migración a 64 a medias con «database is locked». Era el mismo fallo que el plan DR tenía abierto como «database is locked en la primera migración del Mac».
- **Planes que solo estaban en el Mac:** RC, RJ, IN, EX, SV, JP, IC.6, storyboard, F6 v2 y otros en `~/.claude/plans`. Lo que les queda está repartido abajo.
  - `antes-de-eso-quiero-streamed-marble.md` (blindar `/admin`) es de la web ddanidiaz.com, no de Iris: va aparte.

## Hoja de ruta

Cuatro etapas y tres puertas de paso: no se pasa a la siguiente etapa sin cumplir la puerta. Costes estimados con 1–3 GB por proyecto activo.

## P0 · Antes de cualquier usuario externo

Sin coste. Que los datos de otros estén seguros y que varias personas puedan trabajar juntas.

### Primero: cerrar los planes de cada dispositivo
- [x] **Mac:** revisado el 2026-11-22. Todo está subido; ver «Estado del Mac». [Mac]
- [ ] **PC con Windows:**
  - el trabajo de documentos de rodaje (`CONTINUAR_EN_WINDOWS.md`);
  - el 3D de alta calidad (F6.19);
  - F6.17.2, IRIS con RTX, que necesitaría un renderizador nativo;
  - cualquier plan escrito allí sin subir.
- [ ] **iPad e iPhone:** lo anotado en el rodaje y las pruebas sin marcar de `PRUEBA_RODAJE_2026-11.md`.
- [ ] **Tableros:** con todo subido, actualizar `PLAN_ACCION.md` y `PLAN_F6_3D_PREVIS.md` para que reflejen lo hecho.

### Acceso y datos
- [ ] **Traer `plan/invitados-control` a main** y ejecutar sus migraciones 016 y 017. **[2026-11-22] Código traído en la rama `plan/in-sobre-main` (esquema 65, tests y base real bien); falta publicarlo y que Daniel ejecute 016 en Supabase**: aprobación de cuentas, cierre de acceso, mantenimiento, `min_build` y cupo de espacio por cuenta. [rama IN]
  - **[Mac] Choca con main:** la rama usa el **esquema 64** (`mirrorCloudId`), que ya lo ocupa el plan R. Hay que renumerarla a 65 y rehacer su instantánea de `drift_schemas/`.
  - **[Mac]** Viene de v1.9.0, con 51 archivos y unas 3.300 líneas. Conviene rehacerla sobre main más que fusionarla.
  - **[Mac]** La 016 hace administradora a la cuenta más antigua de `auth.users`: comprobarlo con la consulta final de la migración.
- [x] ~~Ejecutar y comprobar en Supabase las migraciones 013 y 014~~: Daniel ejecutó 013, 014 y 015 el 2026-11-10 y la comprobación salió bien. v1.8.0 quedó sin huella; las versiones siguientes la tienen. [Mac, FI.2, FI.3, FI.6]
- [ ] **[Mac] Trigger en Supabase que impide bajar la versión del snapshot:** era parte del plan R y no se hizo. [RC · R] **[2026-11-22] Escrito: migración 018 y aviso «Actualiza IRIS» en la app, en `plan/in-sobre-main`; falta ejecutarla en Supabase.**
- [ ] **Separar Supabase** en dos proyectos gratuitos: desarrollo y producción. [Colaboración, fase 0]
- [ ] **Subida de fotos firmada** (fuera el preset sin firmar de Cloudinary) y paso a Cloudflare R2, para que el cupo cuente también las imágenes. [Colaboración, fase 0; rama IN]

### Colaboración entre personas
- [ ] Canal en vivo por proyecto compartido, no por espacio de trabajo propio. [Colaboración, fase 0]
- [ ] Hora del servidor en los bloqueos (`LiveEditing.focusShot`). [Colaboración, fase 0]
- [ ] Persona, nombre y rol en la presencia, en vez del dispositivo. [Colaboración, fase 0]
- [ ] Planta: bloquear al editar, no al abrir, y soltar tras 2 minutos sin tocar. [Colaboración, fase 0]

### Fiabilidad básica
- [x] **Errores a `ErrorLog`** en las rutas de guardado y sincronización que aún los tragan. [FI.4] **2026-11-22:** revisados los 30 `catch (_)`. Se registran: borrar en la nube, base de la mezcla, ajustes del usuario, imagen sustituida, moodboard antiguo y copias viejas de la base. Un bloque de jornada con ajustes ilegibles se guarda aparte (`preserveDamaged`) antes de que «En set» escriba encima. Quedan 19, a propósito: lecturas de JSON con alternativa, limpiezas e indicadores.
- [x] **Exportación local de la sincronización** fuera del hilo de la interfaz. [RD.1] **Medido el 2026-11-22: no hace falta.** Con la base real, KEBAB se exporta en ~60 ms y la interfaz no se bloquea más de 4–12 ms, porque la base ya trabaja en su propio hilo; la huella ya iba aparte.
- [x] Rechazo de paquetes de una versión más nueva (`assertReadable`, FI.1).
- [x] **[Mac]** Jornadas con uid y mezcla por elemento (DR.6, v1.13.0).
- [x] **[Mac]** `busy_timeout` en la base (v1.13.1).
- [x] **[Mac] Base en WAL (R6):** hecho el 2026-11-22 en `plan/r6-wal`, solo en la carpeta propia de la app. la base sigue en modo diario. Con WAL, leer no bloquea al que escribe, y se quita de raíz el «database is locked» entre dos procesos. Antes hay que resolver la duda de R6: base en una carpeta elegida a mano. Sube de P2 a P0. [PLAN_ACCION · R6]

## P1 · Pruebas reales y modo gaffer

Tres pruebas, de menos a más gente, con la nube gratuita y sin tiendas de apps. La última es la película en la que Daniel trabaja de gaffer: Iris tiene que servir a un gaffer aunque el director de foto no la use.

### Prueba 1 · Un amigo director de foto
- [ ] Pasarle el `.dmg` («Abrir igualmente» la primera vez) y aprobar su cuenta desde Ajustes → Invitados (rama IN, en P0).
- [ ] Cupo de espacio en su cuenta.
- [ ] Sesión guiada de 30 minutos y luego uso libre; recoger lo que no entienda y lo que falle.

### Prueba 2 · Un equipo en un mismo proyecto
- [ ] Invitar a director, 1.º ayudante de dirección y gaffer al mismo proyecto. Requiere de P0 el canal por proyecto, la persona en la presencia y la hora del servidor en los bloqueos.
- [ ] Traer de P2 los roles por proyecto y la autoría.
- [ ] Pasar las pruebas del plan de colaboración: mismo set a la vez, sin cobertura, borrar contra editar.
- [ ] Comprobar que las invitaciones sirven para cualquier rol.
- [ ] **[Mac]** Jornadas: marcar En set en el iPhone mientras otro reordena en el Mac, y que no se pierda nada. Es lo que arregla el plan R; falta probarlo con dos personas.

### Prueba 3 · La película, con Daniel de gaffer
- [ ] Usar Iris en preproducción, prelight y rodaje, y anotar cada fallo en el momento.
- [ ] Copia de seguridad diaria activa y comprobada antes del primer día.
- [ ] Revisión al acabar cada semana: lo que falló sube a P0 o P2.

### Modo gaffer independiente

**Ya existe en Iris:**
- planta de luz con fotometría, reparto en circuitos con grupo electrógeno (`plan_power.dart`), hoja de rigging con campo de gaffer, posición del sol e importación de reservas de alquiler;
- **[Mac] desde v1.12.0:** cada plano marca qué focos del set usa (los demás quedan en fantasma), posiciones 1, 2, 3 por foco con cambios de intensidad y color, y «Igual en toda la escena»;
- **[Mac] en el PDF de planta:** la hoja «Material de la jornada», con lo máximo que se usa a la vez por set, cruzado con las reservas de ese día y marcando lo que falta. Es la base de varios puntos de abajo.

Falta que un gaffer trabaje sin un director de foto que monte el proyecto. Propuesta para validar en la película:
- [ ] **Proyecto del gaffer:** propietario con rol gaffer; importa el guion y el plan de rodaje y empieza por luz y material, sin la biblia.
- [ ] **Inicio para gaffer:** plantas de luz por escena, material eléctrico, carga y jornadas.
- [ ] **Material eléctrico por jornada:** lo que piden las plantas frente a lo reservado (DR.7 visto desde el gaffer). **[Mac]** Parte de la hoja de material del PDF: hay que llevarla a una pantalla viva.
- [ ] **Carga y distribución:** vatios y amperios por circuito, grupo y línea, con el consumo real de cada aparato (hoy el catálogo solo trae `powerW`).
- [ ] **Fotometría del catálogo:** completar los focos que se usen en la película (hoy 7 de 98).
- [ ] **DMX:** universo, dirección y modo por aparato, y hoja de patch.
- [ ] **Prelight:** plantas y listas por set con estado (montado, probado, recogido).
- [ ] **Hoja del gaffer por jornada:** planta, focos, circuitos, DMX y notas en un PDF. **[Mac]** Debe usar los focos por plano y la luz en caliente del plan JP: rótulos «2 · 50 % → 100 %».
- [ ] Si luego entra el director de foto, que se una al proyecto sin rehacer nada.

## P2 · Mejora continua

En paralelo a P1; el orden lo deciden las pruebas: lo que falle o falte en rodaje sube arriba.

### Revisión pantalla a pantalla

Se recorre cada pantalla en Mac, iPad e iPhone (y Windows donde se use), de lo que más se usa en rodaje a lo que menos, y se mira lo mismo en todas:
- **Rendimiento:** tiempo al abrir y al editar, tirones al desplazar o arrastrar.
- **Usabilidad:** que se entienda sin explicaciones, cuántos toques cuesta lo habitual, atajos y deshacer.
- **Funcionalidad:** que haga lo que promete, errores y casos raros, lo que falta para el trabajo real.
- **Estética:** coherencia con el resto, modo oscuro y legibilidad en rodaje.
- **Tamaños:** que quepa y se use bien en iPhone, iPad y escritorio.

Pantallas, en `lib/features/` salvo que se indique:

| N.º | Pantalla | Archivo principal | Estado |
|---|---|---|---|
| 1 | Proyectos | `projects/projects_screen.dart` | Sin revisar |
| 2 | Hub del proyecto | `project_hub/project_hub_screen.dart` | Sin revisar |
| 3 | Importar guion | `script_import/script_import_screen.dart` | Sin revisar |
| 4 | Guion técnico | `technical_script/technical_script_screen.dart` | Sin revisar |
| 5 | Planta de cámara y luz | `camera_plan/plan_workspace_screen.dart` | Sin revisar |
| 6 | Alzado de la planta | `camera_plan/plan_elevation_screen.dart` | Sin revisar |
| 7 | Storyboard | `storyboard/storyboard_screen.dart` | Sin revisar |
| 8 | Hoja de bocetos | `lib/shared/annotations/sketch_sheet_screen.dart` | Sin revisar |
| 9 | Documentos de rodaje | `shoot_documents/shoot_documents_screen.dart` | Sin revisar |
| 10 | Jornada y En set | `shoot_documents/shoot_day_screen.dart` | Sin revisar |
| 11 | Calendario de rodaje | `shoot_documents/shoot_calendar_screen.dart` | Sin revisar |
| 12 | Importar plan de rodaje | `shoot_documents/import/shoot_plan_import_screen.dart` | Sin revisar |
| 13 | Editor de documentos y plantillas | `shoot_documents/shoot_document_editor_screen.dart` | Sin revisar |
| 14 | Equipo y ficha de equipo | `equipment/equipment_screen.dart` | Sin revisar |
| 15 | Importar reservas de alquiler | `equipment/rentals/rental_import_review_screen.dart` | Sin revisar |
| 16 | Localizaciones | `locations/locations_screen.dart` | Sin revisar |
| 17 | Optics Lab | `optics_lab/optics_lab_screen.dart` | Sin revisar |
| 18 | Calculadora de almacenamiento | `storage_calculator/storage_calculator_screen.dart` | Sin revisar |
| 19 | Biblia visual y moodboard | `visual_bible/visual_bible_screen.dart` | Sin revisar |
| 20 | Centro de exportación | `export_center/export_center_screen.dart` | Sin revisar |
| 21 | IRIS Stage (3D) | `iris_stage/iris_stage_screen.dart` | Sin revisar |
| 22 | Importar de Artemis | `artemis_import/artemis_import_screen.dart` | Sin revisar |
| 23 | Ajustes | `lib/core/settings/settings_center_screen.dart` | Sin revisar |
| 24 | Cuenta y primer arranque | `auth/auth_screen.dart` | Sin revisar |
| 25 | Unreal: biblioteca y guía | `unreal_link/unreal_library_screen.dart` | Sin revisar |

Las pantallas de la biblia V2 congelada no se revisan: se decide si se borran.

**[Mac] Pruebas en dispositivo que ya estaban pendientes**, para hacerlas en esta revisión:
- [ ] Orden de rodaje por duraciones con ratón y con dedo (G13). [PLAN_ACCION]
- [ ] El storyboard dibujando en el iPad real, sin que se cierre. [plan storyboard]
- [ ] Botones de imagen de portada y fondo del centro de exportación. [PDF de planta legible]
- [ ] Plan JP en la app:
  - jornada con dos localizaciones;
  - ampliar planta y storyboard;
  - PDF con luz grande y con cámara grande;
  - quitar un foco en el plano 2, luz en caliente y plano 3 heredando actores. [plan JP]
- [ ] Calendario con el dedo en iPad e iPhone; lector de PDF con un plan real. [DR]

### Colaboración completa [plan de colaboración, fases 1–7]
- [ ] **Planta y luces por elemento:** mezcla por uid y campo dentro de `planJson` y `floorPlanJson`, uid en `CameraPlanElements` y pantalla «Cambios descartados». Incluye A1 de F6.20.
  - **[Mac]** El plan R ya hizo lo mismo con las jornadas: copiar su forma. Uid de relleno igual en todos los equipos (`ShootUids`), mezcla solo si las bases coinciden y JSON clave a clave.
- [ ] Autoría por persona y roles por proyecto (director de foto, director, gaffer, 1.º ayudante de cámara, auxiliar de cámara, 1.º ayudante de dirección), todos con «editar todo».
- [ ] Bloqueo por elemento y presencia en la planta, con movimientos en vivo.
- [ ] Comentarios anclados y aprobación de planos.
- [ ] Transporte por pieza (`project_entities` y `push_changes`) cuando la prueba con tres personas lo pida.

### Flujo guion ↔ planta [plan de mejora, FL]
- [ ] Contexto compartido también en Storyboard (FL.3).
- [x] Pasar de plano sin reconstruir el editor (FL.6). El editor sigue montado y solo lee el plano nuevo; el 3D no recarga su visor, y el zoom y las imágenes se quedan como estaban. Una lectura que llega tarde no pisa a la nueva. (paquete de optimización)
  - Medido el 2026-11-22 con KEBAB (escena 10, 61 planos): leer el plano nuevo cuesta unos 30 ms de consultas en el hilo de la base (equipo y reparto, 23 ms; las cámaras de los demás planos, 1 ms). No compensa guardarlo en caché.
- [ ] Vista partida guion | planta en Mac e iPad ancho (FL.8).
- [ ] **[Mac] Ventanas aparte (RP fases 3 y 4):**
  - guion, planta o 3D en otra ventana, para trabajar a dos monitores, con `desktop_multi_window` y base compartida (`DriftIsolate`), tras una prueba técnica;
  - falta decidir si la segunda ventana sigue sola al plano abierto. [plan RP]

### Documentos de rodaje [DR, RC, RJ]
- [x] **[Mac]** DR.6: identidad y mezcla por elemento (v1.13.0).
- [ ] Orden del día dentro del centro de exportación. [DR, resto de la Tanda 1]
- [ ] **Lista maestra de material (DR.7 / RJ · M):**
  - junta reservas, líneas propias y lo que piden las plantas, con «falta por reservar»;
  - **[Mac]** detalle del plan RJ: sin tabla paralela, con `rental_items` como único almacén y las líneas propias en una reserva `kind='own'`;
  - columnas de departamento, proveedor, jornadas, estado e imagen;
  - vista por departamentos con filtros;
  - exportar a Excel, PDF y Word;
  - adjuntar los PDF originales, con aviso porque llevan DNI.
- [ ] Pack por jornada en un PDF (DR.8), plantas en papel blanco (DR.9), acabado común (DR.10), recordatorios de citación e importar `.ics` (DR.11).
- [ ] **[Mac] Calendario de rodaje (RC · K y RJ · K2):**
  - `calendar_events` para lo que no es de una jornada (prelight, visita técnica, pruebas de cámara);
  - horarios de citación, fin y prelight por jornada;
  - mover arrastrando escribe en su origen;
  - Google Calendar en los dos sentidos, más adelante.
- [ ] **[Mac] Centro de control con PDFs publicados (RC · C):**
  - «Publicar en rodaje» junto a exportar, con versión, alcance y tres versiones guardadas;
  - visor pdfrx y copia local para abrirlos sin red en los cuatro sistemas.
- [ ] **[Mac] La jornada en el resto del proyecto (RJ · J7):** etiqueta «J1 · 3» en cada plano y filtro por jornada en Storyboard y Plantas.
- [ ] **[Mac] Herramientas de jornada (RJ · R+):** fotos y adjuntos propios de cada jornada, planta vinculada a la jornada, hoja de citación en PDF (horarios, localización, tiempo y contactos) y contactos de equipo.
- [ ] **[Mac] Reservas desde Excel y Word (RC · E2):** vínculo al catálogo con `_resolveEquipmentId` y añadir a `ProjectEquipment` con una acción expresa.
- [ ] **[Mac] Planta del plano secuencia:** el recorrido entre zonas se sigue pintando encima de lo demás. [planta limpia]
- [x] **[Mac] Caché de las miniaturas de la tira de planos.** [plan JP, PL.6] Revisado el 2026-11-22: ya la cubre `PlanThumbnailCache` (R3), por contenido; las tarjetas de plano usan la portada con `cacheWidth`.

### iPhone [IP, IC, RC · M2]
- [ ] Consulta en set: plan del día, storyboard y edición ligera (IP.2).
- [ ] Fotos de localización y referencias desde la cámara (IP.3, IC.1).
- [ ] Resto de pantallas y diálogos a 390 pt (IP.5).
  - **[Mac]** La lista de RC · M2 da los sitios concretos: `storyboard_screen.dart:99,276`, `camera_plan_screen.dart:89`, `technical_script_screen.dart:207`, `shoot_days_board.dart:66`, `bible_canvas_editor.dart:571` y `hall_builder_sheet.dart:451`. Las líneas son de v1.7; hay que volver a buscarlas.

### Rendimiento y código [RD, Fase R]
- [ ] Terminar de partir `camera_plan_editor.dart` (RD.4).
  - **[Mac]** El plan JP sacó su código nuevo a `camera_plan_editor_light_use.dart` y paneles propios, pero el `State` sigue entero.
  - **2026-11-22:** la carga y la edición compartida pasan a `camera_plan_editor_load.dart`, y el guardado por capas a `camera_plan_editor_save.dart`. Después, tocar y arrastrar en el lienzo a `camera_plan_editor_gestures.dart`, y el teclado y el menú contextual a `camera_plan_editor_keys.dart`. El editor baja de 7.223 a 5.325 líneas. Queda dentro lo que construye la pantalla (`build`, barras y paneles) y la creación de elementos.
- [ ] Medir en perfil en Windows y en iPad (R7). WAL (R6) sube a P0. **R8 medido el 2026-11-22:** al soltar, la interfaz paga 15–50 ms; los 1,5 s eran el rasterizado por CPU del test.
- [ ] Sacar los textos a archivos de traducción; el inglés, al final de la beta.

### Equipo y biblia
- [ ] **Traer `plan/biblia-equipo-detalles` a main:** partes de cada pieza (las focales de un juego) e imagen de referencia. **[Mac]** Fuera de main queda 1 commit con 46 líneas en un solo archivo; es pequeño.
- [ ] Revisión de la biblia pantalla a pantalla con Daniel y segunda vuelta: Iluminación, Formato y Localización (Fases B y C). [PLAN_ACCION]

### Funciones avanzadas para uso propio

Daniel quiere el 3D, el escaneo, el catálogo y la biblia pulidos para sus proyectos. Lo que pide la película como gaffer va primero; Unreal, al final.

**3D e IRIS Stage** [ED, F6, CA]
- [ ] Probar el editor 3D (ED.0–5) y el visor three.js con hasta 40 luces (UN.7) en el Mac, el iPad y Windows; después, quitarles «Experimental».
- [ ] Actualizar `PLAN_F6_3D_PREVIS.md`: F6.12.4, F6.20 A1–E6, F6.21 y F6.22 están en main.
- [ ] CA.8: barra de bar y estanterías con botellas.
- [ ] Mar y costa con oleaje.

**Escaneo de localizaciones** [ES, IC]
- [ ] Cadena real iPhone → PC → vuelta con una casa de verdad (ES.E, IC.6, IC.7).
- [ ] Object Capture en el Mac como alternativa a RealityScan (ES.B).
- [ ] LiDAR con RoomPlan cuando haya iPhone o iPad Pro (ES.C), y escala con hoja de marcadores (ES.F).
- [ ] Paredes con textura real, muebles sustituidos y Unreal sin aberraciones (ES.4–ES.6); profundidad monocular en estudio (ES.7).
- [ ] Fotos de Artemis (IC.3) y «Enviar a IRIS» desde otras apps (IC.5, opcional).

**Catálogo y laboratorio óptico** [Fase 4, BACKLOG]
- [ ] Modos de sensor con códec, fps y relación de aspecto (4.3); laboratorio óptico con cobertura CUBRE / LÍMITE / RIESGO (4.4); pantalla Equipo con semáforo y fuentes (4.5).
- [ ] Rellenar los datos que faltan en el Excel del catálogo y la fotometría del resto de focos.
  - **[Mac]** El Excel no tiene columna RGB: hoy `PlanEquipment.isRgb` lo deduce del modelo y de llegar a 10.000 K.
- [ ] Cascada Equipo ↔ Biblia ↔ Format ↔ Lab.

**Biblia** [PLAN_ACCION]
- [ ] Disposición responsiva por punto (W5) y PDF de todos los widgets (W6).
- [ ] Concepto y su paridad en PDF; Referencias de cine (C3.3, C3.5); Cámara y Óptica desde el catálogo (C1, C2).
- [ ] Limpieza: Look Bible antiguo, BibleV2Host, stubs y el resto de V2 congelado que ya no se use.

**Windows** [PC]
- [ ] Aplazados (PC.2.3–PC.3.3): funciones solo de iPad, rutas absolutas del Mac, arrastrar y abrir con Iris, dónde vive la base y medios pesados.

### Unreal, al final [UN]

Cuando el resto de la app esté muy pulido.
- [ ] Probar dentro de Unreal: RGB de los focos (UN.1), cámara completa (UN.2), paquete `.irisstage` (UN.3) y materiales (UN.5).
- [ ] Fotometría real: IES en el catálogo y en Unreal (UN.4).
- [ ] Texturas PBR y HDRI CC0 en el visor, pendiente del visto bueno de Daniel (UN.6).
- [ ] Recorridos de cámara y actores en la planta, y luego Level Sequence (UN.8).
  - **[Mac] Ya no está bloqueado por falta de datos:** desde el plan JP la planta guarda posiciones por plano para cámaras, actores y focos (`PlanMarks`), con giro por posición y cambios de luz.

## P3 · Lanzar al público (en el futuro)

Sin fecha: se decidirá cuando la app esté pulida y probada en los proyectos de Daniel. Esto es una lista de partida, no un compromiso. Aquí empieza el gasto, unos 35–40 $ al mes, y el objetivo pasa a ser que cualquier director de foto instale Iris y trabaje sin ayuda.

**Distribución**
- [ ] Cuenta de desarrollador de Apple, TestFlight para iPhone y iPad, y Mac notarizado. [IP.6, PC.4.2]
- [ ] Windows firmado o en la Microsoft Store, con actualizaciones por instalador. [PC.4.2, PC.4.3]
- [ ] Volver a la versión anterior desde el actualizador. [FI.6]
  - **[Mac]** En el Mac ya se guarda la versión anterior en `…/com.example.irisDp/version-anterior`; falta el botón.

**Nube**
- [ ] Supabase Pro en región UE, con límite de gasto.
- [ ] Canales en vivo privados con autorización.
- [ ] Política de privacidad, borrado de cuenta y exportar un proyecto entero.

**Fiabilidad**
- [ ] Informe de fallos remoto optativo (decisión abierta). [FI.4]
- [ ] Copias con imágenes y archivo `.iris`. [FI.5]
- [ ] Lista de comprobación de Windows recorrida (`PRUEBA_WINDOWS.md`). [PC.5.1]
- [ ] Matriz de pruebas del núcleo en Mac, Windows, iPad y iPhone antes de cada versión.
  - **[Mac]** Incluir una actualización con migración de esquema y la app abierta: es lo que falló el 2026-11-19.

**Producto y legal**
- [ ] Ajuste «Experimental» que oculte el editor 3D, el visor three.js, Unreal y el escaneo real hasta probarlos.
- [ ] Arranque en 2 minutos: cuenta, primer proyecto y guion importado.
- [ ] «Enviar comentario» en la app, con versión, dispositivo y captura.
- [ ] Licencia comunitaria de Syncfusion registrada al arrancar.
- [ ] Confirmar que se pueden usar los datos de `assets/catalog`, los recursos de `assets/luka` y el nombre «Iris».

## Decisiones abiertas

Las de P0 y P1 bloquean trabajo ya; las de P3 esperan al lanzamiento.

| Decisión | Bloquea | Origen |
|---|---|---|
| Cómo traer `plan/invitados-control`: fusionar o rehacer sobre main. **[Mac]** Recomiendo rehacer, y su esquema pasa a 65. | P0 | rama IN |
| Fotos: Cloudflare R2 o Supabase Storage | P0 | Colaboración |
| **[Mac]** WAL en la base: con qué condición se activa si la base está en una carpeta elegida a mano | P0 | R6 |
| Qué entra en el modo gaffer antes de la película y qué se deja | P1 | Modo gaffer |
| Mismo campo cambiado a la vez: gana el primero o se pregunta siempre | P2 | Colaboración |
| Quién ve «Cambios descartados»: el autor o todos | P2 | Colaboración |
| Cuándo empieza el transporte por pieza | P2 | Colaboración |
| IA optativa con red: sí o no | P2 | Plan de mejora |
| Megascans «solo en Unreal» o también en el visor, si la licencia de Fab lo permite | P2 | Plan de mejora |
| Visto bueno a los packs CC0 de texturas y HDRI | P2 | UN.6 |
| **[Mac]** Luz RGB: un color saturado baja la salida según su luminancia (azul puro, unos −3,3 stops), y las gelatinas no tiñen la luz RGB, solo mueven la temperatura. ¿Se confirman? | P2 | Luz RGB |
| **[Mac]** Ventanas aparte: ¿la segunda ventana sigue sola al plano abierto? | P2 | RP |
| **[Mac]** Google Calendar en los dos sentidos: cuándo | P2 | RC · K |
| Notarizar el Mac (cuenta de pago) o seguir con firma local y huella | P3 | Plan de mejora, PC.4.2 |
| Windows: certificado OV/EV, Microsoft Store o sin firma | P3 | PC.4.2 |
| Informe de fallos remoto: sí o no | P3 | Plan de mejora |

**[Mac] Decidido por el camino:**
- Las marcas de En set se quedan dentro del JSON del bloque, sin columnas: la mezcla clave a clave ya las protege. [plan R]
- El visor de referencias del plano conserva sus funciones propias en vez de delegar en el visor común. [plan JP, J.1]

## Planes de origen

| Plan | Clave | Qué queda | Prioridad |
|---|---|---|---|
| `docs/PLAN_MEJORA_2026-11.md` | FL, FI, RD, ES, UN, ED | Fiabilidad, flujo y lo que falta probar | P0–P3 |
| Plan técnico de colaboración | Fases 0–7 | Canal, bloqueos, roles, mezcla por elemento, nube y costes | P0–P2 |
| `plan/invitados-control` (rama) | IN | Acceso, mantenimiento, versión mínima y cupo; esquema a 65 | P0 |
| `docs/PLAN_DOCUMENTOS_RODAJE.md` | DR | Restos de la Tanda 1 y DR.7–DR.11 (DR.6 hecho) | P1–P2 |
| **[Mac]** `~/.claude/plans/pasted-content-id-e886-…md` | RC, RJ | Trigger de versión, K, C, M2, E2, J7 y R+ | P0–P2 |
| **[Mac]** `~/.claude/plans/respecto-a-la-pantalla-snug-valiant.md` | JP | Caché de miniaturas y pruebas en dispositivo | P2 |
| **[Mac]** Plan RP (notas del Mac) | RP | Ventanas aparte, fases 3 y 4 | P2 |
| `docs/PLAN_IPHONE.md` | IP | IP.2, IP.3, IP.5 e IP.6 | P2, P3 |
| `docs/PLAN_IPHONE_CAPTURA.md` | IC | IC.3, IC.5, IC.6 e IC.7 | P2 |
| `docs/PLAN_IRIS_PC.md` | PC | Firma, actualizador y aplazados | P2, P3 |
| `docs/PLAN_ACCION.md` | Fases 1, 4, 5, B, C, R | Biblia, catálogo, limpieza y rendimiento | P0 (R6), P2 |
| `docs/PLAN_F6_3D_PREVIS.md` | F6 | Actualizar el tablero y probar en dispositivos | P2 |
| `docs/PLAN_ESCANEO.md` | ES | Prueba real y ES.4–ES.7 | P2 |
| `docs/PLAN_CALLE_3D.md` | CA | CA.8 | P2 |
| `BACKLOG.md` | — | Cascada de equipo y datos del Excel | P2 |
| `plan/biblia-equipo-detalles` (rama) | — | Partes de equipo e imagen de referencia | P1, P2 |

**Sin trabajo pendiente propio:**
- `docs/ANALISIS_Y_PLAN_2026-10-15.md` y `docs/BIBLE_V2_IMPLEMENTATION_AUDIT.md`;
- las ramas `cursor/*`, `wip/*`, `plan/docs-sync-archivos` y **[Mac]** `plan/bocetos-planta-nube`: conviene revisarlas y borrarlas;
- **[Mac]** los planes ya cerrados de `~/.claude/plans`: EX, SV, sets desde localización, IN (vive en su rama), storyboard, planta limpia y quitar SideStore. Están en main o en sus planes de `docs/`.
