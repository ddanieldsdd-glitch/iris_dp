# Campos_Tecnicos_Futuros

| área | campo_propuesto | unidad/formato | por_qué | fuente_prioritaria | dependencias | prioridad |
| Luces | lux_1m | lux @ 1 m | Permite comparar intensidad real y no solo vatios | fabricante / fotometría | accesorio + distancia | CRÍTICA |
| Luces | footcandles_1m | fc @ 1 ft/1 m según fuente | Compatibilidad con prácticas de iluminación | fabricante / fotometría | unidad y distancia de medición | ALTA |
| Luces | beam_angle_deg | grados | Define apertura del haz | fotometría fabricante | óptica/accesorio | ALTA |
| Luces | field_angle_deg | grados | Define área útil iluminada | fotometría fabricante | óptica/accesorio | ALTA |
| Luces | photometric_distance | m | Evita mezclar mediciones hechas a distancias distintas | fabricante | lux/fc | ALTA |
| Luces | accessory_photometry_id | ID/ficha | Una misma luminaria cambia mucho con accesorios | fabricante | accesorios | CRÍTICA |
| Luces | power_draw_w | W | Separar consumo real de potencia nominal | fabricante | modo/CCT | CRÍTICA |
| Luces | power_modes | texto/JSON | Permite presupuestar consumo por modo | fabricante | CCT/efectos | ALTA |
| Ópticas | distortion | % / nota | Afecta composición y VFX | fabricante/tests | focal + distancia | MEDIA |
| Ópticas | breathing | bajo/medio/alto + nota | Importante en rack focus | tests/fabricante | focal | ALTA |
| Ópticas | transmission_t | T-stop | Separar f-stop de transmisión real | fabricante/tests | focal | ALTA |
| Ópticas | image_circle_mm | mm | Base del comprobador de cobertura | fabricante/CineD | gate | CRÍTICA |
| Ópticas | close_focus_m | m | Determina posibilidad de planos cercanos | fabricante/CineD | focal | CRÍTICA |
| Ópticas | front_diameter_mm | mm | Compatibilidad con mattebox/filtros | fabricante | accesorios | ALTA |
| Cámaras | recording_media | tipo | Necesario para preparar rodaje | fabricante | codec/modo | ALTA |
| Cámaras | data_rate_mb_s | MB/s | Permite calcular almacenamiento | fabricante | codec/res/fps | ALTA |
| Cámaras | power_draw_w | W | Presupuesto energético real | fabricante | modo/accesorios | ALTA |
| Cámaras | rolling_shutter_ms | ms | Afecta movimiento y elección de cámara | tests/CineD | modo | ALTA |
| Cámaras | dynamic_range_stops | stops | Comparación de respuesta tonal | tests/CineD/fabricante | modo/ISO | MEDIA |
| Cámaras | internal_nd_stops | stops | Afecta exposición y rapidez de trabajo | fabricante | modo | ALTA |
| Modos | iso_base_by_mode | ISO | Evita asumir un ISO global para toda la cámara | fabricante | modo/gamma | CRÍTICA |
| Modos | active_area_mm | ancho x alto | Base exacta de FOV/crop/cobertura | fabricante | resolución/AR | CRÍTICA |
| Película | gauge | 8/16/35/65 | Separar película de formato de captura | Kodak/fabricante | stock | CRÍTICA |
| Película | perforation_by_gauge | 1R/2R/BH/KS etc. | La perforación depende del gauge y uso | Kodak/fabricante | stock + gauge | CRÍTICA |
| Película | exposure_index | EI | Permite planificación de exposición analógica | Kodak/datasheet | stock | ALTA |
| Ópticas | lens_serial_number | texto | Permite asociar un ejemplar concreto a tests y metadatos | fabricante / rental | lente + test | ALTA |
| Ópticas | horizontal_fov_by_mode | grados | Evita aproximaciones cuando el fabricante publica AOV | fabricante | sensor/mode + focal | ALTA |
| Ópticas | focus_rotation_deg | grados | Ayuda a valorar ergonomía y precisión de foco | fabricante/tests | lente | MEDIA |
| Ópticas | parfocal | sí/no | Importante para zooms y operaciones durante toma | fabricante/tests | zoom | ALTA |
| Ópticas | distortion_map_available | sí/no | Interesa para VFX y corrección | fabricante | lente/serial | ALTA |
| Ópticas | shading_map_available | sí/no | Permite registrar caída de luz y corrección | fabricante | lente/serial | MEDIA |
| Ópticas | lens_metadata_protocol | /i, LDS, XD, etc. | Permite pensar integración futura con cámaras/VFX | fabricante | lente | ALTA |
| Luces | ssi | índice | Comparar similitud espectral con referencia | medición independiente/fabricante | CCT | ALTA |
| Luces | tm30_fidelity | Rf | Describir reproducción cromática con mayor detalle | medición independiente | CCT | ALTA |
| Luces | tm30_gamut | Rg | Detectar saturación/desaturación relativa | medición independiente | CCT | MEDIA |
| Luces | duv | valor | Detectar desplazamiento verde/magenta | medición independiente | CCT | ALTA |
| Luces | cct_accuracy | K / ΔK | Comparar consistencia real de temperatura de color | medición independiente | modo | ALTA |
| Luces | fan_noise_db | dBA | Permite valorar fuentes para rodajes sensibles al sonido | medición independiente | modo/distancia | ALTA |
| Luces | output_stability | % | Registrar variación de salida con temperatura/tiempo | medición independiente | modo | MEDIA |
| Cámaras | codec | texto | Base para data rate y workflow | fabricante | modo | CRÍTICA |
| Cámaras | bit_depth | bits | Afecta gradación y flujo de datos | fabricante | codec | ALTA |
| Cámaras | chroma_subsampling | 4:4:4 / 4:2:2 etc. | Describir calidad de señal | fabricante | codec | ALTA |
| Cámaras | bitrate | Mb/s | Calcular almacenamiento | fabricante | codec/res/fps | CRÍTICA |
| Cámaras | power_draw_typical | W | Planificar energía real | fabricante/tests | modo/accesorios | ALTA |
| Cámaras | rolling_shutter_by_mode | ms | Relacionar modo con artefactos de movimiento | tests/fabricante | modo | ALTA |
| Proyecto | storage_margin_percent | % | Evitar quedarse corto de media | regla IRIS | data rate + horas | ALTA |
| Proyecto | backup_strategy | 3-2-1 / personalizada | Integrar seguridad de datos en planificación técnica | workflow IRIS | media | ALTA |
