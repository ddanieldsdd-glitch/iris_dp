# Mapa_Sistema

| bloque | dato | se relaciona con | qué permite calcular/decidir | por qué es importante | nivel de dependencia |
| Cámara | sensor: ancho, alto, diagonal, resolución | formato, aspect ratio, lente | área de imagen, crop, FOV, cobertura, resolución útil | Define qué parte de la imagen registra realmente la cámara | Crítico |
| Cámara | gate / modo de sensor | sensor, aspect ratio, lente, FPS | área activa, crop, FOV, lectura | Un mismo sensor puede comportarse como varios formatos | Crítico |
| Cámara | FPS / shutter | modo de grabación, exposición, luz | tiempo de exposición, motion blur, necesidad de luz | Afecta exposición y movimiento | Alto |
| Cámara | ISO base / dual native ISO | modo, iluminación, exposición | rango de exposición y elección de luz | Evita elegir ISO sin conocer el comportamiento real del modo | Crítico |
| Formato | aspect ratio | gate, sensor, resolución, lente | recorte vertical/horizontal, resolución final, FOV | El aspect ratio puede recortar el sensor y cambiar el encuadre | Crítico |
| Formato | perforaciones / gate de película | película, cámara, área de imagen, lente | frame real, FOV, cobertura, consumo de negativo | En analógico determina el área expuesta y el consumo | Crítico |
| Óptica | focal | sensor/gate, distancia, plano | FOV, magnificación, distancia de cámara | Una focal no tiene un ángulo de visión universal | Crítico |
| Óptica | círculo de imagen | sensor/gate, aspect ratio | si cubre o viñetea | Permite descartar combinaciones incompatibles | Crítico |
| Óptica | close focus / foco mínimo | focal, sensor, sujeto | distancia mínima, macro/primer plano | Determina si una lente sirve para el plano previsto | Alto |
| Óptica | T-stop / apertura | ISO, FPS, shutter, luz | exposición, profundidad de campo | Conecta la óptica con la iluminación necesaria | Crítico |
| Óptica | anamorfosis / squeeze | sensor, aspect ratio, desanamorfización | FOV horizontal, imagen final | Una lente anamórfica altera la geometría efectiva | Alto |
| Óptica | montura / flange | cámara, adaptadores | compatibilidad mecánica | Una óptica puede ser ópticamente válida pero físicamente incompatible | Crítico |
| Iluminación | potencia / fotometría | ISO, T-stop, shutter, distancia | nivel de exposición esperado | Permite comprobar si el paquete de luces es suficiente | Crítico |
| Iluminación | CCT / espectro / CRI / TLCI / SSI | cámara, película, filtros, color | compatibilidad cromática y mezcla de fuentes | Dos fuentes a igual Kelvin no necesariamente se registran igual | Alto |
| Película | ISO nominal | luz, apertura, shutter, push/pull | exposición y cantidad de luz | Conecta stock con el resto del sistema de captura | Crítico |
| Película | balance de color | CCT, filtros, iluminación | corrección de color esperada | Permite decidir tungsteno/daylight y filtrado | Alto |
| Película | formato / perforación | cámara, gate, lente | área expuesta, FOV, consumo | La misma película puede existir en varios formatos | Crítico |
| Escena | distancia cámara-sujeto | focal, sensor, encuadre | FOV y perspectiva | La perspectiva depende principalmente de la posición de cámara | Crítico |
| Escena | tamaño de sujeto / plano | focal, distancia, sensor | encuadre y cobertura | Permite buscar material a partir del plano deseado | Alto |
| Resultado | resolución / delivery | aspect ratio, sensor/gate | resolución útil y crop | Evita diseñar una captura que luego no aprovecha el formato final | Alto |
| Iluminación | fotometría: lux/fc + distancia + beam/field + accesorio | luminaria, modificador, exposición, distancia | lux sobre sujeto, cobertura de haz, diafragma estimado, potencia requerida | Los vatios por sí solos no describen la luz que llega al sujeto | Crítico |
| Iluminación | potencia real y modos de consumo | luces, cargadores, cámara, generador, horas | kW pico, consumo energético, autonomía, margen | Permite construir un paquete eléctrico viable | Alto |
| Óptica | image circle | lente + gate/modo | cobertura real + margen | Evita inferir cobertura solo por S35/FF | Crítico |
| Óptica | distortion / breathing / transmission | lente + focal + distancia | riesgo visual y comportamiento en foco | La compatibilidad geométrica no describe por sí sola el look | Medio |
| Datos | fuente + fecha + confianza | cada campo técnico | trazabilidad, auditoría, alertas de revisión | Un dato sin procedencia no debe tener el mismo peso que uno verificado | Crítico |
| Decisión | configuración A/B | cámara + modo + lente + distancia | matching de focal/FOV y consecuencias del cambio | Permite adaptar paquetes sin perder intención de plano | Alto |
