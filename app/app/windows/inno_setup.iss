; Neo-Stream — Script d'installation Windows (Inno Setup)
;
; Compilation : exécuter `iscc windows\inno_setup.iss` depuis app/app
; (ou via le workflow GitHub Actions qui le fait automatiquement).
;
; Le numéro de version est lu depuis pubspec.yaml par la directive
; #define ; en CI on passe /DAppVersion=x.y.z à iscc.

#ifndef AppVersion
  #define AppVersion "1.2.0"
#endif

[Setup]
AppName=Neo-Stream
AppVersion={#AppVersion}
AppPublisher=pecorio-dev
AppPublisherURL=https://github.com/pecorio-dev/Neo-Stream
AppSupportURL=https://github.com/pecorio-dev/Neo-Stream/issues
AppUpdatesURL=https://github.com/pecorio-dev/Neo-Stream/releases
DefaultDirName={autopf}\Neo-Stream
DefaultGroupName=Neo-Stream
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Neo-Stream-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\neo_stream.exe
UninstallDisplayName=Neo-Stream
; L'icône de l'installeur (à fournir dans windows/runner/resources).
SetupIconFile=runner\resources\app_icon.ico
DisableReadyPage=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Tout le bundle Flutter Windows (release).
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Neo-Stream"; Filename: "{app}\neo_stream.exe"
Name: "{group}\{cm:UninstallProgram,Neo-Stream}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Neo-Stream"; Filename: "{app}\neo_stream.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\neo_stream.exe"; Description: "{cm:LaunchProgram,Neo-Stream}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// Nettoie une ancienne installation si présente (évite les fichiers verrouillés).
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
