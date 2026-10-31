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

## 9 · Lo nuevo del 31 de octubre (rama `plan/pulido-rodaje`)

Esta rama lleva todo lo anterior. IRIS ya está abierto en el PC con ella.

- [ ] **Exports rápidos.** Exporta el guion técnico completo a PDF y a Word: con muchos planos e imágenes tarda segundos, no minutos. En la prueba, 400 planos con imagen tardan unos 13 s en total, cuando antes eran casi 2 minutos. Las fotos se ven igual de bien.
- [ ] **Transparencias.** Un boceto o un recorte con transparencia en la casilla Planta o en Referencia se sigue viendo con su fondo transparente, no negro.
- [ ] **Escaneo en Unreal: el giro.** Gira el escaneo 90° en IRIS: en Unreal debe girar hacia el mismo lado. Se ha corregido el signo; si aún no cuadra, anota cuántos grados difiere.
- [ ] **Storyboard en el iPhone** (o con la ventana a menos de 600 px):
  - la barra de arriba cabe;
  - al tocar un plano se abre el visor compacto;
  - deslizando a izquierda o derecha se pasa de plano;
  - pellizcando se amplía, y ampliada se puede mover;
  - debajo de la imagen va la ficha: encuadre editable, óptica, acción y apuntes, con Anterior y Siguiente.
- [ ] **IRIS Stage en seis pasos.** Proyecto → IRIS Stage: arriba aparece «IRIS Stage en seis pasos · n de 6». Cada paso se marca solo:
  - el proyecto de Unreal preparado;
  - conectado;
  - la planta mandada (dice el nivel de Unreal);
  - assets en la biblioteca.

  Los botones de cada paso hacen lo que dicen.
- [ ] **Quitar de la biblioteca.** Quita un asset de la biblioteca y pulsa «Buscar en Unreal» o «Recoger de Fab»: no vuelve. En otro equipo, tras sincronizar los ajustes, tampoco. Si lo asignas otra vez a un elemento, vuelve.

## 10 · Altura, paneo e inclinación de los focos (F6.21.5)

- [ ] **Ficha del foco.** Selecciona un foco de trípode en la planta. En la ficha (Montaje) salen **Altura** (0,3–12 m), **Paneo** (0–359°) e **Inclinación (tilt)** (−90° a +90°). Lo mismo en un foco colgado.
- [ ] **En el 3D.**
  - Sube un foco de trípode a 2,5 m e inclínalo −30°: en el 3D se ve a esa altura y apuntando hacia abajo.
  - En el panel 3D del foco, el deslizador «Inclinación (tilt)» hace lo mismo.
- [ ] **El fotómetro.** Con ese foco apuntando a una persona, la lectura cambia al inclinarlo: apuntado a ella da más que en horizontal por encima.
- [ ] **En el alzado.** El foco se ve a su altura y con el ángulo de su haz.
- [ ] **Unreal.** Con IRIS Stage conectado:
  - el foco llega a 2,5 m y −30°;
  - inclínalo a −45° en el editor de Unreal: en la ficha de IRIS pone −45° y la altura no cambia;
  - súbelo en Unreal: en IRIS cambia la altura.
- [ ] **Plantas de antes.** Un foco colgado e inclinado de antes de este cambio sigue apuntando igual: 30° desde la vertical se lee como −60°.
- [ ] **Ojo: altura por defecto en trípode.** Un foco de trípode sin altura propia ahora va a 2 m en el 3D y en Unreal (antes, 3 m). El fotómetro lo sigue midiendo como siempre hasta que le pongas altura o inclinación.

## 11 · La misma luz en IRIS y en Unreal (F6.21.4)

- [ ] **Luz real en el 3D de IRIS.**
  - En una planta de plano con su cámara y unos focos encendidos, abre el 3D.
  - En «Qué se ve» está activada **«Luz real · EV n»**, la exposición de la cámara.
  - Baja un foco al 50 % en su ficha: en el 3D se ve la mitad de luz, no casi igual.
  - Desactívala: vuelve la luz de trabajo de siempre.
