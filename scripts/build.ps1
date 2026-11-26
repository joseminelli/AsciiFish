# Compila o app: flutter clean -> pub get -> build windows (release).
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\build.ps1 [-SemClean]
param([switch]$SemClean)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    # O .exe não pode ser substituído com o app aberto
    Get-Process ascii_fish_pet -ErrorAction SilentlyContinue | Stop-Process -Force

    if (-not $SemClean) {
        Write-Host '==> flutter clean' -ForegroundColor Cyan
        flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'flutter clean falhou' }
    }
    Write-Host '==> flutter pub get' -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou' }

    Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build falhou' }

    Write-Host "`nApp pronto em build\windows\x64\runner\Release\ascii_fish_pet.exe" -ForegroundColor Green
} finally { Pop-Location }
