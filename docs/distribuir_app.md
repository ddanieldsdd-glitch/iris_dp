# Distribuir IRIS DP — Mac, Windows e iPad

No existe un **único instalador universal** que detecte solo y funcione en Mac, Windows e iPad: Apple, Microsoft e iOS exigen **formatos distintos** (.dmg / .app, .exe, .ipa). Lo que sí puedes hacer es generar cada build desde este repositorio y compartir el archivo correcto con cada dispositivo.

---

## Resumen rápido

| Dispositivo | Archivo | Cómo generarlo |
|-------------|---------|----------------|
| **Mac** | `IRIS-DP.dmg` | `./scripts/build_release.sh` (en Mac) |
| **Otro Mac** | Mismo `.dmg` | AirDrop, USB, Google Drive, email… |
| **Windows** | Carpeta `Release/` | `./scripts/build_release.sh` en Windows |
| **iPad** | `.ipa` | `./scripts/build_ipad.sh` + TestFlight o Xcode |

Todos los scripts leen **`.env`** con `SUPABASE_URL` y `SUPABASE_ANON_KEY` para incluir la nube en el instalador.

---

## 1. Preparar `.env` (una vez)

```bash
cd iris_dp
cp .env.example .env
```

Edita `.env`:

```bash
SUPABASE_URL=https://TU_PROYECTO_REAL.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

**Importante:** La URL debe ser la **Project URL** exacta de supabase.com → Settings → API. Si la URL no existe en internet, login y sync fallarán.

---

## 2. Instalar en macOS (este Mac)

```bash
cd iris_dp
chmod +x scripts/build_release.sh
./scripts/build_release.sh
```

Resultado: `build/dmg/IRIS-DP.dmg`

1. Abre el `.dmg`
2. Arrastra **IRIS DP** a **Aplicaciones**
3. Primera vez: clic derecho → **Abrir**

---

## 3. Pasar la app a otro Mac

1. Genera el `.dmg` como arriba (con el mismo `.env` / mismas claves Supabase)
2. Copia `IRIS-DP.dmg` al otro Mac (AirDrop, iCloud, USB…)
3. Instala igual (arrastrar a Aplicaciones)
4. Abre IRIS DP → **inicia sesión con el mismo email**
5. Pulsa el **icono de nube** para sincronizar proyectos

---

## 4. Instalar en iPad

Requisitos: **Mac con Xcode**, cuenta **Apple Developer** (99 €/año para TestFlight/App Store, o cuenta gratuita solo para tu iPad en desarrollo).

```bash
cd iris_dp
chmod +x scripts/build_ipad.sh
./scripts/build_ipad.sh
```

El `.ipa` queda en `build/ios/ipa/`.

### Opción A — TestFlight (recomendado para varios iPads)

1. Sube el IPA con la app **Transporter** (Mac App Store)
2. En App Store Connect crea la app y añade testers
3. En el iPad instala **TestFlight** y acepta la invitación

### Opción B — Tu iPad con cable (desarrollo)

1. Conecta el iPad al Mac
2. Xcode → **Window → Devices and Simulators**
3. Selecciona el iPad → arrastra el `.ipa` o instala desde Xcode con `flutter run -d <id-del-ipad>`

### Opción C — Mismo WiFi (desarrollo rápido)

```bash
./scripts/run_cloud.sh   # detecta dispositivos
flutter devices          # copia el ID del iPad
flutter run -d <ID_IPAD> --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

## 5. Windows

En un PC con Flutter instalado:

```powershell
cd iris_dp
.\scripts\build_release.sh   # o build_windows.ps1
```

Comparte la carpeta `build\windows\x64\runner\Release\` (zip). El usuario ejecuta `iris_dp.exe`.

---

## 6. Actualizar la app en todos los dispositivos

### Aviso automático (modo nube)

Con sesión iniciada, IRIS DP comprueba **una vez al día** si hay una versión nueva en Supabase (`app_releases`). Si la hay, verás un **banner azul** en la pantalla de proyectos con enlace a **GitHub Releases** (gratis; los instaladores no están en Supabase).

### Publicar una versión nueva (DP)

1. Sube la versión en `pubspec.yaml` (`version: 1.0.1+2`)
2. Haz commit y crea tag:
   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   ```
3. **GitHub Actions** compila macOS/Windows, crea el Release en GitHub y registra la URL en Supabase.
4. Todos los directores verán el banner al abrir la app (con internet).

**Secretos en GitHub** (Settings → Secrets → Actions):

| Secreto | Uso |
|---------|-----|
| `SUPABASE_URL` | Build + registro de versión |
| `SUPABASE_ANON_KEY` | Build con nube |
| `SUPABASE_SERVICE_ROLE_KEY` | Solo CI — registrar en `app_releases` |

**Migración SQL necesaria (una vez):** ejecuta [`supabase/migrations/006_app_releases.sql`](supabase/migrations/006_app_releases.sql) en el SQL Editor de Supabase.

**Fallback manual** (si el CI falla pero ya subiste el Release a GitHub):

```bash
export SUPABASE_SERVICE_ROLE_KEY=eyJ...   # Dashboard → Settings → API → service_role
./scripts/publish_release.sh v1.0.1 tu-usuario/tu-repo
```

### Tras instalar en cada dispositivo

1. **Instala** la nueva versión (`.dmg`, Windows zip, `.ipa`)
2. **Inicia sesión** con la misma cuenta
3. La app **sincroniza sola** al detectar versión nueva; también puedes pulsar sync manual

Los **proyectos no se pierden**: están en Supabase, no dentro del instalador.

---

## 7. ¿Por qué no hay un instalador «inteligente» único?

- **macOS** usa `.app` / `.dmg` (Apple)
- **Windows** usa `.exe` / MSIX (Microsoft)  
- **iPad** solo acepta apps firmadas por Apple (`.ipa`, App Store, TestFlight)

Un solo archivo `.exe` no puede instalarse en Mac ni iPad, y viceversa. El script `build_release.sh` **detecta en qué sistema lo ejecutas** y genera el formato correcto **para esa plataforma**.

---

## Solución de problemas de login

| Error | Causa | Solución |
|-------|--------|----------|
| `Failed host lookup` | URL Supabase incorrecta | Copia Project URL real desde supabase.com |
| `Invalid login` | Email/contraseña | Usa «Crear cuenta» o corrige credenciales |
| `Email not confirmed` | Confirmación activa | Desactiva en Supabase Auth → Email |
