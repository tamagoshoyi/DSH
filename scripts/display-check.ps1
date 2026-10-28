<#
.SYNOPSIS
  显示器体检：列出当前接入的每一台显示器（型号 / 接口 / 分辨率 / 刷新率 / 面板尺寸 / 原生模式）。

.DESCRIPTION
  只用三条不依赖管理员权限的通道取数据：
    1. DisplayConfig API（QueryDisplayConfig + DisplayConfigGetDeviceInfo）—— 拿到每个活动输出的
       GDI 名称（\\.\DISPLAYn）、显示器友好名、设备路径（含 EDID 实例 UID）、当前刷新率、HDR 状态；
    2. EnumDisplaySettings —— 每个输出的当前分辨率与全部可用模式；
    3. 注册表 Enum\DISPLAY\<厂商>\<实例>\Device Parameters\EDID —— 面板尺寸、出厂年份、接口类型。
  不修改任何设置，纯只读。

.PARAMETER Json
  以 JSON 输出，便于其它脚本消费。

.EXAMPLE
  .\scripts\display-check.cmd
  .\scripts\display-check.cmd -Json
#>
[CmdletBinding()]
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms | Out-Null

if (-not ('DshDisplayConfig' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class DshDisplayConfig
{
    [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint LowPart; public int HighPart; }
    [StructLayout(LayoutKind.Sequential)] public struct RATIONAL { public uint Numerator; public uint Denominator; }
    [StructLayout(LayoutKind.Sequential)] public struct PATH_SOURCE { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] public struct PATH_TARGET { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint outputTechnology; public uint rotation; public uint scaling; public RATIONAL refreshRate; public uint scanLineOrdering; public int targetAvailable; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] public struct PATH_INFO { public PATH_SOURCE source; public PATH_TARGET target; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] public struct MODE_INFO { public uint infoType; public uint id; public LUID adapterId; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 48)] public byte[] pad; }

    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPath, out uint numMode);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint numPath, [Out] PATH_INFO[] paths, ref uint numMode, [Out] MODE_INFO[] modes, IntPtr current);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")] static extern int GetDeviceInfoRaw(byte[] buffer);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")] static extern int GetSourceName(ref SRCNAME d);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct SRCNAME { public uint type; public uint size; public LUID adapterId; public uint id; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string name; }

    public class DisplayPath
    {
        public string GdiName = "";
        public string FriendlyName = "";
        public string DevicePath = "";
        public double RefreshHz;
        public bool HdrSupported;
        public bool HdrEnabled;
    }

    static string ReadUtf16(byte[] buf, int offset, int maxChars)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < maxChars; i++)
        {
            int p = offset + i * 2;
            if (p + 1 >= buf.Length) break;
            char c = (char)(buf[p] | (buf[p + 1] << 8));
            if (c == '\0') break;
            sb.Append(c);
        }
        return sb.ToString();
    }

    public static List<DisplayPath> Query()
    {
        var result = new List<DisplayPath>();
        uint numPath, numMode;
        if (GetDisplayConfigBufferSizes(2, out numPath, out numMode) != 0) return result;
        var paths = new PATH_INFO[numPath];
        var modes = new MODE_INFO[numMode];
        if (QueryDisplayConfig(2, ref numPath, paths, ref numMode, modes, IntPtr.Zero) != 0) return result;

        for (int i = 0; i < numPath; i++)
        {
            var item = new DisplayPath();

            var src = new SRCNAME();
            src.type = 1; src.size = (uint)Marshal.SizeOf(typeof(SRCNAME));
            src.adapterId = paths[i].source.adapterId; src.id = paths[i].source.id;
            if (GetSourceName(ref src) == 0) item.GdiName = src.name;

            // DISPLAYCONFIG_TARGET_DEVICE_NAME：Win10 起名义上是 416 字节，但实测这台机器要 420，
            // 多出的 16 字节夹在头部之后、友好名之前。直接按字节缓冲解析，不依赖结构体布局。
            uint size = 420;
            var buf = new byte[size];
            BitConverter.GetBytes((uint)2).CopyTo(buf, 0);
            BitConverter.GetBytes(size).CopyTo(buf, 4);
            BitConverter.GetBytes(paths[i].target.adapterId.LowPart).CopyTo(buf, 8);
            BitConverter.GetBytes(paths[i].target.adapterId.HighPart).CopyTo(buf, 12);
            BitConverter.GetBytes(paths[i].target.id).CopyTo(buf, 16);
            if (GetDeviceInfoRaw(buf) == 0)
            {
                item.FriendlyName = ReadUtf16(buf, 36, 64);
                item.DevicePath = ReadUtf16(buf, 36 + 128, 128);
            }

            if (paths[i].target.refreshRate.Denominator != 0)
                item.RefreshHz = (double)paths[i].target.refreshRate.Numerator / paths[i].target.refreshRate.Denominator;

            // DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO = 9
            var ac = new byte[32];
            BitConverter.GetBytes((uint)9).CopyTo(ac, 0);
            BitConverter.GetBytes((uint)32).CopyTo(ac, 4);
            BitConverter.GetBytes(paths[i].target.adapterId.LowPart).CopyTo(ac, 8);
            BitConverter.GetBytes(paths[i].target.adapterId.HighPart).CopyTo(ac, 12);
            BitConverter.GetBytes(paths[i].target.id).CopyTo(ac, 16);
            if (GetDeviceInfoRaw(ac) == 0)
            {
                uint v = BitConverter.ToUInt32(ac, 20);
                item.HdrSupported = (v & 1) != 0;
                item.HdrEnabled = (v & 2) != 0;
            }

            result.Add(item);
        }
        return result;
    }
}
'@
}

