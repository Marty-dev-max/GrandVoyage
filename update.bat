@echo off
REM Double-click to get the latest Grand Voyage code from GitHub (the CURRENT game, branch "main").
REM For the remake (branch "remake") use update-remake.bat instead; this file switches the folder back to main.
REM Rojo (if "rojo serve" is running) then syncs it into Studio automatically.
REM This folder is only a mirror of GitHub (all edits happen there), so if a normal update is blocked by
REM local file changes, the script offers to reset the folder to exactly what is on GitHub.
REM NOTE for editors: keep each of update.bat and update-remake.bat the same on both branches (a .bat that changes
REM while it runs breaks when git switches branches under it).
setlocal
set BRANCH=main
cd /d "%~dp0"
echo Getting the latest "%BRANCH%" version from GitHub...
git fetch origin
if errorlevel 1 goto blocked
git checkout %BRANCH%
if errorlevel 1 goto blocked
git pull origin %BRANCH%
if errorlevel 1 goto blocked
goto done
:blocked
echo.
echo ============================================================
echo  The normal update was blocked ^(see the message above^).
echo  Press Y to force it: this folder becomes an exact copy of GitHub "%BRANCH%".
echo ============================================================
choice /c YN /m "Force update"
if errorlevel 2 goto done
git fetch origin
git checkout -f -B %BRANCH% origin/%BRANCH%
git reset --hard origin/%BRANCH%
:done
echo.
echo Branch in this folder now:
git branch --show-current
echo Version in this folder now:
findstr /c:"Version =" src\shared\Config\GameConfig.lua
echo.
echo In Studio: press Stop, then Play. The version bottom-right should match the line above.
echo If it does not, check the Rojo plugin says "Connected" (run serve.bat here if needed).
pause
