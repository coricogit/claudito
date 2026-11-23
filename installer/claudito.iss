; Claudito's installer for Windows (Inno Setup 6). Built by installer/build.py,
; which passes Version, Stage (the folder to pack) and Out.

#define Py "{app}\python\python.exe"
#define Setup "{app}\windows\install.py"

[Setup]
AppId={{7C0B7C53-0C0E-4E0B-9A51-3D8C0D1F6A27}
AppName=Claudito
AppVersion={#Version}
AppVerName=Claudito {#Version}
AppPublisher=coricogit
AppPublisherURL=https://github.com/coricogit/claudito
AppSupportURL=https://github.com/coricogit/claudito/issues
VersionInfoVersion={#Version}
; Only for you: no administrator needed, nothing outside your profile.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Claudito
; Upgrades clean their own subfolders, so the folder is not up for choice.
DisableDirPage=yes
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
LicenseFile={#Stage}\LICENSE
SetupIconFile={#Stage}\claudito.ico
UninstallDisplayIcon={app}\claudito.ico
WizardStyle=modern
ShowLanguageDialog=auto
Compression=lzma2/max
SolidCompression=yes
; The code below stops Claudito.
CloseApplications=no
OutputDir={#Out}
OutputBaseFilename=Claudito-Setup-{#Version}

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[CustomMessages]
en.Autostart=Start Claudito when I log in
es.Autostart=Abrir Claudito al iniciar sesión
en.Connecting=Connecting Claudito to Claude Code...
es.Connecting=Conectando Claudito con Claude Code...
en.ConnectFailed=Claudito is installed, but it could not be connected to Claude Code. Is the file settings.json in your .claude folder valid? After fixing it, run this installer again.%n%nDetails:%n%1
es.ConnectFailed=Claudito está instalado, pero no se pudo conectar con Claude Code. ¿Es válido el archivo settings.json de tu carpeta .claude? Cuando lo arregles, vuelve a ejecutar este instalador.%n%nDetalles:%n%1

[Messages]
en.FinishedLabel=Claudito is installed.%n%nNew Claude Code sessions will drive it on their own. In a terminal session that is already open, run /hooks once; in the desktop app, start a new local session.
en.FinishedLabelNoIcons=Claudito is installed.%n%nNew Claude Code sessions will drive it on their own. In a terminal session that is already open, run /hooks once; in the desktop app, start a new local session.
es.FinishedLabel=Claudito está instalado.%n%nLas sesiones nuevas de Claude Code lo moverán solas. En una sesión de terminal ya abierta, ejecuta /hooks una vez; en la aplicación de escritorio, abre una sesión local nueva.
es.FinishedLabelNoIcons=Claudito está instalado.%n%nLas sesiones nuevas de Claude Code lo moverán solas. En una sesión de terminal ya abierta, ejecuta /hooks una vez; en la aplicación de escritorio, abre una sesión local nueva.

[Tasks]
Name: "autostart"; Description: "{cm:Autostart}"

[InstallDelete]
; Nothing of an older version may stay behind.
Type: filesandordirs; Name: "{app}\python"
Type: filesandordirs; Name: "{app}\windows"
Type: filesandordirs; Name: "{app}\plasma"
Type: filesandordirs; Name: "{app}\__pycache__"

[Files]
Source: "{#Stage}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Claudito"; Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\windows\claudito.pyw"""; WorkingDir: "{app}\windows"; IconFilename: "{app}\claudito.ico"

[Run]
Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\windows\claudito.pyw"""; WorkingDir: "{app}\windows"; Description: "{cm:LaunchProgram,Claudito}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{#Py}"; Parameters: """{#Setup}"" --uninstall --stop --purge"; Flags: runhidden waituntilterminated; RunOnceId: "Disconnect"

[UninstallDelete]
; Compiled Python files and the log.
Type: filesandordirs; Name: "{app}\python"
Type: filesandordirs; Name: "{app}\windows"
Type: filesandordirs; Name: "{app}\plasma"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: files; Name: "{app}\install.log"
Type: dirifempty; Name: "{app}"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  Result := '';
  // An older version of this installer is there: its files are in use.
  if FileExists(ExpandConstant('{#Setup}')) then
    Exec(ExpandConstant('{#Py}'), ExpandConstant('"{#Setup}" --stop'), '', SW_HIDE, ewWaitUntilTerminated, Code);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Params, Log: String;
  Text: AnsiString;
begin
  if CurStep <> ssPostInstall then
    exit;
  WizardForm.StatusLabel.Caption := CustomMessage('Connecting');
  Log := ExpandConstant('{app}\install.log');
  // --stop: a copy run from the source code would keep this one from starting.
  Params := ExpandConstant('"{#Setup}" --stop --no-start --log "') + Log + '"';
  if not WizardIsTaskSelected('autostart') then
    Params := Params + ' --no-autostart';
  if not Exec(ExpandConstant('{#Py}'), Params, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Code := -1;
  if Code <> 0 then
  begin
    Text := '';
    LoadStringFromFile(Log, Text);
    SuppressibleMsgBox(FmtMessage(CustomMessage('ConnectFailed'), [Log]), mbError, MB_OK, IDOK);
  end;
end;
