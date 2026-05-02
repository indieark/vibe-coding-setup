@echo off
setlocal

set "BOOTSTRAP_ROOT=https://raw.githubusercontent.com/indieark/vibe-coding-setup/main"
set "BOOTSTRAP_ASSETS_REPO=indieark/vibe-coding-setup"
set "BOOTSTRAP_ASSETS_TAG=bootstrap-assets"
set "PS_EXE=powershell.exe"

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "$root='%BOOTSTRAP_ROOT%'; $assetsRepo='%BOOTSTRAP_ASSETS_REPO%'; $assetsTag='%BOOTSTRAP_ASSETS_TAG%'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; Invoke-WebRequest ($root + '/bootstrap.ps1') -OutFile $script; & $script -PauseOnExit -BootstrapSourceRoot $root -BootstrapAssetsRepo $assetsRepo -BootstrapAssetsTag $assetsTag -RefreshBootstrapDependencies %*"