- [ ] **Coincide con el fotómetro.** Donde el fotómetro dice que estás al diafragma de trabajo, la cara de una persona se ve en un gris medio. Donde dice dos stops por debajo, se ve claramente oscura.
- [ ] **Diafragma, ISO y ND.** Cambia el diafragma de trabajo (o el ISO, o el ND) de la cámara: el 3D se aclara o se oscurece como se aclararía la imagen de la cámara.
- [ ] **Una planta sin luces encendidas** sigue viéndose (con la luz de trabajo), no negra.
- [ ] **Unreal.**
  - Tras «Abrir en Unreal» (que instala el script y la configuración nuevos) y reiniciar Unreal, en el Outliner aparece **IRIS_Exposicion** (PostProcessVolume).
  - La imagen ya no se autoexpone: bajar un foco al 50 % en IRIS lo baja a la mitad en Unreal.
  - Cerrar o abrir el diafragma en IRIS oscurece o aclara Unreal.
- [ ] **Compara.** La misma escena vista en el 3D de IRIS (Luz real) y en Render RTX debería tener el mismo nivel general. Anota si una sale claramente más clara u oscura y en cuántos stops; es el dato para calibrar.

## 12 · El set a escala en Unreal (F6.21.3)

- [ ] **Muebles a su tamaño.**
  - Pon una mesa en la planta. En su ficha salen **Ancho**, **Fondo** y **Alto** en cm (por defecto 160 × 90 × 80).
  - En la planta 2D se dibuja a ese tamaño, ya no como un icono pequeño.
  - Lo mismo con silla, sofá y cama.
- [ ] **Muebles de antes.** Un mueble que ya tenía un tamaño propio se ve igual que antes. Uno sin tamaño propio ahora sale con medidas típicas: la mesa de 1,60 m en lugar de un cuadrado de 50 cm.
- [ ] **En el 3D.** La mesa de 160 × 90 se ve rectangular, con sus patas en las esquinas. Gírala: se gira con su fondo hacia donde mira.
- [ ] **En Unreal.**
  - Con IRIS Stage conectado y el 3D abierto en una planta con paredes, puerta y ventana, a los 2 s aparece en Unreal **IRIS_Estructura**, que es la habitación.
  - Mide con la regla de Unreal una pared de 4 m: 400 cm. Comprueba que los huecos de la puerta y de la ventana están.
- [ ] **Una pared movida en IRIS.** Mueve una pared: en unos segundos Unreal cambia la estructura por la nueva.
- [ ] **La luz.** Un foco fuera de la ventana entra por el hueco y las paredes dan sombra (Render RTX).
- [ ] **La mesa en Unreal.** Llega como un bloque de 160 × 90 × 80, girado como en la planta.
- [ ] **Anota** si alguna pieza de la estructura sale en otro sitio o con otro giro: sería el importador de glTF de Unreal, y se corrige con ese dato.

## 13 · Plató, interior o exterior (F6.21.1)

- [ ] **El botón.** En la planta de un set, junto al sol y la luna de la barra, hay un botón **Entorno** (cámara, casa o árbol). Elige **Plató**.
- [ ] **El fotómetro en plató.** Con un esquema de día, la lectura ya no incluye el sol ni el cielo: solo los focos. En «Qué aporta cada fuente» no sale el sol.
- [ ] **El 3D en plató.** Fondo negro y suelo gris; con «Luz real», solo alumbran los focos.
- [ ] **Exterior.** Cambia a **Exterior · Asfalto**: el 3D tiene fondo de cielo (de día) y un suelo gris oscuro grande, con el sol del esquema.
- [ ] **Se guarda.** Cierra y abre la planta: sigue con su entorno. En otro equipo, tras sincronizar, también.
- [ ] **Unreal.** Con IRIS Stage (tras «Abrir en Unreal» y reiniciar Unreal):
  - **Plató:** sin sol, cielo ni atmósfera, y el suelo gris;
  - **Exterior:** el suelo del terreno hasta el horizonte, con cielo y sol;
  - **Interior:** como antes.

