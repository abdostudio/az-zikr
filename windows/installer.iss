; AZ Zikr — Windows installer (Inno Setup 6). Built by .github/workflows/windows.yml.
; Per-user install: no admin prompt, one click, starts with Windows.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6B0E2F7A-4C1D-4C7B-9A2E-3F5D1C8A2B71}
AppName=AZ Zikr
AppVersion={#AppVersion}
AppPublisher=AZ Creative
AppPublisherURL=https://www.behance.net/Abdostudio
DefaultDirName={localappdata}\Programs\AZ Zikr
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableWelcomePage=no
OutputDir=output
OutputBaseFilename=AZ-Zikr-Setup-{#AppVersion}
SetupIconFile=AZZikr\app.ico
UninstallDisplayIcon={app}\AZZikr.exe
UninstallDisplayName=AZ Zikr
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "autostart"; Description: "Start AZ Zikr with Windows (recommended)"

[Files]
Source: "publish\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{userprograms}\AZ Zikr"; Filename: "{app}\AZZikr.exe"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AZ Zikr"; \
  ValueData: """{app}\AZZikr.exe"" --startup"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\AZZikr.exe"; Description: "Open AZ Zikr"; Flags: nowait postinstall

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im AZZikr.exe"; Flags: runhidden; RunOnceId: "StopAZZikr"

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\AZ Zikr"
