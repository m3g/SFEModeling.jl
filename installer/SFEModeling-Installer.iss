; SFEModeling Windows Installer
; Requires Inno Setup 6.1+: https://jrsoftware.org/isinfo.php
;   (CreateCallback is needed for the progress timer — added in Inno Setup 6.1)
;
; Build:  Open this file in the Inno Setup Compiler and click Build > Compile.
; Output: installer\Output\SFEModeling-Installer.exe

#define AppName      "SFEModeling"
; AppVersion can be overridden from the command line: ISCC /DAppVersion=1.2.3 ...
#ifndef AppVersion
  #define AppVersion "1.0.16"
#endif
#define AppPublisher "m3g"
#define AppURL       "https://github.com/m3g/SFEModeling.jl"
#define JuliaMinMajor 1
#define JuliaMinMinor 12

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
; No program files are installed — Julia and Pkg.Apps handle everything.
; We still need a DefaultDirName; use a harmless temp location.
DefaultDirName={tmp}\{#AppName}-setup
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
; Run as current user so Julia installs to %LOCALAPPDATA% (its default)
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename={#AppName}-Installer
WizardStyle=modern
; Nothing to uninstall
Uninstallable=no
CreateUninstallRegKey=no
SolidCompression=yes
Compression=lzma2

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"


[CustomMessages]
english.JuliaPageTitle=Julia Requirement
english.JuliaPageDesc={#AppName} requires Julia {#JuliaMinMajor}.{#JuliaMinMinor} or later.
english.JuliaInstallCheck=Install or update Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ automatically using winget (recommended)
english.JuliaInstallNote=If unchecked, the installer will proceed assuming Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ is already installed and available in PATH. You are responsible for ensuring that is the case.
english.WingetMissingWarn=winget (Windows Package Manager) was not found, so Julia cannot be installed automatically.%n%nThe installer will proceed anyway. Make sure Julia {#JuliaMinMajor}.{#JuliaMinMinor}+ is installed and in PATH, or install winget and re-run this installer.
english.InstPageTitle=Installing {#AppName}
english.InstPageDesc=Please wait while {#AppName} is being installed.
english.InstallingJulia=Installing / updating Julia via winget...
english.InstallingPackage=Installing {#AppName}...
english.InstDone=Installation complete.
english.ShowDetails=Show details
english.HideDetails=Hide details
english.PkgInstFailed=Failed to install {#AppName}.%n%nYou can install it manually from Julia with:%n%n    import Pkg%n    Pkg.Apps.add("{#AppName}")

[Code]

// ---------------------------------------------------------------------------
// Windows API — timer (TTimer is not available in Inno Setup Pascal)
// ---------------------------------------------------------------------------

function SetTimer(hWnd: HWND; nIDEvent: LongWord; uElapse: UINT;
  lpTimerFunc: LongWord): LongWord;
  external 'SetTimer@user32.dll stdcall';

function KillTimer(hWnd: HWND; nIDEvent: LongWord): BOOL;
  external 'KillTimer@user32.dll stdcall';

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var
  GJuliaExe:    String;   // resolved path to julia.exe
  GScriptPath:  String;   // temp .jl file passed to julia

  // Julia option page
  GJuliaPage:         TWizardPage;
  GInstallJuliaChk:   TCheckBox;  // "install/update Julia automatically"
  GDesktopChk:        TCheckBox;  // "create desktop shortcut"
  GStartMenuChk:      TCheckBox;  // "add to Start Menu"

  // Install page
  GInstPage:    TWizardPage;
  GInstPhaseL:  TLabel;   // current phase  ("Installing Julia...")
  GInstWaitL:   TLabel;   // animated "Please wait..."
  GDetailsBtn:  TButton;  // toggle output pane
  GDetailsMemo: TMemo;    // output pane (hidden by default)

  // Timer state
  GTimerID:     LongWord;
  GDotIdx:      Integer;

  // Phase state
  GInstPhase:   Integer;  // 0=julia  1=pkg  2=done  -1=error
  GSentinel:    String;
  GLogFile:     String;
  GInstStarted: Boolean;
  GDetailsOpen: Boolean;

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------

procedure OnInstTimerBody; forward;

// ---------------------------------------------------------------------------
// Timer helpers
// ---------------------------------------------------------------------------

// TimerProc matches the Windows TIMERPROC signature and delegates to the body.
procedure TimerProc(hWnd: HWND; uMsg: UINT; idEvent: LongWord; dwTime: DWORD);
begin
  OnInstTimerBody;
end;

procedure StartInstTimer;
begin
  GTimerID := SetTimer(0, 0, 300, CreateCallback(@TimerProc));
end;

procedure StopInstTimer;
begin
  if GTimerID <> 0 then begin
    KillTimer(0, GTimerID);
    GTimerID := 0;
  end;
end;

// ---------------------------------------------------------------------------
// Julia / winget detection helpers
// ---------------------------------------------------------------------------

// Run a command via cmd.exe, capture first line of stdout into Output.
// Returns True when something was captured.
function RunAndCapture(ExePath, Params: String; var Output: String): Boolean;
var
  TmpFile, CmdArgs: String;
  Lines: TArrayOfString;
  RC: Integer;
begin
  Result := False;
  Output := '';
  TmpFile  := ExpandConstant('{tmp}\sovova_capture.txt');
  CmdArgs  := '/C ""' + ExePath + '" ' + Params + ' > "' + TmpFile + '" 2>&1"';
  Exec(ExpandConstant('{cmd}'), CmdArgs, '', SW_HIDE, ewWaitUntilTerminated, RC);
  if LoadStringsFromFile(TmpFile, Lines) and (GetArrayLength(Lines) > 0) then begin
    Output := Trim(Lines[0]);
    Result := Output <> '';
  end;
end;

// Parse "julia version X.Y.Z" and return True if >= JuliaMinMajor.JuliaMinMinor.
function JuliaVersionOK(VerStr: String): Boolean;
var
  Rest: String;
  Major, Minor, DotPos: Integer;
begin
  Result := False;
  Rest := Trim(VerStr);
  if Pos('julia version ', LowerCase(Rest)) = 1 then
    Delete(Rest, 1, Length('julia version '));
  DotPos := Pos('.', Rest);
  if DotPos = 0 then Exit;
  Major := StrToIntDef(Copy(Rest, 1, DotPos - 1), 0);
  Delete(Rest, 1, DotPos);
  DotPos := Pos('.', Rest);
  if DotPos > 0 then
    Minor := StrToIntDef(Copy(Rest, 1, DotPos - 1), 0)
  else
    Minor := StrToIntDef(Trim(Rest), 0);
  Result := (Major > {#JuliaMinMajor}) or
            ((Major = {#JuliaMinMajor}) and (Minor >= {#JuliaMinMinor}));
end;

// Scan %LOCALAPPDATA%\Programs\Julia* and return ANY julia.exe found (first match).
// Used only as a fallback after winget installs Julia, when PATH is not yet updated.
function FindJuliaInLocalPrograms: String;
var
  FindRec: TFindRec;
  BaseDir, Candidate: String;
begin
  Result := '';
  BaseDir := ExpandConstant('{localappdata}\Programs');
  if FindFirst(BaseDir + '\Julia*', FindRec) then begin
    try
      repeat
        if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then begin
          Candidate := BaseDir + '\' + FindRec.Name + '\bin\julia.exe';
          if FileExists(Candidate) then begin
            Result := Candidate;
            Break;
          end;
        end;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

// Attempt to locate a julia.exe that satisfies the minimum version.
// Checks PATH first, then scans ALL Julia* dirs under %LOCALAPPDATA%\Programs.
// Sets GJuliaExe and returns True on success.
function DetectJulia: Boolean;
var
  FindRec: TFindRec;
  BaseDir, Candidate, Output: String;
begin
  Result := False;
  GJuliaExe := '';

  // 1. Try julia from PATH
  if RunAndCapture('julia', '--version', Output) then
    if JuliaVersionOK(Output) then begin
      GJuliaExe := 'julia';
      Result := True;
      Exit;
    end;

  // 2. Scan ALL %LOCALAPPDATA%\Programs\Julia* directories
  // (filesystem order is not guaranteed to be version-sorted, so we check each)
  BaseDir := ExpandConstant('{localappdata}\Programs');
  if FindFirst(BaseDir + '\Julia*', FindRec) then begin
    try
      repeat
        if FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY <> 0 then begin
          Candidate := BaseDir + '\' + FindRec.Name + '\bin\julia.exe';
          if FileExists(Candidate) and
             RunAndCapture(Candidate, '--version', Output) and
             JuliaVersionOK(Output) then begin
            GJuliaExe := Candidate;
            Result := True;
          end;
        end;
      until (not FindNext(FindRec)) or Result;
    finally
      FindClose(FindRec);
    end;
  end;
end;

// Return the full path to winget.exe, trying the known AppX location before PATH.
function WingetExePath: String;
var
  WingetLocal: String;
begin
  WingetLocal := ExpandConstant('{localappdata}\Microsoft\WindowsApps\winget.exe');
  if FileExists(WingetLocal) then
    Result := WingetLocal
  else
    Result := 'winget';
end;

function WingetAvailable: Boolean;
var
  Output: String;
begin
  Result := RunAndCapture(WingetExePath, '--version', Output);
end;

// Write the Julia install script to a temp file (avoids shell quoting hell).
// flush(stdout) after each step ensures output appears in the log incrementally.
procedure CreateInstallScript;
var
  Lines: TArrayOfString;
begin
  GScriptPath := ExpandConstant('{tmp}\sovova_install.jl');
  SetArrayLength(Lines, 8);
  Lines[0] := 'import Pkg';
  Lines[1] := 'println("Updating Julia registry..."); flush(stdout)';
  Lines[2] := 'Pkg.Registry.update()';
  Lines[3] := 'println("Registry updated."); flush(stdout)';
  Lines[4] := 'println("Installing SFEModeling (this may take a few minutes)..."); flush(stdout)';
  Lines[5] := 'Pkg.Apps.add("SFEModeling")';
  Lines[6] := 'println("SFEModeling installed successfully."); flush(stdout)';
  Lines[7] := '';
  SaveStringsToFile(GScriptPath, Lines, False);
end;

// ---------------------------------------------------------------------------
// Background launcher
//
// Writes a batch wrapper that runs ExePath+Params, appends output to GLogFile,
// and stores the exit code in GSentinel.  Launched with ewNoWait so the wizard
// remains responsive; OnInstTimerBody polls GSentinel for completion.
// ---------------------------------------------------------------------------

procedure LaunchBackground(ExePath, Params: String);
var
  BatchPath, CmdArgs: String;
  Lines: TArrayOfString;
  RC: Integer;
begin
  DeleteFile(GSentinel);
  BatchPath := ExpandConstant('{tmp}\sovova_bg.bat');
  SetArrayLength(Lines, 3);
  Lines[0] := '@echo off';
  Lines[1] := '"' + ExePath + '" ' + Params + ' >> "' + GLogFile + '" 2>&1';
  Lines[2] := 'echo %ERRORLEVEL% > "' + GSentinel + '"';
  SaveStringsToFile(BatchPath, Lines, False);
  CmdArgs := '/C "' + BatchPath + '"';
  Exec(ExpandConstant('{cmd}'), CmdArgs, '', SW_HIDE, ewNoWait, RC);
end;

// ---------------------------------------------------------------------------
// Details pane (output log)
// ---------------------------------------------------------------------------

procedure RefreshMemo;
var
  Lines: TArrayOfString;
  I: Integer;
begin
  if not GDetailsOpen then Exit;
  if not FileExists(GLogFile) then Exit;
  if not LoadStringsFromFile(GLogFile, Lines) then Exit;
  GDetailsMemo.Lines.Clear;
  for I := 0 to GetArrayLength(Lines) - 1 do
    GDetailsMemo.Lines.Add(Lines[I]);
  // Scroll to bottom by moving caret to end of text
  GDetailsMemo.SelStart  := Length(GDetailsMemo.Text);
  GDetailsMemo.SelLength := 0;
end;

procedure OnDetailsClick(Sender: TObject);
begin
  GDetailsOpen := not GDetailsOpen;
  if GDetailsOpen then begin
    GDetailsBtn.Caption  := CustomMessage('HideDetails');
    GDetailsMemo.Visible := True;
    RefreshMemo;
  end else begin
    GDetailsBtn.Caption  := CustomMessage('ShowDetails');
    GDetailsMemo.Visible := False;
  end;
end;

// ---------------------------------------------------------------------------
// Install phases
// ---------------------------------------------------------------------------

procedure StartPkgInstall; forward;

// Run sfemodeling.bat --create-shortcut to create the desktop icon.
// Called synchronously after Pkg install succeeds; failure is non-fatal.
procedure CreateDesktopShortcut;
var
  AppBat: String;
  RC: Integer;
begin
  if not GDesktopChk.Checked then Exit;
  AppBat := ExpandConstant('{%USERPROFILE}\.julia\bin\sfemodeling.bat');
  if FileExists(AppBat) then
    Exec(ExpandConstant('{cmd}'), '/C "' + AppBat + '" --create-shortcut', '',
         SW_HIDE, ewWaitUntilTerminated, RC);
end;

// Create a Start Menu shortcut pointing to the installed launcher.
// Called synchronously after Pkg install succeeds; failure is non-fatal.
procedure CreateStartMenuShortcut;
var
  AppBat, LinkPath: String;
begin
  if not GStartMenuChk.Checked then Exit;
  AppBat   := ExpandConstant('{%USERPROFILE}\.julia\bin\sfemodeling.bat');
  LinkPath := ExpandConstant('{userprograms}\{#AppName}.lnk');
  if FileExists(AppBat) then
    CreateShellLink(LinkPath, '{#AppName}', AppBat, '', '', '', 0, SW_SHOWNORMAL);
end;

procedure StartJuliaInstall;
begin
  GInstPhase := 0;
  GDotIdx    := 0;
  GSentinel  := ExpandConstant('{tmp}\sovova_julia_done.txt');
  GInstPhaseL.Caption := CustomMessage('InstallingJulia');
  SaveStringToFile(GLogFile,
    '--- Installing Julia via winget ---' + #13#10, True);
  LaunchBackground(WingetExePath,
    'install --id Julialang.Julia --silent --accept-package-agreements' +
    ' --accept-source-agreements');
  StartInstTimer;
end;

procedure StartPkgInstall;
begin
  GInstPhase := 1;
  GDotIdx    := 0;
  GSentinel  := ExpandConstant('{tmp}\sovova_pkg_done.txt');
  GInstPhaseL.Caption := CustomMessage('InstallingPackage');
  SaveStringToFile(GLogFile,
    '--- Installing SFEModeling Julia package ---' + #13#10 +
    'Julia: ' + GJuliaExe + #13#10, True);
  LaunchBackground(GJuliaExe, '"' + GScriptPath + '"');
  StartInstTimer;
end;

// ---------------------------------------------------------------------------
// Timer body — animates the wait text and checks for phase completion
// ---------------------------------------------------------------------------

procedure OnInstTimerBody;
var
  Lines: TArrayOfString;
  ExitCode, CurPhase: Integer;
begin
  // Animate "Please wait" dots
  case GDotIdx mod 4 of
    0: GInstWaitL.Caption := 'Please wait';
    1: GInstWaitL.Caption := 'Please wait.';
    2: GInstWaitL.Caption := 'Please wait..';
    3: GInstWaitL.Caption := 'Please wait...';
  end;
  GDotIdx := GDotIdx + 1;

  // Refresh output pane if open
  RefreshMemo;

  // Wait for sentinel
  if not FileExists(GSentinel) then Exit;

  StopInstTimer;
  CurPhase := GInstPhase;

  // Read exit code written by the batch wrapper
  ExitCode := 0;
  if LoadStringsFromFile(GSentinel, Lines) and (GetArrayLength(Lines) > 0) then
    ExitCode := StrToIntDef(Trim(Lines[0]), 0);

  if CurPhase = 0 then begin
    // Julia install via winget: verify by detection (winget exit code unreliable).
    if not DetectJulia then
      GJuliaExe := FindJuliaInLocalPrograms;
    if GJuliaExe = '' then
      GJuliaExe := 'julia';  // last resort — let pkg install produce a clear error
    StartPkgInstall;
  end else begin
    // Pkg install: exit code is reliable
    RefreshMemo;
    if ExitCode <> 0 then begin
      GInstPhase := -1;
      MsgBox(CustomMessage('PkgInstFailed'), mbError, MB_OK);
      WizardForm.Close;
      Exit;
    end;
    // Create desktop / Start Menu shortcuts (conditional on user choices)
    CreateDesktopShortcut;
    CreateStartMenuShortcut;
    GInstPhase := 2;
    GInstPhaseL.Caption := CustomMessage('InstDone');
    GInstWaitL.Caption  := '';
    WizardForm.NextButton.Enabled := True;  // user clicks Next to finish
  end;
end;

// ---------------------------------------------------------------------------
// Inno Setup event functions
// ---------------------------------------------------------------------------

function InitializeSetup: Boolean;
begin
  Result := True;
  CreateInstallScript;
  GLogFile := ExpandConstant('{tmp}\sovova_install_log.txt');
end;

procedure InitializeWizard;
var
  Surface: TWinControl;
  W, Y: Integer;
  NoteL, SepL: TLabel;
begin
  // ── Julia option page — appears right after the Welcome screen ────────────
  GJuliaPage := CreateCustomPage(wpWelcome,
    CustomMessage('JuliaPageTitle'), CustomMessage('JuliaPageDesc'));
  Surface := GJuliaPage.Surface;
  W := Surface.Width;
  Y := 12;

  // AutoSize must be False so the Width assignment is respected and text wraps
  // correctly instead of collapsing the control to one word wide.
  GInstallJuliaChk := TCheckBox.Create(Surface);
  GInstallJuliaChk.Parent   := Surface;
  GInstallJuliaChk.Left     := 0;
  GInstallJuliaChk.Top      := Y;
  GInstallJuliaChk.AutoSize := False;
  GInstallJuliaChk.Width    := W;
  GInstallJuliaChk.Height   := 20;
  GInstallJuliaChk.Caption  := CustomMessage('JuliaInstallCheck');
  GInstallJuliaChk.Checked  := True;
  Y := Y + 24;

  NoteL := TLabel.Create(Surface);
  NoteL.Parent     := Surface;
  NoteL.Left       := 20;   // indent under the checkbox tick
  NoteL.Top        := Y;
  NoteL.AutoSize   := False;
  NoteL.Width      := W - 20;
  NoteL.Height     := 40;
  NoteL.WordWrap   := True;
  NoteL.Caption    := CustomMessage('JuliaInstallNote');
  NoteL.Font.Color := $00666666;
  Y := Y + 48;

  // ── Separator ─────────────────────────────────────────────────────────────
  SepL := TLabel.Create(Surface);
  SepL.Parent    := Surface;
  SepL.Left      := 0;
  SepL.Top       := Y;
  SepL.AutoSize  := False;
  SepL.Width     := W;
  SepL.Height    := 1;
  SepL.Caption   := '';
  // A thin etched line — set colour to a mid-grey
  SepL.Color      := $00CCCCCC;
  SepL.Transparent := False;
  Y := Y + 10;

  // ── Shortcut options ──────────────────────────────────────────────────────
  GDesktopChk := TCheckBox.Create(Surface);
  GDesktopChk.Parent   := Surface;
  GDesktopChk.Left     := 0;
  GDesktopChk.Top      := Y;
  GDesktopChk.AutoSize := False;
  GDesktopChk.Width    := W;
  GDesktopChk.Height   := 20;
  GDesktopChk.Caption  := 'Create a desktop shortcut';
  GDesktopChk.Checked  := True;
  Y := Y + 24;

  GStartMenuChk := TCheckBox.Create(Surface);
  GStartMenuChk.Parent   := Surface;
  GStartMenuChk.Left     := 0;
  GStartMenuChk.Top      := Y;
  GStartMenuChk.AutoSize := False;
  GStartMenuChk.Width    := W;
  GStartMenuChk.Height   := 20;
  GStartMenuChk.Caption  := 'Add to Windows Start Menu';
  GStartMenuChk.Checked  := True;

  // ── Custom install page — shown after the (instant) wpInstalling step ─────
  GInstPage := CreateCustomPage(wpInstalling,
    CustomMessage('InstPageTitle'), CustomMessage('InstPageDesc'));
  Surface := GInstPage.Surface;
  W := Surface.Width;
  Y := 16;

  // Current phase label  (e.g. "Installing Julia via winget...")
  GInstPhaseL := TLabel.Create(Surface);
  GInstPhaseL.Parent  := Surface;
  GInstPhaseL.Left    := 0;
  GInstPhaseL.Top     := Y;
  GInstPhaseL.Width   := W;
  GInstPhaseL.Caption := '';
  Y := Y + 24;

  // "Please wait..." animation label
  GInstWaitL := TLabel.Create(Surface);
  GInstWaitL.Parent     := Surface;
  GInstWaitL.Left       := 0;
  GInstWaitL.Top        := Y;
  GInstWaitL.Width      := W;
  GInstWaitL.Caption    := '';
  GInstWaitL.Font.Color := $00888888;
  Y := Y + 32;

  // "Show details" toggle button — width is generous to avoid text clipping on high-DPI
  GDetailsBtn := TButton.Create(Surface);
  GDetailsBtn.Parent   := Surface;
  GDetailsBtn.Left     := 0;
  GDetailsBtn.Top      := Y;
  GDetailsBtn.Width    := 140;
  GDetailsBtn.Height   := 26;
  GDetailsBtn.Caption  := CustomMessage('ShowDetails');
  GDetailsBtn.OnClick  := @OnDetailsClick;
  Y := Y + 30;

  // Read-only output memo (hidden by default, shown when button is clicked)
  GDetailsMemo := TMemo.Create(Surface);
  GDetailsMemo.Parent     := Surface;
  GDetailsMemo.Left       := 0;
  GDetailsMemo.Top        := Y;
  GDetailsMemo.Width      := W;
  GDetailsMemo.Height     := Surface.Height - Y;
  GDetailsMemo.ReadOnly   := True;
  GDetailsMemo.ScrollBars := ssVertical;
  GDetailsMemo.Font.Name  := 'Courier New';
  GDetailsMemo.Font.Size  := 8;
  GDetailsMemo.Visible    := False;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID <> GInstPage.ID then Exit;
  if GInstStarted then Exit;
  GInstStarted := True;

  // Lock wizard navigation while work is in progress
  WizardForm.NextButton.Enabled := False;
  WizardForm.BackButton.Visible := False;

  // Start fresh log file
  SaveStringToFile(GLogFile, '', False);

  if GInstallJuliaChk.Checked then begin
    // User wants Julia installed/updated automatically
    if not WingetAvailable then begin
      // winget not found — warn and proceed directly to pkg install
      MsgBox(CustomMessage('WingetMissingWarn'), mbInformation, MB_OK);
      if not DetectJulia then
        GJuliaExe := 'julia';  // let pkg install fail naturally with a clear log
      StartPkgInstall;
    end else
      StartJuliaInstall;
  end else begin
    // User opted out — skip Julia, trust their environment
    if not DetectJulia then
      GJuliaExe := 'julia';
    StartPkgInstall;
  end;
end;
