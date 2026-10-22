# Análisis de IRIS DP y plan de trabajo

15 de octubre de 2026. Analizado sobre `plan/b1-biblia-pantallas` (la rama más avanzada: contiene l12, g1 y t1; no contiene l13) y comprobado también en `plan/l12-mapa-de-luz`. Las líneas citadas son de b1.

## 1. Foto general

| | |
|---|---|
| Tamaño | 523 archivos Dart, ~220.000 líneas (61.000 generadas por Drift) |
| Base local | Drift, schema 46, 36 tablas |
| Tests | b1: **789 pasan, 0 fallan**, 4 omitidos. l12: 608 pasan, **4 fallan** (tests de Iluminación sin actualizar) |
| Analizador | b1: 123 avisos, 0 errores (36 warnings). l12 con cambios sin commit: **2 errores de compilación** en `lighting_diagram_editor.dart` (falta el caso `pencil` del trabajo de anotaciones en curso) |
| `main` | Último commit el **11 de septiembre**. b1 va 124 commits por delante. La versión publicada (1.0.19) no tiene nada de este mes, tampoco el arreglo de pérdida de datos al sincronizar |
| Ramas | 25+ ramas `plan/*` locales sin fusionar, 3 carpetas de trabajo a la vez |
| CI | Solo corre en `main`: **ninguna rama de este mes ha pasado por CI** |

Lo bueno: el motor de luz, la biblia y la sincronización por huellas están bien cubiertos por tests; Supabase tiene RLS correcto por propietario/miembro; la importación de un proyecto desde la nube es todo o nada y deja copia de la base antes.

## 2. Fallos encontrados

Ordenados por gravedad. **Crítico** = puede perder datos del usuario.

### Críticos

**F1. La cola de subida se salta los conflictos y pisa la nube.**
`sync_engine.dart` marca los conflictos como «saltar» y luego llama a `CloudSyncQueueService.processPending()`, que sube el contenido local de **todo** proyecto con una entrada en la cola (`touchProjectContent` crea una en cada edición), sin mirar si estaba en conflicto. Resultado: la versión de la nube que el usuario debía elegir queda sustituida y la huella base se guarda como «sincronizado». Anula la garantía de la Fase 2.0.

**F2. Subir no comprueba que la nube siga igual.**
`ProjectContentSyncService.upload` hace un `upsert` a ciegas. Si otro dispositivo sube entre «preparar» y «aplicar», su versión se pierde sin aviso.

**F3. Los planos pierden datos al sincronizar.**
El bundle (v4) no lleva `shutterAngle`, `fps`, `description`, `autoNumbering` ni `cameraPlanImagePath` de `Shots`. Tampoco entran en la huella, así que cambiarlos ni siquiera marca el proyecto como modificado. (Es la 2.1 del tablero, sigue abierta.)

**F4. Imágenes identificadas por su posición.**
Las claves de medios son `moodboard:<grupo por orden y nombre>:<orden>` (`media_entity_keys.dart`) y el `publicId` de Cloudinary sale de lo mismo. Reordenar o renombrar un grupo vuelve a subir las imágenes con otra clave, y dos imágenes con el mismo orden comparten clave: una pisa a la otra en la nube y otro dispositivo descarga la equivocada. (Es la 3.1 del tablero.)

### Altos

**F5. Migraciones que fallan al actualizar desde versiones antiguas.**
`onUpgrade` crea tablas con `createTable` (que usa la definición *actual*, con todas las columnas) y en pasos posteriores les añade columnas con `addColumn`. Desde schema < 14 la migración rompe con «duplicate column» (cameras, lenses, lights, visualBibles, moodboardImages, lightingSetups…). Ya pasó algo parecido con columnas sobrantes en `location_sites`.

**F6. No hay copia de la base antes de migrar.**
Solo se copia antes de descargar de la nube. Las copias `antes-de-capas-…` las han hecho las sesiones a mano.

**F7. La cola de imágenes se atasca o se rompe.**
En `media_upload_queue.dart`:
- una subida cortada (app cerrada) queda en `processing` para siempre: el worker solo coge `pending`;
- tras un fallo definitivo se inserta otra fila con la misma clave y la siguiente vez `getSingleOrNull` lanza «too many elements»;
- no hay forma de reintentar las fallidas desde la app;
- la espera entre reintentos bloquea el lote entero.

**F8. Cambiar de tema reinicia la app.**
`main.dart` pone `key: ValueKey(themeMode)` en `MaterialApp` y lanza `_bootstrapApp()` dentro de `build`. Cambiar claro/oscuro desmonta todo: vuelve el splash, se vuelve a Proyectos y se pierde lo que estuviera abierto. Además el tema no se guarda: siempre arranca en oscuro.

