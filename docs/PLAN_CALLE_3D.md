# Plan CA · 3D legible y calle con perfil

Aprobado el 2026-11-04. Rama `plan/calle-3d` (worktree `iris_dp_calle`), desde
`plan/es-escaneo-estructura`.

## Por qué

Daniel dibuja la «calle Raval» del plano maestro de la escena 1 de *Kebab
Khaled* y quiere que el 3D de IRIS (y luego Unreal) se parezca a la calle real
de noche: farolas cálidas de brazo en las fachadas, soportales y plataforma
única. Hoy:

- el 3D solo se lee bien en «Luz»; «Claro» es solo más claro;
- una puerta cerrada es un hueco;
- un tubo se ve como un foco y no se puede pegar a la pared;
- la altura de las paredes no se puede cambiar;
- la «Calle» es un trazo de 1,28 m sin aceras, fachadas ni farolas;
- el «Rectángulo» no pasa de 4 m de largo.

Decisiones de Daniel (2026-11-04): calle con **perfil**; farolas como **luz
práctica real** con kelvin y altura editables (estándar 4–5 m); **primero el 3D
legible**, después la calle.

## Fases

| Id | Qué | Estado |
|----|-----|--------|
| CA.1 | Modo «Maqueta» en 3D (sustituye a «Claro»), paredes con grosor, línea de altura hasta el suelo | hecho |
| CA.2 | Puertas con hoja (cerrada = cerrada) y ventanas con marco y cristal | hecho |
| CA.3 | Cada foco con su forma (tubo, panel, fresnel, práctica, farola) y tubos pegados a la pared | hecho |
| CA.4 | Altura y grosor de pared editables; el motor de luz respeta la altura | hecho |
| CA.5 | Farola real: brazo en fachada o báculo, 4,5 m, kelvin editable | hecho |
| CA.6 | Calle con perfil: calzada, aceras, bordillo o plataforma única, fachadas y «Poner farolas» | pendiente |
| CA.7 | Poyete / murete y cajas de hasta 30 m con medidas escritas | pendiente |
| CA.8 | Barra de bar y estanterías con botellas de cristal (pedido el 2026-11-04) | pendiente |

### Medidas de referencia de la calle

| Campo | Por defecto | Nota |
|---|---|---|
| Calzada | 6,0 m | 3–3,5 m por carril |
| Aceras | 2,0 m cada una | 1,8 m mínimo accesible |
| Bordillo | 0,15 m | 0 = plataforma única (Raval) |
| Fachadas | 16 m | 0 = sin fachada; planta baja ~4 m |
| Farolas | cada 18 m, 4,5 m, 2700 K | brazo en fachada o báculo |

Plantillas: «Calle del Raval» (plataforma única, 7 m entre fachadas, fachadas
de 16 m, farolas de brazo cada 15 m), «Calle con aceras» (6 + 2 × 2 m) y
«Avenida».

### Después

Unreal con el mismo aspecto: las superficies, las farolas y las hojas de las
puertas van en la misma escena que ya se manda a Unreal (F6 / ES.6).

## Verificación

- Pruebas de `PlanScene3d.build` (hojas, forma de tubo, montaje en pared,
  superficies y fachadas de la calle, farolas) y de `LightScene` (altura de
  pared, kelvin de la farola).
- En la app del Mac: la calle Raval con la plantilla, dos farolas, el poyete y
  una puerta cerrada, vista en «Maqueta» y en «Luz».
