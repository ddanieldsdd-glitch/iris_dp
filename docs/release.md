# Release IRIS DP — macOS + Windows

## Publicación automática (recomendado)

Tag `v*` en GitHub dispara [`.github/workflows/release.yml`](../.github/workflows/release.yml) en la raíz del repo:

1. Build macOS (`.dmg`) y Windows (`.zip`)
2. Crea **GitHub Release** con los assets
3. Registra URLs en Supabase (`app_releases`) — aviso automático en la app

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

---

## macOS (.dmg) — build local

```bash
chmod +x scripts/build_macos_dmg.sh
./scripts/build_macos_dmg.sh
```

### Notarización Apple (App Store / distribución fuera de store)

1. Certificado **Developer ID Application** en Keychain
2. Firmar: `codesign --deep --force --verify --verbose --sign "Developer ID Application: …" build/macos/Build/Products/Release/iris_dp.app`
3. Notarizar el DMG (ver comentarios en `scripts/build_macos_dmg.sh`)
4. Staple: `xcrun stapler staple IRIS-DP.dmg`

## Windows

```powershell
.\scripts\build_windows.ps1
```

Distribuir carpeta `Release` o empaquetar con MSIX / Inno Setup.

## iPad (TestFlight)

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Subir con Transporter o `xcrun altool`.

## Variables de entorno en CI

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (registrar `app_releases`; solo CI)
- `APPLE_CERTIFICATE` / `APPLE_CERTIFICATE_PASSWORD` (macOS)
- `WINDOWS_CERTIFICATE` (opcional)
