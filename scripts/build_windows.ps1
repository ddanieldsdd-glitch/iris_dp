#Requires -Version 5.1
# Empaqueta IRIS DP para Windows (MSIX / carpeta Release).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

flutter build windows --release
Write-Host "✓ Build en build\windows\x64\runner\Release\"
Write-Host "Para MSIX: flutter pub run msix:create (requiere msix package)"
