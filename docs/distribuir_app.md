# Distribuir IRIS DP — Mac, Windows e iPad

No existe un **único instalador universal** que detecte solo y funcione en Mac, Windows e iPad: Apple, Microsoft e iOS exigen **formatos distintos** (.dmg / .app, .exe, .ipa). Lo que sí puedes hacer es generar cada build desde este repositorio y compartir el archivo correcto con cada dispositivo.

---

## Resumen rápido

| Dispositivo | Archivo | Cómo generarlo |
|-------------|---------|----------------|
| **Mac** | `IRIS-DP.dmg` | Tag `v*` → GitHub Actions, o `./scripts/build_release.sh` local |
| **Otro Mac** | Mismo `.dmg` | AirDrop, USB, Google Drive, email… |
| **Windows** | `IRIS-DP-Windows.zip` | Tag `v*` → GitHub Actions, o build local |
| **iPad** | `IRIS-DP.ipa` | Tag `v*` → GitHub Actions (sin firma, SideStore), o `./scripts/build_ipad.sh` local |

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

### Opción A — Desde la app (recomendado para amigos)

1. Inicia sesión en IRIS DP
2. Si hay versión nueva, pulsa **Actualizar ahora** en el banner
3. Se descarga el `.dmg` y se abre solo
4. Arrastra **IRIS DP** a **Aplicaciones**
5. Pulsa **Ya actualicé** en la app

### Opción B — Build local

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

## 4. Instalar en iPad (SideStore — gratis)

Cada release en GitHub incluye **`IRIS-DP.ipa`** (generado por CI, sin firma). SideStore re-firma en el iPad con tu Apple ID gratuito.

### Primera vez

1. En el Mac: instala **SideServer** y empareja el iPad (sidestore.io)
2. En el iPad: instala **SideStore**
3. Descarga el IPA:
   - Desde IRIS DP en el iPad: banner → **Descargar IPA**
   - Desde Mac/Windows: Ajustes → **Estado del sistema** → **Descargar para iPad**
4. Abre el `.ipa` con **SideStore**
5. Inicia sesión en IRIS DP con el mismo email y pulsa sync

### Actualizar

1. Descarga el IPA nuevo (mismo flujo)
2. Reinstala en SideStore encima de la versión anterior
3. Pulsa sync en la app

### Refrescar firma (~7 días)

Con Apple ID gratuito la app caduca si SideStore no refresca. Abre **SideStore en Wi‑Fi** cada semana. La app avisa a los 5 días.

### Build local (opcional)

```bash
cd iris_dp
chmod +x scripts/build_ipad.sh scripts/package_unsigned_ipa.sh
./scripts/build_ipad.sh
# o tras flutter build ios --release --no-codesign:
./scripts/package_unsigned_ipa.sh
```

### TestFlight (cuando pagues Apple Developer $99/año)

1. Sube el IPA con **Transporter**
2. Invita testers en App Store Connect
3. Instala **TestFlight** en el iPad

---

## 5. Windows

### Desde la app

1. Banner → **Actualizar ahora**
2. La app descarga, reemplaza archivos y se reinicia

### Build local

```powershell
cd iris_dp
.\scripts\build_release.sh
```

Comparte `IRIS-DP-Windows.zip` del GitHub Release o la carpeta `build\windows\x64\runner\Release\`.

---

## 6. Actualizar la app en todos los dispositivos

### Aviso automático (modo nube)

Con sesión iniciada, IRIS DP comprueba **una vez al día** si hay versión nueva en Supabase (`app_releases`). Si la hay, verás un **banner** en proyectos:

| Plataforma | Acción |
|------------|--------|
| macOS | **Actualizar ahora** → descarga `.dmg` y lo abre |
| Windows | **Actualizar ahora** → descarga `.zip` e instala |
| iPad | **Descargar IPA** → abrir con SideStore |

Los instaladores viven en **GitHub Releases** (gratis). Supabase solo guarda metadatos y URLs.

### Publicar una versión nueva (DP)

1. Sube la versión en `pubspec.yaml` (`version: 1.0.1+2`)
2. Haz commit y crea tag:
   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   ```
3. **GitHub Actions** compila macOS, Windows e iPad, crea el Release y registra URLs en Supabase (macos, windows, ipad).
4. Todos los usuarios verán el banner al abrir la app (con internet).

**Secretos en GitHub** (Settings → Secrets → Actions):

| Secreto | Uso |
|---------|-----|
| `SUPABASE_URL` | Build + registro de versión |
| `SUPABASE_ANON_KEY` | Build con nube |
| `SUPABASE_SERVICE_ROLE_KEY` | Solo CI — registrar en `app_releases` |

**Migración SQL necesaria (una vez):** ejecuta [`supabase/migrations/006_app_releases.sql`](supabase/migrations/006_app_releases.sql) en el SQL Editor de Supabase.

**Fallback manual** (si el CI falla pero ya subiste el Release a GitHub):

```bash
export SUPABASE_SERVICE_ROLE_KEY=eyJ...
./scripts/publish_release.sh v1.0.1 tu-usuario/tu-repo
```

### Tras instalar en cada dispositivo

1. **Instala** la nueva versión (`.dmg`, Windows zip, `.ipa`)
2. **Inicia sesión** con la misma cuenta
3. La app **sincroniza sola** al detectar versión nueva; también puedes pulsar sync manual

Los **proyectos no se pierden**: están en Supabase, no dentro del instalador.

### Conectividad

- Sin internet: banner «Sin conexión — los cambios se guardan localmente»
- Al reconectar: sync automático en segundo plano
- Cola pendiente visible en el icono de nube (Ajustes → Estado del sistema)

---

## 7. ¿Por qué no hay un instalador «inteligente» único?

- **macOS** usa `.app` / `.dmg` (Apple)
- **Windows** usa `.exe` / MSIX (Microsoft)  
- **iPad** solo acepta apps firmadas por Apple (`.ipa`, App Store, TestFlight, SideStore)

Un solo archivo `.exe` no puede instalarse en Mac ni iPad, y viceversa. El script `build_release.sh` **detecta en qué sistema lo ejecutas** y genera el formato correcto **para esa plataforma**.

---

## Solución de problemas

| Error | Causa | Solución |
|-------|--------|----------|
| `Failed host lookup` | URL Supabase incorrecta | Copia Project URL real desde supabase.com |
| `Invalid login` | Email/contraseña | Usa «Crear cuenta» o corrige credenciales |
| `Email not confirmed` | Confirmación activa | Desactiva en Supabase Auth → Email |
| iPad «no abre» tras ~7 días | Firma SideStore caducada | Abre SideStore en Wi‑Fi para refrescar |
| No veo actualización | Sin sesión o throttle 24h | Inicia sesión; Ajustes → Buscar actualizaciones |
