# Plan de mejora de IRIS · noviembre 2026

## Contexto

Daniel pidió un repaso general de la app: ideas, fiabilidad, uso futuro, compatibilidad con Unreal / Fab / Megascans, escaneo de localizaciones con y sin LiDAR, y —añadido después— que pasar entre guion técnico y planta sea rápido e intuitivo, con planos y sets nuevos que nazcan acordes al anterior.

Se revisó `main` (copia local en v1.7.0; `origin/main` ya está en **v1.7.4**) y las ramas en curso. Respuestas de Daniel:
- **Primero, tras el rodaje (después del 18-11): el flujo guion ↔ planta.**
- LiDAR: todavía no hay, pero habrá iPhone Pro o iPad Pro → se diseñan las dos vías.
- Este documento es solo el plan: no se toca código hasta pasado el rodaje.

Las rutas y números de línea corresponden a v1.7.0 y pueden haberse movido; confírmalos antes de empezar cada bloque.

## Estado encontrado (resumen)

| Área | Hallazgo | Dónde |
|---|---|---|
| Flujo | Desde el guion se abre un editor suelto, sin tira ni ◀ ▶ ni vincular por gesto | `camera_plan/camera_plan_status_cell.dart:25-35` |
| Flujo | No hay camino de la planta al plano del guion | `TechnicalScriptScreen` solo recibe `projectId` |
| Flujo | El plano nuevo nace vacío: sin set, lente ni cámara | `technical_script_screen.dart:1171`, `storyboard_viewer.dart:71` |
| Flujo | «Set nuevo» crea un set vacío en los 4 puntos de entrada | `floor_plan_repository.dart:508` |
| Flujo | No hay «plano/escena/set actual» compartido; Plantas abre siempre en la primera escena | `camera_plan_screen.dart:46` |
| Datos | La versión del paquete no se comprueba al importar: un dispositivo antiguo puede pisar la nube | `project_content_bundle.dart:118, 1305` |
| Datos | Una fila por proyecto en la nube, sin historial | `supabase/migrations/007` |
| Datos | «Gana la última edición» depende del reloj del dispositivo | `content_merge_service.dart:54-63` |
| Datos | 261 `catch (_)`; cola de subida y borrados fallan en silencio | `project_content_sync_service.dart:276, 345` |
| Rendimiento | Cada minuto: baja todos los proyectos enteros y los re-exporta en el hilo de la interfaz | `sync_plan_builder.dart:182-201` |
| Rendimiento | Mapa de luz dentro de `paint()`; moodboard sin carga perezosa | `camera_plan_painter.dart:982`, `moodboard_stitch_shell.dart:417` |
| Actualizador | Sin checksum; Windows extrae el zip sin validar rutas y sin marcha atrás | `mac_auto_update.dart:166`, `app_update_installer.dart:79` |
| Unreal | Solo enlace en vivo; no hay paquete portable; RGB no se envía; sin IES; 16:9 forzado | `unreal_stage_payload.dart`, `iris_stage_link.py:280` |
| Escaneo | Cero código LiDAR; malla solo en PC con RealityScan; cadena sin probar en dispositivo real | `IrisCapturePlugin.swift`, `rig/scan_builder.dart` |
| Catálogo | 7 de 98 focos con fotometría; sin consumo real, peso ni modos DMX | `assets/catalog/lights.json` |
| Código | ~7.700 líneas de V2 congelado + ~6.000 sin referencias; `AI_CONTEXT.md` desfasado | `visual_bible/v2/` |

---

## FL · Flujo guion ↔ planta (primer bloque tras el 18-11)

Respeta lo ya decidido: capas por referencia, un solo lienzo, nada superpuesto, vincular por gesto.

