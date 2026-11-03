# Plan ES · Escaneo de localizaciones: estructura antes que malla

Propuesta y aprobada el 2026-11-03. Rama `plan/es-escaneo-estructura` desde
`origin/main` (v1.4.1, esquema 59). Amplía F6.12 y F6.20 E de
`PLAN_F6_3D_PREVIS.md`.

## La idea

Una malla de fotogrametría sale con agujeros, paredes onduladas, techos rotos y
muebles fundidos con las paredes. Llevarla tal cual a la planta o a Unreal da
aberraciones, porque nadie ha entendido qué es pared, qué es puerta y qué es
cama. Por eso aquí **la estructura es lo que manda y la malla es la piel**:

- el escaneo sirve para **medir** y para **sacar texturas**;
- a la planta, al motor de luz y a Unreal va **geometría limpia**: paredes con
  grosor, alturas, puertas, ventanas y muebles como cajas con su categoría;
- la malla real queda como referencia, apagada por defecto.

Decisiones de Daniel (2026-11-03):

- se escanea con un **iPhone sin LiDAR**;
- en Unreal, los muebles se **sustituyen por modelos limpios** con las mismas
  medidas;
- lo primero es una **planta 2D fiable**.

```
iPhone (ARKit)              PC (RealityScan)
 planos de pared y suelo     malla + fotos con pose
 toques en esquinas/huecos          │
        └───────────┬───────────────┘
        Solucionador de estructura (Dart)
  paredes · grosor · alturas · recintos · puertas · ventanas · muebles (cajas)
                    │  cada elemento con su confianza
        Revisión en la planta (aceptar / ajustar / «pegar al escaneo»)
                    │
  PlanSegment / PlanOpening / props ─→ motor de luz, 3D, Unreal
```

## Fases

| Id | Qué | Estado |
|----|-----|--------|
| ES.1 | La captura del iPhone guarda la estructura (`capture.json` v2) | pendiente |
| ES.2 | Solucionador de estructura | hecho (pruebas sintéticas; falta la casa real) |
| ES.3 | Revisión en la planta y «pegar al escaneo» | pendiente (antes, maqueta) |
| ES.4 | Paredes limpias con la textura real proyectada | después |
| ES.5 | Muebles sustituidos por modelos | después |
| ES.6 | Unreal sin aberraciones | después |
| ES.7 | Malla en vivo sin LiDAR (profundidad monocular) | estudio, opcional |

### ES.1 · Captura que guarda estructura · iPhone

En `ios/Runner/IrisCapturePlugin.swift`:

- Al cerrar la captura se guardan los `ARPlaneAnchor` (verticales y
  horizontales, con su clasificación, que funciona sin LiDAR desde el A12) y la
  nube de puntos dispersa.
- **Toques de precisión**: con un raycast sobre los planos se marcan esquinas,
  bordes de puertas y ventanas, el suelo y el techo. Es lo más exacto que se
  puede hacer sin LiDAR.
- **Guía**: línea de paredes ya cerradas en el minimapa, aviso de «falta esta
  pared» y cobertura por pared.

Formato `capture.json` **v2**. Añade a la v1 estos campos, todos opcionales y
en el mundo de ARKit (metros, Y arriba):

```jsonc
{
  "version": 2,
  "frames": [ /* igual que en la v1 */ ],
  "planes": [{
    "id": "UUID",
    "alignment": "vertical" | "horizontal",
    "classification": "wall" | "floor" | "ceiling" | "door" | "window" | "table" | "seat" | "none",
    "transform": [16],              // ancla → mundo, por columnas
    "center": [x, y, z],            // centro en el sistema del ancla
    "extent": [ancho, alto],        // en el plano del ancla (x, z)
    "boundary": [[x, z], …]         // contorno en el sistema del ancla, opcional
  }],
  "marks": [{
    "kind": "corner" | "door" | "window" | "floor" | "ceiling",
    "position": [x, y, z],          // en el mundo
    "planeId": "UUID"               // el plano tocado, opcional
  }],
  "points": [x, y, z, x, y, z, …]   // nube dispersa, ≤ 20 000 puntos
}
```

