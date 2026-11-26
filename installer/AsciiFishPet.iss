; Instalador do ASCII Fish Pet — Whiskline Studio
; Compilar:  powershell -ExecutionPolicy Bypass -File scripts\release.ps1
; Só o instalador:  ISCC.exe /DMyAppVersion=1.0.0 installer\AsciiFishPet.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppName "ASCII Fish Pet"
#define MyAppPublisher "Whiskline Studio"
#define MyAppExe "ascii_fish_pet.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{7B1F6C52-3D0A-4E5B-9A57-AF15C0FFEE01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
WizardStyle=modern
WizardImageFile=assets\wizard-large.bmp,assets\wizard-large-150.bmp,assets\wizard-large-200.bmp
WizardSmallImageFile=assets\wizard-small.bmp
SetupIconFile=assets\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
OutputDir=Output
OutputBaseFilename=AsciiFishPet-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Instalador do {#MyAppName}
CloseApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
brazilianportuguese.StartupTask=Iniciar com o Windows
brazilianportuguese.SmartScreen=O Windows pode exibir um aviso do SmartScreen ao abrir este instalador, pois o aplicativo ainda não possui assinatura digital. Clique em "Mais informações" e depois em "Executar assim mesmo".
brazilianportuguese.DeleteSave=Deseja apagar também o progresso salvo do seu peixe (nível, pérolas, itens)?%n%nEscolha "Não" para manter o progresso caso reinstale o aplicativo depois.
english.StartupTask=Start with Windows
english.SmartScreen=Windows may show a SmartScreen warning when opening this installer because the app is not yet code-signed. Click "More info" and then "Run anyway".
english.DeleteSave=Do you also want to delete your fish's saved progress (level, pearls, items)?%n%nChoose "No" to keep it in case you reinstall later.

[Messages]
brazilianportuguese.WelcomeLabel2=Este assistente instalará o [name/ver] no seu computador.%n%n{cm:SmartScreen}
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%n{cm:SmartScreen}

[Tasks]
Name: "startup"; Description: "{cm:StartupTask}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Registry]
; "Iniciar com o Windows" — marcado por padrão; removido ao desinstalar
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExe}"""; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
; Atualização automática pelo app (/SILENT /RELAUNCH=1): reabre o app no final
Filename: "{app}\{#MyAppExe}"; Flags: nowait; Check: Relaunch

[Code]
// O app vive na bandeja (sem janela visível), então fechamos pelo nome do processo.
procedure KillApp;
var
  R: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExe}', '', SW_HIDE, ewWaitUntilTerminated, R);
end;

function Relaunch: Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillApp;
  Result := '';
end;

function InitializeUninstall: Boolean;
begin
  KillApp;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  SaveDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // O save fica em %APPDATA%\com.asciifish\ascii_fish_pet; só apagamos se o usuário quiser.
    if not UninstallSilent then
      if MsgBox(CustomMessage('DeleteSave'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        SaveDir := ExpandConstant('{userappdata}\com.asciifish');
        DelTree(SaveDir + '\ascii_fish_pet', True, True, True);
        RemoveDir(SaveDir);
      end;
  end;
end;
