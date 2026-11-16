@echo off
REM Double-click to start the Rojo server, then press Connect in Studio's Rojo plugin.
REM Keep this window OPEN while you work in Studio: closing it disconnects Rojo.
cd /d "%~dp0"
where rojo >nul 2>nul
if errorlevel 1 (
  echo Rojo was not found, installing it with rokit...
  rokit install
)
echo.
echo Starting Rojo... when it says "Rojo server listening", go to Studio and press Connect in the Rojo plugin.
echo Keep this window open.
echo.
rojo serve default.project.json
echo.
echo Rojo stopped. If you see an error above, send a screenshot of this window.
pause
