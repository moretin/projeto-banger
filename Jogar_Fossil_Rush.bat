@echo off
setlocal
cd /d "%~dp0" || exit /b 1
set "engine=%GODOT_BIN%"
if defined engine goto launch
for %%G in (godot.exe godot4.exe) do if not defined engine set "engine=%%~$PATH:G"
if not defined engine set "engine=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"

:launch
if exist "%engine%" (
    start "" "%engine%" --path . %*
    exit /b
)
echo Godot 4.7+ nao encontrado. Defina GODOT_BIN com o caminho do executavel.
pause
exit /b 1
