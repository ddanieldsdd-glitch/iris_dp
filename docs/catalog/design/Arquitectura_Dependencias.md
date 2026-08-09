# Arquitectura_Dependencias

| Capa | entidad | depende_de | habilita | prioridad |
| Datos | Cámara | fabricante + modo | FOV, crop, exposición, energía, media | CRÍTICA |
| Datos | Modo de cámara | cámara | FOV, cobertura, resolución, bitrate | CRÍTICA |
| Datos | Lente | fabricante + tests | FOV, DOF, cobertura, carácter, VFX | CRÍTICA |
| Datos | Luz | fabricante + fotometría | Pre-Light, exposición, energía | CRÍTICA |
| Datos | Accesorio de luz | luz | fotometría real por configuración | ALTA |
| Motor | Cobertura | modo + image circle | alertas de viñeteo | CRÍTICA |
| Motor | FOV | modo + focal + AR | selector de lente y matching | CRÍTICA |
| Motor | DOF | focal + distancia + T-stop + CoC | planificación de foco | ALTA |
| Motor | Exposición | ISO + T-stop + shutter + luz | Pre-Light | CRÍTICA |
| Motor | Potencia | W + horas + baterías/generador | Power Planner | CRÍTICA |
| Motor | Media | bitrate + horas + cámaras | Data Planner | ALTA |
| UX | Recomendador | todos los motores | decisiones explicables | ALTA |
| UX | Test Library | material + proyecto + imágenes | personalización basada en experiencia | ALTA |
