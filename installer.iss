; Inno Setup Script for Kamdraaa
#define MyAppName "Kamdraaa"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "Kamdraaa Studio"
#define MyAppExeName "Kamdraaa.exe"
#ifndef MyAppId
#define MyAppId "{{D37F2C0B-97A4-4A6E-8041-EE5277189A0C}"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer
OutputBaseFilename=Kamdraaa_Setup_v0.2.0
#if FileExists("build\dist\app_icon.ico")
SetupIconFile=build\dist\app_icon.ico
#endif
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
Uninstallable=yes
CreateUninstallRegKey=yes
UninstallDisplayName={#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[CustomMessages]
russian.UninstallGame=Удалить Kamdraaa
english.UninstallGame=Uninstall Kamdraaa

[Files]
Source: "build\dist\Kamdraaa.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\dist\Kamdraaa.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\dist\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{app}\{cm:UninstallGame}"; Filename: "{uninstallexe}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
