# IRIS DP

App Flutter de **preproducción cinematográfica**: guion, localizaciones, biblia de fotografía, moodboard y colaboración en la nube.

## Plataformas

| Plataforma | Estado |
|------------|--------|
| macOS | Principal — instalador `.dmg` |
| Windows | `flutter build windows` |
| iPad | `flutter build ipa` (biblia + moodboard v1) |

## Requisitos

- Flutter 3.8+
- Licencia Syncfusion PDF para extracción en producción (opcional en dev)

## Primer arranque

```bash
cd iris_dp
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

### Modo nube (multi-dispositivo + directores)

1. Crea proyecto Supabase y ejecuta [`supabase/migrations/001_initial_schema.sql`](supabase/migrations/001_initial_schema.sql)
2. Crea bucket Storage `project-media`
3. Arranca con credenciales:

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Sin credenciales → **modo local** (como antes).

### Tutorial e instalación

Al abrir la app por primera vez verás un **tutorial paso a paso** (instalación, cuenta, carpetas, sync). Guía completa: [`docs/instalacion_y_actualizacion.md`](docs/instalacion_y_actualizacion.md).

### Wizard post-instalación

1. Bienvenida e instrucciones de instalación por plataforma  
2. Cuenta IRIS DP (si hay nube)  
3. Carpeta cache local (datos técnicos + documentos)  
4. Cómo actualizar en varios dispositivos (sync Supabase)  
5. Migración opcional local → nube  
6. Tour rápido en la pantalla de proyectos  

## Roles

- **DP (owner)**: ve todos los proyectos del workspace  
- **Director invitado**: solo proyectos asignados (no ve otros directores)  

Invitar desde **Editar proyecto → Invitar director por email**.

## Sync

Botón nube en la barra de proyectos. Drift = cache offline; Supabase = fuente de verdad.

## Release

Ver [`docs/release.md`](docs/release.md) y [`scripts/build_macos_dmg.sh`](scripts/build_macos_dmg.sh).

Tag `v*` dispara GitHub Actions ([`.github/workflows/release.yml`](../.github/workflows/release.yml)): build, GitHub Release y aviso automático vía Supabase.

## Diseño

Tokens estilo ShotDeck: [`docs/shotdeck_design_tokens.md`](docs/shotdeck_design_tokens.md)

## Tests

```bash
flutter analyze
flutter test
```

## Estructura

```
lib/
  core/cloud/      # Supabase, sesión
  core/sync/       # SyncEngine, proyectos, medios
  features/auth/   # Login, invitaciones
  features/onboarding/
  features/migration/
  supabase/        # SQL + RLS
```
