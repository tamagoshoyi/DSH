# 幽灵程序与残留注册表扫描

日期：2026-10-23 · 扫描内容：启动项 / 服务驱动 / 卸载记录 / App Paths / 快捷方式 / 计划任务 / 事件日志 / 残留目录

## 扫描方法与限制

- 启动项、服务、卸载记录、App Paths：读注册表，逐条把 `ImagePath` / `InstallLocation` / `UninstallString` / `DisplayIcon` 解析成真实路径后用 `Test-Path` 验证。
- 快捷方式：用 `WScript.Shell` COM 解析 `.lnk` 的 `TargetPath`（130 个，全量）。
- 服务：枚举 785 个带 `ImagePath` 的服务与驱动（含内核驱动）。
- **未覆盖**：计划任务（`C:\Windows\System32\Tasks` 对普通用户拒绝访问，需管理员）；WMI 在沙箱内被整体禁用，无法读 `Win32_Product` 这类源。

## 结论摘要

| 类别 | 数量 | 影响 |
| --- | --- | --- |
| 幽灵服务 / 驱动 | 5 个纯幽灵 + 2 个半坏 | 其中 `cpuz159` 正在加载；`XLWFP` 每次开机失败（30 天 13 次） |
| 幽灵卸载记录 | 10 条 | 控制面板/设置里能看到，点卸载会报错或什么都不发生 |
| 幽灵启动批准项 | 4 条 | 任务管理器启动项里看不到，但残留决策记录 |
| 空壳 / 半卸载目录 | 6 处 | 约 1.9 GB |
| 启动项 Run 本身 | 17 条，0 幽灵 | 全部可执行，健康 |
| 快捷方式 | 130 个，0 幽灵 | 健康 |
| App Paths | 0 幽灵 | 健康 |

## 1. 幽灵服务与驱动

服务键还在，`ImagePath` 指向的文件已经不在了。**结论：可以安全删除注册表项**，因为这些驱动/服务本身的文件都没了。

| 服务名 | 类型 | 启动 | ImagePath（缺失） | 来源 | 状态 |
| --- | --- | --- | --- | --- | --- |
| `ACE-CORE106010071` | 内核驱动 | 手动 | `C:\Program Files\AntiCheatExpert\ACE-CORE106010071.sys` | 三角洲行动反作弊旧版 | 已停止 |
| `ACE-CORE206010071` | 内核驱动 | 手动 | `C:\Program Files\AntiCheatExpert\ACE-CORE206010071.sys` | 同上 | 已停止 |
| `ace-game-0` | 内核驱动 | 手动 | `C:\WINDOWS\System32\drivers\ace-game-0.sys` | 同上 | 已停止 |
| `atvi-randgrid_msstore` | 内核驱动 | 手动 | `D:\XGP\Call of Duty\Content\Randgrid.sys` | 使命召唤（XGP）已卸载 | 已停止 |
| `cpuz159` | 内核驱动 | 手动 | `C:\WINDOWS\temp\cpuz159\cpuz159_x64.sys` | CPU-Z 临时驱动，残留注册 | **正在运行** |
| `XLWFP` | 内核驱动 | **自动** | `system32\drivers\xlwfp.sys` | 迅雷 WFP 过滤驱动 | 每次开机失败 |
| `XLServicePlatform` | 服务 | 自动 | DLL 仍存在 | 迅雷服务 | 正常运行，非幽灵 |

注意两点：

- **ACE 目录里其实还有 5 个 `.sys`**（`ACE-CORE1019791`、`ACE-CORE102706` …），只是名字和注册的服务对不上——说明三角洲行动反作弊升级过版本，旧版的服务项没被清掉。删掉这 3 个服务项不影响现役 ACE。
- **`cpuz159` 是 CPU-Z 的即用即删驱动**，文件删了但服务注册和内核里已加载的映像还在。先 `sc stop` 再删。
- **`XLWFP` 不是"程序没了"，是驱动文件丢了**（大概率被火绒隔离或迅雷更新中断）。D 盘 `D:\Thunder\Program\Thunder.exe` 还在，迅雷本身是装了半截。要么重装迅雷，要么把这个自动启动的服务删掉/禁用——留着就是白刷 13 次/月的开机失败事件。