**F9. Exportar puede romper si un plano apunta a una escena que no está.**
`project_content_bundle.dart:200` y `:612` usan `scenes.firstWhere` sin `orElse`. Hay 22 `firstWhere` así en total (la primera cuenta, 55, era por línea y contaba los que tienen `orElse` en la línea siguiente).

### Medios

**F10. Sin captura global de errores.** No hay `FlutterError.onError` ni `PlatformDispatcher.onError`: un fallo en producción no deja rastro.
**F11. Blobs ilegibles que se reescriben vacíos.** Hay 51 `catch (_) {}` vacíos. Varios leen un JSON, devuelven `{}` si falla y después escriben encima (p. ej. `formatData` en `reconcile…` de `app_database.dart`). Un JSON dañado se convierte en datos borrados en silencio.
**F12. PDF con imágenes a tamaño completo.** `visual_bible_pdf_service.dart:893` carga las imágenes del moodboard sin reducir (`loadFromPath` en vez de `loadFromPathMaxEdge`): PDFs enormes y riesgo de memoria en iPad.
**F13. Uso de `context` tras `await`** en `lighting_section.dart` (aviso del analizador).
**F14. Carpeta de l12 sin compilar** por el trabajo de anotaciones a medias (ver tabla). No es un fallo publicado, pero bloquea los tests de esa carpeta.

## 3. Deuda técnica y mejoras

**Arquitectura**
- `core` importa `features` (`project_content_bundle.dart` → `camera_plan/shot_route.dart`).
- 145 archivos de `features` usan `AppDatabase` directamente; los repositorios son pocos.
- Archivos gigantes: `camera_plan_editor.dart` (~4.500 líneas), `app_database.dart` (~4.300), `visual_bible_pdf_service.dart` (~2.600), varias secciones de la biblia entre 1.700 y 2.300.
- Estado en `SharedPreferences` que debería ir en la base y sincronizarse (estilos, huellas de sync, anotaciones resueltas; 2.2 del tablero).

**Rendimiento**
- El mapa de luz se recalcula en el hilo principal (pasada fina a los 280 ms): candidato a isolate, sobre todo para iPad.
- `notifyProgress` de la cola trae todas las filas tres veces solo para contarlas, y las filas `done` no se borran nunca.

**Producto (alineado con el tablero)**
- Exposición, Cámara, Óptica y Formato siguen rellenándose con diálogos (`_prompt`), justo lo que se decidió quitar; además crean controladores de texto que no se liberan.
- Secciones técnicas con valores de ejemplo en vez del equipo del proyecto (4.6).
- Fallos de subida de imágenes invisibles para el usuario.

**Calidad del código**
- ~20 funciones y variables sin usar (sobre todo en Iluminación, storyboard, almacenamiento).
- APIs obsoletas: `DropdownButtonFormField.value`, `onReorder`.
- Los tests importan el paquete `supabase` sin declararlo.
- 4 logs `flutter_0X.log` y carpetas `.venv_*` en la raíz.

## 4. Plan de trabajo

Cada punto es un PR pequeño con `flutter analyze` y `flutter test` en verde, como el resto del tablero.

### Fase 0 — Poner orden (antes de nada)

- [x] **0.1 Consolidar ramas.** Hecho en `integracion/2026-10` (b1 + l13), pendiente de llevar a `main`. Las ramas `cursor/*` y `wip/*` antiguas no se fusionan (V2 congelado o borradores de agosto). Acordar qué rama es la base (b1 lo contiene casi todo), fusionar l13 en ella y llevarla a `main`. A partir de ahí, ramas cortas desde `main`.
- [x] **0.2 CI en todas las ramas** (`push` a cualquier rama y PRs), para que nada llegue a `main` sin tests.
- [ ] **0.3 Una carpeta por sesión.** Cada sesión trabaja en su propio worktree; nadie en la carpeta principal salvo para fusionar.

### Fase A — Corregir fallos (por gravedad)