- ✅ **FL.1 Una sola entrada a la planta.** `openShotPlan` abre `PlanWorkspaceScreen(initial: PlanTarget.shot(...))` en vez de `CameraPlanEditor.shot` suelto. Así el camino desde el guion tiene tira, ◀ ▶, cabecera de set y gestos.
- ✅ **FL.2 Volver al plano.** `TechnicalScriptScreen(initialShotId:)` + desplazamiento hasta la fila y resaltado (patrón de `StoryboardViewer(initialShotId:)`). Botón «Ver en el guion» en la tira y en cada plano de «Vinculada a N planos». Si se vino del guion, volver devuelve el plano en el que se acabó.
- 🟡 Guion y Plantas hechos; falta Storyboard. **FL.3 Contexto compartido.** Un `projectFocusProvider(projectId)` con escena, plano y set actuales, guardado en `PlanPrefs`. Plantas abre en la última escena, el guion en el último plano, Storyboard igual.
- ✅ **FL.4 El plano nuevo hereda del anterior.** «Añadir plano» (guion y storyboard) copia del plano anterior de la escena: `lightSetupId`, `locationBasePlanId`, lente y movimiento, y la cámara en su misma posición (`CameraLinks.setLinks` si era cámara de set; copia de `CameraPlanElements` si era propia). Ajuste global «Plano nuevo: como el anterior / en blanco». `_ensureLightSetup` deja de crear «Setup X» vacío sin preguntar: propone el set del plano anterior.
- ✅ **FL.5 Set nuevo acorde.** `pickLightSetupStart` gana «Como el set anterior» (vía `createLightSetupFrom(renewUids)`), además de «Luz de la localización» y «Vacío», y se usa en los 4 puntos de «Set nuevo». Escena nueva: `WhereField(initial:)` con el lugar de la escena anterior.
- 🟡 Atajos, tira y carga de la lista de planos hechos; que el editor no se reconstruya va con RD.4. **FL.6 Pasar de plano sin esperar.** Atajos ⌘← / ⌘→ (y en la hoja de atajos). El cambio de plano no reconstruye el editor: se separa la carga del proyecto (ya en `PlanProjectData`) de la del plano. En la tira, tocar siempre abre; vincular pasa a un botón explícito cuando hay cámara seleccionada.
- ✅ **FL.7 Quitar la puerta falsa.** `PlanEntryState.need` devuelve `none` si el plano ya tiene set, aunque la localización no tenga planta maestra.
- 🟡 Paleta ⌘K en guion y plantas hecha y ajuste muerto retirado; falta la vista partida guion | planta. **FL.8 Saltar a cualquier sitio.** Paleta ⌘K global (escenas, planos, sets, localizaciones) reutilizando el patrón de `bible_command_palette.dart`. Después, vista partida guion | planta en Mac e iPad ancho. Se retira el ajuste muerto «Cámaras de otros planos».

Comprobación: pruebas de widget por recorrido (plano→planta→plano; plano nuevo con set y cámara heredados; set nuevo desde el anterior) y recuento de toques antes/después: a) 2→1, b) sin camino→1, c) ~8→1, d) ~6→2, e) con teclado.

## FI · Fiabilidad de datos

- 🟡 Rechazar paquetes más nuevos ya está en `plan/rc-rodaje-control` (`assertReadable`), sin fusionar; la versión mínima en `app_releases` sigue pendiente porque exige cambiar Supabase. **FI.1 Versión de paquete (pequeño y crítico; primero junto a FL).** Al importar, rechazar un `bundleVersion` mayor que el conocido y no subir desde una app por debajo de la versión mínima publicada en `app_releases`. Antes, comprobar qué cubre ya el «P0.3 version guard» de la rama de rodaje.
- 🟡 Hecho en la app y en `supabase/migrations/013`; funciona cuando se ejecute esa migración en Supabase. **FI.2 Historial en la nube.** Tabla `cloud_project_snapshot_history` con disparador (últimas N versiones por proyecto) y pantalla «Restaurar versión».
- 🟡 `updated_at` lo pone el servidor y la mezcla corrige el desfase del reloj (`ServerClock`); necesita la misma migración 013. **FI.3 Reloj.** Decidir el ganador con hora del servidor o contador de revisión, no con `DateTime.now()` local.
- 🟡 Cola, borrados, copias y volcado de la base van a `ErrorLog` (sin los fallos de red); quedan las lápidas en la base (exige subir el esquema, choca con la rama de rodaje) y el lint por carpetas (el analizador no lo permite por carpeta). **FI.4 Errores a la vista.** La cola de subida y los borrados escriben en `ErrorLog`; lápidas de borrado a la base (hoy en SharedPreferences); lint `avoid_catches_without_on_clauses` por carpetas, empezando por `core/sync` y `core/database`. Envío de informe de fallos **solo si Daniel lo activa**.
- 🟡 Copia diaria, segunda carpeta en ordenador y pantalla de restaurar hechas; falta el archivo `.iris`, y las copias no incluyen imágenes. **FI.5 Copias.** Copia diaria automática, segunda ubicación elegible (iCloud Drive o disco), pantalla «Restaurar copia», y archivo de proyecto `.iris` para traspasar o archivar.
- 🟡 Huella, rutas del zip y copia de la versión anterior hechas; falta un botón para volver a ella (choca con la actualización automática) y notarizar. La huella necesita la migración 014. **FI.6 Actualizador.** SHA-256 en `app_releases` y comprobación antes de instalar; validar rutas del zip en Windows; conservar la versión anterior para poder volver. Notarización: decisión de Daniel (cuenta de desarrollador de pago).
- 🟡 Revisión al arrancar y en Ajustes, e instantánea del esquema 62. No hay instantáneas de versiones anteriores, así que las pruebas de migración por versión empiezan a partir de aquí. **FI.7 Base.** `PRAGMA integrity_check` y revisión de huérfanos al arrancar (informar, no borrar); instantáneas de esquema de Drift con pruebas de migración por versión.
- ✅ **FI.8 CI.** `tool/check_architecture.dart`, build de macOS en cada PR, avisos fatales por carpetas. Actualizar `AI_CONTEXT.md`.

