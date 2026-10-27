<#
.SYNOPSIS
  清理迅雷卸载后的残留：XLGuard 幽灵驱动服务、Common Files 目录、注册表键、浏览器原生消息宿主。

.DESCRIPTION
  迅雷主程序卸载后留下了四类残渣，全部指向已删除的 D:\Thunder：
    1. 服务 XLGuard（内核驱动，SYSTEM_START，ImagePath 为相对路径 system32\drivers\XLGuard.sys，文件不存在）
       → 每次开机都会尝试加载并失败，属于"幽灵驱动"。
    2. 目录 C:\Program Files (x86)\Common Files\Thunder Network（约 15 MB，ServicePlatform / BHO / UserAgent / xlguard）
    3. 注册表 HKLM\SOFTWARE\WOW6432Node\Thunder Network（Thunder BHO Platform、Xmp 两组，都指向已删的 D:\Thunder）
    4. Chrome / Firefox 原生消息宿主 com.xunlei.thunder，指向上面那个目录里的 manifest

  默认只做只读检查（dry-run），列出将要删除的内容；加 -Execute 才真正执行。
  必须以管理员身份运行（脚本会自检，不是管理员直接退出）。

.PARAMETER Execute
  真正执行清理。不加时只输出计划。

.EXAMPLE
  .\scripts\cleanup-thunder-remnants.cmd            # 只看计划
  .\scripts\cleanup-thunder-remnants.cmd -Execute   # 执行（会弹 UAC）
#>
param(
    [switch]$Execute
)

$ErrorActionPreference = 'Continue'

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}

# ---------------------------------------------------------------- 权限自检
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Execute -and -not $isAdmin) {
    Say '执行清理需要管理员权限：请右键“以管理员身份运行”本脚本，或直接运行 cleanup-thunder-remnants.cmd。' 'Red'
    exit 2
}
if (-not $isAdmin) {
    Say '（当前不是管理员，只能预演；真正删除请走 cleanup-thunder-remnants.cmd）' 'DarkYellow'
}

$mode = if ($Execute) { '执行' } else { '预演（只读）' }
Say ''
Say ("迅雷残留清理 — 模式：{0}" -f $mode) 'Cyan'
Say ('-' * 62)

$results = New-Object System.Collections.ArrayList
function Add-Result {
    param([string]$Item, [string]$Action, [string]$State)
    [void]$results.Add([pscustomobject]@{ 项目 = $Item; 动作 = $Action; 结果 = $State })
}

# ---------------------------------------------------------------- 1. 幽灵服务 XLGuard
$svcName = 'XLGuard'
Say ''
Say '[1] 幽灵驱动服务 XLGuard' 'White'
$query = & sc.exe query $svcName 2>&1 | Out-String
if ($query -match 'SERVICE_NAME') {
    $qc = & sc.exe qc $svcName 2>&1 | Out-String
    $bin = (($qc -split "`r?`n") | Where-Object { $_ -match 'BINARY_PATH_NAME' }) -join ''
    Say ("    当前状态：存在并已注册    {0}" -f $bin.Trim())
    if ($Execute) {
        & sc.exe stop $svcName 2>&1 | Out-Null
        $del = & sc.exe delete $svcName 2>&1 | Out-String
        $after = & sc.exe query $svcName 2>&1 | Out-String
        if ($after -match 'SERVICE_NAME') {
            Say '    删除失败，需要重启后重试。' 'Yellow'
            Add-Result "服务 $svcName" 'sc delete' '失败（重启后重试）'
        } else {
            Say '    已删除。' 'Green'
            Add-Result "服务 $svcName" 'sc delete' '已删除'
        }
    } else {
        Say '    计划：sc.exe delete XLGuard' 'DarkGray'
        Add-Result "服务 $svcName" 'sc delete' '待执行'
    }
} else {
    Say '    不存在，无需处理。' 'Green'
    Add-Result "服务 $svcName" 'sc delete' '已不存在'
}

