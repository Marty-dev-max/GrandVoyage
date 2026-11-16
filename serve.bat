@echo off
REM Double-click to start the Rojo server, then press Connect in Studio's Rojo plugin.
REM Keep this window OPEN while you work in Studio: closing it disconnects Rojo.
REM No install needed: the first time it downloads rojo.exe (7.4.4, same as the Studio plugin) into tools\bin.
cd /d "%~dp0"
set ROJO=rojo
where rojo >nul 2>nul
if not errorlevel 1 goto run
set ROJO=%~dp0tools\bin\rojo.exe
if exist "%ROJO%" goto run
echo Rojo is not installed on this PC yet. Downloading Rojo 7.4.4 (about 3 MB)...
if not exist "%~dp0tools\bin" mkdir "%~dp0tools\bin"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-windows-x86_64.zip' -OutFile '%TEMP%\rojo.zip'; Expand-Archive -Force '%TEMP%\rojo.zip' '%~dp0tools\bin'"
if not exist "%ROJO%" (
  echo.
  echo Could not download Rojo. Check the internet connection and send a screenshot of this window.
  pause
  exit /b 1
)
echo Rojo downloaded.
:run
echo.
echo Starting Rojo... when it says "Rojo server listening", go to Studio and press Connect in the Rojo plugin.
echo Keep this window open.
echo.
"%ROJO%" serve default.project.json
echo.
echo Rojo stopped. If you see an error above, send a screenshot of this window.
pause