- [x] **A1. Conflictos respetados en la cola (F1).** También se quitó la subida de contenido escondida en «actualizar datos del proyecto». Antes de subir desde la cola, rehacer la decisión por huellas; si hay conflicto o cambios en la nube, no subir y dejarlo para la revisión. Test: proyecto en conflicto + entrada en cola → la nube no cambia.
- [x] **A2. Subida condicionada (F2).** Subir solo si el `content_hash` de la nube es el de la base (comprobación en la consulta o función RPC); si no, devolver conflicto.
- [x] **A3. Bundle v5 con los planos completos (F3).** Incluye localización y set de los esquemas de luz de la biblia. El test de columnas cubre `Shots`; queda extenderlo al resto de tablas. Añadir los campos de `Shots` que faltan y meterlos en la huella. Test de ida y vuelta que compare **todas** las columnas de cada tabla del bundle, para que no vuelva a pasar con columnas nuevas.
- [x] **A4. Copia automática antes de migrar (F6).** Ya existía para el esquema 45; ahora para toda subida de esquema, con las tres últimas copias. Si la versión de la base en disco es menor que `schemaVersion`, copia `antes-de-migrar-<versión>` antes de abrirla.
- [x] **A5. Migraciones a prueba de choques (F5).** Un `addColumnIfMissing` que mire `pragma table_info`, usado en todos los pasos; test que migre una base vacía de cada versión antigua disponible hasta la actual.
- [x] **A6. Cola de imágenes sana (F7).** Al arrancar, `processing` → `pending`; reutilizar la fila fallida en vez de crear otra; reintento sin bloquear el lote; botón «Reintentar subidas fallidas» y recuento de fallos visible.
- [x] **A7. Tema sin reinicio y guardado (F8).** Al probarlo, Daniel decidió quitar el tema claro: la app es solo oscura. Quitar la `key` del `MaterialApp`, crear el futuro de arranque una sola vez y guardar el tema.
- [x] **A8. `firstWhere` seguros (F9)** en sync y export primero; el resto, al tocar cada archivo.
- [x] **A9. Errores con rastro (F10).** Registro en `iris_dp/logs/` y «Compartir registro de errores» en Ajustes. Captura global que escriba en un log local rotativo, con opción de enviarlo.
- [x] **A10. Blobs dañados no se pisan (F11).** Hecho en las pantallas de la biblia (el punto común de guardado); quedan los blobs de otras tablas. Si un JSON no se puede leer, no se escribe encima: se guarda aparte y se avisa.
- [x] **A11. PDF con imágenes reducidas (F12)** y caché de imágenes durante una exportación.
- [x] **A13. Huella estable entre versiones.** `hashBundle` usa `String.hashCode`, que no está garantizado entre versiones de Dart ni plataformas y es de 32 bits. Pasar a SHA-256 (ya está `crypto`) con transición: comparar las huellas guardadas con el método antiguo hasta la siguiente sincronización.
- [ ] **A12. Avisos del analizador a cero** (hecho fuera de las zonas en obras: de 73 a 57 en `lib/`; el resto, al cerrar las sesiones de biblia, planta y anotaciones) en `lib/` (F13, código muerto, APIs obsoletas, dependencia `supabase` de los tests).

### Fase B — Mejoras de funcionamiento

- [x] **B1. Identidad estable de escenas, planos e imágenes (F4, 3.1 del tablero).** Hecho el 2026-10-16 (schema 47, bundle v6). Probado con la base real: 142 de 146 imágenes se reconocieron por contenido sin volver a subirse. Los demás equipos (iPad) deben actualizarse. `uid` en `Scenes`, `Shots` y `MoodboardImages`; claves de medios y `publicId` por `uid`; migración que mantenga lo ya subido.
- [x] **B2. Lo que vive en `SharedPreferences` pasa a la base (2.2).** Hecho el 2026-10-16 (schema 48): huellas de sincronización y catálogo propio del moodboard. Los metadatos de las imágenes ya estaban en la base (`metaJson`). Estilos de sección, blueprint y preset de PDF son restos sin uso: a la limpieza de la Fase 5. Lo demás son preferencias de este equipo y se quedan.
- [x] **B3. Estado de sincronización a la vista.** Hecho el 2026-10-16 como tarjetas de proyecto nuevas (esquemas 49 y 50): grandes, con anillo de preparación, barras de avance, estado de la nube en pastilla y color, tamaño, imagen y datos elegibles por proyecto. Por proyecto: al día / cambios por subir / conflicto / imágenes pendientes o fallidas.
- [ ] **B4. Secciones técnicas sin diálogos y con datos reales (4.6 + 1.5).** Exposición, Cámara, Óptica y Formato con edición directa, leyendo el equipo del proyecto.
- [ ] **B5. Mapa de luz fuera del hilo principal**, con medición en iPad.
- [ ] **B6. Partir los archivos gigantes**, empezando por `camera_plan_editor.dart` (ya previsto en P3) y `app_database.dart` (DAOs por área). Sin cambiar comportamiento, con los tests como red.
- [ ] **B7. Repositorios** para Proyectos, Escenas/Planos y Localizaciones, y quitar la importación `core → features`.