## 2. 幽灵卸载记录

控制面板/设置-应用里还会显示，但卸载按钮指向的目标不存在。

| 显示名 | 注册表位置 | 缺失的是 |
| --- | --- | --- |
| `Steam App 1681430`（机械战警：暴戾都市） | HKLM\...\Uninstall\Steam App 1681430 | 安装目录 + 图标 |
| `Steam App 365360`（战场兄弟） | HKLM\...\Uninstall\Steam App 365360 | 安装目录 + 图标 |
| `Steam App 431960`（Wallpaper Engine） | HKLM\...\Uninstall\Steam App 431960 | 安装目录 + 图标 |
| `Steam App 553850`（HELLDIVERS 2） | HKLM\...\Uninstall\Steam App 553850 | 图标 |
| `Intel(R) Management Engine Components` | HKLM\...\Uninstall\{1CEAC85D-2590-4760-800F-8DE5E91F3700} | Package Cache 里的 SetupME.exe |
| `DF Launcher` | HKLM\WOW6432Node\...\Uninstall\DF Launcher | `D:\Delta Force\launcher\DF Launcher卸载.exe` |
| `微信` | HKLM\WOW6432Node\...\Uninstall\WeChat | `D:\WeChat\WeChat.exe`（已搬到 `D:\Weixin`） |
| `三角洲行动` | HKLM\WOW6432Node\...\Uninstall\三角洲行动 | `D:\Delta Force\...\三角洲行动卸载.exe` |
| `三角洲行动`（启动器） | HKCU\SOFTWARE\...\Uninstall\delta_force_launcher | `D:\Delta Force\launcher\uninst.exe` |
| `TraeWork CN (User)` | HKCU\SOFTWARE\...\Uninstall\{953A2114-1972-4389-9722-1F54639F3958}_is1 | `AppData\Local\Programs\TRAE SOLO CN\unins000.exe` |

四条 Steam 记录值得单独说：Steam 的 `appmanifest_*.acf` 已经不在库里了（当前库只剩 MENACE、Gray Zone Warfare、Pandora's Toybox、Warband、Barotrauma、The Invincible 等），这四条是历史卸载没清干净的注册表尾巴。

`AntiCheatExpert` 那条**不算幽灵**：卸载器 `C:\Program Files\AntiCheatExpert\Uninstaller.exe` 还在，只是图标指向已删除的三角洲目录。要么留着，要么连 ACE 一起卸。

## 3. 幽灵启动批准项

任务管理器的"启动"页会读 `HKCU\...\Explorer\StartupApproved\Run`，下面的项已经没有任何对应的启动项了：

| 批准项 | 现状 |
| --- | --- |
| `ShimakazeGo` | 无对应 Run 项 |
| `Tobii GameHub` | 无对应 Run 项（GameHub 已卸载） |
| `WallpaperEngine` | 无对应 Run 项（壁纸引擎已卸载） |
| `Wechat` | 无对应 Run 项（已改名为 `Weixin`） |

纯垃圾数据，删掉不影响任何功能。

## 4. 残留目录

| 路径 | 体积 | 判断 |
| --- | --- | --- |
| `D:\Thunder` | 1.35 GB / 414 文件 | 迅雷主体在（`Program\Thunder.exe`），但驱动坏了，属半卸载 |
| `D:\SquirrelTemp` | 0.48 GB / 7 文件 | Squirrel 安装器（Discord/Teams 类）临时文件，可删 |
| `C:\Program Files (x86)\Interhaptics` | 0.33 GB / 24217 文件 | 触觉反馈 SDK，自带 Uninstall.exe，无对应卸载记录 → 孤儿 |
| `D:\WeChat` | 0 文件 | 旧微信目录，已迁到 `D:\Weixin`，空壳可删 |
| `D:\msdownld.tmp`、`D:\Config.Msi`、`D:\WpSystem` | 0 | 安装/商店残留空目录 |
| `D:\sdkdata` | 2 文件 | 待确认归属 |
| `C:\Program Files (x86)\QQMailPlugin` | 0 GB | 无服务、无卸载记录的空壳 |
| `C:\Program Files (x86)\EasyAntiCheat` + `_EOS` | 0.06 GB | **不要删**：Gray Zone Warfare 等现役游戏还在用 EAC |
| `C:\Program Files (x86)\Tobii` | 0.06 GB | Tobii EyeX/Service 组件，`Tobii Service` 服务仍在（已停止），属半卸载 |

