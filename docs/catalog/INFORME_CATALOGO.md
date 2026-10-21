# Informe del catálogo generado

Generado por `tools/build_catalog.py`. No editar a mano.

Versión del catálogo: 10. Modos de sensor en total: 675.

Grabación: `arri_alexa_sxt` con 6 medios y 41 formatos.

## Resumen

- Cámaras: 75 (5 nuevas respecto a la base). Modos leídos de la lista: 59. Modos confirmados por el master: 5. Modos del flujo v2.0: 72.
- Ópticas: 431 (62 nuevas de la lista). Con círculo de imagen publicado: 71 (48 de la lista; el resto, del master y del flujo v2.0). Círculos inferidos descartados de la base: 382.
- Squeeze descartado en 56 ópticas esféricas (VAL-002). 59 anamórficas no traen squeeze en la lista; conservan el de la base, sin verificar. Fichas por focal del master: 16. Familias del master aplicadas: 2. 35 ópticas marcadas `es_custom` en la lista no entran en el catálogo oficial.
- Luces: 98 (13 nuevas de la lista, 5 duplicados retirados). Con haz: 59; con fotometría: 7.

## Estado de los datos

| Tipo | Fichas | Aptas para cálculos | Por estado |
|---|---|---|---|
| Cámaras | 75 | 11 | PENDIENTE 63, CONFIRMADO 10, CONFLICTO 1, SECUNDARIO 1 |
| Ópticas | 431 | 105 | PENDIENTE 326, SECUNDARIO 62, CONTRASTADO 24, CONFIRMADO 14, OBSERVADO 5 |
| Luces | 98 | 8 | PENDIENTE 87, SECUNDARIO 5, CONFIRMADO 3, CONFLICTO 3 |

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
- Gate pendiente de confirmar: `blackmagic_pyxis_6k_pl` · 4K S35 4:3 (PENDIENTE confirmar ventana)
- Gate pendiente de confirmar: `blackmagic_pyxis_6k_pl` · 4K 16:9 (PENDIENTE confirmar ventana)
- Gate pendiente de confirmar: `blackmagic_pyxis_6k_pl` · 4K DCI 17:9 (PENDIENTE confirmar ventana)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 2.2:1 Open Gate (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 2:1 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 3:2 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 16:9 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 17:9 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 8K 2.4:1 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 2.2:1 Open Gate (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 2:1 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 3:2 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 16:9 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 17:9 (PENDIENTE confirmar escalado)
- Gate pendiente de confirmar: `blackmagic_ursa_cine_17k_65` · 4K 2.4:1 (PENDIENTE confirmar escalado)
- `dzofilm_pictor_20_55`: la columna `cobertura` trae un número (31.7); se mantiene el formato «FF» y no se toma como círculo de imagen.
- `dzofilm_pictor_50_125`: la columna `cobertura` trae un número (31.7); se mantiene el formato «FF» y no se toma como círculo de imagen.
- Master: `Signature Prime` aplicado a 18 ópticas (image_circle_mm).
- Master: `Master Anamorphic` aplicado a 6 ópticas (squeeze).
- Master: `Anamorphic Ultra Wide Zoom` está en estado PARTIAL y no se aplica.
- Retiradas 18 ópticas heredadas: Familia heredada con datos erróneos (T2.8 y focales 16/20/24 mm que no existen en Super Speed). La sustituyen «Super Speed MKI» y «Super Speed MKII/III».
- Flujo v2.0: 5 ópticas ZEISS Super Speed con círculo de imagen medido (típico y peor caso).
- Luces que la revisión corrige y conviene corregir también en el Excel:
  - `arri_l7c`: tipo_luz «fresnel» → formato «fresnel», tecnologia «led»
  - `arri_m18`: tipo_luz «hmi» → formato «open», tecnologia «hmi»
  - `arri_m40`: tipo_luz «hmi» → formato «open», tecnologia «hmi»
  - `aputure_storm_1200`: tipo_luz «hmi» → formato «cob», tecnologia «led»
  - `dedolight_dled4`: tipo_luz «led» → formato «fresnel», tecnologia «led»
  - `creamsource_vortex8`: tipo_luz «led» → formato «panel», tecnologia «led»
  - `practical_led_strip`: tipo_luz «practical» → formato «practical», tecnologia «led»
  - `practical_candle`: tipo_luz «practical» → formato «practical», tecnologia «led»
  - `mole_led_20k`: tipo_luz «fresnel» → formato «fresnel», tecnologia «led»
  - `mole_led_20k`: potencia_w 20000 → 3000
  - `dedolight_dled12`: tipo_luz «led» → formato «fresnel», tecnologia «led»
  - `arri_m12`: tipo_luz «hmi» → formato «open», tecnologia «hmi»
  - `arri_m8`: tipo_luz «hmi» → formato «open», tecnologia «hmi»
  - `arri_m8`: potencia_w 8000 → 800
  - `litegear_litemat`: tipo_luz «led_panel» → formato «flex», tecnologia «led»
  - `nanlux_dyno_1200c`: tipo_luz «led» → formato «panel», tecnologia «led»
  - `arri_l5_c`: tipo_luz «fresnel» → formato «fresnel», tecnologia «led»
  - `creamsource_vortex4`: tipo_luz «led» → formato «panel», tecnologia «led»
  - `astera_ax9_powerpar`: tipo_luz «LED Point Source» → formato «open», tecnologia «led»
  - `arri_s60_c_skypanel`: duplicado de `arri_skypanel_s60`; quitar la fila
  - `arri_skypanel_s60-c`: duplicado de `arri_skypanel_s60`; quitar la fila
  - `nanlite_pavotube`: duplicado de `nanlite_pavotube_ii_30x`; quitar la fila
  - `aputure_ls1200d`: duplicado de `aputure_ls_1200d_pro`; quitar la fila
  - `creamsource_doppio_plus`: duplicado de `creamsource_doppio`; quitar la fila
