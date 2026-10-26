; Instalador de IRIS para Windows (Inno Setup 6).
;
; Se instala para el usuario, sin pedir administrador, en
; %LOCALAPPDATA%\Programs\IRIS DP: así el actualizador de IRIS puede
; sobrescribir la carpeta al instalar una versión nueva.
;
; Compilar (desde la raíz del repositorio, tras `flutter build windows`):
;   iscc /DAppVersion=1.2.0 windows\installer\iris_dp.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppName "IRIS"
#define AppExe "iris_dp.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{1259D858-8751-46A7-B65A-4D8811F988F5}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=IRIS DP
DefaultDirName={localappdata}\Programs\IRIS DP
DefaultGroupName=IRIS
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=IRIS-DP-Windows-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\IRIS"; Filename: "{app}\{#AppExe}"
Name: "{group}\Desinstalar IRIS"; Filename: "{uninstallexe}"
Name: "{userdesktop}\IRIS"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Abrir IRIS"; Flags: nowait postinstall skipifsilent
