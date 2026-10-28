@echo off
REM Launcher per App-Uninstaller
setlocal
cd /d "%~dp0"

echo ============================================================
echo   APP UNINSTALLER - SCEGLI LA VERSIONE
echo ============================================================
echo   1. GUI (interfaccia grafica Matrix)
echo   2. CLI (terminale)
echo   0. Esci
echo ============================================================
set /p choice="Scegli (1-2, default 1): "
if "%choice%"=="" set choice=1

if "%choice%"=="1" (
    where pwsh.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0App-Uninstaller-GUI.ps1"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0App-Uninstaller-GUI.ps1"
    )
) else if "%choice%"=="2" (
    where pwsh.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0App-Uninstaller-CLI.ps1"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0App-Uninstaller-CLI.ps1"
    )
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Errore durante l'esecuzione.
    pause
)
endlocal
