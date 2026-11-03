# Plan IC · Captura desde el iPhone (scouting, Artemis, 3D de la localización)

Propuesta del 2026-10-31; IC.1, IC.3 e IC.4 hechas el 2026-11-03 (sin commit).
IC.2 se recorta: main v1.4.0 (F6.20 E) ya trae la captura guiada del iPhone
(`ScanCaptureChannel`, `.iriscapture` en zip) y RealityScan sin interfaz en el
PC; aquí solo se enlaza desde la localización. Rama `plan/iphone-captura`
desde `origin/main` (v1.3.0, esquema 58). Amplía IP.3 de `PLAN_IPHONE.md`.

## Lo que ya hay

- **Localización** (`LocationSites`): `scanPath`, `scanSource`, `scanMetadataJson`,
  lat/long. **Set** (`LocationBasePlans`): `model3dPath`, `scanPath`, `floorPlanJson`.
  Los dos se sincronizan como archivo (Supabase Storage, ≤ 50 MB) por
  `media_slots.dart` (`site_scan`, `set_scan`, `set_model3d`).
- **Fotos**: `SiteImages` (localización) y `LocationImages` (set), con `kind`
  `scouting` ya previsto; van a Cloudinary reducidas a 3840 px y JPG 85.
- **Artemis**: `source = artemis_capture` ya existe en `ShotReferences` y
  `MoodboardImages`, pero la importación es un selector de archivos normal.
- **Plantas**: `LightSetups.locationSiteId / locationBasePlanId`; la planta del set
  en `LocationBasePlans.floorPlanJson`; escaneos en la planta como `PlanScan`
  (GLB/GLTF/OBJ/PLY, sin USDZ) con visor three.js en `InAppWebView`.
- **Falta**: cámara (no hay `image_picker`), vídeo (ni campo ni subida),
  permisos de cámara y micrófono, abrir el 3D en iOS (`openFileExternally` no hace
  nada), compartir desde otra app (sin Share Extension ni tipos de documento).
- En la pantalla de localización, «Modelo 3D · Importar glTF / USDZ» sigue como
  «próximamente» (`location_coming_soon.dart`).

## Fases

### IC.1 · Captura base (cámara, fototeca y archivos)
`image_picker` (foto, vídeo y selección múltiple de la fototeca) y permisos
`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`. Un único
«Añadir desde: Cámara · Fototeca · Archivos» reutilizable; en el Mac y Windows
sigue el selector de siempre. Botón de cámara en la galería de la localización y
del set, y en el moodboard (IP.3.1).

### IC.2 · Scouting para RealityScan (recortada)
**Hecho:** «Capturar con el iPhone» en el panel de scan de cada set: abre la
captura guiada de F6.20 E y comparte el `.zip` para el PC. Lo de abajo
(tabla `LocationCaptures`, vídeo, carpeta para RealityScan) queda aparcado
salvo que haga falta además de F6.20 E.

Propuesta original:
- Tabla nueva `LocationCaptures` (esquema 59): localización, set opcional, foto o
  vídeo, ruta, tamaño, duración, fecha y si entra en el escaneo.
- Sección «Scouting 3D» en la localización (y en cada set): cuadrícula con
  miniaturas de vídeo, contador (n.º de fotos, minutos, MB) y consejos breves
  de captura (solape, luz difusa, sin zoom).
- Las fotos se guardan **originales con su EXIF** (sin pasar por Cloudinary, que
  las recomprime): es lo que necesita la fotogrametría.
- «Preparar para RealityScan»: una carpeta `Scouting_<localización>_<fecha>` con
  fotos (JPG), vídeo y un `manifest.json`, enviada con la hoja de compartir
  (AirDrop, Archivos, Guardar en…). Encaja con F6.20 (captura sin interfaz en
  el PC).

### IC.3 · Fotos de Artemis
**Hecho:** botón «Importar de Artemis» en el Storyboard → fotos (cámara,
fototeca o archivos) → pantalla de reparto foto a foto: plano (pasa al
siguiente; «Repartir en planos seguidos»), moodboard con categoría, o
localización (galería + moodboard de la biblia en Localización). La referencia
de un plano suelto también usa cámara/fototeca en el iPhone. Pendiente: leer
óptica y cámara del EXIF (hace falta una foto de muestra de Artemis).

Propuesta original:
- «Importar de Artemis» (selección múltiple de la fototeca) y luego «¿A dónde va?»:
  - **Plano**: escena → plano, en `ShotReferences` con `artemis_capture`; con
    «siguiente plano» para repartir una tanda en orden.
  - **Moodboard**: grupo y categoría, en `MoodboardImages`.
  - **Localización**: la galería (`SiteImages` / `LocationImages`) y su moodboard
    (`MoodboardImages` enlazada a la localización).
- Si las fotos de Artemis traen óptica y cámara en el EXIF, se rellenan en la
  ficha del plano (hace falta una muestra para comprobarlo).

### IC.4 · Pantalla de localización: modelo 3D y plantas
**Hecho:** «Abrir 3D» funciona en iOS con Vista Rápida (USDZ en 3D y AR;
`IrisQuickLookPlugin.swift`), con la hoja de compartir si no lo sabe abrir.
Sección «Plantas de luz y cámara» en la localización (las suyas y las de sus
sets) con «Enlazar planta libre». Pendiente: pegar un enlace (Sketchfab,
Polycam…) y el visor GLB dentro de la ficha.

Propuesta original:
- La tarjeta «Modelo 3D» deja de ser «próximamente»: importar archivo (GLB,
  USDZ, OBJ o PLY) **o** pegar un enlace (Sketchfab, Fab, Polycam…).
- Ver: USDZ con AR Quick Look nativo en el iPhone y el iPad; GLB con el visor
  three.js que ya existe; en el Mac, como hoy.
- «Plantas de esta localización»: lista de los esquemas de luz y cámara de la
  localización y de sus sets, que se abren en el editor (compacto en el iPhone),
  y «Enlazar planta libre», que mueve una planta libre a esta localización.

### IC.5 (opcional) · «Enviar a IRIS» desde otras apps
Share Extension para mandar fotos desde Fotos o Artemis sin abrir IRIS.

## Pruebas por fase
Pruebas de widget a 390 × 844 y en tamaño iPad. Compilar y probar en el simulador
iPhone 17e (iOS 26.5) y en un iPad. Instalar en dispositivos solo con aviso.
