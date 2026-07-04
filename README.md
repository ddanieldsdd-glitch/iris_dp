# IRIS DP

App Flutter de **preproducción cinematográfica** para macOS: importación de guiones, localizaciones y guion técnico de planos.

## Requisitos

- Flutter 3.8+ ([instalación](https://docs.flutter.dev/get-started/install))
- macOS (plataforma principal de desarrollo)
- Licencia de [Syncfusion Flutter PDF](https://www.syncfusion.com/sales/products) para extracción de texto en producción (modo community disponible bajo condiciones)

## Primer arranque

```bash
cd iris_dp
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

## Clave API de Claude (opcional)

La normalización de escenas con IA es opcional. **No incluyas claves en el código ni en assets.**

1. Abre la app → icono de **Ajustes** (en la pantalla de proyectos)
2. Pega tu clave de [Anthropic Console](https://console.anthropic.com/)
3. Se guarda localmente en `~/Documents/iris_dp/settings.json`

Sin clave, el parser local detecta escenas automáticamente.

## Workflow

1. **Proyectos** — crear y organizar por grupos
2. **Guion literario** — importar PDF/DOCX/TXT/Fountain, editar escenas, sincronizar
3. **Localizaciones** — sitios, sets, galerías de referencia
4. **Guion técnico** — tabla de planos por escena; exportar a PDF

## Tests

```bash
flutter analyze
flutter test
```

## Estructura

```
lib/
  core/          # BD (Drift), tema, utilidades, ajustes
  features/      # projects, script_import, locations, technical_script, pdf_export
test/            # Tests unitarios y de widget
```

## Datos locales

- Base de datos: `~/Documents/iris_dp.db`
- Archivos de proyecto: `~/Documents/iris_dp/projects/{id}/`

## CI

GitHub Actions ejecuta `flutter analyze` y `flutter test` en cada push/PR (ver `.github/workflows/ci.yml`).
