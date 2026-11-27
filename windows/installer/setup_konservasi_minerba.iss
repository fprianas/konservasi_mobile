; Script Inno Setup untuk Konservasi Minerba (Windows Desktop)
; Otomatis mendeteksi versi sebelumnya berdasarkan AppId dan melakukan update bersih.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#define MyAppName "Konservasi Minerba"
#define MyAppPublisher "Direktorat Pembinaan Pengusahaan Mineral dan Batubara - ESDM"
#define MyAppExeName "minerba_mobile.exe"
#define MyReleaseDir "..\..\build\windows\x64\runner\Release"

[Setup]
; AppId tetap (JANGAN DIUBAH antar versi) agar sistem otomatis melakukan update/timpa
AppId={{8F3B4D21-7C9E-4A51-B6D0-2E1A9F8C4D10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Mendukung instalasi per-user maupun admin dengan dialog pilihan
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Otomatis menutup aplikasi jika sedang berjalan saat proses update
CloseApplications=force
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=yes
; Kompresi maksimal agar ukuran installer ringkas
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=C:\Users\ms-yhan\Documents\konservasi
OutputBaseFilename=Setup_Konservasi_Minerba

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#MyReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#MyReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
