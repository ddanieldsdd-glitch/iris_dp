#Requires -Version 5.1
# Abre IRIS en Windows en modo desarrollo, con la nube de .env y recarga en
# caliente (r = recargar, R = reiniciar, q = salir). Equivale a
# scripts/run_cloud.sh en el Mac.
#
#   .\scripts\run_windows.ps1            # depuración, con recarga en caliente
#   .\scripts\run_windows.ps1 -Perfil    # perfil: medir rendimiento real
param([switch]$Perfil)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

# El Flutter fijado de setup_windows_dev.ps1 va primero, aunque haya otro en el
# PATH (una consola abierta antes del setup o una instalación antigua).
$pinned = Join-Path (Split-Path -Parent $Root) "flutter\bin"
if (Test-Path (Join-Path $pinned "flutter.bat")) { $env:Path = "$pinned;$env:Path" }

if (-not (Test-Path ".env")) {
  throw "Falta .env. Copia .env.example a .env y rellena SUPABASE_URL y SUPABASE_ANON_KEY."
}
$defines = @()
Get-Content ".env" | ForEach-Object {
  if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$') { $defines += "--dart-define=$($Matches[1])=$($Matches[2])" }
}
if (-not ($defines -match "SUPABASE_URL=")) {
  throw "Define SUPABASE_URL y SUPABASE_ANON_KEY en .env"
}

Write-Host "→ Cierra cualquier IRIS abierto antes de seguir (comparten la base de datos)."
$mode = if ($Perfil) { "--profile" } else { "--debug" }
flutter run -d windows $mode @defines
