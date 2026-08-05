# Cloudinary — configuración para IRIS DP

IRIS DP sube imágenes de proyectos a **Cloudinary** (CDN optimizado). Supabase guarda solo metadatos en `media_assets`.

## 1. Crear cuenta y cloud

1. Regístrate en [cloudinary.com](https://cloudinary.com)
2. Anota **Cloud name** (Dashboard → Account Details)

## 2. Upload preset (unsigned)

Settings → Upload → Add upload preset:

| Campo | Valor |
|-------|--------|
| Preset name | `iris_dp_unsigned` (o el que prefieras) |
| Signing Mode | **Unsigned** |
| Folder | `iris-dp` |
| Allowed formats | jpg, png, webp, gif, heic |
| Max file size | 20 MB (ajusta si necesitas más) |

### Transformaciones en el preset (optimización)

En **Upload manipulations** o **Incoming transformation**:

```
c_limit,w_3840,h_3840/f_auto/q_auto:good/fl_strip_profile
```

Esto limita a 4K, comprime automáticamente y elimina EXIF.

## 3. Variables en la app

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key \
  --dart-define=CLOUDINARY_CLOUD_NAME=tu_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=iris_dp_unsigned
```

Añade a `.env` (para `scripts/run_cloud.sh`):

```
CLOUDINARY_CLOUD_NAME=tu_cloud
CLOUDINARY_UPLOAD_PRESET=iris_dp_unsigned
```

## 4. Secretos GitHub Actions

| Secreto | Valor |
|---------|--------|
| `CLOUDINARY_CLOUD_NAME` | Cloud name |
| `CLOUDINARY_UPLOAD_PRESET` | Nombre del preset |

**No** incluyas `API Secret` en la app — solo el preset unsigned con carpeta restringida.

## 5. Estructura en Cloudinary

Las imágenes se organizan reflejando el orden de la app:

```
iris-dp/{workspaceId}/{projectCloudId}/moodboard/g002_luz_nocturna/0003
iris-dp/{workspaceId}/{projectCloudId}/shots/scene3_shot2/refs/0001
```

## 6. Migración Supabase

Ejecuta [`supabase/migrations/010_media_assets_cloudinary.sql`](../supabase/migrations/010_media_assets_cloudinary.sql) en el SQL Editor.

## 7. Modo offline

Sin credenciales Cloudinary la app funciona en local; las imágenes no se sincronizan entre dispositivos hasta configurar Cloudinary.