if (-not ('DshDisplayMode' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class DshDisplayMode
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public ushort dmSpecVersion; public ushort dmDriverVersion; public ushort dmSize; public ushort dmDriverExtra;
        public uint dmFields;
        public int dmPositionX; public int dmPositionY; public uint dmDisplayOrientation; public uint dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public ushort dmLogPixels; public uint dmBitsPerPel; public uint dmPelsWidth; public uint dmPelsHeight;
        public uint dmDisplayFlags; public uint dmDisplayFrequency;
        public uint dmICMMethod; public uint dmICMIntent; public uint dmMediaType; public uint dmDitherType;
        public uint dmReserved1; public uint dmReserved2; public uint dmPanningWidth; public uint dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettingsW(string deviceName, int modeNum, ref DEVMODE devMode);

    public static DEVMODE Current(string deviceName)
    {
        var dm = new DEVMODE();
        dm.dmSize = (ushort)Marshal.SizeOf(typeof(DEVMODE));
        EnumDisplaySettingsW(deviceName, -1, ref dm);
        return dm;
    }

    // 返回 "宽x高@刷新率" 的字符串数组
    public static string[] AllModes(string deviceName)
    {
        var list = new System.Collections.Generic.List<string>();
        for (int i = 0; i < 4000; i++)
        {
            var dm = new DEVMODE();
            dm.dmSize = (ushort)Marshal.SizeOf(typeof(DEVMODE));
            if (!EnumDisplaySettingsW(deviceName, i, ref dm)) break;
            list.Add(string.Format("{0}x{1}@{2}", dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency));
        }
        return list.ToArray();
    }
}
'@
}

