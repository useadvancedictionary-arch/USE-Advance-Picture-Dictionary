#define MyAppName USE Advance Picture Dictionary
#define MyAppVersion 1.0.0
#define MyAppPublisher Badruddin Siddiqui
#define MyAppExeName use_advance_picture_dictionary_app.exe
#define MySourceDir build\\windows\\x64\\runner\\Release

[Setup]
AppId={{9C52E3A1-6D87-4E2F-A5C9-123456789ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=build\windows_installer
OutputBaseFilename=USE_Advance_Picture_Dictionary_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: english; MessagesFile: compiler:Default.isl

[Tasks]
Name: desktopicon; Description: {cm:CreateDesktopIcon}; GroupDescription: {cm:AdditionalIcons}; Flags: unchecked

[Files]
Source: {#MySourceDir}\*; DestDir: {app}; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: {group}\{#MyAppName}; Filename: {app}\{#MyAppExeName}
Name: {autodesktop}\{#MyAppName}; Filename: {app}\{#MyAppExeName}; Tasks: desktopicon

[Registry]
; Register custom protocol: useadvancepicdict://
Root: HKCR; Subkey: useadvancepicdict; ValueType: string; ValueName: "; ValueData: URL:USE Advance Picture Dictionary Protocol; Flags: uninsdeletekey
Root: HKCR; Subkey: useadvancepicdict; ValueType: string; ValueName: URL Protocol; ValueData: 
Root: HKCR; Subkey: useadvancepicdict\DefaultIcon; ValueType: string; ValueName: ; ValueData: {app}\{#MyAppExeName},0
Root: HKCR; Subkey: useadvancepicdict\shell\open\command; ValueType: string; ValueName: ; ValueData: "{app}\{#MyAppExeName} %1"

[Run]
Filename: {app}\{#MyAppExeName}; Description: {cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}; Flags: nowait postinstall skipifsilent