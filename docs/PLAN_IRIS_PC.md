# IRIS en el PC (Windows): plan para usarlo también ahí

Plan vivo con puntos numerados (`PC.x.y`), como el plan F6. Estado de cada punto: **pendiente**, **en curso**, **hecho (PR)**, **descartado**.

## Estado (2026-10-26)

Lo de compilar e instalar está en la PR #49 (`plan/pc-windows`). El resto **se aplaza**: ahora el trabajo del PC es el 3D de alta calidad (bloque F6.19 del plan 3D, `PLAN_F6_3D_PREVIS.md`).

| Punto | Estado |
|---|---|
| PC.0.1–0.2 Preparar el PC | hecho (#49: `setup_windows_dev.ps1`, `DESARROLLO_EN_WINDOWS.md`) |
| PC.1.1 PNG del plugin nativo | hecho (#49) |
| PC.1.2 PDF en Windows | hecho (#49, `pdfrx`) |
| PC.1.3 WebView2 para el 3D | hecho (#49) |
| PC.1.4 Windows en cada PR | hecho (#49) |
| PC.1.5 Instalador de prueba | hecho (#49, artefacto del CI) |
| PC.2.1 Portapapeles y guardar | portapapeles hecho (#49); guardar archivos **aplazado** |
| PC.2.2 Atajos con Ctrl | hecho (#49) |
| PC.2.3 Funciones solo de iPad | **aplazado** |
| PC.2.4 Nombre del equipo | **aplazado** (`device_label.dart` ya distingue Windows; falta comprobarlo) |
| PC.2.5 Rutas absolutas del Mac | **aplazado** |
| PC.2.6 Arrastrar y abrir con IRIS | **aplazado** |
| PC.2.7 Aspecto de Windows | icono y ventana hechos (#49); barra de título, menú y escalado **aplazados** |
| PC.3.1 Dónde vive la base | **aplazado** |
| PC.3.2 Primer arranque y sincronización | **aplazado** |
| PC.3.3 Medios pesados | **aplazado** (sigue a F6.12.5 y F6.15) |
| PC.4.1 Instalador | hecho (#49, Inno Setup) |
| PC.4.2 Firma | **aplazado** (decisión abierta: sin firma o certificado OV/EV) |
| PC.4.3 Actualizaciones automáticas | **aplazado** (hoy el actualizador de Windows espera un zip, no el instalador) |
| PC.4.4 Documentación | hecho (#49) |
| PC.5.1 Lista de comprobación | escrita (#49, `PRUEBA_WINDOWS.md`); falta recorrerla |
| PC.5.2 Rendimiento con NVIDIA | pasa a F6.19.8 |
| PC.6 Lo que gana el PC | pasa a F6.19 (en curso) |

### Para más adelante: lo que falta por definir

1. **Guardar archivos (PC.2.1):** si `export_file_saver.dart` usa el canal nativo de Windows o el selector de archivos.
2. **Funciones solo de iPad (PC.2.3):** ocultarlas o explicarlas en el PC (LiDAR, SideStore, guía del iPad).
3. **Rutas (PC.2.5):** qué datos guardan rutas del Mac y si pasan a medios sincronizados o a rutas relativas.
4. **Abrir con IRIS (PC.2.6):** qué tipos de archivo se registran en el Explorador.
5. **Aspecto (PC.2.7):** barra de título propia o la de Windows; dónde va el menú.
6. **Base local (PC.3.1)** y **primer arranque (PC.3.2):** depende de arreglar antes «La descarga de la nube pierde datos».
7. **Firma (PC.4.2):** sin firma para uso propio, o certificado si se reparte.
8. **Actualizar sola (PC.4.3):** descargar el instalador o el zip, y cómo se reabre IRIS.

## Para qué

Daniel tiene un PC con tarjeta NVIDIA y quiere usar IRIS también ahí: con sus mismos proyectos, sincronizados con el Mac y el iPad, y después como estación de render con Unreal (F6.19 del plan 3D).

## Lo que ya hay (revisado el 2026-10-23)

- **Proyecto de Windows en el repositorio:** `windows/runner`, con un plugin nativo propio (`iris_export_plugin.cpp`) para el portapapeles de imágenes y para guardar archivos.
- **Script de compilación:** `scripts/build_windows.ps1`.
- **Parche** para un fallo de `pdf_render_maintained` en Windows: `scripts/patch_pdf_render_windows.sh`.
- **Trabajo de Windows en el workflow de publicación** (`.github/workflows/release.yml`), que sube `IRIS-DP-Windows.zip` al release.
- **Actualizaciones:** el sistema de IRIS ya distingue Windows (`app_update_checker.dart`, `app_update_installer.dart`), y la tabla `app_releases` de Supabase tiene la plataforma `windows`.
- **Documentación** de distribución para Windows: `docs/distribuir_app.md` y `docs/release.md`.

## El problema

**La compilación de Windows falla desde hace varias versiones.** El trabajo lleva `continue-on-error`, así que no se veía: v1.1.2 salió solo con el `.dmg` y el `.ipa`. Errores del último intento (run 39702191432):

1. `iris_export_plugin.cpp(97)`: `GetEncoderClsid` no existe en GDI+. Es la función de ejemplo de la documentación de Microsoft y hay que escribirla en el plugin.
2. `generated_plugin_registrant.cc(12)`: no encuentra `pdf_render_maintained/pdf_render_plugin.h`. El parche de CMake cambia el nombre del target pero no la ruta de las cabeceras.
3. **Nuevo con F4 (#42):** `flutter_inappwebview` en Windows usa WebView2 y descarga su SDK con NuGet al compilar. Hay que comprobar que la compilación lo tiene.

---

## PC.0 · Preparar el PC (lo hace Daniel, una vez)

**PC.0.1 Para usar IRIS**
- Windows 10 u 11 de 64 bits, al día.
- Runtime de **Microsoft Edge WebView2**: viene con Windows 11. En Windows 10 se instala desde Microsoft si falta. Lo usa el 3D.
- Drivers de NVIDIA al día (Game Ready o Studio).
- Unos 2 GB libres para la app y sus datos, más los packs y escaneos que se usen.

**PC.0.2 Solo si se quiere compilar en el propio PC** (no hace falta para probar: el instalador sale de GitHub, PC.1.5)
- Git.
- Flutter estable, la misma versión que en el Mac (3.44.8).
- Visual Studio 2022 Community con la carga «Desarrollo para el escritorio con C++».
- Modo de desarrollador de Windows activado (Flutter lo necesita para los enlaces de los plugins).
- NuGet en el PATH (para WebView2).
- El `.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` (como en el Mac).

---

## PC.1 · Que compile en Windows

Desde el Mac no se puede compilar para Windows. La compilación se comprueba en GitHub Actions (`windows-latest`) y, si Daniel quiere, en el PC.

**PC.1.1 Arreglar el guardado de PNG del plugin nativo**
- **Qué:** escribir en `iris_export_plugin.cpp` la función que busca el codificador PNG de GDI+ (con `Gdiplus::GetImageEncodersSize` y `GetImageEncoders`) en lugar de llamar a `Gdiplus::GetEncoderClsid`.
- **Hecho cuando:** ese archivo compila y copiar o pegar una imagen funciona en Windows.

**PC.1.2 Arreglar `pdf_render_maintained` en Windows**
- **Qué:** completar el parche para que, además del target, apunte bien a las cabeceras. Si no se puede de forma fiable, sustituir el paquete por `pdfrx` (que soporta Windows de serie) en los cuatro sitios donde se usa:
  - `bible_export_pdf_preview_screen.dart`;
  - `script_pdf_viewer.dart`;
  - `camera_plan_pdf.dart`;
  - `sketch_sheet_screen.dart`.
- **Hecho cuando:** compila y se ven los PDF del guion, de la biblia y de las plantas en Windows.

**PC.1.3 WebView2 para el 3D**
- **Qué:** asegurar que la compilación descarga el SDK de WebView2 (NuGet en el runner de Windows) y que el visor 3D (`assets/viewer3d/`) se abre en WebView2.
- **Hecho cuando:** el panel 3D y la pantalla 3D funcionan en el PC con la caseta de prueba.

**PC.1.4 Compilar Windows en cada PR**
- **Qué:** un trabajo de Windows en `ci.yml` para que una rotura se vea en el PR y no meses después. Quitar `continue-on-error` del trabajo de publicación cuando esté en verde.
- **Hecho cuando:** los PRs muestran «build-windows» en verde y un release sin Windows falla de forma visible.

**PC.1.5 Instalador de prueba sin esperar a un release**
- **Qué:** el trabajo de Windows de los PRs sube el zip como artefacto. Daniel lo descarga desde GitHub, lo descomprime en el PC y abre `iris_dp.exe`.
- **Hecho cuando:** hay un zip descargable de la rama con F4 y F5.

---

## PC.2 · Lo que hoy da por hecho que es un Mac o un iPad

Hay 17 archivos con `Platform.isMacOS` o `Platform.isIOS`. Se revisan uno por uno.

**PC.2.1 Portapapeles y guardar archivos**
- **Qué:** `clipboard_image_reader.dart` y `export_file_saver.dart` usan un canal nativo de Mac (`com.iris_dp/export_file_saver`). En Windows deben usar el plugin nativo de Windows (el mismo canal en `iris_export_plugin.cpp`) o el selector de archivos.
- **Hecho cuando:** pegar una imagen en la planta o en el moodboard y guardar un PDF, DXF o MVR funcionan en Windows.

**PC.2.2 Atajos de teclado**
- **Qué:** IRIS usa ⌘ en 23 sitios y Ctrl en 19. En Windows todos los atajos deben ir con Ctrl (deshacer, copiar, pegar, guardar, ⌘1–⌘9 de F6.8.2), y la ayuda de teclas debe decir «Ctrl».
- **Hecho cuando:** los atajos del editor de planta y del storyboard funcionan con Ctrl en Windows.

**PC.2.3 Funciones solo de iPad**
- **Qué:** que no aparezcan o se expliquen en el PC el escaneo LiDAR (`location_scan_service.dart`), el aviso de SideStore (`sidestore_reminder_banner.dart`) y la guía de instalación del iPad.

**PC.2.4 Nombre del equipo para la sincronización**
- **Qué:** `device_label.dart` da el nombre del PC, para que en la nube se sepa desde qué máquina se hizo cada cambio.

**PC.2.5 Rutas y archivos**
- **Qué:** revisar que nada guarda rutas absolutas del Mac (`/Users/…`) dentro de los proyectos sincronizados. Por ejemplo: imágenes de la planta (`FloorPlanUnderlay.path`, `plan_images.dart`), documentos de rodaje, guiones importados y escaneos (`ScanStore`, que ya guarda solo el nombre).
- **Si alguna lo hace:** se pasa a medios sincronizados (como las imágenes en la nube) o a rutas relativas a la carpeta de la app.
- **Hecho cuando:** un proyecto creado en el Mac se abre en el PC con todas sus imágenes y documentos.

**PC.2.6 Arrastrar archivos y abrir con IRIS**
- **Qué:** arrastrar un guion, una imagen o un escaneo a la ventana (`desktop_drop`), y abrir un `.pdf` o un `.fdx` con IRIS desde el Explorador si se registra el tipo.

**PC.2.7 Aspecto de Windows**
- **Qué:** la barra de título, el menú (en el Mac hay menú de app; en Windows va dentro de la ventana), los tamaños de letra con el escalado de pantalla de Windows y el icono de la app.

---

## PC.3 · Datos y sincronización

**PC.3.1 Dónde vive la base en Windows**
- **Qué:** la base local va en la carpeta de la app de Windows (`AppData\Roaming\…`, la que da `path_provider`). Se documenta y se añade a la sección de salud de Ajustes (`settings_health_section.dart`).

**PC.3.2 Primer arranque en el PC**
- **Qué:** iniciar sesión en la nube y bajar los proyectos con la sincronización automática que ya existe. Hay que tener en cuenta la nota de memoria «La descarga de la nube pierde datos» antes de fiarse de ella para un proyecto real.
- **Hecho cuando:** un proyecto del Mac aparece completo en el PC y un cambio hecho en el PC llega al Mac.

**PC.3.3 Medios pesados**
- **Qué:** imágenes, PDF, escaneos y packs del 3D. Las imágenes ya van a la nube; los escaneos y los packs siguen la decisión de F6.12.5 y F6.15.

---

## PC.4 · Instalar y actualizar

**PC.4.1 Instalador**
- **Qué:** pasar del zip a un instalador de verdad. Con **Inno Setup** sale un `.exe` que instala, crea el acceso directo en el escritorio y en el menú Inicio, y desinstala. Con **MSIX** se puede publicar en la tienda y actualizar solo, pero obliga a firmar.
- **Recomendación:** Inno Setup para empezar.

**PC.4.2 Firma**
- **Qué:** sin certificado de firma de código, Windows SmartScreen avisa al abrir el instalador («Windows protegió su PC») y hay que pulsar «Más información → Ejecutar de todos modos». Para uso propio basta. Para repartirlo a más gente conviene un certificado de firma (OV o EV).

**PC.4.3 Actualizaciones automáticas**
- **Qué:** el actualizador de IRIS ya distingue Windows. Se comprueba que descarga el instalador del release, lo ejecuta y vuelve a abrir IRIS, igual que hoy en el Mac desde v1.1.1. `release.sh` y `register_app_release.sh` deben registrar la versión de Windows en `app_releases`.
- **Hecho cuando:** al publicar una versión, el PC la detecta y se actualiza sin pasos manuales.

**PC.4.4 Documentación**
- **Qué:** actualizar `docs/distribuir_app.md` e `instalacion_y_actualizacion.md` con los pasos reales en Windows.

---

## PC.5 · Prueba en el PC

**PC.5.1 Lista de comprobación** (en `docs/`, marcada en cada versión):
1. Abre, inicia sesión y sincroniza.
2. Proyectos, escenas y planos: crear, editar y borrar.
3. Planta de cámara y luz: paredes, luces, fotómetro, mapa de luz y rendimiento (#37).
4. Nave, telas, truss, imán, rigging y avisos.
5. Panel 3D y pantalla 3D: órbita, vistas, mover, apuntar, por la cámara, sol y luz en el suelo.
6. Hoja A3, DXF, MVR y glTF.
7. Biblia visual, storyboard, guion técnico y PDF diario.
8. Pegar imágenes, arrastrar archivos, atajos con Ctrl.
9. Actualizar a una versión nueva.

**PC.5.2 Rendimiento con NVIDIA**
- **Qué:** medir fotogramas por segundo del 3D y el tiempo del mapa de luz en el PC frente al Mac. Sirve para decidir el perfil «ultra» (F6.0.2 y F6.19.1).

---

## PC.6 · Lo que gana el PC después (enlaza con el plan 3D)

**Estado:** en curso. Se trabaja en el bloque F6.19 del plan 3D (`PLAN_F6_3D_PREVIS.md`): el PC con NVIDIA es la máquina de referencia del 3D de alta calidad.


- **F6.19.1:** perfil de calidad «ultra» y capturas con trazado de rayos más rápidas, con WebGPU sobre NVIDIA.
- **F6.19.3–19.5:** IRIS conectado en vivo a Unreal en el mismo PC, con la imagen RTX y DLSS dentro de IRIS y capturas RTX al storyboard.

---

## Orden propuesto

1. **PC.1.1–1.3:** que compile.
2. **PC.1.5:** zip de prueba, para que Daniel lo abra en el PC.
3. **PC.1.4:** que no se vuelva a romper.
4. **PC.2:** lo específico de Apple, empezando por 2.1 (portapapeles y guardar), 2.2 (Ctrl) y 2.5 (rutas).
5. **PC.3:** datos y sincronización.
6. **PC.5:** lista de comprobación en el PC.
7. **PC.4:** instalador y actualizaciones.
8. **PC.6:** se hace y se corrige al construir el motor 3D más exigente (F6).

## Cómo se trabaja

- El código se cambia desde el Mac. La compilación de Windows se comprueba en GitHub Actions y Daniel prueba el zip en el PC.
- Si algo solo se puede depurar en Windows, se abre una sesión de Claude Code en el propio PC, con el repositorio clonado y el entorno de PC.0.2.
- Nada de esto toca los datos del Mac. El PC usa su propia base local y la nube.
