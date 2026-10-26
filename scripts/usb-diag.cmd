@echo off
rem usb-diag.cmd - wrap usb-diag.ps1 so it runs despite the machine's script execution policy
rem usage: usb-diag.cmd watch [-Seconds 1200]
rem        usb-diag.cmd smart
rem        usb-diag.cmd scan -DriveNumber 2 -LimitGB 20
setlocal
if "%~1"=="" goto usage
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0usb-diag.ps1" -Mode %*
exit /b %errorlevel%

:usage
echo usage:
echo   usb-diag.cmd watch [-Seconds 1200]
echo   usb-diag.cmd smart
echo   usb-diag.cmd scan -DriveNumber 2 -LimitGB 20
exit /b 2
