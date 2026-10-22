# scripts/env.ps1 — 把 DSH 内置 node / pnpm 注入当前 PowerShell 会话
#
# 用法（开头的点是必需的，表示在当前会话生效）：
#   . .\scripts\env.ps1
#
# 注入后可用：node、pnpm、pnpx，以及 $env:DSH_NODE / $env:DSH_PNPM。

$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$deps    = Join-Path $dshHome 'dsh-runtimes\dsh-primary-runtime\dependencies'
$nodeExe = Join-Path $deps 'node\bin\node.exe'
$pnpmCli = Join-Path $deps 'pnpm\bin\pnpm.mjs'
$pnpxCli = Join-Path $deps 'pnpm\bin\pnpx.mjs'

foreach ($p in @($nodeExe, $pnpmCli, $pnpxCli)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "缺少内置运行时：$p`n请检查 DSH 安装是否完整，或用 `$env:DSH_HOME 指向正确位置。"
    }
}

$env:DSH_NODE = $nodeExe
$env:DSH_PNPM = $pnpmCli
$env:DSH_PNPX = $pnpxCli

# node 目录放到 PATH 最前（先去重，避免反复导入后 PATH 无限增长）
$nodeDir = Split-Path -Parent $nodeExe
$rest    = @($env:PATH -split ';' | Where-Object { $_ -and $_ -ne $nodeDir })
$env:PATH = (@($nodeDir) + $rest) -join ';'

# 便携版 git（.tools\git）优先于任何系统安装
$portableGit = Join-Path (Split-Path -Parent $PSScriptRoot) '.tools\git\cmd'
$portableGitExe = Join-Path $portableGit 'git.exe'
if (Test-Path -LiteralPath $portableGitExe) {
    $rest = @($env:PATH -split ';' | Where-Object { $_ -and $_ -ne $portableGit })
    $env:PATH = (@($portableGit) + $rest) -join ';'
    $env:DSH_GIT = $portableGitExe
}

# pnpm / pnpx 是 Node 单文件分发，没有 .cmd 垫片，用函数补上
function global:pnpm { & $env:DSH_NODE $env:DSH_PNPM @args }
function global:pnpx { & $env:DSH_NODE $env:DSH_PNPX @args }

# 代理：从 Windows 的 Internet 设置实时读取（VPN 开着才生效，关掉不会留脏值）
$inetKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$ie = Get-ItemProperty -Path $inetKey -ErrorAction SilentlyContinue
if ($ie -and $ie.ProxyEnable -eq 1 -and $ie.ProxyServer) {
    $proxy = 'http://' + ($ie.ProxyServer -replace '^https?://', '')
    $env:HTTP_PROXY  = $proxy
    $env:HTTPS_PROXY = $proxy
    $env:http_proxy  = $proxy
    $env:https_proxy = $proxy
    $env:DSH_PROXY   = $proxy
}

$gitVer = if ($env:DSH_GIT) { (& $env:DSH_GIT --version) -replace '^git version\s*', 'git ' } else { 'git 未安装' }
$proxyVer = if ($env:DSH_PROXY) { "代理 $env:DSH_PROXY" } else { '无代理' }
Write-Host ("node {0} | pnpm {1} | {2} | {3}" -f (& $nodeExe -v), (& $nodeExe $pnpmCli -v), $gitVer, $proxyVer) -ForegroundColor DarkGray
