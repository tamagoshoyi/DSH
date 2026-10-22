@echo off
rem 环境体检（绕过本机脚本执行策略，不改系统设置）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1" %*
exit /b %ERRORLEVEL%
