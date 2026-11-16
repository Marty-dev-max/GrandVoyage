@echo off
REM Double-click to get the latest Grand Voyage code from GitHub.
REM Rojo (if "rojo serve" is running) then syncs it into Studio automatically.
cd /d "%~dp0"
git pull
echo.
echo Done. In Studio: press Stop, then Play. The version bottom-right should change.
pause
