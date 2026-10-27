<#
.SYNOPSIS
  多显示器画面测试工具：纯色 / 灰阶 / 渐变 / 棋盘 / 网格 / 移动条 / 坏点扫描，逐屏独立显示。

.DESCRIPTION
  在每一台显示器上各开一个无边框全屏窗口，同时显示同一套测试图案，用于检查：
    - 亮点 / 暗点 / 死像素（纯色、坏点扫描、棋盘格）
    - 漏光与亮度均匀性（纯黑、10% 灰、90% 灰）
    - 色阶断层与色带（水平/垂直渐变、16 级灰阶条）
    - 刷新与撕裂（移动竖条），以及面板是否真的跑在标称刷新率上
    - 灰阶响应拖影（棋盘格 + 移动条）

  按键：
    空格 / → / PageDown / 鼠标左键    下一个图案
    ← / ↑ / PageUp / 鼠标右键          上一个图案
    1..9                              直接跳到第 N 个图案
    I                                 显示/隐藏信息层
    T                                 自动轮播开关（每 5 秒）
    M                                 一次只点亮一台屏，反复按切换；再次循环回到全部
    Esc                               退出

.PARAMETER Screen
  只测试指定的一台显示器。编号即 display-check 输出里的 [1] [2] …；不填则全部。

.PARAMETER Pattern
  起始图案编号（1 起）或名称关键字，例如 -Pattern 5 或 -Pattern 黑。

.PARAMETER AutoCycle
  启动即开启自动轮播。

.PARAMETER AutoClose
  运行 N 秒后自动退出（自检用，正常使用不要加）。

.EXAMPLE
  .\scripts\monitor-test.cmd
  .\scripts\monitor-test.cmd -Screen 2 -Pattern 5
  .\scripts\monitor-test.cmd -AutoClose 5
