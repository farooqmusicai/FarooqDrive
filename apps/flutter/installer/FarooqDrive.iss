#ifndef AppVersion
  #define AppVersion "19.0.0"
#endif

#ifndef BuildRoot
  #define BuildRoot "..\\build\\windows\\x64\\runner\\Release"
#endif

[Setup]
AppId={{9A0363F0-73EB-44AA-A0D4-B4B3E00A2919}
AppName=FarooqDrive
AppVersion={#AppVersion}
AppVerName=FarooqDrive {#AppVersion}
AppPublisher=Mohammad Farooq
AppPublisherURL=https://www.mymandoob.com/farooqdrive/
AppSupportURL=https://www.mymandoob.com/farooqdrive/
AppUpdatesURL=https://github.com/farooqmusicai/FarooqDrive/releases
DefaultDirName={localappdata}\Programs\FarooqDrive
DefaultGroupName=FarooqDrive
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\release
OutputBaseFilename=FarooqDrive-Setup-v{#AppVersion}-Windows-x64
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\farooqdrive.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany=Mohammad Farooq
VersionInfoDescription=FarooqDrive Windows Installer
VersionInfoProductName=FarooqDrive
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FarooqDrive"; Filename: "{app}\farooqdrive.exe"
Name: "{autodesktop}\FarooqDrive"; Filename: "{app}\farooqdrive.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\farooqdrive.exe"; Description: "Launch FarooqDrive"; Flags: nowait postinstall skipifsilent
