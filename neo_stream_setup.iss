#define MyAppName "Neo-Stream"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "p3cori0"
#define MyAppURL "https://neo-stream.eu"
#define MyAppExeName "neo_stream.exe"
#define BuildDir "app\build\windows\x64\runner\Release"

[Setup]
AppId={{B7F3A2C1-4E8D-4F9A-BC12-7D6E5F3A8C90}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\Neo-Stream
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer
OutputBaseFilename=NeoStream-Setup-v{#MyAppVersion}
SetupIconFile=app\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Icônes supplémentaires :"
Name: "startmenuicon"; Description: "Ajouter au menu Démarrer"; GroupDescription: "Icônes supplémentaires :"

[Files]
; Executable
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Flutter & app DLLs
Source: "{#BuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\libmpv-2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\d3dcompiler_47.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\libEGL.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\libGLESv2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\vk_swiftshader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\vulkan-1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\zlib.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\flutter_inappwebview_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\flutter_secure_storage_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\media_kit_libs_windows_video_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\media_kit_video_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Flutter data assets
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\Désinstaller {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
