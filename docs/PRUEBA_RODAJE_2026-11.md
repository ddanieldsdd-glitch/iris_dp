# Prueba antes del rodaje (noviembre 2026)

Lista para recorrer en el PC (y luego en el iPhone y el Mac) todo lo hecho el 2026-10-30. Rama con todo junto: `plan/ip2-rodaje-iphone` (PRs #59, #60 y #61, apiladas).

Usa el proyecto **PRUEBA WINDOWS** o una copia, no el del rodaje, hasta revisar la sincronización (ver el apartado 6).

Marca cada punto con ✅ o ❌ y una nota de qué pasó.

## 1 · Guion técnico: exportar (PR #59)

- [ ] **Diálogo y PDF.** Guion técnico → icono Exportar. Salen: PDF/Word, Índice, Columnas (chips), Letra (Pequeña, Normal, Grande) y Papel (A4/Carta, Horizontal/Vertical).
- [ ] **Columnas en el PDF.** Quita REFERENCIA, activa STORYBOARD y exporta a PDF. En el PDF no hay columna REFERENCIA, hay STORYBOARD con su imagen, y las columnas de la pantalla no han cambiado.
- [ ] **Papel y letra.** Exporta en A4 vertical con letra Grande: la página es vertical y el texto más grande.
- [ ] **Carta.** Exporta en Carta horizontal: la página mide 27,9 × 21,6 cm.
- [ ] **Índice.** Con Índice, la primera página es el índice; al pulsar una escena se salta a ella y los números de página cuadran.
- [ ] **Word.** Exporta en Word y ábrelo:
  - no pregunta «¿actualizar campos?»;
  - sale la fuente de la hoja (Inter, Noto o Tinos);
  - las *cursivas*, la **negrita**, el subrayado, el marcador y el color de texto se ven igual que en pantalla.
- [ ] **Recuerda lo elegido.** Vuelve a abrir el diálogo: propone lo último que elegiste. Lo mismo tras cerrar y abrir IRIS.
- [ ] **Planta en papel.** Con la columna PLANTA, ¿la planta sale sobre fondo blanco o sobre oscuro? Anótalo.
- [ ] **Copiar y pegar.** Copia una celda con formato a otra con formato: se conserva. Pegada en una celda sin formato, entra como texto limpio.

## 2 · Hoja de rodaje (PR #59)

- [ ] **Hub.** Documentos de rodaje: tres tarjetas arriba (Jornada, Guion técnico completo, Documento libre) y las jornadas agrupadas por fecha.
- [ ] **Vista Escenas.** Crea una jornada y añade planos de 3 escenas desordenados. En «Escenas (n)», cada tramo es una tarjeta: arrastra un tramo y se mueve entero.
- [ ] **Vista Planos.** En «Planos (n)», arrastra un plano suelto.
- [ ] **Orden de guion.** Pulsa «Orden de guion»: todo vuelve al orden del guion.
- [ ] **Quitar una escena.** Quita una escena de la jornada: pide confirmación y el plano sigue en el guion técnico.
- [ ] **Exportar la jornada.** Exportar desde la jornada: el PDF y el Word siguen el orden de la pantalla, la columna ORDEN va de 1 a n, y el índice lleva «ESCENA 4. INT COCINA NOCHE (1-2)».
- [ ] **Botones directos.** Los botones PDF y Word de la tarjeta de la jornada, en el hub, exportan sin diálogo con lo último elegido.

## 3 · Escaneos para ensayar la luz (PR #60)

Necesitas un escaneo real. En RealityScan (o Polycam) en el iPhone, exporta en **GLB con texturas**, con detalle medio (menos de 50 MB).

- [ ] **Importar.** Planta de cámara y luz → 3D → «Importar escaneo»: se ve en el 3D. El aviso dice si se sube a la nube o si pesa demasiado.
- [ ] **Colocar y calibrar.** Gíralo, súbelo o bájalo hasta que su suelo coincida con el de la planta, y calíbralo con «Medir» sobre una puerta y «Calibrar».
- [ ] **Cenital de fondo.**
  - Con el escaneo seleccionado, pulsa «Cenital de fondo en la planta».
  - En la planta 2D aparece la vista desde arriba, a escala, debajo de los elementos.
  - Comprueba con la regla que una pared mide lo mismo en la cenital que en la realidad.
- [ ] **Sombras.** Pon 2 o 3 focos apuntando al escaneo: en el 3D dan sombra sobre él (paredes y muebles escaneados tapan la luz).
- [ ] **Rendimiento.** Mueve la vista del 3D con el escaneo y los focos: debe ir fluido. Anota si no.
- [ ] **En otro equipo.** Abre el mismo proyecto en el Mac o el iPad, después de sincronizar: el escaneo aparece sin volver a importarlo (puede tardar lo que tarde en bajar).
- [ ] **Un escaneo de antes.** Si tenías uno importado antes de hoy, ábrelo una vez en el PC: a partir de ahí también viaja.

## 4 · Escaneo y luces en Unreal (PR #60)

En el PC, con Unreal 5.5. Sigue también `docs/PRUEBA_IRIS_STAGE.md`.

- [ ] **Instalar.** Desde el 3D, «Abrir en Unreal». Si Unreal ya estaba abierto, **ciérralo y ábrelo** para que cargue el script nuevo. El informe dice «IRIS Stage Link actualizado».
- [ ] **El escaneo llega.** En el Outliner, carpeta IRIS, aparece `IRIS_<nombre del escaneo>`, y en el Content Browser está `/Game/IRIS/Scans/S_…`.
- [ ] **Sitio, giro y escala.** Está en su sitio, a escala y con el mismo giro que en IRIS. Si el giro no cuadra, anota cuántos grados difiere: es el ajuste que falta.
- [ ] **En vivo.** Gira el escaneo en IRIS: en Unreal gira solo, sin volver a importar.
- [ ] **Render.** Con los focos de IRIS en Unreal, «Render RTX» y la captura al storyboard funcionan con el escaneo en escena.

## 5 · iPhone (PR #61)

En el iPhone con el .ipa de esta rama, o en el PC estrechando la ventana a menos de 600 px.

- [ ] **Abrir una jornada.** Documentos de rodaje → una jornada: se abre «En set», con los planos en orden de rodaje, agrupados por escena.
- [ ] **Tarjetas.** Cada tarjeta muestra Esc · Plano · encuadre, la óptica, la imagen de referencia, la acción y los apuntes.
- [ ] **Hecho y descartar.** Marca «Hecho» en dos planos: arriba pone «2 de n hechos». «Descartar» tacha el plano y lo saca de la cuenta.
- [ ] **Nota de set.** «Nota» guarda una nota de set que sale en la tarjeta.
- [ ] **Sincroniza.** Lo marcado en el iPhone aparece en el Mac o el PC, en «En set» de esa jornada.
- [ ] **Guion en lectura.** Guion técnico en el iPhone: se abre en «Lectura», con tarjetas por escena. «Tabla» lleva a la tabla de siempre.
- [ ] **Sin desbordes.** Nada se sale de la pantalla: no aparecen franjas amarillas y negras.

## 6 · Sincronización y estabilidad

- [ ] **Descargas de la nube.** Al abrir IRIS, la terminal del PC repite `pullContentCloud · El Bosque de Aldrun` cada uno o dos segundos durante unos minutos; después baja a una vez por minuto, con la pasada ligera. Anota si en algún equipo no para nunca, o si al bajar falta algo de un proyecto (es la nota «La descarga de la nube pierde datos» de `PLAN_IRIS_PC.md`). Hasta comprobarlo, no te fíes de la nube con el proyecto del rodaje.
- [ ] **Del PC al Mac.** Un cambio hecho en el PC (un plano, una luz) llega al Mac, y al revés.

## 7 · Fab, Megascans y jornada (rama `plan/f6-20-d-fab-quixel`)

Esta rama lleva todo lo anterior, más la biblioteca de assets (#58, ya en `main`).

- [ ] **Biblioteca.** Planta → icono de colección (o IRIS Stage → Biblioteca): se abre la biblioteca de Unreal.
- [ ] **Buscar en Fab.** Escribe «sofa» y pulsa «Buscar en Fab»: se abre fab.com con la búsqueda. «Megascans» busca solo lo de Quixel.
- [ ] **Packs de partida.** «Packs de partida» → «Cocina»: se abre la búsqueda de cocina en Fab.
- [ ] **Recoger de Fab.**
  - En Unreal, con el plugin Fab (Ventana → Fab), añade al proyecto un asset gratuito.
  - Vuelve a IRIS con la biblioteca abierta: el asset entra solo. También con «Recoger de Fab».
- [ ] **Con el asset en la biblioteca.**
  - «Hacer miniaturas» hace sus miniaturas.
  - «Poner en la planta» crea la pieza con sus medidas.
  - En Unreal aparece con el asset de Fab.
- [ ] **Jornadas desde el guion.** Guion técnico → icono de calendario: lista las jornadas y abre la elegida (en el iPhone, «En set»).
- [ ] **Deshacer en la jornada.** Mueve un tramo o un plano: el aviso «Orden de rodaje cambiado» trae «Deshacer» y lo devuelve. Quita un plano o una escena: «Deshacer» los vuelve a poner en su sitio.
- [ ] **Estado en el PDF.** Marca planos «Hecho» y «Descartado» en «En set» y exporta la jornada: en la columna ORDEN pone **HECHO** o DESCART. bajo el número.

## 8 · Pendiente (no está en estas ramas)

- **F6.20 D3 · Tejidos y superficies:** materiales de Fab en paredes y suelo, en Unreal y en el 3D.
- **F6.20 C1–C4 · IRIS Stage en seis pasos, con tutorial y guía.** En `.claude/worktrees/f6-3d-pc` hay un inicio de C1 de la cuenta anterior, sin guardar: opciones del esquema de luz en la miniatura y «quitar» en la biblioteca.
- **F6.20 E · RealityScan sin interfaz en el PC:** de fotos o vídeo a malla sin abrir RealityScan, y paredes propuestas a partir del escaneo.
- **IP.2.2 · Storyboard compacto en el iPhone.**
- **Revisar el bucle de `pullContentCloud`** (apartado 6).