## 5. 事件日志佐证

近 30 天服务类失败事件：

- `XLWFP` 失败 **13 次**（Id 7000）——与驱动文件丢失一致。
- `Steam Client Service` 超时 2 次 + 失败 2 次——Steam 提权服务偶发，正常现象。
- `BcastDVRUserService_*` 失败/超时若干——Xbox 录屏服务，Windows 已知噪音。
- `ASUS Com Service`、`ASUS AURA SYNC lighting service` 各异常终止 1 次。

## 清理优先级建议

1. **先删 5 个纯幽灵服务**（零风险，文件都已不存在）。
2. **处理 `XLWFP`**：想继续用迅雷就重装/修复；不用了就删服务并考虑整体卸载。
3. **删 10 条幽灵卸载记录**（零风险）。
4. **删 4 条启动批准项**（零风险）。
5. **删空壳目录**（`D:\WeChat`、`D:\SquirrelTemp`、`D:\msdownld.tmp`、`D:\Config.Msi`、`D:\WpSystem`、`QQMailPlugin`）。
6. **单独决策**：`Interhaptics`（先跑它自带的 Uninstall.exe）、`Tobii`（确认无眼动仪硬件后再卸）、迅雷整体去留。

清理脚本：`.tmp\cleanup-ghosts.ps1`（默认 dry-run，加 `-Execute` 才动手，需管理员）。

## 清理执行记录（2026-10-23 19:06）

管理员终端执行 `cleanup-ghosts.ps1 -Execute`，全部返回 OK：

| 项 | 结果 |
| --- | --- |
| 5 个幽灵服务 | 4 个已删除；`cpuz159` 记为「待删除」（`DeleteFlag=1`），内核映像仍在内存，**重启后自动消失** |
| `XLWFP` | 已禁用（`START_TYPE: 4 DISABLED`），不再每次开机报错 |
| 10 条幽灵卸载记录 | 全部删除 |
| 4 条失效启动批准项 | 全部删除 |
| 6 个空壳目录 | 全部删除（D: 释放 0.48 GB） |

### 复核（清理后重跑全套扫描）

| 指标 | 清理前 | 清理后 |
| --- | --- | --- |
| 有 ImagePath 的服务/驱动 | 785 个，7 个目标缺失 | 781 个，**1 个**缺失（`cpuz159`，待重启清除） |
| 卸载记录 | 217 条，11 条路径失效 | 207 条，**1 条**（`AntiCheatExpert`，仅图标失效，卸载器仍在） |
| 启动项 Run | 17 条，0 幽灵 | 17 条，0 幽灵 |
| 快捷方式 | 130 个，0 幽灵 | 130 个，0 幽灵 |
| 计划任务 | 未扫描（权限不足） | 仍然未扫描，需管理员运行 `schtasks` |

事件日志里的 13 次 `XLWFP` 失败是清理前的历史记录，重启后观察一天应归零。

## 计划任务扫描（补充，2026-10-23 19:12）

管理员导出 `schtasks /query /fo csv /v` 后解析：523 行 → 去重 **281 个任务**，其中 48 个已禁用（全是 Windows 内置，属正常状态）。

目标文件缺失的只有 7 个，全部处于「已启用」：

