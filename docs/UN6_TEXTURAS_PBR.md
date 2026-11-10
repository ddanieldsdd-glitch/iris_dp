# UN.6 · Texturas PBR y HDRI CC0 (preparación)

Estado a 2026-11-10: **no se ha descargado nada**. Los identificadores se han confirmado en las API públicas de Poly Haven y ambientCG, solo con metadatos; el aspecto de cada textura está por revisar. Las dos bibliotecas publican con CC0.

## Emparejado por tipo de superficie

`Tesela` es el tamaño real según Poly Haven. Las claves son los `id` de `kWallMaterials` y `kFloorMaterials` (`lib/features/camera_plan/light/surfaces.dart`), y sirven también de clave para el material de Unreal de UN.5.

| Superficie | `id` | Poly Haven | Tesela | Alternativa ambientCG |
|---|---|---|---|---|
| Pared blanca | `white` | `white_plaster_02` | 1,0 m | `Plaster001` |
| Pared crema | `cream` | `painted_plaster_wall` | 2,0 m | `PaintedPlaster017` |
| Pared gris | `grey` | `grey_plaster` | 1,0 m | `Concrete031` |
| Pared de hormigón | `concrete` | `concrete_wall_008` | 2,7 m | `Concrete034` |
| Pared de ladrillo | `brick` | `red_brick` | 1,4 m | `Bricks074` |
| Pared de madera | `wood` | `weathered_brown_planks` | 1,8 m | `Wood051` |
| Pared negra | `black` | sin textura | | |
| Suelo de madera | `wood` | `wood_floor` | 1,7 m | `WoodFloor043` |
| Suelo de hormigón | `concrete` | `concrete_floor_02` | 2,0 m | `Concrete042A` |
| Suelo claro | `light` | `concrete_floor_painted` | por confirmar | `Concrete031` |
| Moqueta oscura | `dark` | `dirty_carpet` | 0,6 m | `Carpet016` |

## HDRI por entorno

| Entorno | HDRI de Poly Haven |
|---|---|
| Interior | `empty_warehouse_01` |
| Plató | Sin HDRI: el plató sigue negro, solo focos |
| Exterior nublado o sin sol | `kloofendal_overcast_puresky` |
| Exterior con sol | `qwantani_noon_puresky` |

## Qué falta en el código

1. `plan_scene3d.dart` manda solo `rgb` por pared; hay que añadir el `id` del material.
2. Las paredes de `viewer.js` no tienen UV: se generan en metros del mundo, con la tesela de la tabla.
3. **La calibración manda sobre la textura.** El albedo se escala para que su luminancia lineal media sea la `reflectance` del material, y el fotómetro no cambia. El mapa de color es sRGB; normal y rugosidad, lineales.
4. Un HDRI solo como fondo y reflejo, con intensidad ligada a `exposure.scale`. Si suma luz difusa, el visor dejará de coincidir con el fotómetro.
5. El glTF a Unreal sigue sin texturas: allí manda el material de UN.5.
6. Las texturas no van dentro de la app: pack aparte que se baja al pedirlo, a 1K. Conviene medir el peso real antes de decidir.

## Fab: ¿se puede cargar en IRIS un GLB propio?

Leído en `https://www.fab.com/eula` (versión del 1-10-2024). Es una lectura del texto, no asesoramiento legal.

**Sí, para uso privado en los propios dispositivos.** La sección 3(a) permite usar, reproducir y mostrar el contenido en privado, y el resumen dice que no se limita a Unreal. Las imágenes y los vídeos hechos con él se reparten libremente (4(b)).

Límites para el diseño:

- IRIS no puede incluir contenido de Fab: cada usuario aporta su archivo (5(a) y 6(b)(ii)).
- No se puede dejar que terceros lo incorporen a sus proyectos, ni ofrecerlo en herramientas que permitan exportarlo (6(b)(iii)).
- Solo se comparte con colaboradores del mismo proyecto, que lo borran al acabar (5(a)). La nube entre cuentas y el `.irisstage` no deberían llevarlo por defecto.
- La sincronización entre dispositivos del mismo dueño no aparece en el texto. Parece fuera de «Distribute» (4(a)), pero es interpretación.
- Por asset, mirar en la ficha si hay GLB (2(d)) y qué licencia lleva (2(c)). Lo adquirido antes conserva sus términos (7(a)); los Megascans reclamados en Quixel podrían seguir atados a Unreal.

## Decisiones de Daniel

- Descargar el pack CC0 y con qué peso máximo.
- Revisar «Megascans solo dentro de Unreal».
