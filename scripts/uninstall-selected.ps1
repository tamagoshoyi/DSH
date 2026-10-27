#requires -Version 5.1
<#
  卸载用户选定的程序（默认 dry-run，加 -Execute 才真正执行）
  用法：
    .\scripts\uninstall-selected.cmd            # 只看会做什么
    .\scripts\uninstall-selected.cmd -Execute   # 真删
  说明：
    - 全部走 Windows 官方卸载通道：MSI 用 msiexec /x，其余用注册表里的 Quiet/UninstallString
    - 不手删 Program Files 目录，不碰用户数据目录（会在末尾列出需人工确认的残留）
    - 日志：.tmp\uninstall-selected.log
#>
param(
    [switch]$Execute,
    [string]$Log = "$PSScriptRoot\..\.tmp\uninstall-selected.log"
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

# ---- 本次要卸载的清单（由对话中的编号决定）----
$Items = @(
    @{ Id = '1';  Name = 'Python 3.14.5 Documentation (64-bit)';                       Kind = 'msi' }
    @{ Id = '2';  Name = 'Python 3.14.5 Test Suite (64-bit)';                          Kind = 'msi' }
    @{ Id = '3';  Name = 'Microsoft Teams Meeting Add-in for Microsoft Office';        Kind = 'msi' }
    @{ Id = '4';  Name = 'Windows 电脑健康状况检查';                                   Kind = 'msi' }
    @{ Id = '5';  Name = 'CertsUpdater version 1.5';                                   Kind = 'inno' }
    @{ Id = '19'; Name = '迅雷';                                                       Kind = 'gui' }
    @{ Id = '22'; Name = 'Discord';                                                    Kind = 'exe' }
    @{ Id = '44'; Name = 'Microsoft .NET SDK 8.0.426 (x64)';                           Kind = 'burn' }
    @{ Id = '45'; Name = 'Microsoft .NET Toolset 8.0.426 (x64)';                       Kind = 'msi' }
    @{ Id = '50'; Name = 'Microsoft .NET Targeting Pack - 8.0.32 (x64)';               Kind = 'msi' }
    @{ Id = '51'; Name = 'Microsoft .NET Standard Targeting Pack - 2.1.0 (x64)';       Kind = 'msi' }
    @{ Id = '52'; Name = 'Microsoft .NET AppHost Pack - 8.0.32 (x64)';                 Kind = 'msi' }
    @{ Id = '53'; Name = 'Microsoft .NET AppHost Pack - 8.0.32 (x64_arm64)';           Kind = 'msi' }
    @{ Id = '54'; Name = 'Microsoft .NET AppHost Pack - 8.0.32 (x64_x86)';             Kind = 'msi' }
    @{ Id = '55'; Name = 'Microsoft .NET 8.0 Templates 8.0.426 (x64)';                 Kind = 'msi' }
)

# 卸载后需要人工确认的残留（脚本不自动删，只提示体积）
$Residue = @(
    @{ Path = 'D:\Thunder';                                                  Note = '迅雷程序目录，卸载器可能留下部分文件' }
    @{ Path = "$env:LOCALAPPDATA\Discord";                                   Note = 'Discord 本体与缓存目录' }
    @{ Path = "$env:APPDATA\Thunder Network";                                Note = '迅雷配置与数据' }
    @{ Path = "$env:LOCALAPPDATA\Thunder Network";                           Note = '迅雷本地缓存' }
)

$Roots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Get-Entries {
    $all = @()
    foreach ($r in $Roots) {
        try { $all += Get-ItemProperty -Path $r -ErrorAction SilentlyContinue } catch { }
    }
    return $all
}

function ConvertTo-Command {
    param($Entry, [string]$Kind)

    $un  = [string]$Entry.UninstallString
    $qt  = [string]$Entry.QuietUninstallString

    # MSI：注册表里常写成 /I（= 修复安装），必须换成 /X 才是卸载
    $m = [regex]::Match($un, 'MsiExec\.exe\s+/[IX]\s*(\{[0-9A-Fa-f\-]+\})')
    if ($m.Success) {
        return @{ Args = @("msiexec.exe", "/x", $m.Groups[1].Value, "/qn", "/norestart"); Display = "msiexec.exe /x $($m.Groups[1].Value) /qn /norestart" }
    }

    # Inno Setup：unins000.exe /SILENT
    $m = [regex]::Match($un, '^"?(?<exe>[^"]*unins\d+\.exe)"?')
    if ($m.Success) {
        $exe = $m.Groups['exe'].Value
        return @{ Args = @($exe, '/SILENT', '/NORESTART'); Display = "$exe /SILENT /NORESTART" }
    }

    # Burn bundle（.NET SDK 等）：优先 QuietUninstallString，没有则补 /quiet
    if ($un -match '\.exe"?\s+/uninstall') {
        if ($qt) {
            $m2 = [regex]::Match($qt, '^"(?<exe>[^"]+)"\s*(?<rest>.*)$')
            $exe = if ($m2.Success) { $m2.Groups['exe'].Value } else { $qt }
            return @{ Args = @($exe, '/uninstall', '/quiet', '/norestart'); Display = "$exe /uninstall /quiet /norestart" }
        }
        $m2 = [regex]::Match($un, '^"(?<exe>[^"]+)"\s*(?<rest>.*)$')
        $exe = if ($m2.Success) { $m2.Groups['exe'].Value } else { $un }
        return @{ Args = @($exe, '/uninstall', '/quiet', '/norestart'); Display = "$exe /uninstall /quiet /norestart" }
    }

    # Squirrel（Discord 等）：Update.exe --uninstall -s（静默）
    if ($un -match '(?i)Update\.exe') {
        $m3 = [regex]::Match($un, '"?([^"]*Update\.exe)"?')
        $exe = $m3.Groups[1].Value
        return @{ Args = @($exe, '--uninstall', '-s'); Display = "$exe --uninstall -s" }
    }

    if ($qt) {
        return @{ Args = @('cmd.exe', '/c', $qt); Display = $qt }
    }

    return @{ Args = @('cmd.exe', '/c', $un); Display = $un }
}

function Get-FolderMB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [math]::Round($sum / 1MB, 1)
    } catch { return $null }
}

