# Release IRIS DP — macOS + Windows + iPad

## Publicación automática (recomendado)

Tag `v*` en GitHub dispara [`.github/workflows/release.yml`](../.github/workflows/release.yml):

1. Build macOS (`.dmg`), Windows (`.zip`) e iPad (`.ipa` sin firma)
2. Crea **GitHub Release** con los tres assets
3. Registra URLs en Supabase (`app_releases` para macos, windows, ipad)

```bash
# 1. Bump version en pubspec.yaml
# 2. Publicar
git tag v1.0.2 && git push origin v1.0.2
```

### Secretos GitHub (Settings → Secrets → Actions)

| Secreto | Obligatorio |
|---------|-------------|
| `SUPABASE_URL` | Sí |
| `SUPABASE_ANON_KEY` | Sí |
| `SUPABASE_SERVICE_ROLE_KEY` | Sí (registrar versión; **nunca** en la app) |

### Supabase (una vez)

Ejecuta [`supabase/migrations/006_app_releases.sql`](../supabase/migrations/006_app_releases.sql).

### Registro manual

Si el Release ya existe en GitHub pero Supabase no tiene la fila:

```bash
export SUPABASE_URL=https://...
export SUPABASE_SERVICE_ROLE_KEY=eyJ...
./scripts/publish_release.sh v1.0.2 owner/repo
```

El script [`scripts/register_app_release.sh`](../scripts/register_app_release.sh) registra tres plataformas:

- `macos` → `IRIS-DP.dmg`
- `windows` → `IRIS-DP-Windows.zip`
- `ipad` → `IRIS-DP.ipa`

---

## Actualizador en la app (escritorio)

Mac y Windows pueden actualizar **desde la app** sin abrir GitHub:

1. Banner detecta versión en Supabase
2. **Actualizar ahora** descarga el asset del Release
3. macOS: abre el `.dmg` montado
4. Windows: descomprime, reemplaza archivos y reinicia
5. **Ya actualicé** dispara sync con la nube

Código: [`lib/core/update/app_update_installer.dart`](../lib/core/update/app_update_installer.dart)

---

## macOS (.dmg) — build local

```bash
chmod +x scripts/build_macos_dmg.sh
./scripts/build_macos_dmg.sh
```

### Notarización Apple (opcional, distribución fuera de store)

1. Certificado **Developer ID Application** en Keychain
2. Firmar: `codesign --deep --force --verify --verbose --sign "Developer ID Application: …" build/macos/Build/Products/Release/iris_dp.app`
3. Notarizar el DMG (ver comentarios en `scripts/build_macos_dmg.sh`)
4. Staple: `xcrun stapler staple IRIS-DP.dmg`

## Windows

```powershell
.\scripts\build_windows.ps1
```

Distribuir `IRIS-DP-Windows.zip` del Release o carpeta `Release`.

## iPad (SideStore — CI sin firma)

GitHub Actions ejecuta:

```bash
flutter build ios --release --no-codesign \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
./scripts/package_unsigned_ipa.sh
```

SideStore re-firma el IPA en cada dispositivo con el Apple ID del usuario.

Build local equivalente:

```bash
./scripts/build_ipad.sh
# o
flutter build ios --release --no-codesign ...
./scripts/package_unsigned_ipa.sh
```

### TestFlight (Apple Developer $99/año)

Subir IPA firmado con Transporter o `xcrun altool`.

## Variables de entorno en CI

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (registrar `app_releases`; solo CI)

No se requieren certificados Apple para el IPA de SideStore (build `--no-codesign`).
