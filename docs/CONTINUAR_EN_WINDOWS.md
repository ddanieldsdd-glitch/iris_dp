# Seguir el desarrollo en el PC (Windows)

Desde el 2026-11-10 el plan [PLAN_DOCUMENTOS_RODAJE.md](PLAN_DOCUMENTOS_RODAJE.md) se programa en el PC. Esta nota recoge lo que una sesión de Claude Code en el Mac sabía y que no viaja al PC.

## 1. Preparar y abrir

La preparación del PC y el arranque están en [DESARROLLO_EN_WINDOWS.md](DESARROLLO_EN_WINDOWS.md) (`setup_windows_dev.ps1` y `run_windows.ps1`). Después:

```powershell
cd C:\dev\iris_dp
git fetch
git switch plan/dr-documentos-rodaje
git pull
flutter pub get
.\scripts\run_windows.ps1
```

- `.env` no está en el repositorio. Rellénalo con las cuatro claves del Mac (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET`).
- En Claude Code para Windows, abre la carpeta `C:\dev\iris_dp` y pide: «sigue docs/PLAN_DOCUMENTOS_RODAJE.md desde DR.1, leyendo antes docs/CONTINUAR_EN_WINDOWS.md».

## 2. Normas que siguen vigentes

- Interfaz y mensajes de commit en español.
- No publicar ni fusionar en `main` sin el OK de Daniel. Antes de dar algo por bueno, leer de verdad el resultado de `flutter analyze`, `flutter test` y `dart run tool/check_architecture.dart`.
- Si sube `kSchemaVersion`, guardar su instantánea: `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/drift_schema_v<N>.json` (si se queda colgado tras escribir el archivo, se puede cortar). Sin ella falla `test/database_health_test.dart`.
- Las migraciones de Supabase (`supabase/migrations/`) las ejecuta Daniel en el SQL Editor.
- Los PDF de reserva de material llevan datos personales tras «Observaciones»: nunca guardar ese texto ni meter esos PDF en el repositorio.
- No usar `dart format` sobre archivos enteros que no estaban formateados.
- Antes de probar una rama que cambie el esquema, copiar `%APPDATA%\IRIS DP\IRIS`.

## 3. Lo que no se hace desde el PC

| Tarea | Quién la cubre |
|---|---|
| Compilar macOS e iOS | El CI de GitHub en cada `git push` (`.github/workflows/ci.yml`) |
| Instalar en iPad e iPhone | El Mac, solo, cada 15 minutos cuando coincide encendido con ellos, una vez publicada la versión |
| Actualizar el Mac | La propia app al detectar la versión nueva |
| Publicar | `scripts/release.sh` desde Git Bash en una copia limpia de `main`, solo con OK de Daniel |

## 4. Estado al 2026-11-10

- Publicada v1.8.0 (esquema 63). Migraciones 013–015 aplicadas en Supabase. Instalador del iPad e iPhone al día.
- Rodaje de Kebab Khaled del 13 al 16-11. La Tanda 1 del plan se quiere usar en el rodaje: publicarla como muy tarde el 12-11 por la mañana, solo si todo está en verde.
- Pendiente de confirmar en un PC real: al cerrar la ventana, la app terminó con error en la máquina Windows de GitHub (también la 1.7.4, sin GPU real).
- Visto una vez en el Mac: la primera apertura tras actualizar falló con «database is locked» al migrar la base y no lo reintentó; al reabrir migró bien. La app no fija `busy_timeout`. Si se repite, empezar por ahí (`_openConnection` en `lib/core/database/app_database.dart`).
- Para DR.4 hace falta el plan de rodaje real (PDF) como muestra. Guardarlo fuera del repositorio si lleva datos personales.