## 14 · Niebla y humo (F6.21.2)

- [ ] **El control.** En una planta con esquema de luz, abre el botón del sol o la luna (Ambiente). Abajo sale **Niebla**, de 0 a 100 %, y al subirla, el tipo: **Bruma**, **Humo** o **Niebla exterior**.
- [ ] **En el 3D.** Sube la bruma al 40 %: la escena se espesa y los conos de los focos se ven más. Al 0 % vuelve a estar limpia.
- [ ] **Humo y exterior.** El humo es más denso; la niebla exterior se nota sobre todo a lo lejos.
- [ ] **Se guarda con el esquema.** Otro esquema de luz del mismo set puede llevar otra niebla.
- [ ] **Unreal.** Con IRIS Stage (tras «Abrir en Unreal» y reiniciar Unreal):
  - aparece **IRIS_Niebla**, y los haces de los focos se ven en el aire (Render RTX);
  - subir o bajar la niebla en IRIS cambia Unreal al momento;
  - a 0 % desaparece.

## 15 · Navegar como en Unreal (F6.22.6)

- [ ] **Planta 2D.** Arrastra con el botón derecho: la planta se desplaza y no sale ningún menú. Un clic derecho sin arrastrar abre el menú de siempre (copiar, pegar…).
- [ ] **3D.**
  - Haz clic una vez dentro del 3D. Con el **botón derecho pulsado**, mueve el ratón para mirar y usa **W A S D** para moverte; **Q** y **E** bajan y suben.
  - La rueda, con el derecho pulsado, cambia la velocidad, y **Mayúsculas** corre.
  - Al soltar, la vista se queda donde estás y se puede girar como antes.
- [ ] **El ajuste.** En **Ajustes → Plantas**, apaga **«3D como Unreal»** y vuelve a abrir el 3D: el botón derecho vuelve a desplazar como antes.
- [ ] **Anota** si las teclas no responden. En Windows, el 3D necesita tener el foco: haz clic dentro antes.

## 16 · Marcos, palios y difusión (F6.22.1–22.2)

- [ ] **Formato.** Pon un **Marco de difusión** en la planta. En su ficha, en **Formato**, elige **Marco 2×1**: mide 2 m de ancho y 1 de alto. Cambia a **Palio 4×4**.
- [ ] **Medidas.** **Alto** y **Altura del centro** suben y bajan la tela. En el alzado se ve a su altura.
- [ ] **Telas.** **Tela:** Grid Cloth, ½ o ¼, sedas. En un marco (no en un palio) sale también **Gelatina**: un CTO tiñe la luz que sale.
- [ ] **Rebote como palio.** Un **Rebote** con Formato **Palio 3×3** y Material **Cinebounce**.
- [ ] **Fotómetro.** Un foco detrás de la tela, apuntando a un actor. Cambia de ¼ Grid Cloth a Grid Cloth full: la lectura del actor baja. En «Qué aporta cada fuente» sale la tela.
- [ ] **El 3D.**
  - La tela se ve como un panel blanco translúcido a su tamaño y el negro como uno negro.
  - El negro da **sombra** en el actor y el suelo.
  - Con «Luz real», la luz que sale de la tela ilumina al actor, más baja con más difusión.
- [ ] **Unreal.**
  - Los paneles llegan a su tamaño, altura y giro, negros, blancos o del color de la tela.
  - Delante de cada tela hay una **RectLight** de su tamaño con la luz que deja pasar.
  - Al cambiar la tela en IRIS, cambia su intensidad en Unreal.
