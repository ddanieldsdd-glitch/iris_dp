# Plan IRIS en el iPhone (IP)

Objetivo: usar IRIS DP en el iPhone en rodaje y en localización, con la misma
base de datos y la misma sincronización (Supabase + Cloudinary) que el Mac, el
iPad y Windows. No es otra app: es la misma, con un diseño compacto para
pantallas de menos de 600 pt.

## Decisiones (Daniel, 2026-10-28)

- **Para qué**, por orden: 1) consultar storyboard y plan del día; 2) fotos de
  localización al moodboard y a las referencias; 3) ver la planta y el 3D;
  4) notas rápidas.
- **Edición ligera**: todo se puede consultar; se editan campos sueltos (plano
  hecho, notas, estado de la jornada) y se capturan fotos y notas. La edición
  seria (componer la planta, maquetar la biblia, importar guiones) sigue en
  Mac/iPad: en el iPhone esas pantallas se abren en lectura o avisan.
- **Tamaño de referencia**: 390 × 844 pt (iPhone 14/15/16). Se comprueba
  también 375 (SE/mini) y 430 (Pro Max), y el iPhone en horizontal
  (844 × 390: ancho «medio», alto muy justo).
- **Distribución**: la misma que el iPad, SideStore con el .ipa sin firmar del
  workflow de release (`docs/ipad_sidestore.md`). El proyecto iOS ya admite
  iPhone (`TARGETED_DEVICE_FAMILY = "1,2"`).
- Lo que no toca este plan: 3D/Unreal (`lib/features/unreal_link`,
  `iris_stage`, `rig/`, `viewer.js`; lo lleva F6, regla 5 «Móvil: ver y
  recorrer el set, calidad ligera») y `lib/core/sync` (sesión de Windows).

## Auditoría a 390 pt (2026-10-28)

Hecha leyendo el código y con pruebas de widget: la app no arranca en web
(drift sin wasm) y la de escritorio comparte la base de datos con las otras
sesiones.

| Pantalla | Qué pasa a 390 | Fase |
|---|---|---|
| Lista de proyectos | La cabecera (título + 3 iconos + «Nuevo grupo» + «Nuevo proyecto») se desborda ~370 pt. Las tarjetas ya se ajustan al ancho. | IP.1 ✅ |
| Hub del proyecto | Portada de 280 pt (un tercio de pantalla); margen de 32; tarjetas a una columna con aspecto 2.4 que se desbordan por abajo. No hay forma rápida de saltar entre módulos. | IP.1 ✅ |
| Diálogos | ~20 diálogos con `SizedBox(width: 340…1080)` dentro de un AlertDialog: a 390 solo caben 262. | IP.1 (helper) + cada fase |
| Documentos de rodaje (plan del día) | `ShootDocumentOnSetView` ya es una lista de lectura: casi vale. `shoot_day_screen` tiene una columna fija de 400; el selector de guion, 560. | IP.2 |
| Storyboard | Cuadrícula 3/2 columnas: baja a 1 bien, pero el export de fotogramas es un diálogo de 620. | IP.2 |
| Guion técnico | Tabla ancha con desplazamiento horizontal: usable pero incómoda; formulario de escena 600, importación 1180. | IP.2 (vista de lectura por plano) |
| Localizaciones | Por debajo de 960 ya cambia a lista/detalle, bien. `site_place` 460, diálogo de 360. Falta la cámara. | IP.3 |
| Moodboard / biblia | 65 000 líneas, 47 comprobaciones de ancho propias; diálogos de 280–640. Se consulta; no se maqueta en el iPhone. | IP.3 / IP.5 |
| Planta de cámara y luz | La pantalla de trabajo se desbordaba 503 pt (columna lateral de 300, o 44 plegada) y el editor 459 pt (~20 botones arriba). Diálogos de 380–1080 (hall builder). | IP.4.1 ✅ / IP.4 |
| 3D | Lo lleva F6. Aquí solo: abrir el visor en modo ligero desde la planta. | IP.4 (enganche) |
| Ajustes y cuenta | Secciones en lista: caben; revisar diálogos de cuenta. | IP.5 |

## Fases

### IP.1 · Base compacta y navegación ✅ (este PR)

- **IP.1.1** Corte «compacto» en `AppLayout`: `compactBreakpoint = 600`,
  `AppSizeClass {compact, medium, wide}`, `isCompact`, `gutter` (16 en
  compacto, 32 el resto) y `dialogWidth(context, preferido)` para que los
  diálogos de ancho fijo no se salgan.
- **IP.1.2** Barra inferior: `CompactNavShell` (`lib/core/widgets`). En el
  iPhone el hub del proyecto lleva abajo *Proyecto · Rodaje · Storyboard ·
  Planta · Localiz.*; cada pestaña se construye al visitarla y se conserva. En iPad y
  escritorio no cambia nada. La app no tiene barra lateral global: las
  barras laterales están dentro de plantas y localizaciones (IP.3/IP.4).