| 任务 | 缺失的可执行文件 | 判断 |
| --- | --- | --- |
| `\ASUS\P508PowerAgent_sdk` | `ASUS\ArmouryDevice\...\ROG STRIX CARRY\P508PowerAgent.exe` | 华硕鼠标电源代理，设备已不在，可删 |
| `\Microsoft\Windows\Location\Notifications` | `System32\LocationNotificationWindows.exe` | 定位通知，组件已不存在，可删/禁用 |
| `\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser` | `System32\MbaeParserTask.exe` | 移动宽带，本机无蜂窝模块，可删/禁用 |
| `\Microsoft\Windows\UpdateOrchestrator\MusUx_LogonUpdateResults` | `System32\MusNotification.exe` | 见下 |
| `\Microsoft\Windows\UpdateOrchestrator\Reboot_AC` | 同上 | 见下 |
| `\Microsoft\Windows\UpdateOrchestrator\Reboot_Battery` | 同上 | 见下 |
| `\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker` | 同上 | 见下 |

**重要发现**：`MusNotification.exe` 与 `MusNotificationUx.exe` 在 `System32` 下都不存在，同时缺
`LocationNotificationWindows.exe`、`MbaeParserTask.exe`。这些是 Windows 自带的更新提示/定位/移动宽带组件，
正常安装不该缺——**说明这套系统是被精简（slim）处理过的镜像**，不是原版。

影响评估：

- 这 4 个 UpdateOrchestrator 任务只负责「更新完成后的提示 UI」和「重启提醒」，不是更新机制本身；
- Windows Update 的实际下载安装走 `UsoClient` / `UpdateOrchestrator\Schedule Work` 系列，这些任务的目标文件都在；
- 因此缺这几个组件不会让系统更新失效，也不会影响游戏稳定性，只是这几条任务被触发时会静默失败。

建议：只删前三个（ASUS / 定位 / 移动宽带），后面 4 个改成禁用而不是删除，保留系统更新结构完整。

## 重启后验证（2026-10-23 19:26，开机 19:22:20）

| 检查项 | 结果 |
| --- | --- |
| `ACE-CORE106010071` / `ACE-CORE206010071` / `ace-game-0` / `atvi-randgrid_msstore` | 服务已不存在 ✅ |
| `XLWFP` | `START_TYPE: 4 DISABLED` ✅ |
| `\ASUS\P508PowerAgent_sdk` | 已删除 ✅ |
| `\Microsoft\Windows\Location\Notifications` | 已删除 ✅ |
| `\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser` | **仍在，状态 Ready** ❌（删除没生效） |
| 4 个 `UpdateOrchestrator` 任务 | 非管理员 `schtasks /query` 返回非零（受保护），状态未知 |
| `cpuz159` | **仍 `STATE: 4 RUNNING`**，注册表键存在，`Start=3`，`DeleteFlag` 已消失 ❓ |
| 事件 7000（服务启动失败） | 重启后 0 条（最后一条 18:40，重启前）✅ |
| 事件 7001 | 3 条，均为 "User Logon Notification for Customer Experience Improvement Program"，系统自带噪音，无需处理 |

磁盘：C: 可用 197.92 / 399.02 GB，D: 可用 229.61 / 531.20 GB。
页面文件仍为 `c:\pagefile.sys 0 0 | d:\pagefile.sys 40000 41000`；commit 13.41 GB，可用内存 21197 MB，pf 使用率 0%。

### `cpuz159` 为什么清不掉

`sc query cpuz159` 报 `RUNNING`，但注册表里 `DeleteFlag` 已随重启清除、`Start` 从 4 变回 3（按需启动）——
说明重启后这个键被重新写入了，而不是简单残留。

可疑点：`C:\WINDOWS\temp` 的 ACL 连沙箱的 `danger-full-access` 都读不了
（`Test-Path` 报 `Access is denied`，`Get-ChildItem` 返回 0 项，`cmd /c dir` 显示 File Not Found）。
所以「`cpuz159_x64.sys` 不存在」这个结论**不可靠**，只有管理员/SYSTEM 身份能确认。

待办（管理员终端）：

```cmd
sc query cpuz159
sc stop cpuz159
sc delete cpuz159
dir C:\WINDOWS\temp\cpuz159
```

若 `dir` 显示文件存在，停掉后手动删除该目录，再重启确认服务消失。


