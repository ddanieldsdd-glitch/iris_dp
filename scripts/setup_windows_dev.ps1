#Requires -Version 5.1
# Prepara un PC con Windows para programar y probar IRIS (una vez).
# Instala con winget lo que falte: Git, Visual Studio 2022 Build Tools (C++),
# NuGet e Inno Setup; Flutter 3.44.8 en C:\dev\flutter y el repositorio en
# C:\dev\iris_dp. Se puede volver a lanzar: salta lo que ya está.
#
#   powershell -ExecutionPolicy Bypass -File setup_windows_dev.ps1
param(
  [string]$Dev = "C:\dev",
  [string]$Repo = "https://github.com/ddanieldsdd-glitch/iris_dp.git",
  [string]$FlutterVersion = "3.44.8"
)
$ErrorActionPreference = "Stop"

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function WingetInstall($id, $extra = @()) {
  $listed = winget list --id $id -e --accept-source-agreements 2>$null | Select-String $id
  if ($listed) { Write-Host "✓ $id"; return }
  Write-Host "→ Instalando $id…"
  winget install --id $id -e --accept-package-agreements --accept-source-agreements @extra
}

function RefreshPath {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Have winget)) {
  throw "Falta winget (App Installer de Microsoft Store). Instálalo y vuelve a lanzar."
}

# 1. Herramientas
WingetInstall "Git.Git"
# Solo el compilador de C++ y el SDK de Windows que pide Flutter (unos 6 GB).
WingetInstall "Microsoft.VisualStudio.2022.BuildTools" @(
  "--override",
  "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
)
WingetInstall "Microsoft.NuGet"
WingetInstall "JRSoftware.InnoSetup"
RefreshPath

# Saltos de línea: el repositorio guarda LF; Git los convierte al sacar.
git config --global core.autocrlf true
# Rutas largas (las de build\ y .dart_tool\ pasan de 260 caracteres).
git config --global core.longpaths true

# 2. Flutter fijado a la misma versión que el Mac y el CI
New-Item -ItemType Directory -Force -Path $Dev | Out-Null
$flutter = Join-Path $Dev "flutter"
if (-not (Test-Path $flutter)) {
  Write-Host "→ Flutter $FlutterVersion en $flutter…"
  git clone --depth 1 -b $FlutterVersion https://github.com/flutter/flutter.git $flutter
}
$bin = Join-Path $flutter "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$bin;$userPath", "User")
}
RefreshPath
flutter config --no-analytics | Out-Null
flutter config --enable-windows-desktop | Out-Null

# 3. Modo de desarrollador: Flutter lo necesita para los plugins (enlaces
# simbólicos). Solo se puede activar a mano.
$dev = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
  -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue
if (-not $dev -or $dev.AllowDevelopmentWithoutDevLicense -ne 1) {
  Write-Host "⚠ Activa «Modo de desarrollador» en la ventana que se abre y vuelve aquí."
  Start-Process "ms-settings:developers"
  Read-Host "Pulsa Intro cuando esté activado"
}

# 4. El repositorio
$app = Join-Path $Dev "iris_dp"
if (-not (Test-Path $app)) {
  Write-Host "→ Clonando IRIS en $app (pedirá iniciar sesión en GitHub la primera vez)…"
  git clone $Repo $app
}
Set-Location $app
flutter pub get

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "⚠ Rellena $app\.env con las claves de la nube (las mismas del Mac)."
  Write-Host "  Cópialas desde el gestor de contraseñas; .env no se sube nunca al repositorio."
}

flutter doctor
Write-Host ""
Write-Host "Listo. Para abrir IRIS con recarga en caliente:"
Write-Host "  cd $app"
Write-Host "  .\scripts\run_windows.ps1"