- [ ] **Paneo e inclinación.** En la ficha del palio, **Paneo** lo gira y **Inclinación** lo tumba. A 90° queda **horizontal, sobre las cabezas**.
- [ ] **Palio al sol.**
  - Un exterior de día con sol alto, un actor y un **Palio 4×4** a 90° con el centro a 3 m sobre él.
  - Con **Grid Cloth full**, la lectura del actor baja y el sol directo desaparece de «Qué aporta cada fuente»: sale la luz de la tela.
  - Con un **negro** (Negro con Inclinación 90°), la lectura baja mucho más.
- [ ] **Palio inclinado ante un foco.** Inclínalo 45°: la luz de la tela sale hacia abajo y hacia delante, y cambia con el ángulo.
- [ ] **3D y Unreal.** El palio se ve tumbado, a su altura y con su giro, en el 3D y en Unreal. Su luz cae hacia abajo (RectLight mirando al suelo).
- [ ] **Anota** si en Unreal se inclina hacia el lado contrario que en IRIS: sería el signo del giro, y se corrige con ese dato.

## 17 · La exposición del actor con grip (F6.22.3)

- [ ] **Tela entre el foco y el actor.** Un fresnel a 3 m de un actor y un marco de difusión de 2×2 a mitad de camino. La lectura del actor ahora **baja**:
  - ¼ Grid Cloth: más o menos 1 stop;
  - ½ Grid Cloth: más o menos 1,5 stops;
  - Grid Cloth full: más o menos 2,5 stops.

  Antes la ¼ podía dar más luz que sin tela.
- [ ] **Negro.** Un negro en el mismo sitio: la lectura cae casi del todo.
- [ ] **Rebote de lado.** Detrás del actor y a un lado, de cara al foco: la lectura del actor sube un poco.
- [ ] **En el 3D («Luz real»).** La cara del actor se oscurece al poner la tela o el negro, y más con Grid Cloth full que con ¼.
- [ ] **Anota** cualquier lectura que no te cuadre con lo que verías en el set, con las medidas y la distancia: es el dato para afinar el motor.

## 18 · La cámara en Unreal (F6.22.4)

- [ ] **Ficha de la cámara.** Selecciona una cámara: salen **Altura del objetivo**, **Paneo**, **Inclinación**, **Giro (holandés)** y **Foco**. Ponla a 1,20 m, −10°, foco 2,5 m.
- [ ] **En el 3D.** La cámara se ve a esa altura y mirando un poco hacia abajo. «Ver por la cámara» mira igual.
- [ ] **En Unreal** (tras «Abrir en Unreal» y reiniciar Unreal):
  - la CineCamera de IRIS está a 1,20 m, inclinada −10° y con 5° de giro si se lo pones;
  - tiene el 35 mm a T2.8, el foco manual a 250 cm, y el ISO y el obturador en su posproceso.
- [ ] **Profundidad de campo.** «Ver por la cámara» en Unreal: cambia el diafragma de trabajo en IRIS (T1.4, T8) y la profundidad de campo cambia.
- [ ] **De vuelta.** Inclina la cámara en Unreal: en la ficha de IRIS cambia la inclinación.
- [ ] **Foco automático.** Sin foco propio (deslizador del todo a la izquierda), enfoca al actor que tiene delante.

## 8 · Pendiente (no está en estas ramas)

- **F6.20 D3 · Tejidos y superficies:** materiales de Fab en paredes y suelo, en Unreal y en el 3D.
- **F6.20 C, lo que falta:** la miniatura del esquema de luz con colores por tipo y nombres para el PDF. Es lo que quedó a medias de la cuenta anterior en `plan_thumbnail.dart`, dentro de `.claude/worktrees/f6-3d-pc`.
- **F6.20 E · RealityScan sin interfaz en el PC:** de fotos o vídeo a malla sin abrir RealityScan, y paredes propuestas a partir del escaneo.
- **Revisar el bucle de `pullContentCloud`** (apartado 6).