function Get-EdidRecord {
    param([string]$DevicePath)

    # 设备路径形如 \\?\DISPLAY#PHLC321#5&9f56&0&UID4355#{guid}
    # 中间两段正好对应 Enum\DISPLAY\<厂商+产品码>\<实例名>。必须两者一起匹配：
    # 同一块显卡上不同显示器可能共用同一个 UID（这里 PHLC321 与 LEN60EA 都挂在 UID4355 上）。
    $vendorKey = $null
    $instanceName = $null
    if ($DevicePath -match 'DISPLAY#([^#]+)#([^#]+)#') {
        $vendorKey = $Matches[1]
        $instanceName = $Matches[2]
    }

    $candidates = @()
    if ($vendorKey -and (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\$vendorKey")) {
        $vendorRoots = @(Get-Item "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\$vendorKey")
    } else {
        $vendorRoots = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY' -ErrorAction SilentlyContinue)
    }

    foreach ($vendor in $vendorRoots) {
        foreach ($inst in (Get-ChildItem $vendor.PSPath -ErrorAction SilentlyContinue)) {
            if ($instanceName -and $inst.PSChildName -ne $instanceName) { continue }
            $edid = $null
            try { $edid = (Get-ItemProperty (Join-Path $inst.PSPath 'Device Parameters') -Name EDID -ErrorAction Stop).EDID } catch { }
            if (-not $edid -or $edid.Length -lt 128) { continue }
            $ifaceCode = $edid[20] -band 0x0F
            $iface = switch ($ifaceCode) {
                0 { '未定义' } 1 { 'DVI' } 2 { 'HDMI-a' } 3 { 'HDMI-b' } 4 { 'MDDI' } 5 { 'DisplayPort' } default { "接口$ifaceCode" }
            }
            $candidates += [pscustomobject]@{
                Uid         = $inst.PSChildName
                Vendor      = $vendor.PSChildName
                Digital     = (($edid[20] -band 0x80) -ne 0)
                Interface   = $iface
                WidthCm     = [int]$edid[21]
                HeightCm    = [int]$edid[22]
                Week        = [int]$edid[16]
                Year        = 1990 + [int]$edid[17]
                Serial      = [BitConverter]::ToUInt32($edid, 12)
                Length      = $edid.Length
            }
        }
    }
    if ($candidates.Count -eq 0) { return $null }
    return $candidates[0]
}

$paths = [DshDisplayConfig]::Query()
if ($paths.Count -eq 0) {
    Write-Host '没有读到活动的显示输出（DisplayConfig 返回空）。' -ForegroundColor Red
    exit 1
}

$gdiToPath = @{}
foreach ($p in $paths) { $gdiToPath[$p.GdiName] = $p }

$screens = [System.Windows.Forms.Screen]::AllScreens

$report = foreach ($p in $paths) {
    $dm = [DshDisplayMode]::Current($p.GdiName)
    $allModes = [DshDisplayMode]::AllModes($p.GdiName)

    $byRes = @{}
    foreach ($m in $allModes) {
        $parts = $m -split '@'
        if (-not $byRes.ContainsKey($parts[0])) { $byRes[$parts[0]] = @() }
        $byRes[$parts[0]] += [int]$parts[1]
    }
    $nativeRes = $byRes.Keys |
        Sort-Object -Property @{ Expression = { $r = $_ -split 'x'; [int]$r[0] * [int]$r[1] } } -Descending |
        Select-Object -First 1

    $uid = if ($p.DevicePath -match 'UID(\d+)') { "UID$($Matches[1])" } else { $null }
    $edid = Get-EdidRecord -DevicePath $p.DevicePath

    $screen = $screens | Where-Object { $_.DeviceName -eq $p.GdiName } | Select-Object -First 1

    [pscustomobject]@{
        Gdi           = $p.GdiName
        Name          = if ($p.FriendlyName) { $p.FriendlyName } else { '(无名称)' }
        Interface     = if ($edid) { $edid.Interface } else { '?' }
        Current       = '{0}x{1} @ {2} Hz' -f $dm.dmPelsWidth, $dm.dmPelsHeight, $dm.dmDisplayFrequency
        CurrentW      = [int]$dm.dmPelsWidth
        CurrentH      = [int]$dm.dmPelsHeight
        CurrentHz     = [int]$dm.dmDisplayFrequency
        Native        = $nativeRes
        NativeHz      = if ($nativeRes) { ($byRes[$nativeRes] | Measure-Object -Maximum).Maximum } else { 0 }
        SizeCm        = if ($edid) { "$($edid.WidthCm)x$($edid.HeightCm)" } else { '?' }
        DiagonalIn    = if ($edid -and $edid.WidthCm -gt 0) { [math]::Round([math]::Sqrt($edid.WidthCm * $edid.WidthCm + $edid.HeightCm * $edid.HeightCm) / 2.54, 1) } else { 0 }
        MadeIn        = if ($edid) { "$($edid.Year) 年第 $($edid.Week) 周" } else { '?' }
        BitsPerPixel  = [int]$dm.dmBitsPerPel
        Hdr           = if ($p.HdrSupported) { if ($p.HdrEnabled) { '已启用' } else { '支持(未启用)' } } else { '不支持' }
        Primary       = if ($screen) { $screen.Primary } else { $false }
        Bounds        = if ($screen) { '{0},{1} {2}x{3}' -f $screen.Bounds.X, $screen.Bounds.Y, $screen.Bounds.Width, $screen.Bounds.Height } else { '?' }
        DevicePath    = $p.DevicePath
        ModeCount     = $allModes.Count
        AllModes      = $allModes
    }
}

if ($Json) {
    $report | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ''
Write-Host ("检测到 {0} 台活动显示器" -f @($report).Count) -ForegroundColor Cyan
Write-Host ''

$i = 1
foreach ($r in $report) {
    $tag = if ($r.Primary) { '主显示器' } else { '扩展' }
    Write-Host ("[{0}] {1}   （{2}）" -f $i, $r.Name, $tag) -ForegroundColor Yellow
    Write-Host ("    输出端口   : {0}" -f $r.Gdi)
    Write-Host ("    连接接口   : {0}   色深: {1} bit/像素" -f $r.Interface, $r.BitsPerPixel)
    Write-Host ("    当前模式   : {0}" -f $r.Current)
    Write-Host ("    最高模式   : {0} @ {1} Hz   （共 {2} 种模式）" -f $r.Native, $r.NativeHz, $r.ModeCount)
    Write-Host ("    面板       : {0} cm 对角 {1} 英寸   出厂 {2}" -f $r.SizeCm, $r.DiagonalIn, $r.MadeIn)
    Write-Host ("    HDR        : {0}" -f $r.Hdr)
    Write-Host ("    桌面区域   : {0}" -f $r.Bounds)
    Write-Host ("    设备路径   : {0}" -f $r.DevicePath)

    if ($r.Native -and $r.Current -notlike "$($r.Native) @*") {
        Write-Host ("    ! 当前分辨率不是最高模式，建议在 设置 > 系统 > 显示 里改成 {0}" -f $r.Native) -ForegroundColor DarkYellow
    }
    if ($r.CurrentHz -lt $r.NativeHz -and $r.Native -and $r.Current -like "$($r.Native) @*") {
        Write-Host ("    ! 分辨率已是最高，但刷新率 {0} Hz 低于可用的 {1} Hz" -f $r.CurrentHz, $r.NativeHz) -ForegroundColor DarkYellow
    }
    if ($r.Current -like "$($r.Native) @*" -and $r.CurrentHz -ge $r.NativeHz) {
        Write-Host '    OK 分辨率与刷新率都已在最高档' -ForegroundColor Green
    }
    Write-Host ''
    $i++
}

$dup = $report | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($dup) {
    Write-Host '提示：下面这些型号出现了不止一次，说明同一型号接了多台或在多个端口上被枚举过：' -ForegroundColor Cyan
    foreach ($d in $dup) { Write-Host ("    {0} x{1}" -f $d.Name, $d.Count) }
    Write-Host ''
}

Write-Host '想逐台看画面质量（坏点/漏光/色带/刷新），运行： .\scripts\monitor-test.cmd' -ForegroundColor Gray
