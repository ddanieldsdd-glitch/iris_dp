# Instalación y actualización de IRIS DP

Guía para usuarios: instalar la app, configurarla la primera vez y mantener varios dispositivos sincronizados con Supabase.

## Instalar IRIS DP

### macOS

1. Descarga **IRIS-DP.dmg** (enlace de tu equipo o release de GitHub).
2. Abre el archivo `.dmg`.
3. Arrastra **IRIS DP** a la carpeta **Aplicaciones**.
4. Abre la app. Si macOS la bloquea la primera vez: clic derecho → **Abrir**.
5. Verás el **tutorial inicial** antes de entrar a tus proyectos.

#### Dónde guarda los datos en Mac

Desde octubre de 2026 la app del DMG **no usa el sandbox de macOS** (como las builds Debug y Profile). IRIS DP no se distribuye por la Mac App Store, y con el sandbox la app no veía los datos que ya existían. Por eso todas las builds de Mac usan las mismas carpetas:

| Qué | Dónde |
|-----|-------|
| Configuración de carpetas (`storage_config.json`) | `~/Library/Application Support/com.example.irisDp/iris_dp/` |
| Base de datos (`iris_dp.db`) | La carpeta de datos técnicos que elegiste (por defecto `…/iris_dp/app_data/`) |
| Documentos | La carpeta que elegiste en el tutorial (por defecto `~/Documents/iris_dp/documentos`) |

Qué cambia si ya habías instalado un DMG antiguo (con sandbox):

- La versión nueva abre directamente tus datos de `Application Support` y tu carpeta de documentos. No hay que migrar nada.
- Lo que creó la versión antigua se queda en `~/Library/Containers/com.example.irisDp/` y la app nueva ya no lo usa. Si allí hay proyectos que no están en la nube ni en tu base normal, haz una copia de esa carpeta antes de borrarla.
- Si al abrir aparecen proyectos viejos o no puedes iniciar sesión, comprueba en **Ajustes** que la carpeta de datos apunta a `Application Support` y no al contenedor.

### Windows

1. Ejecuta el instalador o descomprime la carpeta `Release` del build.
2. Inicia `iris_dp.exe`.
3. Confirma en Windows Defender si lo pide.
4. Sigue el tutorial de configuración.

### iPad

1. Instala desde **TestFlight** o **App Store**.
2. Abre IRIS DP e inicia sesión con la misma cuenta que en escritorio.

---

## Primera configuración (tutorial)

Al abrir IRIS DP por primera vez, el tutorial te guía en este orden:

| Paso | Qué haces |
|------|-----------|
| 1 | Bienvenida y visión general de la app |
| 2 | Cómo instalaste según tu plataforma |
| 3 | Crear cuenta o iniciar sesión *(solo modo nube)* |
| 4 | Elegir **carpeta de datos técnicos** y **carpeta de documentos** |
| 5 | Cómo actualizar en varios dispositivos *(solo modo nube)* |
| 6 | Migrar proyectos locales a la nube *(si ya tenías datos)* |
| 7 | Primeros pasos + tour en la pantalla de proyectos |

Las carpetas locales son **cache por dispositivo**. En modo nube, la fuente de verdad está en **Supabase**.

---

## Actualizar la app en otros dispositivos

Cuando instalas una **nueva versión** de IRIS DP en un Mac, Windows o iPad, **tus proyectos no se pierden**. Solo actualizas el programa; los datos siguen en la nube.

### Pasos en cada dispositivo

1. **Instala la nueva versión**  
   Mismo proceso que la primera instalación (.dmg, .exe o App Store).

2. **Abre con la misma cuenta**  
   Email y contraseña iguales. No hace falta volver a migrar proyectos ni recrear el workspace en un dispositivo ya configurado.

3. **Sincroniza**  
   En la pantalla de proyectos, pulsa el **icono de nube**. Espera a que termine antes de editar.

4. **Comprueba**  
   Deberías ver los mismos proyectos que en el dispositivo donde actualizaste primero.

### Aviso automático de nueva versión

Si usas **modo nube** (cuenta iniciada), IRIS DP comprueba una vez al día si el DP publicó una versión nueva. Verás un **banner** en la pantalla de proyectos con:

- **Descargar** — abre GitHub Releases en el navegador  
- **Más tarde** — oculta hasta que salga otra versión  
- **Ya actualicé** — sincroniza proyectos tras instalar

No hace falta que el DP te avise por WhatsApp o email.

### Qué no tienes que repetir

- Elegir carpetas locales *(solo la primera vez en cada máquina)*  
- Migración local → nube *(solo una vez por workspace)*  
- Crear cuenta *(ya existe en Supabase)*

### Si un dispositivo no muestra cambios

- Comprueba conexión a internet.  
- Inicia sesión con la misma cuenta.  
- Pulsa sync otra vez.  
- Cierra y vuelve a abrir la app.

---

## Modo solo local (sin Supabase)

Si ejecutas IRIS DP sin credenciales de Supabase:

- No hay cuenta ni sync en la nube.  
- El tutorial omite pasos de cuenta y sincronización.  
- Los datos viven solo en las carpetas que elijas.  
- Para pasar a nube: configura `SUPABASE_URL` y `SUPABASE_ANON_KEY` y usa el asistente de migración.

---

## Ver el tutorial otra vez

**Ajustes** → **Ver tutorial inicial**  
**Ajustes** → **Instalación y actualización** (guía completa en la app)

---

## Desarrollo / builds con nube

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu_anon_key
```

Ver también [release.md](release.md) para empaquetar instaladores.