# ---------------------------------------------------------------- 2. 目录
Say ''
Say '[2] 目录残留' 'White'
$dirs = @(
    'C:\Program Files (x86)\Common Files\Thunder Network',
    'C:\Program Files\Common Files\Thunder Network'
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        Say ("    {0}  —— 不存在" -f $d) 'DarkGray'
        continue
    }
    $size = 0
    $files = 0
    Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $_.PSIsContainer) { $size += $_.Length; $files++ }
    }
    Say ("    {0}" -f $d)
    Say ("        体积 {0:N1} MB，{1} 个文件" -f ($size / 1MB), $files)
    if ($Execute) {
        & cmd.exe /c "rd /s /q `"$d`"" | Out-Null
        if (Test-Path $d) {
            Say '        直接删除失败（被保护或占用），尝试接管权限…' 'Yellow'
            & takeown.exe /f "$d" /r /d Y 2>&1 | Out-Null
            & icacls.exe "$d" /grant '*S-1-5-32-544:(OI)(CI)F' /t /c /q 2>&1 | Out-Null
            & cmd.exe /c "rd /s /q `"$d`"" | Out-Null
        }
        if (Test-Path $d) {
            Say '        仍然失败，可能有进程占用（先用任务管理器结束迅雷相关进程）。' 'Red'
            Add-Result $d '删除目录' '失败'
        } else {
            Say ("        已删除，释放 {0:N1} MB。" -f ($size / 1MB)) 'Green'
            Add-Result $d '删除目录' ("已删除 {0:N1} MB" -f ($size / 1MB))
        }
    } else {
        Say '        计划：rd /s /q 整个目录' 'DarkGray'
        Add-Result $d '删除目录' ("待执行 {0:N1} MB" -f ($size / 1MB))
    }
}

# ---------------------------------------------------------------- 3. 注册表
Say ''
Say '[3] 注册表残留' 'White'
$regKeys = @(
    'HKLM\SOFTWARE\WOW6432Node\Thunder Network',
    'HKLM\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.xunlei.thunder',
    'HKLM\SOFTWARE\WOW6432Node\Google\Chrome\NativeMessagingHosts\com.xunlei.thunder',
    'HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.xunlei.thunder',
    'HKLM\SOFTWARE\Mozilla\NativeMessagingHosts\com.xunlei.thunder'
)
foreach ($k in $regKeys) {
    $probe = & reg.exe query $k 2>&1 | Out-String
    $exists = ($LASTEXITCODE -eq 0)
    if (-not $exists) { continue }
    $detail = (($probe -split "`r?`n") | Where-Object { $_ -match 'REG_' } | Select-Object -First 1)
    if ($detail) { $detail = ($detail -replace '\s+', ' ').Trim() }
    Say ("    {0}" -f $k)
    if ($detail) { Say ("        {0}" -f $detail) 'DarkGray' }
    if ($Execute) {
        & reg.exe delete $k /f 2>&1 | Out-Null
        & reg.exe query $k 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Say '        删除失败。' 'Red'
            Add-Result $k 'reg delete' '失败'
        } else {
            Say '        已删除。' 'Green'
            Add-Result $k 'reg delete' '已删除'
        }
    } else {
        Say '        计划：reg delete /f' 'DarkGray'
        Add-Result $k 'reg delete' '待执行'
    }
}

# ---------------------------------------------------------------- 4. 复核
Say ''
Say '[4] 复核' 'White'
$leftSvc = (& sc.exe query XLGuard 2>&1 | Out-String) -match 'SERVICE_NAME'
$leftDir = Test-Path 'C:\Program Files (x86)\Common Files\Thunder Network'
& reg.exe query 'HKLM\SOFTWARE\WOW6432Node\Thunder Network' *> $null
$leftReg = ($LASTEXITCODE -eq 0)
Say ("    XLGuard 服务：{0}" -f $(if ($leftSvc) { '仍存在' } else { '已清理' })) $(if ($leftSvc) { 'Yellow' } else { 'Green' })
Say ("    Common Files 目录：{0}" -f $(if ($leftDir) { '仍存在' } else { '已清理' })) $(if ($leftDir) { 'Yellow' } else { 'Green' })
Say ("    Thunder Network 注册表键：{0}" -f $(if ($leftReg) { '仍存在' } else { '已清理' })) $(if ($leftReg) { 'Yellow' } else { 'Green' })

if (-not $Execute) {
    Say ''
    Say '以上为预演结果。确认无误后执行：' 'Cyan'
    Say '    .\scripts\cleanup-thunder-remnants.cmd -Execute' 'White'
}

Say ''
