@echo off
setlocal

set "BOOTSTRAP_ROOT=https://raw.githubusercontent.com/indieark/vibe-coding-setup/main"
set "BOOTSTRAP_ASSETS_REPO=indieark/vibe-coding-setup"
set "BOOTSTRAP_ASSETS_TAG=bootstrap-assets"
set "PS_EXE=powershell.exe"
where /q pwsh.exe
if %ERRORLEVEL% EQU 0 set "PS_EXE=pwsh.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "$root='%BOOTSTRAP_ROOT%'; $assetsRepo='%BOOTSTRAP_ASSETS_REPO%'; $assetsTag='%BOOTSTRAP_ASSETS_TAG%'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; Invoke-WebRequest ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -BootstrapAssetsRepo $assetsRepo -BootstrapAssetsTag $assetsTag %*"
