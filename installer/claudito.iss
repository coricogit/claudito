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
en.InUse=Claudito's files are in use. Close your Claude Code sessions and run this installer again.
es.InUse=Los archivos de Claudito están en uso. Cierra tus sesiones de Claude Code y vuelve a ejecutar este instalador.
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
; Nothing of an older version may stay behind. For the rest, see MoveAway below.
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
Type: filesandordirs; Name: "{app}\*.old"
Type: dirifempty; Name: "{app}"

[Code]
// The older version is moved away, not deleted, until the new one is in place:
// if something goes wrong it is put back.
const
  LastPart = 6;

var
  AppDir: String;
  Moved, Installed: Boolean;

// Run by Claudito itself (windows/updater.py), with nobody watching.
function Updating: Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') = '1';
end;

function Part(I: Integer): String;
begin
  case I of
    0: Result := 'python';
    1: Result := 'windows';
    2: Result := 'plasma';
    3: Result := 'claudito-hook';
    4: Result := 'claudito-statusline';
    5: Result := 'claudito-usage';
  else
    Result := 'version.txt';
  end;
  Result := AppDir + '\' + Result;
end;

function Exists(Path: String): Boolean;
begin
  Result := FileExists(Path) or DirExists(Path);
end;

procedure Remove(Path: String);
begin
  if DirExists(Path) then
    DelTree(Path, True, True, True)
  else if FileExists(Path) then
    DeleteFile(Path);
end;

procedure PutBack;
var
  I: Integer;
begin
  for I := 0 to LastPart do
    if Exists(Part(I) + '.old') then
    begin
      Remove(Part(I));
      if not RenameFile(Part(I) + '.old', Part(I)) then
        Log('Could not put back ' + Part(I));
    end;
end;

// Fails, with everything as it was, if a file is in use.
function MoveAway: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to LastPart do
    if Exists(Part(I)) then
    begin
      Remove(Part(I) + '.old');
      if not RenameFile(Part(I), Part(I) + '.old') then
      begin
        Log('In use: ' + Part(I));
        PutBack;
        Result := False;
        exit;
      end;
    end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code, Attempt: Integer;
begin
  Result := '';
  AppDir := ExpandConstant('{app}');
  // An older version of this installer is there: its files are in use.
  if FileExists(ExpandConstant('{#Setup}')) then
    Exec(ExpandConstant('{#Py}'), ExpandConstant('"{#Setup}" --stop'), '', SW_HIDE, ewWaitUntilTerminated, Code);
  // Claude Code's hooks use them too, for a moment.
  for Attempt := 1 to 40 do
  begin
    Moved := MoveAway;
    if Moved then
      exit;
    Sleep(500);
  end;
  Result := CustomMessage('InUse');
end;

procedure DeinitializeSetup;
var
  I, Code: Integer;
  Dir: String;
begin
  if Moved then
    if Installed then
      for I := 0 to LastPart do
        Remove(Part(I) + '.old')
    else
      PutBack;
  if Updating then
  begin
    // The new version, or the old one if this failed.
    Dir := ExpandConstant('{param:DIR}');
    Exec(Dir + '\python\pythonw.exe', '"' + Dir + '\windows\claudito.pyw"', Dir + '\windows', SW_SHOWNORMAL,
      ewNoWait, Code);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Params, LogFile: String;
  Text: AnsiString;
begin
  if CurStep <> ssPostInstall then
    exit;
  Installed := True;
  WizardForm.StatusLabel.Caption := CustomMessage('Connecting');
  LogFile := ExpandConstant('{app}\install.log');
  // --stop: a copy run from the source code would keep this one from starting.
  Params := ExpandConstant('"{#Setup}" --stop --no-start --log "') + LogFile + '"';
  if Updating then
    Params := Params + ' --keep-autostart'   // it may have been changed in the menu
  else if not WizardIsTaskSelected('autostart') then
    Params := Params + ' --no-autostart';
  if not Exec(ExpandConstant('{#Py}'), Params, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Code := -1;
  if Code <> 0 then
  begin
    Text := '';
    LoadStringFromFile(LogFile, Text);
    SuppressibleMsgBox(FmtMessage(CustomMessage('ConnectFailed'), [LogFile]), mbError, MB_OK, IDOK);
  end;
end;
