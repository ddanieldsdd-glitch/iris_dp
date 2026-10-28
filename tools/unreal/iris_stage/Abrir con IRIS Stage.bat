@echo off
rem Abre un proyecto de Unreal listo para IRIS Stage: Pixel Streaming emite el
rem visor del editor desde el principio, y IRIS lo ve en «Render RTX».
rem Arrastra el .uproject encima de este archivo, o: "Abrir con IRIS Stage.bat" C:\ruta\Proyecto.uproject
setlocal
set "UPROJECT=%~1"
if "%UPROJECT%"=="" (
  echo Arrastra el .uproject del proyecto encima de este archivo.
  pause
  exit /b 1
)
set "UE=C:\Program Files\Epic Games\UE_5.5\Engine\Binaries\Win64\UnrealEditor.exe"
if not exist "%UE%" (
  echo No encuentro Unreal 5.5 en "%UE%".
  pause
  exit /b 1
)
start "" "%UE%" "%UPROJECT%" -EditorPixelStreamingStartOnLaunch -PixelStreamingEditorSource=LevelEditorViewport
