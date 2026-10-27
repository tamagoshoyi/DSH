@echo off
chcp 65001 >nul
setlocal
rem display-check 包装：绕开本机禁止直接运行 .ps1 的执行策略
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0display-check.ps1" %*
endlocal