En el lado de Dart lo lee `CapturePackage` (`rig/scan_capture.dart`), y la v1
se sigue leyendo.

### ES.2 · Solucionador de estructura · todos

En `rig/scan_structure.dart`, Dart puro y con pruebas. El visor da las
mediciones en una sola pasada por la malla (`iris.scanProfile`):

- **Cortes horizontales** cada 15 cm, de suelo a techo.
- **Suelo y techo**: histograma, por alturas, del área de los triángulos
  horizontales que miran arriba y de los que miran abajo. El suelo es el pico
  más bajo de los que miran arriba y el techo el más alto de los que miran
  abajo.
- **Rejilla de alturas** cenital, para los muebles.

Con esas mediciones:

1. **Paredes**: se buscan con `proposeWalls()` sobre todos los cortes juntos.
   Cada pared se acepta según cuántos cortes la ven: una pared de verdad llega
   al techo, y un mueble pegado a la pared no llega.
2. **Regularización**: se toman los ejes dominantes; lo que queda a ±3° de un
   eje o de su perpendicular se endereza, y las esquinas se cierran por
   intersección.
3. **Huecos según el perfil vertical** a lo largo de cada pared:
   - puerta: libre del suelo a unos 2 m y con pared encima;
   - ventana: pared abajo y arriba, libre en medio; da el alféizar y la altura;
   - paso: dos tramos colineales separados por un hueco de suelo a techo.
4. **Grosor** a partir de las dos caras de la pared. Si solo se ve una, 10 cm,
   marcado como estimado.
5. **Fusión con la captura** (ES.1): los planos de pared de ARKit y los toques
   mandan sobre la posición, y la malla rellena lo que falta.
6. **Muebles**: lo que asoma del suelo dentro de los recintos y no es pared se
   agrupa en cajas alineadas a los ejes de la casa (`ScanObject`).

Cada elemento lleva `confidence` (0–1) y `source` (`mesh`, `arkit` o `mark`).

### ES.3 · Revisión en la planta

- Revisión sobre el lienzo, con el corte y la cenital de fondo y las propuestas
  coloreadas por confianza. Se acepta todo o se corrige cada propuesta.
- **«Pegar al escaneo»**: en una pared dibujada a mano, ajusta su posición,
  ángulo, grosor y altura a la malla más cercana.
- Qué se guarda:
  - en `PlanSegment`: `thicknessM`, `heightM` y `source: scan`;
  - los huecos como `PlanOpening`;
  - los muebles como `prop`, con `props.scanBox`, en la capa `environment`;
  - todo va en props libres, sin cambiar el esquema.
- El motor de luz ya convierte segmentos y aberturas en bloqueadores y
  aperturas; solo hay que comprobar que respeta `heightM`.

### ES.4 – ES.7 · Después

- **ES.4**: paredes, suelo y techo paramétricos con UV. Por cada pared se
  proyectan las fotos con pose que la ven de frente, se mezclan las mejores y
  se quita lo que tapa un mueble.
- **ES.5**: la categoría del mueble sale de Vision sobre sus fotos o se elige a
  mano. Se pone el modelo de la biblioteca o de un pack CC0 (F6.15) escalado a
  la caja. A Unreal va como `unreal_asset_ref`.
- **ES.6**: `_apply_structure` (`iris_stage_link.py`) recibe las paredes con su
  material y los muebles como assets. La malla va como actor oculto.
- **ES.7**: profundidad monocular (Depth Anything V2 pequeño en Core ML)
  escalada con los puntos de ARKit y fundida en TSDF, para tener una malla en
  vivo como guía. No sustituye a RealityScan.

## Verificación

- **Pruebas de `scan_structure.dart`** con mallas sintéticas:
  - habitación en L con una puerta;
  - ventana con alféizar;
  - armario pegado a la pared (no es pared);
  - paredes con 2° de ruido (salen rectas y a escuadra).
- **Casa de Daniel**: se compara con medidas tomadas con metro. El objetivo es
  menos de 5 cm de error en paredes y menos de 10 cm en huecos.
- **Motor de luz**: el recinto escaneado tiene techo automático y la luz entra
  por la ventana detectada.
