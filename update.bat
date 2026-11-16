@echo off
REM Double-click to get the latest Grand Voyage code from GitHub.
REM Rojo (if "rojo serve" is running) then syncs it into Studio automatically.
REM This folder is only a mirror of GitHub (all edits happen there), so if a normal pull is blocked by
REM local file changes, the script offers to reset the folder to exactly what is on GitHub.
cd /d "%~dp0"
echo Getting the latest version from GitHub...
git pull
if errorlevel 1 (
  echo.
  echo ============================================================
  echo  The normal update was blocked ^(see the message above^).
  echo  Press Y to force it: this folder becomes an exact copy of GitHub.
  echo ============================================================
  choice /c YN /m "Force update"
  if errorlevel 2 goto done
  git fetch origin
  git reset --hard origin/main
)
:done
echo.
echo Version in this folder now:
findstr /c:"Version =" src\shared\Config\GameConfig.lua
echo.
echo In Studio: press Stop, then Play. The version bottom-right should match the line above.
echo If it does not, check the Rojo plugin says "Connected" (run rojo serve here if needed).
pause
