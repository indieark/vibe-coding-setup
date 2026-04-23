@echo off
setlocal
set SCRIPT_DIR=%~dp0
set "PS_EXE=powershell.exe"
where /q pwsh.exe
if %ERRORLEVEL% EQU 0 set "PS_EXE=pwsh.exe"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%bootstrap.ps1" -PauseOnExit %*