## RD · Rendimiento y limpieza

- 🟡 Solo se baja el contenido de lo que puede haber cambiado y la huella se calcula fuera de la interfaz; la exportación local sigue en el hilo principal. **RD.1** Sync: comparar por hash y fecha sin bajar el contenido; hash local guardado y recalculado solo si algo cambió; exportación en isolate.
- ✅ El mapa fino va en otro hilo; el lienzo como imagen (R5) ya estaba. **RD.2** Mapa de luz en isolate (B5) y lienzo como imagen (R5).
- ✅ **RD.3** Moodboard perezoso con `cacheWidth`; `MediaOptimizer` en isolate.
- 🟡 Las clases de abajo pasan a archivos `part` (6.775 líneas quedan en el principal); el `State` sigue entero, y con él lo que falta de FL.6. **RD.4** Partir `camera_plan_editor.dart` (8.127 líneas), aprovechando FL.6.
- 🟡 Borrados 37 archivos (5.577 líneas) que nadie importa ni en la app, ni en pruebas, ni en otras ramas. V2 no se puede borrar entero: la biblia usa partes. Look Bible (pantalla) borrada. PHFX se queda: lo usa `tools/import_phfx_shotprep.py` y no entra en la app. Worktrees y ramas sin podar: hay sesiones que pueden estar usándolos. **RD.5** Fase 5: borrar V2, Look Bible, ~6.000 líneas sin uso, activos PHFX huérfanos, tarjetas «Próximamente» ya resueltas; podar worktrees y ramas fusionadas.

## ES · Escaneo de localizaciones

- 🟡 Hecho en Dart con pruebas sintéticas (`rig/scan_direct.dart`, botón «Sacar la planta de una captura» en el 3D); sin probar con una captura real, y la nube dispersa solo se usa para el suelo. **ES.A Sin LiDAR y sin PC: planta directa.** Un solucionador que saque muros, suelo y huecos solo de `capture.json` v2 (planos ARKit, marcas y nube dispersa) y los lleve a la revisión existente (`scan_review_sheet.dart`). Planta útil en el propio iPhone/iPad.
- **ES.B Reconstrucción en el Mac.** Motor alternativo a RealityScan con Object Capture (`PhotogrammetrySession`) en un plugin Swift de `macos/Runner`, usando la misma cola de `scan_jobs`. Prueba previa con una captura real para ver si la calidad en interiores compensa.
- **ES.C Con LiDAR (listo para cuando llegue el dispositivo).** `isSupported` detecta LiDAR y ofrece: RoomPlan → muros, puertas, ventanas y muebles directos a `reviewElements`; malla de `sceneReconstruction` y profundidad en un `capture.json` v3. Sin LiDAR, la app sigue por ES.A.
- **ES.D Aceptar USDZ.** Convertir en el Mac/iPad con ModelIO a un formato que el visor ya carga, para importar de Polycam, Scaniverse o RoomPlan.
- ⏳ Necesita el iPhone y el PC: protocolo en `docs/PLAN_ESCANEO.md`. **ES.E Probar la cadena real.** iPhone → PC → vuelta (E6, IC.6, IC.7) y ES.2/ES.3 con un escaneo de verdad; hoy solo hay pruebas sintéticas.
- **ES.F Escala.** Hoja impresa con marcadores para vídeo y gran angular 0,5× (E3). Profundidad monocular (ES.7) sigue en estudio.

