@echo off
chcp 65001 >nul
setlocal
rem monitor-test 包装：绕开本机禁止直接运行 .ps1 的执行策略
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0monitor-test.ps1" %*
endlocal
