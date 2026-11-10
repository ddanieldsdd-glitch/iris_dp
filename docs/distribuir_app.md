# Distribuir IRIS DP — Mac, Windows e iPad

No existe un **único instalador universal** que detecte solo y funcione en Mac, Windows e iPad: Apple, Microsoft e iOS exigen **formatos distintos** (.dmg / .app, .exe, .ipa). Lo que sí puedes hacer es generar cada build desde este repositorio y compartir el archivo correcto con cada dispositivo.

---

## Resumen rápido

| Dispositivo | Archivo | Cómo generarlo |
|-------------|---------|----------------|
| **Mac** | `IRIS-DP.dmg` | Tag `v*` → GitHub Actions, o `./scripts/build_release.sh` local |
| **Otro Mac** | Mismo `.dmg` | AirDrop, USB, Google Drive, email… |
| **Windows** | `IRIS-DP-Windows.zip` | Tag `v*` → GitHub Actions, o build local |
| **iPad e iPhone** | Los instala el Mac | `./scripts/install_ipad.sh` (ver sección 4) |

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

## 4. Instalar en iPad e iPhone (desde el Mac)

El Mac compila, firma con el equipo personal de Xcode e instala con `devicectl`. Es la misma versión publicada que recibe el Mac.

**La primera vez** (una por dispositivo)
1. Conéctalo al Mac por cable y acepta «Confiar en este ordenador». En el iPad o iPhone, activa el modo desarrollador si te lo pide.
2. En el Mac, una sola vez: `./scripts/setup_ipad_install.sh`. Guarda el equipo de firma de Xcode y programa la tarea.
3. Primera instalación: `./scripts/install_ipad.sh`.
4. Abre IRIS, inicia sesión con la misma cuenta que en el Mac y sincroniza.

**Actualizar**
- Solo: cada 15 minutos el Mac mira si hay una versión publicada nueva y la instala en cuanto coinciden encendidos, en la misma Wi‑Fi o por cable, con IRIS cerrada en el dispositivo.
- Sin esperar: en el iPad o iPhone, **Ajustes → Actualizaciones → Actualizar desde el Mac**, o el mismo botón del aviso de versión nueva. Hace falta IRIS abierta en el Mac y el dispositivo desbloqueado. IRIS se cierra al instalar y vuelve a abrirse sola.

**La firma.** Sin cuenta de pago de Apple, la firma dura 7 días. El Mac la renueva solo cuando quedan menos de 5; con menos de 1,5 días instala aunque IRIS esté abierta, y si no llega al dispositivo avisa en el Mac.

---

## 5. Windows

### Primera instalación

`IRIS-DP-Windows-Setup.exe` (Inno Setup, `windows/installer/iris_dp.iss`): instala para el usuario en `%LOCALAPPDATA%\Programs\IRIS DP`, sin administrador, con accesos directos. Sin certificado de firma, SmartScreen avisa la primera vez («Más información → Ejecutar de todos modos»).

Para probar una rama sin release: cada PR (y cada push a `plan/pc*`) compila Windows en GitHub Actions y deja dos artefactos, el zip y el instalador.

### Desde la app

1. Banner → **Actualizar ahora**
2. La app descarga `IRIS-DP-Windows.zip`, reemplaza los archivos de la carpeta de instalación y se reinicia.

### Build local (en el PC)

Necesita Git, Flutter 3.44.8 (la misma que el Mac), Visual Studio 2022 con «Desarrollo para el escritorio con C++», NuGet en el PATH (WebView2 del 3D) y el modo de desarrollador de Windows.

```powershell
cd iris_dp
.\scripts\build_windows.ps1
```

Deja la app en `build\windows\x64\runner\Release\` y, si está Inno Setup, el instalador en `build\installer\`.

---

## 6. Actualizar la app en todos los dispositivos

### Aviso automático (modo nube)

Con sesión iniciada, IRIS DP comprueba **una vez al día** si hay versión nueva en Supabase (`app_releases`). Si la hay, verás un **banner** en proyectos:

| Plataforma | Acción |
|------------|--------|
| macOS | **Actualizar ahora** → descarga `.dmg` y lo abre |
| Windows | **Actualizar ahora** → descarga `.zip` e instala |
| iPad e iPhone | **Actualizar desde el Mac**, o se instala sola desde el Mac |

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
- **iPad e iPhone** solo aceptan apps firmadas para Apple; aquí las firma e instala el Mac

Un solo archivo `.exe` no puede instalarse en Mac ni iPad, y viceversa. El script `build_release.sh` **detecta en qué sistema lo ejecutas** y genera el formato correcto **para esa plataforma**.

---

## Solución de problemas

| Error | Causa | Solución |
|-------|--------|----------|
| `Failed host lookup` | URL Supabase incorrecta | Copia Project URL real desde supabase.com |
| `Invalid API key` | Anon key antigua / incorrecta en la app | Copia «anon public» (JWT `eyJ…`) a `.env`, cierra la app y `./scripts/run_cloud.sh`. Si vinculaste a mano: Ajustes → Desvincular → Activar nube |
| `Invalid login` | Email/contraseña | Usa «Crear cuenta» o corrige credenciales |
| `Email not confirmed` | Confirmación activa | Desactiva en Supabase Auth → Email |
| iPad o iPhone «no abre» tras ~7 días | La firma caducó sin coincidir con el Mac | Enciende y desbloquea el dispositivo en la misma Wi‑Fi que el Mac; se renueva en 15 minutos o con `./scripts/install_ipad.sh` |
| No veo actualización | Sin sesión o throttle 24h | Inicia sesión; Ajustes → Buscar actualizaciones |