## UN · Unreal, Fab y Megascans

- 🟡 Hecho en la app, el visor, el MVR y el script de Unreal; sin probar dentro de Unreal. **UN.1 RGB de los focos** a Unreal, al MVR y al visor 3D (hoy solo viaja la temperatura).
- 🟡 Alto de sensor, squeeze y actores (bloque con altura, orientación y pose) hechos, sin probar dentro de Unreal; sigue sin haber modo de cámara por elemento (se usa el sensor de la cámara) y un actor con modelo propio no cambia de pose. **UN.2 Cámara completa.** Alto de sensor y squeeze desde el modo del catálogo; fuera el 16:9 forzado; orientación, altura y pose de actores.
- 🟡 Paquete, botón en Exportar e `import_package` hechos, sin miniaturas ni USD; sin probar dentro de Unreal. **UN.3 Paquete `.irisstage` portable** (F6.16.1): escena v2 en unidades reales + estructura GLB + escaneos + miniaturas; el plugin lo importa sin enlace vivo. Después, valorar salida USD.
- **UN.4 Fotometría real.** Archivo IES por foco en el catálogo, usado por el motor de luz y asignado en Unreal; GDTF real en el MVR donde exista. Requiere rellenar el Excel (87 focos pendientes).
- 🟡 Las paredes con material llevan su reflectancia y su tinte al visor y al glTF de Unreal. Fab/Megascans por superficie y la comparación de lux necesitan Unreal delante. **UN.5 Materiales.** Fab/Megascans en paredes y suelos (F6.20 D3), tabla material IRIS ↔ material Unreal con reflectancia, y comparación de lux IRIS ↔ Unreal (F6.21.4).
- **UN.6 Ver algo parecido en Mac e iPad.** Packs CC0 (Poly Haven, ambientCG) con texturas PBR y HDRI en el visor, emparejados por tipo de superficie con el material de Unreal. A verificar: si la licencia actual de Fab permite cargar en IRIS el GLB que Daniel descarga con su cuenta (sin redistribuirlo); si es así, se revisa la decisión «solo dentro de Unreal».
- **UN.7 Base del visor** (F6.0): three.js moderno, más de 14 luces, luces de área; habilita splats reales.
- **UN.8 Level Sequence** a partir de recorridos de cámara y actores (F6.16.7).

## NF · Ideas de funciones nuevas (por valor)

1. Planificador eléctrico: consumo real, reparto por circuito, generadores (L7).
2. Patch DMX y MVR con direcciones (necesita modos DMX en el catálogo).
3. Biblioteca de sets y esquemas de luz reutilizables entre proyectos.
4. Sol real por fecha, hora y coordenadas de la localización (L9).
5. Hoja de citación y lista maestra de material (ya en el plan RC, tras el 18-11).
6. Roles de equipo (gaffer, foquista) con solo lectura real y PDF publicados por enlace.
7. Final Draft `.fdx` interpretado de verdad; EXIF de fotos → cámara y lente.
8. Parte de cámara: lo rodado frente a lo planificado, con exportación.
9. Deshacer en biblia, localizaciones y equipo.
10. Inglés y accesibilidad (texto dinámico, hoja de atajos global).
11. Ayudas con IA **optativas** (desglose del guion en planos propuestos, etiquetado de referencias): rompe la regla «sin red», decisión de Daniel.

## Orden propuesto

| Cuándo | Qué |
|---|---|
| Hasta el 18-11 | Nada de este plan: solo el plan RC del rodaje |
| 1 | **FL.1–FL.7** + **FI.1** |
| 2 | FI.2–FI.5, RD.1, FL.8 |
| 3 | ES.A, ES.E, UN.1, UN.2 |
| 4 | RD.2–RD.5, FI.6–FI.8, UN.3, UN.5 |
| 5 | ES.B–ES.D y ES.C al llegar el LiDAR, UN.4, UN.6–UN.8, NF |

Cada bloque va en su worktree y rama `plan/…`, con sus pruebas, y se instala en el iPad solo con aviso.

## Decisiones abiertas para Daniel

- Notarizar la app de Mac (cuenta de pago) o seguir con firma local más checksum.
- Informe de fallos remoto optativo: sí o no.
- IA optativa con red: sí o no.
- Revisar la decisión de Megascans «solo en Unreal» si la licencia de Fab lo permite.
