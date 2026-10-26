# usb-diag.ps1 - 移动硬盘故障定位助手（只读为主）
# 用法（管理员 PowerShell）：
#   .\usb-diag.ps1 -Mode watch            # 插盘前先跑，实时抓掉线事件（不用管理员）
#   .\usb-diag.ps1 -Mode smart            # 读 SMART / 健康状态（需管理员）
#   .\usb-diag.ps1 -Mode scan -DriveNumber 1 -LimitGB 50   # 只读顺序读测试，找慢块/坏块（需管理员）
param(
    [ValidateSet('watch','smart','scan')]
    [string]$Mode = 'watch',
    [int]$Seconds = 600,
    [int]$DriveNumber = 1,
    [int]$LimitGB = 0,
    [int]$SlowMs = 800,
    [string]$Log = ''
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Ts { (Get-Date).ToString('HH:mm:ss') }

# ---------------- watch ----------------
if ($Mode -eq 'watch') {
    if ($Log -eq '') { $Log = '.tmp\usb-watch.log' }
    "=== 监听开始 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')，时长 $Seconds 秒 ===" | Tee-Object -FilePath $Log -Append
    "现在插入移动硬盘。掉线/重试/文件系统错误会实时打印。`n" | Tee-Object -FilePath $Log -Append

    $seen = @{}
    $lastDiskSig = ''
    $ids = @(7,9,11,15,51,52,98,129,140,150,153,157,161,162,24620)
    $end = (Get-Date).AddSeconds($Seconds)

    while ((Get-Date) -lt $end) {
        # 1) 事件
        try {
            $ev = Get-WinEvent -FilterHashtable @{ LogName='System'; StartTime=(Get-Date).AddSeconds(-15) } -EA SilentlyContinue |
                Where-Object { $_.Id -in $ids -and $_.ProviderName -match 'disk|storport|volmgr|partmgr|Ntfs|usb' }
            foreach ($e in $ev) {
                $key = "$($e.RecordId)"
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = 1
                    $msg = ($e.Message -split "`r?`n")[0]
                    $line = "[{0}] {1,-24} Id={2,-5} {3}" -f (Ts), $e.ProviderName, $e.Id, $msg
                    $line | Tee-Object -FilePath $Log -Append
                }
            }
        } catch {}

        # 2) 磁盘枚举变化（新盘出现 / 消失）
        try {
            $enum = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\disk\Enum' -EA SilentlyContinue
            $sig = ($enum.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' } | ForEach-Object { $_.Value }) -join '|'
            if ($sig -ne $lastDiskSig) {
                $n = ($sig -split '\|' | Where-Object { $_ }).Count
                ("[{0}] 磁盘枚举变化：当前 {1} 块 -> {2}" -f (Ts), $n, $sig) | Tee-Object -FilePath $Log -Append
                $lastDiskSig = $sig
            }
        } catch {}

        Start-Sleep -Seconds 3
    }
    "`n=== 监听结束 ===" | Tee-Object -FilePath $Log -Append
    return
}

# ---------------- smart ----------------
if ($Mode -eq 'smart') {
    "=== 磁盘与健康状态 ==="
    try {
        Get-Disk -EA Stop | ForEach-Object {
            "Disk {0}: {1}  总线={2}  健康={3}  状态={4}  大小={5:N1} GB" -f $_.Number, $_.FriendlyName, $_.BusType, $_.HealthStatus, $_.OperationalStatus, ($_.Size/1GB)
        }
    } catch { "  Get-Disk 失败（需要管理员）: " + $_.Exception.Message }

    ""
    "=== 可靠性计数器（SMART 摘要） ==="
    try {
        foreach ($d in (Get-PhysicalDisk -EA Stop | Where-Object { $_.BusType -eq 'USB' })) {
            "设备: " + $d.FriendlyName + "  序列号=" + $d.SerialNumber + "  固件=" + $d.FirmwareVersion
            $r = $d | Get-StorageReliabilityCounter -EA SilentlyContinue
            if ($r) {
                "  温度={0}C  通电小时={1}" -f $r.Temperature, $r.PowerOnHours
                "  读错误总数={0}  未纠正读错误={1}  写错误总数={2}  未纠正写错误={3}" -f `
                    $r.ReadErrorsTotal, $r.ReadErrorsUncorrected, $r.WriteErrorsTotal, $r.WriteErrorsUncorrected
                "  启停次数={0}  磁头加载次数={1}  读写磨损={2}" -f $r.StartStopCycleCount, $r.LoadUnloadCycleCount, $r.Wear
                "  最大延迟(ms)  读={0}  写={1}  刷新={2}" -f $r.ReadLatencyMax, $r.WriteLatencyMax, $r.FlushLatencyMax
                "  注意：USB 桥接一般不透传 SMART 属性表，重分配/待映射扇区通常读不到（显示为空属正常）。"
            } else { "  读不到 SMART（USB 桥接芯片可能不支持透传）" }
        }
    } catch { "  Get-PhysicalDisk 失败: " + $_.Exception.Message }

    ""
    "=== 卷与文件系统 ==="
    try {
        Get-Volume -EA Stop | Where-Object { $_.DriveType -eq 'Fixed' -and $_.FileSystem -ne '' } |
            Select-Object DriveLetter, FileSystem, FileSystemLabel, HealthStatus, @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}} |
            Format-Table -AutoSize | Out-String
    } catch { "  Get-Volume 失败: " + $_.Exception.Message }

    ""
    "=== 事件日志里的坏道证据（近 7 天） ==="
    try {
        $bad = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=7,11,51,55,98,140; StartTime=(Get-Date).AddDays(-7) } -EA Stop
        "  共 {0} 条" -f $bad.Count
        $bad | Group-Object Id | ForEach-Object { "    Id={0}  {1} 次" -f $_.Name, $_.Count }
    } catch { "  无" }
    return
}

# ---------------- scan ----------------
if ($Mode -eq 'scan') {
    if ($Log -eq '') { $Log = ".tmp\usb-scan-disk$DriveNumber.log" }
    $path = "\\.\PhysicalDrive$DriveNumber"
    "=== 只读顺序读取 $path（慢块阈值 ${SlowMs}ms） ===" | Tee-Object -FilePath $Log -Append
    try {
        $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    } catch {
        "打开失败（需要管理员，且盘不能被占用）: " + $_.Exception.Message
        return
    }
    $buf = New-Object byte[] (1024*1024)
    $max = if ($LimitGB -gt 0) { [int64]$LimitGB * 1GB } else { [int64]::MaxValue }
    $offset = 0L
    $slow = @()
    $slowCount = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while ($offset -lt $max) {
            $t = [System.Diagnostics.Stopwatch]::StartNew()
            $n = $fs.Read($buf, 0, $buf.Length)
            $t.Stop()
            if ($n -le 0) { break }
            if ($t.ElapsedMilliseconds -ge $SlowMs) {
                $slowCount++
                $line = "[{0}] 慢块 @ {1:N2} GB  耗时 {2} ms" -f (Ts), ($offset/1GB), $t.ElapsedMilliseconds
                $line | Tee-Object -FilePath $Log -Append
                if ($slowCount -gt 500) { "慢块过多(>500)，停止" | Tee-Object -FilePath $Log -Append; break }
            }
            $offset += $n
            if (($offset % (1GB)) -eq 0) {
                $sec = $sw.Elapsed.TotalSeconds
                "  已读 {0:N1} GB  平均 {1:N1} MB/s  慢块 {2}" -f ($offset/1GB), (($offset/1MB)/$sec), $slowCount
            }
        }
    } catch {
        "[{0}] 读取异常 @ {1:N2} GB: {2}" -f (Ts), ($offset/1GB), $_.Exception.Message | Tee-Object -FilePath $Log -Append
    } finally {
        $fs.Close()
    }
    ""
    "总读取 {0:N2} GB，慢块 {1} 个，耗时 {2:N0} 秒" -f ($offset/1GB), $slowCount, $sw.Elapsed.TotalSeconds
    $speed = ($offset/1MB)/$sw.Elapsed.TotalSeconds
    if ($speed -lt 60) {
        "平均速度 {0:N1} MB/s -> 这是 USB 2.0 档位（3.0 机械盘应 90+ MB/s）。换蓝色/青色口或换线后再测一次对比。" -f $speed
    } else {
        "平均速度 {0:N1} MB/s -> USB 3.0 档位正常。" -f $speed
    }
    "日志: $Log"
    return
}
