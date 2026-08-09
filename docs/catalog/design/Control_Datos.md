# Control_Datos

| id | hoja | campo | registro/modelo | dato actual | problema o duda | fuente a contrastar | estado |
| DQ-001 | Ópticas | cobertura | ZEISS Master Prime | S35/FF verify | Cobertura no debe inferirse solo por nombre de familia; depende de generación/focal | ARRI/ZEISS + CineD | Pendiente |
| DQ-002 | Ópticas | close_focus | Standard Speed MKII | varios vacíos | Faltan datos por focal | CineD + fabricante | Pendiente |
| DQ-003 | Ópticas | máximo foco | familias de cine | vacío | El máximo foco normalmente es infinito; conviene normalizar el campo | Fabricante | Pendiente |
| DQ-004 | Película | perforaciones | stocks Kodak | BH/KS / según formato | La perforación depende de emulsión y formato; no debe quedar como atributo único del stock | Kodak datasheets | Pendiente |
| DQ-005 | Cámaras | ISO base | modos de cámara | por completar | ISO base/dual native depende del modo, gamma y resolución en muchas cámaras | Manual/ficha fabricante | Pendiente |
| DQ-006 | Modos_Cámara | crop | aspect ratios | por completar | El crop debe calcularse desde área activa, no desde un factor genérico | Fabricante + VFXCamDB | Pendiente |
| DQ-007 | Luces | CRI/TLCI/SSI | nuevas luces | vacío | No completar métricas de color sin fuente fiable | Fabricante / mediciones | Pendiente |
| DQ-008 | PHFX | acceso | PHFX Tools | Web | No se ha asumido API pública | PHFX | Documentado |
| DQ-F1-001 | Cámaras | max_fps | ARRI ALEXA Mini LF | 100 | Página de producto ARRI: 90 fps; manual oficial: 100 fps | ARRI product page + manual | Contradictorio |
| DQ-F1-002 | Cámaras | sensor_ancho_mm / sensor_alto_mm | Blackmagic PYXIS 6K L | 23.1 × 12.99 | Ficha oficial PYXIS 6K L: 36 × 24 mm | Blackmagic Design | Corregido |
| DQ-F1-003 | Cámaras | fuente_datos | Blackmagic PYXIS 6K | W-BOX-04 | W-BOX-04 corresponde a variante PL; la fila es L | Blackmagic Design | Corregido |
| DQ-F1-004 | Cámaras | especificaciones Sony FX6 | Sony FX6 | 35.6 × 23.8 / E | Fuente oficial registrada pero no recuperada en fase 1 | Sony | Pendiente |
| DQ-F1-005 | Película | ISO_EI | EASTMAN DOUBLE-X | 250 | No se ha contrastado en ficha específica durante Fase 1 | Kodak | Pendiente |
| DQ-F1-006 | Película | ISO_EI | TRI-X 7266 | 200 | No se ha contrastado en ficha específica durante Fase 1 | Kodak | Pendiente |