$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

$mode = if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' }
$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s) { Write-Host $s; $lines.Add($s) }

Emit "==================== 卸载清单 $mode ===================="
Emit ("管理员权限: " + $(if ($isAdmin) { '是' } else { '否  <-- 机器级 MSI 需要管理员' }))
Emit ""

$all = Get-Entries
$plan = @()
foreach ($it in $Items) {
    $hit = @($all | Where-Object { $_.DisplayName -eq $it.Name })
    if ($hit.Count -eq 0) {
        $plan += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; State = '已不存在'; Cmd = $null; Display = ''; Entry = $null }
        continue
    }
    $e = $hit[0]
    $c = ConvertTo-Command -Entry $e -Kind $it.Kind
    $plan += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; State = '待卸载'; Cmd = $c.Args; Display = $c.Display; Entry = $e }
}

foreach ($p in $plan) {
    $mark = if ($p.State -eq '待卸载') { '[ ]' } else { '[x]' }
    Emit ("{0} #{1} {2}" -f $mark, $p.Id, $p.Name)
    if ($p.Display) { Emit ("       -> " + $p.Display) }
}

$todo = @($plan | Where-Object { $_.State -eq '待卸载' })
Emit ""
Emit ("待处理: {0} 项 / 已不存在: {1} 项" -f $todo.Count, ($plan.Count - $todo.Count))

if (-not $Execute) {
    Emit ""
    Emit "这是 DRY-RUN，什么都没动。确认无误后执行："
    Emit "    .\scripts\uninstall-selected.cmd -Execute"
    Emit ""
    Emit "---- 卸载后建议人工确认的残留 ----"
    foreach ($r in $Residue) {
        $mb = Get-FolderMB $r.Path
        if ($null -ne $mb) { Emit ("  {0,-45} {1,8} MB   {2}" -f $r.Path, $mb, $r.Note) }
    }
    $lines | Set-Content -LiteralPath $Log -Encoding UTF8
    Write-Host ""
    Write-Host ("日志已写入 " + $Log)
    exit 0
}

if (-not $isAdmin) {
    Emit "ERROR: 需要管理员权限。请右键以管理员身份打开 PowerShell 再运行。"
    $lines | Set-Content -LiteralPath $Log -Encoding UTF8
    exit 2
}

Emit ""
Emit "==== 开始执行 ===="

# 卸载前先停掉会挡住卸载器的进程/服务
$PreKill = @{
    '19' = @('Thunder', 'ThunderPlatform', 'ThunderService', 'XLServicePlatform')
    '22' = @('Discord')
}
$PreService = @{
    '19' = @('XLServicePlatform')
}

$ok = 0; $fail = 0
foreach ($p in $todo) {
    Emit ""
    Emit ("---- #{0} {1}" -f $p.Id, $p.Name)

    if ($PreService.ContainsKey($p.Id)) {
        foreach ($svc in $PreService[$p.Id]) {
            & sc.exe stop $svc 2>&1 | Out-Null
            Emit ("     已请求停止服务: " + $svc)
        }
    }
    if ($PreKill.ContainsKey($p.Id)) {
        foreach ($pn in $PreKill[$p.Id]) {
            $procs = @(Get-Process -Name $pn -ErrorAction SilentlyContinue)
            if ($procs.Count -gt 0) {
                $procs | Stop-Process -Force -ErrorAction SilentlyContinue
                Emit ("     已结束进程: {0} x{1}" -f $pn, $procs.Count)
                Start-Sleep -Milliseconds 400
            }
        }
    }

    $exe = $p.Cmd[0]
    $argList = @()
    if ($p.Cmd.Count -gt 1) { $argList = $p.Cmd[1..($p.Cmd.Count - 1)] }
    try {
        $proc = Start-Process -FilePath $exe -ArgumentList $argList -Wait -PassThru -ErrorAction Stop
        $code = $proc.ExitCode
        Emit ("     退出码: {0}" -f $code)
        if ($code -in 0, 1605, 3010, 1641) { $ok++ } else { $fail++ }
    } catch {
        Emit ("     启动失败: " + $_.Exception.Message)
        $fail++
    }
    Start-Sleep -Milliseconds 600
    $still = @((Get-Entries) | Where-Object { $_.DisplayName -eq $p.Name })
    if ($still.Count -eq 0) { Emit "     注册表: 已移除 [OK]" } else { Emit "     注册表: 仍存在 [!]" }
}

Emit ""
Emit ("==== 完成: 成功 {0} / 失败 {1} ====" -f $ok, $fail)
Emit ""
Emit "---- 剩下的残留（人工确认后再删）----"
foreach ($r in $Residue) {
    $mb = Get-FolderMB $r.Path
    if ($null -ne $mb) { Emit ("  {0,-45} {1,8} MB   {2}" -f $r.Path, $mb, $r.Note) }
}
$lines | Set-Content -LiteralPath $Log -Encoding UTF8
Write-Host ""
Write-Host ("日志已写入 " + $Log)
if ($fail -gt 0) { exit 1 } else { exit 0 }