- **IP.1.3** Cabecera de proyectos compacta: los dos botones pasan a un «+»
  con menú; título más pequeño.
- **IP.1.4** Hub compacto: portada de 180, margen de 16, tarjetas de módulo
  más pequeñas que caben a una columna.
- Pruebas: `test/iphone/compact_layout_test.dart`, todo a 390 × 844.

### IP.2 · Consulta en set: plan del día y storyboard (prioridad 1)

- **IP.2.1** Documento del día a pantalla completa en el iPhone: abrir
  directamente el documento activo (`primaryDocument`) desde la pestaña
  *Rodaje*; `ShootDocumentOnSetView` con tipografía de lectura y bloques a
  ancho completo; quitar la columna fija de 400 de `shoot_day_screen`.
- **IP.2.2** Storyboard en compacto: una columna, deslizar entre planos,
  pellizcar para ampliar, ficha del plano (óptica, encuadre, notas) debajo.
- **IP.2.3** Guion técnico en lectura: lista de escenas → planos como tarjetas
  en vez de la tabla (la tabla queda para iPad/Mac).
- **IP.2.4** Edición ligera: marcar plano hecho / descartado y nota rápida
  sobre el plano; se sincroniza como cualquier cambio.
- **IP.2.5** Diálogos de estas pantallas con `AppLayout.dialogWidth` o como
  hoja inferior a pantalla completa.

### IP.3 · Cámara: fotos de localización y referencias (prioridad 2)

- **IP.3.1** Botón de cámara en la galería de la localización y en el
  moodboard: añadir `image_picker` (hoy no está en `pubspec.yaml`) con fuente
  cámara; `NSCameraUsageDescription` en `ios/Runner/Info.plist` (hoy solo
  está `NSPhotoLibraryUsageDescription`).
- **IP.3.2** Foto a referencias del plano (`shot_reference_gallery`) y al
  moodboard del proyecto, con nota y geolocalización opcional.
- **IP.3.3** Subida: la foto entra en el almacenamiento local y la sube
  `MediaSyncBinder` a Cloudinary como el resto (sin tocar `lib/core/sync`);
  compresión antes de subir para datos móviles.
- **IP.3.4** Localizaciones en compacto: detalle con galería a ancho completo;
  `site_place` y diálogo de 360 ajustados.
- **IP.3.5** Notas rápidas de localización (texto y, más adelante, voz).

### IP.4 · Planta y 3D en consulta (prioridad 3)

- **IP.4.1** ✅ (adelantado a petición de Daniel) Planta en compacto: el
  navegador de plantas sale en una hoja inferior (botón «Plantas») en vez de
  la columna lateral, y el lienzo ocupa todo el ancho. Arriba solo imagen,
  3D, encajar y «Más» (deshacer, rehacer, luz, exposición, lecturas,
  rótulos, imán, alzado, bocetos, asociar planos); guardar y añadir siguen
  en la barra de abajo. Vaciar la planta, atajos y ajustes se quedan para el
  iPad y el Mac. Pruebas: `test/iphone/plan_compact_test.dart`.
- **IP.4.2** Ficha del plano desde la planta: cámara, óptica, luces.
- **IP.4.3** Enganche con el visor 3D de F6 en calidad ligera (lo implementa
  F6; aquí solo el botón y la comprobación a 390).
- **IP.4.4** iPhone en horizontal (844 × 390): planta y storyboard
  aprovechan el ancho; barra inferior oculta para ganar alto.

### IP.5 · Resto de pantallas y pulido

- **IP.5.1** Biblia y moodboard en lectura (lookbook a una columna).
- **IP.5.2** Ajustes y cuenta: revisar diálogos y hojas.
- **IP.5.3** Pantallas de edición pesada (importar guion, componer planta,
  editar plantillas): aviso «mejor en el iPad o el Mac» con opción de
  seguir.
- **IP.5.4** Área segura, teclado y Dynamic Type en las pantallas de IP.2–IP.4.
- **IP.5.5** Barrido de diálogos con ancho fijo que queden (lista en la
  auditoría).

### IP.6 · Distribución

- **IP.6.1** Confirmar que el .ipa del workflow de release instala y arranca
  en iPhone con SideStore (mismo .ipa que el iPad: es universal).
- **IP.6.2** Iconos y pantalla de arranque de iPhone en `Assets.xcassets`.
- **IP.6.3** Apartado iPhone en `docs/ipad_sidestore.md` (o
  `docs/iphone_sidestore.md`): instalación, refresco cada 7 días, y el aviso
  de `SideStoreReminderBanner` también en el iPhone.
- **IP.6.4** Lista de prueba manual en el iPhone (como `PRUEBA_WINDOWS.md`).

## Cómo se prueba

- Pruebas de widget a 390 × 844 (`tester.view.physicalSize` con
  `devicePixelRatio = 3`) en `test/iphone/`: cada fase añade las suyas y
  comprueba que no hay desbordes (`tester.takeException()` nulo).
- En el iPhone real con SideStore al cerrar cada fase.
