# Informe del catálogo generado

Generado por `tools/build_catalog.py`. No editar a mano.

Versión del catálogo: 7. Modos de sensor en total: 606.

## Resumen

- Cámaras: 72 (2 nuevas de la lista). Modos leídos de la lista: 50. Modos confirmados por el master: 4.
- Ópticas: 444 (62 nuevas de la lista). Con círculo de imagen publicado: 66 (48 de la lista, el resto del master). Círculos inferidos descartados de la base: 382.
- Squeeze descartado en 56 ópticas esféricas (VAL-002). 59 anamórficas no traen squeeze en la lista; conservan el de la base, sin verificar. Fichas por focal del master: 16. Familias del master aplicadas: 2. 35 ópticas marcadas `es_custom` en la lista no entran en el catálogo oficial.
- Luces: 103 (13 nuevas de la lista).

## Estado de los datos

| Tipo | Fichas | Aptas para cálculos | Por estado |
|---|---|---|---|
| Cámaras | 72 | 7 | PENDIENTE 64, CONFIRMADO 6, CONFLICTO 1, SECUNDARIO 1 |
| Ópticas | 444 | 100 | PENDIENTE 344, SECUNDARIO 62, CONTRASTADO 24, CONFIRMADO 14 |
| Luces | 103 | 1 | PENDIENTE 102, CONFIRMADO 1 |

## Incidencias

- `Modos_Cámara`: 13 modos estaban escritos en escalera (un valor por fila) y se han recompuesto. Conviene corregir la hoja.
- Modo sin gate, no utilizable: `bm_pyxis` · 6K 16:9
- Modo sin gate, no utilizable: `bm_pyxis` · 4K 16:9
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 17K 2:1
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 17K 17:9
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 17K 16:9
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 17K 2.4:1
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 12K 3:2
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 12K 16:9
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 12K 17:9
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 12K 2.4:1
- Modo sin gate, no utilizable: `blackmagic_ursa_17k` · 12K 6:5
- Modo de una cámara que no está en el catálogo: arri_alexa35_xtreme · 4.6K 3:2 Open Gate
- Modo de una cámara que no está en el catálogo: arri_alexa35_xtreme · 4.6K 16:9
- Modo de una cámara que no está en el catálogo: arri_alexa35_xtreme · 3.8K 2.39:1
- Modo de una cámara que no está en el catálogo: blackmagic_pyxis_6k_pl · 6K Open Gate
- Modo de una cámara que no está en el catálogo: blackmagic_pyxis_6k_pl · 6K 2.4:1
- Modo de una cámara que no está en el catálogo: blackmagic_pyxis_6k_pl · Super 35 4:3
- Modo de una cámara que no está en el catálogo: blackmagic_ursa_cine_17k_65 · 17K 2.2:1 Open Gate
- Modo de una cámara que no está en el catálogo: blackmagic_ursa_cine_17k_65 · 17K 16:9
- Modo de una cámara que no está en el catálogo: blackmagic_ursa_cine_17k_65 · 12K 3:2
- Master: cámara sin ficha en el catálogo: ALEXA 35 Xtreme
- `dzofilm_pictor_20_55`: la columna `cobertura` trae un número (31.7); se mantiene el formato «FF» y no se toma como círculo de imagen.
- `dzofilm_pictor_50_125`: la columna `cobertura` trae un número (31.7); se mantiene el formato «FF» y no se toma como círculo de imagen.
- Master: `Signature Prime` aplicado a 18 ópticas (image_circle_mm).
- Master: `Master Anamorphic` aplicado a 6 ópticas (squeeze).
- Master: `Anamorphic Ultra Wide Zoom` está en estado PARTIAL y no se aplica.
