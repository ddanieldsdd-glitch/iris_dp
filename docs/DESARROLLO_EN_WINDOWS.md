# Programar y probar IRIS en el PC (Windows)

Hay dos maneras de usar IRIS en el PC:

1. **Solo probar:** instalar `IRIS-DP-Windows-Setup.exe`, del release o del artefacto del PR (ver [PRUEBA_WINDOWS.md](PRUEBA_WINDOWS.md)). No hace falta nada más.
2. **Programar y probar ahí** las funciones nuevas: el código en el PC, la app abierta con recarga en caliente y los cambios subidos a GitHub. Es lo que explica esta guía.

Las dos conviven. El IRIS instalado y el de desarrollo usan la misma carpeta de datos (ver «Datos» más abajo).

## 1. Preparar el PC (una vez, unos 30–45 min)

En PowerShell, **sin** administrador:

```powershell
irm https://raw.githubusercontent.com/ddanieldsdd-glitch/iris_dp/main/scripts/setup_windows_dev.ps1 -OutFile $env:TEMP\setup.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\setup.ps1
```

Mientras la rama no esté en `main`, copia `scripts/setup_windows_dev.ps1` al PC (por ejemplo por la nube o un USB) y lánzalo igual.

El script hace esto, y salta lo que ya esté:

| Paso | Qué |
|---|---|
| Git | Con `core.autocrlf` y `core.longpaths` |
| Visual Studio 2022 Build Tools | Solo «Desarrollo de escritorio con C++», que es lo que pide Flutter |
| NuGet e Inno Setup 6 | Para los plugins nativos y para hacer el instalador |
| Flutter 3.44.8 | En `C:\dev\flutter`, la misma versión que el Mac y el CI. No actualizarlo con `flutter upgrade`: la versión fija evita el fallo de `pdfrx` |
| Modo de desarrollador | Abre Configuración para activarlo a mano. Flutter lo necesita para los plugins |
| Repositorio | Lo clona en `C:\dev\iris_dp`. Una ruta corta evita el límite de 260 caracteres de Windows |
| `.env` | Lo crea desde `.env.example`. **Hay que rellenarlo** con las mismas claves del Mac, copiadas desde el gestor de contraseñas. Nunca se sube al repositorio |

Al final lanza `flutter doctor`. Deben salir en verde «Windows Version», «Visual Studio» y «Flutter». Android, Chrome y Xcode dan igual.

## 2. Abrir IRIS en modo desarrollo

```powershell
cd C:\dev\iris_dp
.\scripts\run_windows.ps1
```

- La primera compilación tarda unos minutos; las siguientes, segundos.
- En la consola: **r** recarga el código Dart sin cerrar la app, **R** la reinicia y **q** sale.
- Los cambios en C++ (`windows/runner/`) o en `pubspec.yaml` necesitan salir y volver a lanzar.
- Para medir rendimiento de verdad, con la GPU NVIDIA y sin el coste de depuración, usa `.\scripts\run_windows.ps1 -Perfil`.
- Para hacer el instalador en el PC, usa `.\scripts\build_windows.ps1`.

## 3. Editar el código en el PC

Puedes usar cualquiera de estas:

- **Claude Code en el PC.** La app de Claude para Windows, pestaña Code, con la carpeta `C:\dev\iris_dp`. Trabaja igual que en el Mac: puede compilar, lanzar `run_windows.ps1`, ver los errores de Windows y arreglarlos ahí mismo. Es lo más útil para lo que solo falla en Windows (WebView2, portapapeles, rutas, atajos).
- **VS Code** con la extensión Flutter: F5 lanza la app con recarga en caliente y puntos de parada. Para la nube, añade los `--dart-define` de `.env` en `.vscode/launch.json`. Ese archivo lleva las claves y está en `.gitignore`, así que no se sube.
- **Desde el Mac, sin tocar el PC.** Con OpenSSH Server activado en Windows, una sesión de Claude Code puede trabajar en el PC por SSH si la app ofrece esa conexión. La ventana de IRIS se ve en la pantalla del PC (o por Escritorio remoto).

## 4. Cómo se mueve el trabajo entre el Mac y el PC

Todo pasa por GitHub, con ramas. Las dos máquinas no se copian carpetas.

```powershell
git fetch
git switch plan/la-rama-a-probar   # la del PR que toque
git pull
.\scripts\run_windows.ps1
```

- **Probar una función nueva:** se cambia a su rama y se lanza. Si algo falla solo en Windows, se arregla en esa misma rama, se hace commit y push, y el Mac lo baja con `git pull`.
- **Una rama, una máquina a la vez.** Antes de editar en una máquina, `git pull`. Al terminar, `git push`. Si las dos tocan la misma rama a la vez, habrá conflictos.
- **Lo que es solo de Windows** (C++, instalador) puede ir en una rama `pc/…` con su propio PR.
- **Cada push compila en GitHub para Windows.** El instalador del PR sale como artefacto `IRIS-DP-Windows-Setup-<commit>` en la pestaña Actions. Sirve para probar sin compilar en el PC, o para que lo pruebe otra persona.
- **Pruebas:** `flutter test` funciona igual en el PC. Lo que solo pase en Windows se anota en [PRUEBA_WINDOWS.md](PRUEBA_WINDOWS.md).

## 5. Datos

- El IRIS instalado y el de desarrollo guardan en `%APPDATA%\IRIS DP\IRIS`. Comparten proyectos y no deben estar abiertos a la vez.
- **Antes de probar una rama que cambie el esquema de la base de datos** (sube `kSchemaVersion` en `lib/core/database/app_database.dart`), copia esa carpeta. Al abrirla con la rama, la base se migra, y el IRIS instalado, si es más antiguo, puede no leerla.
- Usa un proyecto de prueba, o uno que ya esté en la nube con copia en el Mac. La descarga de la nube tiene un fallo conocido que pierde metadatos.

## 6. Problemas típicos

| Síntoma | Arreglo |
|---|---|
| `Building with plugins requires symlink support` | Activa el Modo de desarrollador y abre otra consola |
| `Unable to find suitable Visual Studio toolchain` | Abre «Visual Studio Installer» → Build Tools → marca «Desarrollo de escritorio con C++» |
| `nuget.exe not found` (al compilar el 3D) | `winget install Microsoft.NuGet` y abre otra consola |
| Errores de `pdfrx` o de null safety | Flutter no es la 3.44.8: `cd C:\dev\flutter; git fetch --tags; git checkout 3.44.8; flutter --version` |
| La nube no aparece en Ajustes | `.env` vacío o mal escrito, o se abrió con `flutter run` a secas en vez de `run_windows.ps1` |
| `Filename too long` | `git config --global core.longpaths true` y el repositorio en `C:\dev` |
| El 3D sale en blanco | Falta WebView2 Runtime (viene con Windows 11 y Edge). Instálalo desde la web de Microsoft |
| PowerShell no deja lanzar el script | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
