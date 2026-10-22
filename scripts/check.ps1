# scripts/check.ps1 — 环境体检
#
# 用法：.\scripts\check.cmd   （本机执行策略禁止直接运行 .ps1）
# 退出码：0 = 关键工具齐全；1 = 有必需项缺失。

$ErrorActionPreference = 'Continue'

$root    = Split-Path -Parent $PSScriptRoot
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$deps    = Join-Path $dshHome 'dsh-runtimes\dsh-primary-runtime\dependencies'
$nodeExe = Join-Path $deps 'node\bin\node.exe'
$pnpmCli = Join-Path $deps 'pnpm\bin\pnpm.mjs'
$portGit = Join-Path $root '.tools\git\cmd\git.exe'

$rows = New-Object System.Collections.Generic.List[object]
$missingRequired = 0

function Add-Row {
    param([string]$Name, [string]$Status, [string]$Detail, [string]$Level = 'info')
    $rows.Add([pscustomobject]@{ Tool = $Name; Status = $Status; Detail = $Detail; Level = $Level })
}

# --- 内置运行时（必需） ---
if (Test-Path -LiteralPath $nodeExe) {
    Add-Row 'node' 'OK' (& $nodeExe -v) 'required'
} else {
    Add-Row 'node' 'MISSING' $nodeExe 'required'
    $script:missingRequired++
}

if ((Test-Path -LiteralPath $nodeExe) -and (Test-Path -LiteralPath $pnpmCli)) {
    Add-Row 'pnpm' 'OK' (& $nodeExe $pnpmCli -v) 'required'
} else {
    Add-Row 'pnpm' 'MISSING' $pnpmCli 'required'
    $script:missingRequired++
}

# --- git：优先 PATH，其次便携版 .tools\git ---
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    Add-Row 'git' 'OK' ((& $gitCmd.Source --version) -replace '^git version\s*', 'v') 'optional'
} elseif (Test-Path -LiteralPath $portGit) {
    Add-Row 'git' 'OK' (((& $portGit --version) -replace '^git version\s*', 'v') + ' (portable)') 'optional'
} else {
    Add-Row 'git' 'ABSENT' '未安装；可解压便携版到 .tools\git' 'optional'
}

# --- 其他系统工具 ---
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) { Add-Row 'python' 'OK' ((& $py.Source --version 2>&1) -replace '^Python\s*', 'v') 'optional' }
else     { Add-Row 'python' 'ABSENT' '未安装或不在 PATH' 'optional' }

# --- 沙箱 / 会话上下文 ---
Add-Row 'workspace' 'INFO' (Get-Location).Path
if ($env:DSH_HOME)       { Add-Row 'DSH_HOME' 'INFO' $env:DSH_HOME }
if ($env:DSH_PROFILE)    { Add-Row 'DSH_PROFILE' 'INFO' $env:DSH_PROFILE }
if ($env:DSH_SESSION_ID) { Add-Row 'session' 'INFO' $env:DSH_SESSION_ID }
if ($env:DSH_WEB_URL)    { Add-Row 'web' 'INFO' $env:DSH_WEB_URL }

$rows | Format-Table -AutoSize Tool, Status, Detail

if ($missingRequired -gt 0) {
    Write-Host "`n$missingRequired 项必需运行时缺失。" -ForegroundColor Red
    exit 1
}

Write-Host "`n环境正常。首次使用先执行：powershell -NoProfile -NoExit -ExecutionPolicy Bypass -Command `". .\scripts\env.ps1`"" -ForegroundColor Green
exit 0
