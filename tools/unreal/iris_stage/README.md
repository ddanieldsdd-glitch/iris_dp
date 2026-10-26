# IRIS Stage Link para Unreal

Con esto, lo que cambias en la planta de IRIS (luces, sol y cielo) se aplica al momento en Unreal. Es el paso 1 de F6.19 (`docs/PLAN_F6_3D_PREVIS.md`).

## Instalar (una vez por proyecto de Unreal)

1. En Unreal 5.5, **Edit → Plugins**, activa:
   - Python Editor Script Plugin;
   - Remote Control API;
   - Editor Scripting Utilities.

   Reinicia el editor.
2. Copia la carpeta `Content/Python` de aquí dentro de la carpeta `Content` del proyecto. Si el proyecto ya tiene un `init_unreal.py`, añádele la línea `import iris_stage_link`.
3. Abre el proyecto. En el **Output Log** debe salir:
   `[IRIS Stage] Link v1 listo en /Game/Python/iris_stage_link_PY.Default__IrisStageLink`.

## Conectar desde IRIS

1. Abre la planta de cámara y luz, y el panel 3D.
2. Pulsa el botón de Unreal de la barra del 3D (o «Unreal en vivo» a pantalla entera).
3. Escribe el equipo:
   - `127.0.0.1` si Unreal está en el mismo PC;
   - si no, la IP del PC en la red local.

   El puerto es 30010.
4. Pulsa **Conectar**.

Mientras el 3D esté abierto, cada cambio llega a Unreal en unos milisegundos. Las piezas de IRIS van en la carpeta «IRIS» del World Outliner, con la etiqueta `iris:<id>`. IRIS no toca nada más del nivel.

## Qué se manda

| IRIS | Unreal |
|---|---|
| Foco pequeño (fresnel, PAR, recorte) | SpotLight. El haz de IRIS cae entre el cono interior y el exterior |
| Panel, tubo o softbox (desde 25 cm) | RectLight del tamaño de la fuente |
| Luz omni (práctica, globo) | PointLight |
| Intensidad | Candelas en el eje, con regulación, difusiones y gelatinas aplicadas. Son los mismos números que el fotómetro de IRIS |
| Color | Temperatura en kelvin |
| Sol del esquema | DirectionalLight en lux, con SkyAtmosphere y SkyLight |

## Seguridad

Remote Control escucha en toda la red local sin contraseña. IRIS Stage Link solo deja hacer lo de la tabla: no hace falta activar «Enable Remote Python Execution». Si el PC está en una red compartida, pon una contraseña en **Project Settings → Remote Control → Security** y escríbela en IRIS al conectar.

## Para después

- La niebla y el humo (F6.9 y F6.16.5), cuando existan en la planta.
- La vuelta, de Unreal a IRIS (paso 2). `Snapshot()` ya devuelve cómo están las piezas en Unreal.
- La exposición de la cámara (F6.4.6). Con intensidades físicas, la exposición automática de Unreal se adapta. Para comparar con el fotómetro conviene fijarla a mano.
