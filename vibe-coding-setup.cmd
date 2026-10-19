@echo off
setlocal

set "BOOTSTRAP_ROOT=https://raw.githubusercontent.com/indieark/vibe-coding-setup/main"
set "BOOTSTRAP_ASSETS_REPO=indieark/vibe-coding-setup"
set "BOOTSTRAP_ASSETS_TAG=bootstrap-assets"
set "PS_EXE=powershell.exe"

if exist "%~dp0desktop\bin\IndieArkSetup.exe" if exist "%~dp0bootstrap.ps1" (
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" -PauseOnExit %*
  exit /b
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root='%BOOTSTRAP_ROOT%'; $assetsRepo='%BOOTSTRAP_ASSETS_REPO%'; $assetsTag='%BOOTSTRAP_ASSETS_TAG%'; $runRoot=Join-Path $env:TEMP 'vibe-coding-setup'; New-Item -ItemType Directory -Path $runRoot -Force | Out-Null; $entry=Join-Path $runRoot 'bootstrap.ps1'; $pending=$entry+'.'+[guid]::NewGuid().ToString('N')+'.download'; try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 ($root + '/bootstrap.ps1') -OutFile $pending; Move-Item -LiteralPath $pending -Destination $entry -Force; & $entry -PauseOnExit -BootstrapSourceRoot $root -BootstrapAssetsRepo $assetsRepo -BootstrapAssetsTag $assetsTag %* } finally { if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending -Force } }"