### Fase C — Refinamiento

- [ ] **C1. Pasada visual pantalla a pantalla** (lo que ya hace Daniel en la biblia), extendida a Proyectos, Equipo, Guion y Planta.
- [ ] **C2. Coherencia de textos:** todo en castellano y con el vocabulario acordado (quedan títulos en inglés en Exposición: «SOURCE INTENSITY», «Badge de escena»…).
- [ ] **C3. Estados vacíos y de carga** uniformes, mensajes de error que digan qué hacer.
- [ ] **C4. Atajos y accesibilidad:** atajos de teclado documentados, tamaños táctiles en iPad, contraste en tema claro.
- [ ] **C5. Limpieza del repositorio:** logs y `.venv_*` fuera, V2 y Look Bible antiguo según la Fase 5.
- [ ] **C6. Rendimiento percibido:** arranque, apertura de la biblia con muchas imágenes y PDF de ~20 páginas medidos en iPad.

### Fase D — Trabajar a la vez desde varios aparatos (tiempo real)

Idea de Daniel (2026-10-18), al estilo de Miro: lo que se edita en un equipo aparece solo en el otro, y lo que alguien está editando se ve bloqueado en los demás. Así no hay duplicados ni conflictos.

Ya hecho y que sirve de base: sincronización automática (al volver, cada minuto y 5 s después de editar), mezcla por elemento con «gana la última edición» e historial de conflictos (`plan/sync-mezcla`).

- [ ] **D1. Presencia por proyecto.**
  - Un canal de Supabase Realtime por proyecto: qué equipos lo tienen abierto y en qué pantalla.
  - En la tarjeta y en la cabecera, «iPad aquí».
- [ ] **D2. Bloqueo de lo que se está editando.**
  - Al entrar a editar un plano, una escena, una planta o una sección de la biblia, el equipo avisa por el canal: «editando plano 3/2».
  - En los demás, ese elemento sale bloqueado, con el nombre del equipo, en solo lectura y con el borde del color del equipo.
  - El bloqueo se mantiene con un latido cada ~10 s. Caduca solo si el equipo se cierra o pierde la red (~30 s), y se suelta al salir del editor.
  - Lo bloqueado se puede abrir igualmente si se pide, y entonces se avisa al otro.
- [ ] **D3. Cambios en vivo.**
  - Escuchar `cloud_project_snapshots` (postgres_changes): cuando el otro sube, este equipo baja y mezcla en segundos, sin esperar al minuto.
  - La subida tras editar pasa de 5 s a ~1–2 s mientras haya alguien más en el proyecto.
  - Lo que cambia se repinta sin recargar la pantalla. Opcional: un destello breve en lo recién llegado.
- [ ] **D4. Después, si hace falta:** filas por elemento en la nube (escenas y planos en tablas propias) en vez de un único snapshot por proyecto. Así se suben y bajan solo los cambios. Solo merece la pena si D3 se nota lento con proyectos grandes.
- Decisiones abiertas para Daniel:
  - qué se bloquea: plano entero, campo o pantalla;
  - si un bloqueo se puede forzar;
  - si la presencia se ve también fuera del proyecto.
- Requisito: Realtime activado en Supabase para `cloud_project_snapshots` y un canal de presencia; no hace falta guardar los bloqueos en la base.

## 5. Orden recomendado

1. Fase 0 (sin ella, todo lo demás se pierde entre ramas).
2. A1–A3 juntos: son los que pueden borrar trabajo de alguien, y conviene una sincronización real con Daniel delante después.
3. A4–A7, luego el resto de la Fase A.
4. B1 lo antes posible dentro de la Fase B: cuanto más tarde, más imágenes subidas con claves por posición.
5. Fase C en paralelo a las secciones de la biblia que ya están en marcha.

## 6. Visto en la primera sincronización real (2026-10-15/16)

- [x] Cada sincronización volvía a subir todas las imágenes. Arreglado.
- [x] 30 subidas fallidas de un proyecto borrado en agosto (y restos de otros dos). La cola los descarta.
- [x] La copia antes de migrar reutilizaba una vieja de la misma versión. Ahora lleva el día.
- [ ] Las builds de otras ramas (l12, l13…) abren la base y rebajan su versión: conviene que todas las sesiones fusionen `main` cuanto antes.
- [ ] Error de interfaz repetido en bucle: «ListTile background color or ink splashes may be invisible» (un ListTile sin Material debajo). Llena el registro de errores.
- [ ] La cola local guarda las filas antiguas por posición junto a las nuevas por uid: limpiar las que ya tienen su par.

