# Tokens de diseño IRIS DP (referencia ShotDeck)

Estética oscura cinematográfica para moodboard, biblia y pantallas de colaboración.

## Color (modo oscuro — principal)

| Token | Hex | Uso |
|-------|-----|-----|
| `background` | `#000000` | Fondo app |
| `surface` | `#0D0D0D` | Paneles base |
| `surfaceElevated` | `#1A1A1C` | Tarjetas, modales |
| `surfaceOverlay` | `#2C2C2E` | Inputs, chips |
| `accent` | `#2997FF` | CTAs, selección, links |
| `textPrimary` | `#FFFFFF` | Títulos |
| `textSecondary` | `#99EBEBF5` | Cuerpo, descripciones |
| `textTertiary` | `#636366` | Hints, metadatos |
| `success` | `#30D158` | Sync OK, estados positivos |
| `warning` | `#FFD60A` | Pendiente, preproducción |
| `error` | `#FF453A` | Errores, eliminar |

## Imagen / grid (estilo ShotDeck)

- Stills en grid denso, `BorderRadius` 12px
- Overlay inferior: gradiente `black87 → transparent`
- Caption blanco, 1 línea, ellipsis
- Selección: borde `accent` 3px + overlay 25% accent
- Badge fuente (Scout, UE5) esquina superior

## Tipografía

- Display: bold, tracking apretado
- Cuerpo: regular 14–16px
- Captions: 10–12px, `textSecondary` o blanco sobre imagen

## Componentes nuevos (auth, sync)

Reutilizar `AppPalette` y `AppTypography` — no crear paleta paralela.
- Botones primarios: `FilledButton` con `accent`
- Indicador sync: icono nube + color `success` / `warning` / `textTertiary`

Implementación: [`lib/core/theme/app_colors.dart`](../lib/core/theme/app_colors.dart)
