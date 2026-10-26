#Requires -Version 5.1
# Compila IRIS para Windows y, si está Inno Setup 6, su instalador.
# Necesita Flutter 3.44.8, Visual Studio 2022 (escritorio con C++) y NuGet.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$defines = @()
if (Test-Path ".env") {
  Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$') { $defines += "--dart-define=$($Matches[1])=$($Matches[2])" }
  }
}

flutter pub get
flutter build windows --release --no-tree-shake-icons @defines
Write-Host "App: build\windows\x64\runner\Release\"

$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
  $version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
  & $iscc "/DAppVersion=$version" windows\installer\iris_dp.iss
  Write-Host "Instalador: build\installer\IRIS-DP-Windows-Setup.exe"
} else {
  Write-Host "Sin Inno Setup 6: solo la carpeta Release (instálalo para tener el .exe)."
}
