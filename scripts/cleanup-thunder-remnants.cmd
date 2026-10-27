@echo off
chcp 65001 >nul
setlocal
rem 迅雷残留清理：先自检管理员权限，不足则弹 UAC 重新以管理员运行自身
set "ARGS=%*"
net session >nul 2>&1
if errorlevel 1 (
  echo 需要管理员权限，正在请求提权...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%ARGS%' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup-thunder-remnants.ps1" %*
echo.
pause
endlocal
