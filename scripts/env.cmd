@echo off
rem 打开一个已载入 node / pnpm 的 PowerShell 会话
powershell -NoProfile -NoExit -ExecutionPolicy Bypass -Command ". '%~dp0env.ps1'"
