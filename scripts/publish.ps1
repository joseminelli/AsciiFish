# Gera o instalador e publica uma Release no GitHub (tag vX.Y.Z, com o Setup.exe anexado).
# O app dos usuários procura essa Release para se atualizar sozinho.
# Uso:  .\publish [-Notas "texto das novidades"] [-SemClean]
# Requer o GitHub CLI:  winget install GitHub.cli   e   gh auth login   (uma vez)
param([string]$Notas = '', [switch]$SemClean)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI não encontrado. Instale com: winget install GitHub.cli  (depois: gh auth login)'
    }
    $ErrorActionPreference = 'Continue'   # no PS 5.1, stderr do gh viraria exceção
    gh auth status *> $null
    $logado = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if (-not $logado) { throw 'Faça login primeiro: gh auth login' }

    $ver = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([\d\.]+)').Matches[0].Groups[1].Value
    $tag = "v$ver"
    $ErrorActionPreference = 'Continue'
    gh release view $tag *> $null
    $existe = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if ($existe) { throw "A Release $tag já existe. Aumente o version: no pubspec.yaml." }

    if (git status --porcelain) { Write-Warning 'Há alterações não commitadas: elas NÃO entram na tag, mas entram no build.' }
    git fetch --quiet
    if (git log '@{u}..' --oneline) { throw 'Há commits não enviados. Rode git push antes de publicar.' }

    & (Join-Path $PSScriptRoot 'release.ps1') -SemClean:$SemClean
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw 'release falhou' }

    $setup = 'installer\Output\AsciiFishPet-Setup.exe'
    Write-Host "==> Publicando $tag no GitHub" -ForegroundColor Cyan
    if ($Notas) {
        # Texto com várias linhas não passa como argumento no PS 5.1 (só a 1ª linha chega): usa arquivo UTF-8 sem BOM
        $notasArq = Join-Path ([IO.Path]::GetTempPath()) "afp-notas-$ver.md"
        [IO.File]::WriteAllText($notasArq, $Notas, (New-Object Text.UTF8Encoding($false)))
        gh release create $tag $setup --title "ASCII Fish Pet $ver" --notes-file $notasArq
        Remove-Item $notasArq -ErrorAction SilentlyContinue
    }
    else { gh release create $tag $setup --title "ASCII Fish Pet $ver" --generate-notes }
    if ($LASTEXITCODE -ne 0) { throw 'gh release create falhou' }
    Write-Host "`nRelease $tag publicada. Os apps instalados vão detectar sozinhos." -ForegroundColor Green
} finally { Pop-Location }
