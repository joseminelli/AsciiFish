# Tudo: flutter clean -> pub get -> build -> instalador (Inno Setup).
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\release.ps1 [-SemClean]
param([switch]$SemClean)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'build.ps1') -SemClean:$SemClean

Push-Location $root
try {
    $ver = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([\d\.]+)').Matches[0].Groups[1].Value
    $iscc = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
    if (-not (Test-Path $iscc)) { $iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' }
    if (-not (Test-Path $iscc)) { throw 'Inno Setup não encontrado (winget install JRSoftware.InnoSetup)' }

    Write-Host "==> Gerando instalador v$ver" -ForegroundColor Cyan
    & $iscc "/DMyAppVersion=$ver" installer\AsciiFishPet.iss
    if ($LASTEXITCODE -ne 0) { throw 'ISCC falhou' }

    Write-Host "`nInstalador pronto em installer\Output\AsciiFishPet-Setup.exe (v$ver)" -ForegroundColor Green
} finally { Pop-Location }
