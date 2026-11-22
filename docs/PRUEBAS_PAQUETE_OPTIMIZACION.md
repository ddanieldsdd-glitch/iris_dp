# Pruebas del paquete de optimización

Rama `plan/paquete-optimizacion`, sin publicar. Lleva tres cambios:
- **WAL (R6):** la base en modo WAL.
- **Pasar de plano sin esperar (FL.6).**
- **Editor de plantas partido en archivos (RD.4).**

Marca cada punto al probarlo. Si algo falla, anota en qué aparato, en qué plano y qué hiciste justo antes.

Antes de empezar, haz una copia de seguridad desde Ajustes → Almacenamiento.

## 1. Base en WAL (R6)

Qué debería notarse: guardar va más rápido y desaparece el «database is locked» al actualizar.

- [ ] La app abre normal tras actualizar y los proyectos están todos (KEBAB con sus planos, plantas y jornadas).
- [ ] En la carpeta de datos de la app aparecen `iris_dp.db-wal` e `iris_dp.db-shm` junto a `iris_dp.db`. Es normal: no los borres ni copies el `.db` solo.
- [ ] Cambia algo (mover una luz, renombrar un plano), cierra la app del todo y ábrela: el cambio sigue ahí.
- [ ] La sincronización con la nube sube y baja como antes: un cambio en el Mac llega al iPad.
- [ ] Al publicar la siguiente versión, la actualización automática del Mac no da «database is locked».
- [ ] **Solo si usas una carpeta elegida a mano** (disco externo o carpeta sincronizada): ahí la base sigue en el modo de siempre, sin `-wal`. Comprueba que abre y guarda.
- [ ] **Cambiar la carpeta de almacenamiento:**
  1. En Ajustes → Almacenamiento, elige otra carpeta.
  2. Reinicia cuando lo pida.
  3. Al abrir, los datos están completos en la carpeta nueva, también lo último que tocaste justo antes.

## 2. Pasar de plano sin esperar (FL.6)

Qué debería notarse: al cambiar de plano no se recarga la pantalla, y el 3D no tarda en volver.

- [ ] En Plantas, pasa de un plano a otro desde la tira de arriba. Cambia al momento, sin pantalla de carga ni parpadeo.
- [ ] Con ⌘→ y ⌘← pasa al plano siguiente y al anterior.
- [ ] Haz zoom en un rincón y pasa a otro plano del mismo set: el zoom se queda.
- [ ] Pasa a un plano de otro set: se encuadra solo en el set nuevo.
- [ ] **Con el panel 3D abierto (Mac):** al cambiar de plano, el visor no se recarga desde cero. Se ve la escena nueva y mira por la cámara del plano nuevo.
- [ ] **En el iPad, con el 3D a pantalla entera:** elige otro plano desde la tira del 3D. Vuelve a abrirse a pantalla entera en el plano nuevo.
- [ ] **Guardar y cambiar enseguida:**
  1. Mueve una luz o un actor.
  2. Sin esperar, pasa al plano siguiente.
  3. Vuelve. El cambio está en el primer plano y no ha pasado al segundo.
- [ ] **Ajuste solo en este plano:**
  1. En el plano 2, cambia una luz con «Ajustar solo en este plano».
  2. Pasa al 3 y vuelve al 2.
  3. El ajuste sigue en el 2, y el 3 la ve como en el set.
- [ ] **Cambiar muy rápido:** salta varios planos seguidos en la tira, sin esperar. Al parar, se ve el último plano que tocaste y no otro.
- [ ] **Opacidad de una imagen:** mueve el deslizador de opacidad y cambia de plano enseguida. Al volver, la opacidad está guardada.
- [ ] **Plano secuencia:** pasar de un tramo a otro enseña lo de cada tramo.
- [ ] **Con dos aparatos abiertos:** el aviso de «se está editando» pasa al plano nuevo cuando cambias.

## 3. Editor de plantas partido en archivos (RD.4)

El comportamiento no debería cambiar en nada. Es repaso general para detectar si algo se ha roto.

- [ ] **Ratón y dedo:**
  - [ ] seleccionar con un toque;
  - [ ] arrastrar un elemento;
  - [ ] girar desde el asa;
  - [ ] seleccionar varios con un rectángulo;
  - [ ] mover el lienzo con el botón central o con el derecho;
  - [ ] zoom con la rueda y con pellizco.
- [ ] **Recorridos:**
  - [ ] añadir un punto con doble toque;
  - [ ] arrastrar un punto;
  - [ ] borrarlo;
  - [ ] cambiar de marca con las teclas 1–9.
- [ ] **Zona del set:** mover sus esquinas.
- [ ] **Paredes:** mover los extremos de un tramo.
- [ ] **Copiar y pegar:**
  - [ ] ⌘C, ⌘X y ⌘V dentro de un plano y de un plano a otro;
  - [ ] ⌘A para seleccionarlo todo.
- [ ] **Teclado:**
  - [ ] mover con las flechas, y con ⇧ en pasos grandes;
  - [ ] girar con su atajo;
  - [ ] deshacer y rehacer;
  - [ ] Esc cancela lo que estés haciendo.
- [ ] **Clic derecho:** el menú contextual sale con sus opciones.
- [ ] **Hoja de atajos:** se abre y enseña los atajos.

## 4. Medido y sin cambios

No hace falta probarlo; queda anotado:
- **Exportar para sincronizar (RD.1):** unos 60 ms, y la interfaz no se para más de 12 ms.
- **Soltar tras arrastrar (R8):** la interfaz paga 15–50 ms. Los 1,5 s solo salían en el test.
- **Miniaturas de la tira:** ya iban en caché.
- **Leer un plano al cambiar:** unos 30 ms en el hilo de la base.

## Pendiente fuera del paquete

- **R7:** medir en perfil en el iPad y en Windows.
