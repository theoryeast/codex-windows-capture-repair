@echo off
powershell.exe -NoProfile -File "%~dp0Repair-ComputerUse.ps1" -Action Check
set "repairResult=%errorlevel%"
if /I not "%~1"=="/nopause" pause
exit /b %repairResult%
