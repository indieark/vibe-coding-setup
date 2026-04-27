@echo off
setlocal
set SCRIPT_DIR=%~dp0
set "PS_EXE=powershell.exe"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%bootstrap.ps1" -PauseOnExit %*
