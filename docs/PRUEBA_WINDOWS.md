# Prueba de IRIS en Windows (PC.5)

Se marca en cada versión que se pruebe en el PC: fecha, versión o rama, y ✅, ⚠️ (funciona con algo raro) o ❌ (no funciona) en cada punto, con una nota.

**Antes de empezar:**
- Usa un proyecto de prueba, o uno que ya esté en la nube con copia en el Mac. La descarga de la nube tiene un fallo conocido que pierde metadatos (nota de memoria «La descarga de la nube pierde datos»).
- Instala con `IRIS-DP-Windows-Setup.exe`, del release o del artefacto del PR.

| Fecha | Versión o rama | Equipo (Windows, GPU) | Quién |
|---|---|---|---|
| | | | Daniel |

## 1. Arranque y nube
- [ ] El instalador abre (aviso de SmartScreen: «Más información → Ejecutar de todos modos»), instala sin pedir administrador y deja los accesos en el escritorio y en el menú Inicio.
- [ ] IRIS abre con su icono y su nombre en la barra de tareas.
- [ ] Iniciar sesión en la nube.
- [ ] Los proyectos bajan completos, con imágenes, guiones y documentos.
- [ ] Un cambio hecho en el PC aparece en el Mac, y al revés («editado en Windows»).
- [ ] **Ajustes → Almacenamiento** enseña las carpetas de Windows (`AppData` y `Documentos`).

## 2. Proyectos, escenas y planos
- [ ] Crear, editar y borrar un proyecto, una escena y un plano.
- [ ] Importar un guion PDF y verlo en el visor (pdfrx).
- [ ] Vista previa de la biblia en PDF.

## 3. Planta de cámara y luz
- [ ] Dibujar paredes, ventanas y puertas; poner luces, cámaras y actores.
- [ ] Fotómetro y mapa de luz, con fluidez al arrastrar (rendimiento de #37).
- [ ] Deshacer y rehacer con **Ctrl+Z** y **Ctrl+Mayús+Z**; duplicar con **Ctrl+D**; copiar y pegar con **Ctrl+C** y **Ctrl+V**.
- [ ] El menú contextual y la ayuda de atajos dicen «Ctrl+», no «⌘».
- [ ] Zoom con **Ctrl** y el panel táctil, o con la rueda.

## 4. Nave, telas y truss
- [ ] Constructor de nave con plantillas, lados curvos y ventanales.
- [ ] Herramientas «Tela» y «Truss»; el imán cuelga las luces del truss.
- [ ] Lista de rigging y avisos.

## 5. 3D (WebView2)
- [ ] El panel 3D abre junto a la planta; el borde se arrastra.
- [ ] Pantalla 3D completa: vistas, cubo, capas, conos.
- [ ] Mover y apuntar desde el 3D; los cambios llegan a la planta.
- [ ] Ver por la cámara, sol con sombras, luz en el suelo, medir.
- [ ] Importar un escaneo GLB.

## 6. Exportar
- [ ] Hoja A3 en PDF, DXF, MVR y glTF: el diálogo de guardar de Windows funciona y los archivos se abren.
- [ ] Storyboard, guion técnico y PDF diario.

## 7. Portapapeles y archivos
- [ ] Pegar en el moodboard una imagen copiada en el navegador (PNG).
- [ ] Pegar una captura (Win+Mayús+S).
- [ ] Pegar una imagen copiada en el Explorador (Ctrl+C sobre el archivo).
- [ ] Pegar una URL de imagen como texto.
- [ ] Copiar una imagen de IRIS y pegarla en otro programa (Paint, Word).
- [ ] Arrastrar una imagen o un PDF a la ventana.
- [ ] La paleta de comandos de la biblia abre con **Ctrl+K**.

## 8. Actualizar
- [ ] Con una versión nueva publicada, el aviso sale y «Actualizar ahora» descarga el zip, reemplaza la app y la vuelve a abrir, sin perder datos.

## 9. Rendimiento con NVIDIA (PC.5.2)

Misma planta y misma caseta en los dos equipos:

| Medida | Mac | PC |
|---|---|---|
| Fotogramas por segundo del 3D, caseta 24 × 12 con 12 focos, vista iso | | |
| Ídem con sol y sombras | | |
| Tiempo de «Luz en el suelo» | | |
| Arrastrar una luz en la planta con el mapa de luz (fluido / a saltos) | | |
| GPU que usa el 3D (Administrador de tareas → GPU) | — | |

## Notas
-