#>
[CmdletBinding()]
param(
    [int]$Screen = 0,
    [string]$Pattern = '',
    [switch]$AutoCycle,
    [int]$AutoClose = 0
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName System.Drawing | Out-Null

[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- 图案定义
function New-PatternList {
    $list = New-Object System.Collections.ArrayList
    $add = {
        param($id, $name, $kind, $color)
        [void]$list.Add([pscustomobject]@{ Id = $id; Name = $name; Kind = $kind; Color = $color })
    }
    & $add 1  '纯红'          'solid'    ([System.Drawing.Color]::FromArgb(255, 0, 0))
    & $add 2  '纯绿'          'solid'    ([System.Drawing.Color]::FromArgb(0, 255, 0))
    & $add 3  '纯蓝'          'solid'    ([System.Drawing.Color]::FromArgb(0, 0, 255))
    & $add 4  '纯白'          'solid'    ([System.Drawing.Color]::White)
    & $add 5  '纯黑'          'solid'    ([System.Drawing.Color]::Black)
    & $add 6  '10% 灰'        'solid'    ([System.Drawing.Color]::FromArgb(26, 26, 26))
    & $add 7  '50% 灰'        'solid'    ([System.Drawing.Color]::FromArgb(128, 128, 128))
    & $add 8  '90% 灰'        'solid'    ([System.Drawing.Color]::FromArgb(230, 230, 230))
    & $add 9  '水平渐变'      'gradient' 'horizontal'
    & $add 10 '垂直渐变'      'gradient' 'vertical'
    & $add 11 '16 级灰阶条'   'steps'    $null
    & $add 12 '棋盘格'        'checker'  $null
    & $add 13 '十字网格'      'grid'     $null
    & $add 14 '移动竖条'      'moving'   $null
    & $add 15 '坏点扫描'      'sweep'    $null
    return ,$list
}

$patterns = New-PatternList

$startIndex = 0
if ($Pattern) {
    $byName = $patterns | Where-Object { $_.Name -like "*$Pattern*" }
    if ($byName) {
        $startIndex = [int]$byName[0].Id - 1
    } elseif ($Pattern -as [int]) {
        $n = [int]$Pattern
        if ($n -ge 1 -and $n -le $patterns.Count) { $startIndex = $n - 1 }
    }
}

$allScreens = @([System.Windows.Forms.Screen]::AllScreens)

$visible = New-Object System.Collections.ArrayList
if ($Screen -gt 0) {
    if ($Screen -gt $allScreens.Count) {
        Write-Host ("只有 {0} 台显示器，-Screen {1} 超出范围。" -f $allScreens.Count, $Screen) -ForegroundColor Red
        exit 1
    }
    [void]$visible.Add($Screen - 1)
} else {
    for ($i = 0; $i -lt $allScreens.Count; $i++) { [void]$visible.Add($i) }
}

# ---------------------------------------------------------------- 共享状态
$script:state = @{
    Index     = $startIndex
    ShowInfo  = $true
    AutoCycle = [bool]$AutoCycle
    Visible   = $visible
    SingleAt  = $(if ($Screen -gt 0) { $Screen - 1 } else { -1 })   # -1 = 全部
    Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Forms     = New-Object System.Collections.ArrayList
}

$script:fonts = @{
    Big  = New-Object System.Drawing.Font('Microsoft YaHei UI', 16, [System.Drawing.FontStyle]::Regular)
    Hint = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Regular)
}

function Get-CurrentPattern {
    $script:state.Index = (($script:state.Index % $patterns.Count) + $patterns.Count) % $patterns.Count
    return $patterns[$script:state.Index]
}

function Invoke-Repaint {
    foreach ($f in $script:state.Forms) {
        if ($f -and -not $f.IsDisposed -and $f.Visible) { $f.Invalidate() }
    }
}

function Set-Visibility {
    $v = $script:state.Visible
    for ($i = 0; $i -lt $script:state.Forms.Count; $i++) {
        $f = $script:state.Forms[$i]
        if (-not $f -or $f.IsDisposed) { continue }
        if ($v -contains $i) {
            if (-not $f.Visible) {
                $f.Show()
                $f.Activate()
            }
            $f.Invalidate()
        } else {
            if ($f.Visible) { $f.Hide() }
        }
    }
}

function New-TestForm {
    param([System.Windows.Forms.Screen]$Target)

    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $f.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $f.Bounds = $Target.Bounds
    $f.TopMost = $true
    $f.KeyPreview = $true
    $f.BackColor = [System.Drawing.Color]::Black
    $f.ShowInTaskbar = $false
    $f.Text = "monitor-test {0}" -f $Target.DeviceName

    $f.add_Paint({
        param($s, $e)

        $g = $e.Graphics
        $rect = $s.ClientRectangle
        $p = Get-CurrentPattern

        switch ($p.Kind) {
            'solid' {
                $b = New-Object System.Drawing.SolidBrush($p.Color)
                $g.FillRectangle($b, $rect)
                $b.Dispose()
            }
            'gradient' {
                $angle = if ($p.Color -eq 'vertical') { 90 } else { 0 }
                $b = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::Black, [System.Drawing.Color]::White, $angle)
                $g.FillRectangle($b, $rect)
                $b.Dispose()
            }
            'steps' {
                $g.FillRectangle([System.Drawing.Brushes]::Black, $rect)
                $bands = 16
                $w = [math]::Ceiling($rect.Width / $bands)
                for ($i = 0; $i -lt $bands; $i++) {
                    $v = [int][math]::Round(255 * $i / ($bands - 1))
                    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, $v, $v, $v))
                    $g.FillRectangle($b, ($i * $w), 0, $w, $rect.Height)
                    $b.Dispose()
                }
            }
            'checker' {
                $g.FillRectangle([System.Drawing.Brushes]::White, $rect)
                $tile = 64
                for ($y = 0; $y -lt $rect.Height; $y += $tile) {
                    for ($x = 0; $x -lt $rect.Width; $x += $tile) {
                        if ((([int]($x / $tile)) + ([int]($y / $tile))) % 2 -eq 0) {
                            $g.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, $tile, $tile)
                        }
                    }
                }
            }
            'grid' {
                $g.Clear([System.Drawing.Color]::Black)
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1)
                for ($x = 0; $x -lt $rect.Width; $x += 100) { $g.DrawLine($pen, $x, 0, $x, $rect.Height) }
                for ($y = 0; $y -lt $rect.Height; $y += 100) { $g.DrawLine($pen, 0, $y, $rect.Width, $y) }
                $g.DrawRectangle($pen, 0, 0, $rect.Width - 1, $rect.Height - 1)
                $pen.Dispose()
            }
            'moving' {
                $g.Clear([System.Drawing.Color]::Black)
                $t = $script:state.Stopwatch.Elapsed.TotalSeconds
                $barW = [math]::Max(4, [int]($rect.Width / 160))
                $x = [int](($t * 320) % ($rect.Width + $barW)) - $barW
                $g.FillRectangle([System.Drawing.Brushes]::White, $x, 0, $barW, $rect.Height)
            }
            'sweep' {
                $g.Clear([System.Drawing.Color]::White)
                $t = $script:state.Stopwatch.Elapsed.TotalSeconds
                $size = 48
                $cols = [math]::Max(1, [int][math]::Floor($rect.Width / $size))
                $step = [int]($t * 4) % ($cols * 2)
                if ($step -ge $cols) { $step = $cols * 2 - 1 - $step }
                $x = $step * $size
                $y = [int](($t * 60) % [math]::Max(1, ($rect.Height - $size)))
                $g.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, $size, $size)
            }
        }

        if ($script:state.ShowInfo) {
            $sp = $s.Screen
            $idx = 0
            for ($i = 0; $i -lt $allScreens.Count; $i++) {
                if ($allScreens[$i].DeviceName -eq $sp.DeviceName) { $idx = $i + 1 }
            }
            $line1 = '屏幕 {0}/{1}   {2}   {3}x{4}' -f $idx, $allScreens.Count, $sp.DeviceName, $sp.Bounds.Width, $sp.Bounds.Height
            $line2 = '图案 {0}/{1}  {2}' -f $p.Id, $patterns.Count, $p.Name
            $line3 = '空格/→ 下一个   ← 上一个   I 信息   T 轮播   M 单屏   Esc 退出'

            $boxH = 96
            $boxW = [math]::Min(980, $rect.Width - 48)
            $box = New-Object System.Drawing.Rectangle(24, ($rect.Height - $boxH - 24), $boxW, $boxH)
            $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 0, 0, 0))
            $g.FillRectangle($bg, $box)
            $bg.Dispose()

            $g.DrawString($line1, $script:fonts.Big, [System.Drawing.Brushes]::White, ($box.X + 14), ($box.Y + 8))
            $g.DrawString($line2, $script:fonts.Big, [System.Drawing.Brushes]::White, ($box.X + 14), ($box.Y + 38))
            $g.DrawString($line3, $script:fonts.Hint, [System.Drawing.Brushes]::LightGray, ($box.X + 14), ($box.Y + 70))
        }
    })

    $f.add_KeyDown({
        param($s, $e)
        switch ($e.KeyCode) {
            'Escape'   { [System.Windows.Forms.Application]::Exit(); return }
            'Space'    { $script:state.Index++; Invoke-Repaint }
            'Right'    { $script:state.Index++; Invoke-Repaint }
            'PageDown' { $script:state.Index++; Invoke-Repaint }
            'Left'     { $script:state.Index--; Invoke-Repaint }
            'Up'       { $script:state.Index--; Invoke-Repaint }
            'PageUp'   { $script:state.Index--; Invoke-Repaint }
            'I'        { $script:state.ShowInfo = -not $script:state.ShowInfo; Invoke-Repaint }
            'T'        { $script:state.AutoCycle = -not $script:state.AutoCycle }
            'M'        {
                if ($allScreens.Count -gt 1) {
                    $next = $script:state.SingleAt + 1
                    if ($next -ge $allScreens.Count) { $next = -1 }
                    $script:state.SingleAt = $next
                    $script:state.Visible.Clear()
                    if ($next -lt 0) {
                        for ($i = 0; $i -lt $allScreens.Count; $i++) { [void]$script:state.Visible.Add($i) }
                    } else {
                        [void]$script:state.Visible.Add($next)
                    }
                    Set-Visibility
                }
            }
            default {
                if ($e.KeyCode -ge 'D1' -and $e.KeyCode -le 'D9') {
                    $n = [int]$e.KeyCode - [int][System.Windows.Forms.Keys]::D1
                    if ($n -lt $patterns.Count) { $script:state.Index = $n; Invoke-Repaint }
                }
            }
        }
    })

    $f.add_MouseDown({
        param($s, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:state.Index++; Invoke-Repaint }
        elseif ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) { $script:state.Index--; Invoke-Repaint }
    })

    return $f
}

