[CmdletBinding()]
param([switch]$SkipInstall)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root 'desktop')
try {
    if (-not $SkipInstall) { & npm.cmd ci; if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' } }
    & npm.cmd run tauri build -- --no-bundle
    if ($LASTEXITCODE -ne 0) { throw 'Tauri build failed' }
    $targetRoot = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $PWD 'src-tauri\target' }
    $source = Join-Path $targetRoot 'release\indieark-setup.exe'
    if (-not (Test-Path -LiteralPath $source)) { throw ('Built executable not found: ' + $source) }
    $output = Join-Path $PWD 'bin\IndieArkSetup.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $output -Force
    Write-Output ('Desktop executable: ' + $output)
}
finally { Pop-Location }
