# Funciones_Futuras

| función | entradas | salidas | valor para IRIS DP | dependencias | prioridad | estado |
| Calculadora FOV | cámara, gate, focal, AR, squeeze | HFOV/VFOV/DFOV | Elegir focal con precisión | sensor + lente | Crítica | Diseño |
| Comprobador de cobertura | círculo de imagen + área activa | cubre/no cubre + margen | Evitar viñeteo | lens data + sensor data | Crítica | Diseño |
| Calculadora de crop por AR | sensor/gate + AR | área activa + crop | Saber cuánto sensor se pierde | camera modes | Crítica | Diseño |
| Selector de lente por plano | plano + distancia + sujeto + cámara | focales compatibles | Buscar óptica desde la intención fotográfica | FOV | Crítica | Diseño |
| Calculadora DOF | focal, T-stop, distancia, CoC | near/far/DOF | Control de foco y look | sensor + lens | Alta | Diseño |
| Calculadora de exposición | ISO, T-stop, shutter, FPS, EV | EV / stops / luz requerida | Planificar exposición | camera + light | Crítica | Diseño |
| Selector de luz | T-stop, ISO, distancia, modificador | potencia/fotometría requerida | Construir paquete de iluminación | photometrics | Alta | Diseño |
| Comparador de cámaras | sensor, modes, ISO, codec, FPS | tabla de diferencias | Elegir cámara por proyecto | camera database | Alta | Diseño |
| Comparador analógico/digital | gauge, stock, sensor, lens | área, FOV, DOF, exposición | Traducir entre formatos | film + camera + lens | Alta | Diseño |
| Presupuesto técnico | material + alquiler + días | coste estimado | Elegir sistema dentro de presupuesto | catálogo/precios | Media | Futuro |
| Compatibilidad de rig | cámara, lens, accessories | alertas de incompatibilidad | Evitar problemas de rodaje | mount/accessory DB | Media | Futuro |
| Asistente de paquete | look + formato + restricciones | propuesta de cámara/lentes/luz | Preproducción rápida | toda la base | Crítica | Futuro |
| Historial de fuentes | registro + fuente + versión | trazabilidad | Auditar cualquier dato | Fuentes_Informacion | Crítica | Incluido |
| Motor Técnico / Technical Decision Engine | proyecto, cámara, modo, lente, distancia, sujeto, T-stop, FPS, shutter, ISO, luz | compatibilidad + FOV + DOF + exposición + luz requerida + alertas | Convierte la base de datos en herramienta de decisión de DP | cámaras + modos + lentes + fotometría + fórmulas | Crítica | Propuesta v1.5 |
| Comparador Cámara A/B | cámara A, modo A, cámara B, modo B | focal equivalente, crop, FOV, área activa, resolución y diferencias | Mantener encuadre al cambiar cámara | sensor + modos + FOV | Alta | Propuesta v1.5 |
| Selector de lente por intención de plano | tipo de plano, tamaño sujeto, distancia disponible, cámara | focales recomendadas + alternativas | Elegir óptica desde el plano y no solo desde catálogo | FOV + lens DB | Crítica | Propuesta v1.5 |
| Mapa de cobertura visual | cámara/gate + lente/focal + image circle | diagrama sensor/círculo + margen de cobertura | Detectar viñeteo antes de rodaje | image circle + gate | Crítica | Propuesta v1.5 |
| Pre-Light Planner | T-stop, ISO, FPS, shutter, distancia, luminaria, accesorio | lux/footcandles objetivo + luminarias candidatas + margen | Planificar iluminación antes de llegar al set | photometrics + exposición | Crítica | Propuesta v1.5 |
| Presupuesto de potencia del rodaje | luces, cargadores, cámara, monitor, accesorios, horas | W/kW, pico, consumo estimado y margen de generador | Evitar sobredimensionar o quedarse corto de energía | inventario + potencia + tiempo | Alta | Propuesta v1.5 |
| Selector de modificadores | luminaria + objetivo de calidad + distancia | softbox/lantern/grid/difusión/reflector candidatos | Relacionar luminaria con el resultado buscado | catálogo de accesorios + fotometría | Alta | Propuesta v1.5 |
| Calculadora anamórfica | sensor/gate + focal + squeeze | FOV equivalente, resolución horizontal, desqueeze y cobertura | Elegir anamórficas y prever el formato final | sensor + squeeze + lens | Alta | Propuesta v1.5 |
| Planificador de película | stock + gauge + duración + FPS + ratio de descarte | rollos, metraje, consumo, coste estimado y margen | Preparar rodaje analógico | stocks + gauge + fps | Alta | Propuesta v1.5 |
| Ficha de procedencia del dato | registro + campo | fuente, fecha, nivel de confianza y evidencia | Saber por qué IRIS cree un dato | Fuentes + Control_Datos | Crítica | Propuesta v1.5 |
| Semáforo de confianza | campo, fuente, antigüedad, conflicto | Alta/Media/Baja + motivo | Evitar decisiones basadas en datos dudosos | Control_Datos + fuentes | Crítica | Propuesta v1.5 |
| Alertas de incompatibilidad | combinación cámara/lente/formato/accesorio | bloqueos y advertencias explicadas | Prevenir errores de alquiler/preparación | reglas de compatibilidad | Crítica | Propuesta v1.5 |
| Presets de trabajo | perfil de rodaje, cámara, lentes, luces, formato | configuración reutilizable | Acelerar prep de proyectos recurrentes | todo el catálogo | Alta | Propuesta v1.5 |
| Kit Builder / Paquete de rodaje | cámara + ópticas + luces + soportes + energía + media | lista de material, cantidades, peso, potencia y faltantes | Pasar del catálogo a una lista de alquiler real | todas las categorías | Crítica | Propuesta v1.5 |
| Registro de tests | cámara/lente/stock/luz + fecha + condiciones + notas | resultado visual + valoración + enlaces/imágenes | Convertir experiencia personal en conocimiento reutilizable | proyecto + material | Alta | Propuesta v1.5 |
| Simulador de cambios | cambiar una variable: cámara/lente/ISO/T-stop/FPS/luz | diferencia antes/después | Entender consecuencias de cada decisión | motor técnico | Alta | Propuesta v1.5 |
| Modo aprendizaje | concepto + parámetros | explicación visual y resultado calculado | Usar IRIS también como herramienta formativa | motor técnico + documentación | Media | Propuesta v1.5 |
| Lens Metadata / VFX | serial, focal, focus, T-stop, distortion, shading | metadata técnico + continuidad | Preparar workflow VFX y matching | lens DB + protocolos | Alta | Fase 2 |
| Light Quality Analyzer | SSI, TM-30, DUV, CCT, ruido, estabilidad | perfil espectral/operativo | Comparar calidad real de fuentes | mediciones + fabricante | Alta | Fase 2 |
| Media & Data Planner | codec, bitrate, resolución, FPS, horas | TB + margen + backups | Planificar media y seguridad | camera modes | Alta | Fase 2 |
| Lens Character Matcher | carácter óptico + cámara + intención | familias compatibles | Elegir óptica por look además de especificación | tests + lens DB | Alta | Fase 2 |
| Scenario Compare | 2-3 configuraciones completas | ventajas, riesgos y compromisos | Tomar decisiones de sistema | motor técnico | Alta | Fase 2 |