# 每台屏各建一个窗口（是否显示由 Visible 决定）
for ($i = 0; $i -lt $allScreens.Count; $i++) {
    [void]$script:state.Forms.Add((New-TestForm -Target $allScreens[$i]))
}

# 动画帧计时器（移动条 / 坏点扫描 / 轮播）
$script:autoCloseTimer = $null
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 16
$script:lastCycle = [datetime]::Now
$timer.add_Tick({
    $p = Get-CurrentPattern
    if ($p.Kind -eq 'moving' -or $p.Kind -eq 'sweep') { Invoke-Repaint }
    if ($script:state.AutoCycle) {
        if (([datetime]::Now - $script:lastCycle).TotalSeconds -ge 5) {
            $script:lastCycle = [datetime]::Now
            $script:state.Index++
            Invoke-Repaint
        }
    }
})
$timer.Start()

if ($AutoClose -gt 0) {
    $script:autoCloseTimer = New-Object System.Windows.Forms.Timer
    $script:autoCloseTimer.Interval = [int]($AutoClose * 1000)
    $script:autoCloseTimer.add_Tick({
        $script:autoCloseTimer.Stop()
        [System.Windows.Forms.Application]::Exit()
    })
    $script:autoCloseTimer.Start()
}

Write-Host ''
Write-Host ("画面测试：{0} 台显示器，{1} 个图案。Esc 退出。" -f $allScreens.Count, $patterns.Count) -ForegroundColor Cyan
foreach ($s in $allScreens) { Write-Host ("    {0}  {1}" -f $s.DeviceName, $s.Bounds) }
Write-Host ''

# 要显示的窗口在消息循环启动前 Show，进入循环后一起绘制
$mainForm = $script:state.Forms[$script:state.Visible[0]]
for ($i = 0; $i -lt $script:state.Forms.Count; $i++) {
    if ($script:state.Visible -contains $i) { $script:state.Forms[$i].Show() }
}

[System.Windows.Forms.Application]::Run($mainForm)

$timer.Stop()
if ($script:autoCloseTimer) { $script:autoCloseTimer.Stop() }
foreach ($f in $script:state.Forms) { if ($f -and -not $f.IsDisposed) { $f.Dispose() } }

Write-Host '已退出画面测试。' -ForegroundColor Green
