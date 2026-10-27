# C:/D: 全盘审计报告（2026-10-27）

> 目标：找出垃圾文件、无头注册表项、僵尸软件残留，并给出可逐项决策的已安装程序全量清单。
> 交互式表格：`docs/program-audit-2026-10-27.xlsx`（6 个工作表，「你的决定」列带下拉：保留 / 删除 / 待定）。

---

## 一、结论速览

| 维度 | 结果 |
| --- | --- |
| 已安装程序 | **210 条**，已知体积合计 **165.9 GB** |
| 其中建议「可删」 | 6 条，已知体积 **149.7 MB**；待你判断 53 条；建议保留 151 条 |
| 垃圾/缓存「安全可删」 | 32 项中 25 项可清，合计 **15.4 GB** |
| 残留数据目录待判断 | **37 个，37.5 GB** |
| 僵尸项 | **12 条**（1 个服务 + 11 个孤儿目录），真正的死链 **0** |
| 空间大头 | 游戏本体 ~146 GB、`D:\迅雷下载` 25.3 GB、各类应用缓存 37.5 GB |

**一句话**：机器上没有「坏掉的注册表」级垃圾了（10-23 那次清理确实干净），现在能榨的空间在**缓存**和**你不再用的软件**，前者约 15 GB 立等可取，后者取决于你对下面几条的判断。

---

## 二、扫描方法（可复现）

| 数据源 | 手段 | 产物 |
| --- | --- | --- |
| 已安装程序 | 三个 Uninstall 注册表 hive（HKLM 64 位 / WOW6432Node / HKCU）逐项解析，合并 MSI 产品库 `Installer\UserData\*\Products\*\InstallProperties` 判活 | `.tmp\progs.csv` |
| 僵尸项 | 卸载记录、Run 启动项、桌面+开始菜单快捷方式、App Paths、服务 ImagePath、Program Files 孤儿目录，逐条 Test-Path / 解析 lnk | `.tmp\zombies.csv` |
| 垃圾文件 | 26 处已知缓存位置 + 阈值扫描，按「安全可删 / 需确认 / 保留」分级 | `.tmp\junk.csv` |
| 残留数据目录 | `%LOCALAPPDATA%`、`%APPDATA%`、`%ProgramData%` 一级子目录，按体积排序人工核实 | `.tmp\appdata.csv` |

关键判活规则（这次踩过的坑）：MSI 程序的 `UninstallString` 一律是 `MsiExec.exe /X{GUID}`，**不能**拿来判文件是否存在，否则 210 条里会误报 105 条"幽灵"。正确做法是用 MSI 产品库的 `DisplayName` 反查。

---

## 三、垃圾文件（`.tmp\junk.csv`，60 行 → 32 项有内容）

### 立即可清，无需判断（合计 15,418 MB）

| 体积 | 路径 | 说明 |
| --- | --- | --- |
| 10,115 MB | `C:\Users\WINDOWS\AppData\Local\D3DSCache` | **最大单块**。DirectX 着色器缓存，删了游戏首次进场景会重建（几分钟卡顿），之后正常 |
| 2,252 MB | `C:\ProgramData\ASUS\ARMOURY CRATE Diagnosis` | 奥创诊断日志，纯日志，可全删 |
| 699 MB | `...\AppData\Local\Steam\htmlcache` | Steam 内置浏览器缓存 |
| 525 MB | `...\AppData\Local\NVIDIA\DXCache` | 驱动着色器缓存 |
| 413 MB | Chrome `Cache` | 浏览器缓存 |
| 365 MB | `...\AppData\Local\NVIDIA\GLCache` | OpenGL 着色器缓存 |
| 347 MB | `...\Microsoft\Windows\Explorer` | 缩略图数据库，删了会重建 |
| 304 MB | `C:\Windows\Logs` | Windows 日志（CBS/DISM 等） |
| 268 MB | Edge `Cache` | 浏览器缓存 |
| 其余 | Chrome Code Cache 79、%TEMP% 43、CrashDumps 8 等 | — |

### 需要你点头（493 MB）
- `C:\ProgramData\Package Cache` —— 各安装器的缓存，删掉不影响使用，但以后「修复安装」或卸载某些 VC++ 运行库时会重新下载。

### 明确保留
- `D:\迅雷下载` 25.3 GB（你的影视/资源，你说过留着）
- `C:\Windows\WinSxS` 23.8 GB（组件存储，只能用 `DISM /Online /Cleanup-Image /StartComponentCleanup` 清超期部分，不能手删）
- `C:\Windows\Installer` 1.26 GB（MSI 缓存，删了没法修复/卸载程序）

---

## 四、僵尸项（`.tmp\zombies.csv`，12 条）

### 好消息
卸载记录 / Run 启动项 / 桌面与开始菜单快捷方式 / App Paths —— **全部 0 条死链**。10-23 那次清理把该删的都删干净了。

### 唯一"服务"项：不是幽灵
`cpuz159` —— 微软电脑管家（Microsoft PC Manager）做硬件检测时加载的 CPU-Z 签名驱动，每次开机由管家重建，删除后下次开机又回来。属于正常行为，不用管。

### 11 个孤儿目录（无对应卸载记录）

| 体积 | 目录 | 判断 |
| --- | --- | --- |
| 988 MB | `C:\Program Files\NVIDIA Corporation` | **保留**，NVIDIA App 本体在这；其中 `Installer2` 333 MB 是旧安装包，可清 |
| 982 MB | `C:\Program Files\SogouInput` | **误报**（输入法主目录），保留 |
| 708 MB | `C:\Program Files\Paradox Interactive` | 启动器实体，删不删跟「Paradox Launcher」一起决定 |
| 473 MB | `C:\Program Files\Tencent` | QQ 组件；其中 `Qzone` 7 MB + `QzoneMusic` 15 MB 是 2024 年的旧组件，可删 |
| 339 MB | `C:\Program Files (x86)\Interhaptics` | Razer 触觉反馈组件，安装器没登记卸载项，但自带 `Uninstall.exe` → **可删** |
| 124 MB | Adobe（`Program Files` 86.9 + `Program Files (x86)` 37.1） | Creative Cloud 卸载后的空壳，**可删** |
| 41 MB | `EasyAntiCheat_EOS` / 17 MB `EasyAntiCheat` | **保留**，现役游戏反作弊 |
| 14 MB | `C:\Program Files (x86)\LightingService` | Aura 灯效服务，`LastProfile` 当天还在写 → 保留 |
| 1 MB | `C:\Program Files (x86)\Kingsoft` | WPS 组件，留 |

---

## 五、残留数据目录（37 个，37.5 GB，`.tmp\appdata.csv`）

按体积前 12：

| 体积 | 目录 | 说明 |
| --- | --- | --- |
| 10,115 MB | `AppData\Local\D3DSCache` | 与垃圾表重复计数，删一次就行 |
| 6,136 MB | `Local\JianyingPro` | 剪映草稿 + 素材缓存，**先确认有没有没导出的工程** |
| 4,129 MB | `Roaming\Tencent` | QQ/微信数据，删了聊天记录就没了 |
| 3,418 MB | `Local\Larian Studios` | 博德之门 3 存档 + 配置，**不能整删** |
| 2,585 MB | `Local\Programs` | 用户级安装目录（VS Code、TRAE 等装在这），别整体删 |
| 1,378 MB | `Local\GZW` | 灰区战争缓存 |
| 795 MB | `ProgramData\SogouInput` | 搜狗输入法词库 |
| 640 MB | `Local\Wardogs` | 某游戏（战争号令？）缓存 |
| 606 MB | `Local\Hujiang` | 沪江网校残留 |
| 572 MB | `Local\poi` | 舰C 浏览器缓存 |
| 553 MB | `Local\@deepseek-ai\dsh-desktop-updater` | DSH 更新器下载缓存，**可删** |
| 511 MB | `Local\ElectronicObserver` | 舰C 工具 |

> 完整的 37 行在表格「垃圾与残留」页，每条都带「建议」列。

---

## 六、已安装程序（210 条）

分类分布（体积只统计能查到的部分）：

| 类别 | 条目 | 已知体积 | 处理原则 |
| --- | --- | --- | --- |
| 游戏/平台 | 16 | 146.2 GB | 按需保留，占全机一半以上 |
| 应用软件 | 9 | 5.5 GB | 浏览器、网盘、输入法，看你用不用 |
| 运行库 | 56 | 5.3 GB | **别动**，删了别的软件会崩 |
| 其他 | 16 | 4.6 GB | 杂项，多数需要你判断 |
| 驱动/硬件组件 | 84 | 1.8 GB | 主板灯效、声卡、芯片组，删了功能异常 |
| 办公 | 2 | 1.6 GB | WPS 与 Office 插件 |
| 系统组件 | 14 | 0.6 GB | 系统自带，保留 |
| 开发工具 | 11 | 0.3 GB | Python / .NET / TRAE，看你写不写代码 |
| 工具 | 2 | 0 MB | 更新修复、安全软件 |

### 我已明确建议「可删」的（6 条，149.7 MB）
- Python 3.14.5 的 **Documentation**（64 MB）、**Test Suite**（37 MB）—— 网上都能查，个人不需要
- Microsoft Teams Meeting Add-in（34 MB）—— 没装 Teams 就是摆设
- RivaTuner Statistics Server（RTSS）—— 通常随 MSI Afterburner 一起装，不超频/不看帧率就没用
- CertsUpdater 1.5（3 MB）—— Saber 游戏遗留的证书更新器
- 「Windows 电脑健康状况检查」（12 MB）—— 微软的健康检查小工具，信息都能在系统信息里看到
- 完整 6 条见表格「程序清单」页，按「建议」列筛选「可删」（已排在最前 6 行）

### 需要你重点表态的几条
1. **安全软件真空**：火绒和 Defender 现在**都没在跑**。建议二选一启用（火绒留着就启动它，不用就卸掉并开 Defender）。
2. **剪映 vs 必剪**：功能重叠，留一个即可（剪映 6.1 GB 数据 + 588 MB 程序）。
3. **迅雷 vs 比特彗星**：功能重叠；迅雷的 WFP 驱动文件已丢失、服务已禁用，属于半卸载状态。
4. **TRAE CN / TRAE SOLO CN**：两个 IDE 共 2 GB，看你还用不用。
5. **Epic 全家桶**（Launcher 238 MB + EOS 305 MB + UE4 前置 178 MB）：不玩 Epic 游戏可整组删。
6. **Paradox Launcher**（137 MB + 708 MB 目录）：不玩群星/CK3 就删。
7. **Process Lasso 38 MB**：进程调优工具，不是必需品。

---

## 七、怎么用这张表

1. 打开 `program-audit-2026-10-27.xlsx`，先看「说明」页了解每列含义。
2. 「重点程序」页是**需要你决策的 56 条**（驱动和运行库已过滤掉，别浪费时间看）。每行「你的决定」列有下拉：保留 / 删除 / 待定。
3. 「垃圾与残留」页对每一处垃圾给了「建议」列，安全可删的直接勾就行。
4. 「僵尸项」页 12 条，我已在「解析」列写清每条该不该动。
5. 填完发我，我出**先 dry-run 的执行脚本**：先只打印将要做什么，你确认后再真删。程序类的一律走卸载器（`MsiExec /X` 或官方 uninstall），不手删目录。

---

## 八、风险与限制

- **体积列不全**：很多程序注册表里没有 `EstimatedSize`，尤其绿色版和游戏客户端，所以「可删 149.7 MB」远小于真实可省空间。
- **本机是精简镜像**（`MusNotification.exe` 等系统文件缺失），个别卸载器可能报错，届时按提示处理。
- **D3DSCache 删了首进游戏会卡**：这是重建着色器，不是故障。
- **删除不可逆**：脚本会先 dry-run，二次确认才执行。

---

## 九、已决策清单与执行脚本（2026-10-27 更新）

用户在对话中决定删除以下 15 项（编号对应聊天里的清单）：

| # | 程序 | 卸载方式 |
| --- | --- | --- |
| 1 | Python 3.14.5 Documentation (64-bit) | `msiexec /x {EDE01DCA-...}` |
| 2 | Python 3.14.5 Test Suite (64-bit) | `msiexec /x {F479F658-...}` |
| 3 | Microsoft Teams Meeting Add-in for Office | `msiexec /x {A7AB73A3-...}` |
| 4 | Windows 电脑健康状况检查 | `msiexec /x {84A03DEC-...}` |
| 5 | CertsUpdater 1.5 | `C:\WINDOWS\unins000.exe /SILENT` |
| 19 | 迅雷 | `D:\Thunder\Program\ThunderUninstall.exe`（会弹界面） |
| 22 | Discord | `Update.exe --uninstall -s` |
| 44 | .NET SDK 8.0.426 (x64) | `dotnet-sdk-8.0.426-win-x64.exe /uninstall /quiet` |
| 45 | .NET Toolset 8.0.426 (x64) | `msiexec /x {91A7FF58-...}` |
| 50 | .NET Targeting Pack 8.0.32 | `msiexec /x {E59CDBC8-...}` |
| 51 | .NET Standard Targeting Pack 2.1.0 | `msiexec /x {A7036CFB-...}` |
| 52 | .NET AppHost Pack 8.0.32 (x64) | `msiexec /x {9F61C99B-...}` |
| 53 | .NET AppHost Pack 8.0.32 (arm64) | `msiexec /x {C663892E-...}` |
| 54 | .NET AppHost Pack 8.0.32 (x64_x86) | `msiexec /x {24AF8A28-...}` |
| 55 | .NET 8.0 Templates 8.0.426 | `msiexec /x {DAF2FAD1-...}` |

**保留未动的相关项**（用户未选）：RTSS（#6，配合 Afterburner）、.NET **运行时** 46-49 / 56-59（游戏与工具依赖）、全部游戏、OneDrive、Chrome 等。

执行脚本：`scripts/uninstall-selected.ps1` + `scripts/uninstall-selected.cmd`

```powershell
.\scripts\uninstall-selected.cmd            # dry-run，只打印
.\scripts\uninstall-selected.cmd -Execute   # 管理员窗口中真删
```

脚本行为：默认 dry-run；`-Execute` 需管理员；MSI 的注册表项常写成 `/I`（修复安装），脚本一律改写为 `/x`；卸载前自动结束 Discord / 迅雷进程并停 `XLServicePlatform` 服务；每项执行后回查注册表确认是否移除；日志写 `.tmp\uninstall-selected.log`。

卸载后需人工确认的残留（脚本只列出体积，不自动删）：
- `D:\Thunder` 1,378 MB
- `%LOCALAPPDATA%\Discord` 464 MB
- `%LOCALAPPDATA%\Thunder Network` 260 MB
- `%APPDATA%\Thunder Network` 361 MB

### 9.1 执行结果（2026-10-27 20:05 复核）

15 项全部确认从注册表移除。卸载后**多出 17 项连带移除**，全部来自 .NET SDK bundle（它把运行时和打包组件装成了同一个包）：

```
Microsoft ASP.NET Core 8.0.32 Shared Framework (x64)     <- ASP.NET Core 运行时
Microsoft ASP.NET Core 8.0.32 Targeting Pack (x64)
Microsoft Windows Desktop Runtime - 8.0.32 (x64)         <- WPF/WinForms 运行时
Microsoft Windows Desktop Targeting Pack - 8.0.32 (x64)
Microsoft.NET.Sdk.{Android,iOS,macOS,MacCatalyst,Maui,tvOS,Aspire}.Manifest-8.0.100
Microsoft.NET.Workload.{Emscripten,Mono.Toolchain}.*.Manifest
```

**现状（`dotnet --list-runtimes`）**

```
Microsoft.NETCore.App        6.0.36
Microsoft.NETCore.App        8.0.32
Microsoft.WindowsDesktop.App 6.0.36     <- 8.0.x 桌面运行时已随之移除
```

影响面：.NET 8 的**控制台/服务程序**照常运行；.NET 8 的 **WPF/WinForms 桌面程序**会报“需要 .NET Desktop Runtime 8”。修复办法是装回 Windows Desktop Runtime 8.0.x（约 55 MB）。

Python 本体完好（`python --version` → 3.14.5），只少了文档和测试套件。

### 9.2 残留清理

| 路径 | 处理 |
| --- | --- |
| `D:\Thunder` | 卸载器已移除 |
| `%APPDATA%\Thunder Network`（361 MB） | 卸载器已移除 |
| `%LOCALAPPDATA%\Thunder Network`（260 MB） | 已手动删除 |
| `%LOCALAPPDATA%\Discord`（1.5 MB） | 已手动删除 |
| 开始菜单 `Discord Inc` 快捷方式（死链） | 已删除 |
| `%USERPROFILE%\.dotnet`（空目录） | 已删除 |

遗留待处理（需管理员）：孤儿服务键 `XLWFP`（Start=4 已禁用、驱动文件不存在），命令 `sc.exe delete XLWFP`。

磁盘：C: 可用 178.75 GB / 399 GB，D: 可用 229.51 GB / 531.2 GB。

## 十、补齐运行时与 User / Program Files 清理（第二轮）

### 10.1 装回 .NET 8 桌面运行时

用 `Start-Process -Verb RunAs` 提权安装 `windowsdesktop-runtime-8.0.32-win-x64.exe`（55.9 MB，exit=0）。装完：

```
Microsoft.NETCore.App        6.0.36
Microsoft.NETCore.App        8.0.32
Microsoft.WindowsDesktop.App 6.0.36
Microsoft.WindowsDesktop.App 8.0.32   <- 已恢复
```

ASP.NET Core 运行时仍未装（本机无 Web 服务需求，需要时再补）。

### 10.2 删除的文件（共 1.81 GB）

扫描范围：`C:\Users\WINDOWS`、`C:\Program Files`、`C:\Program Files (x86)` 一级目录，逐个用 `robocopy /L` 量体积，再用注册表（卸载记录 / 服务 ImagePath / Run / App Paths）判定是否还被引用，最后人工核实进程与服务。

| 路径 | 体积 | 依据 |
| --- | --- | --- |
| `C:\Program Files\Common Files\Adobe` | 421.1 MB | 无任何 Adobe 卸载记录，无 Adobe 进程/服务 |
| `C:\Program Files\ASUS\RLSDownload` | 302.6 MB | 奥创灯光 SDK 下载缓存（`*.zip`），可重新下载 |
| `C:\Program Files\Razer\Razer Surround Sound Setup` | 197.3 MB | 安装包缓存（`RzAppEngine_installer.exe`） |
| `C:\Program Files\Microsoft OneDrive\26.189.0928.0009\OneDriveSetup.exe` | 128.4 MB | OneDrive 自带安装包，可重新下载 |
| `C:\Program Files\Adobe` | 86.9 MB | Creative Cloud Experience 残留 |
| `C:\Program Files (x86)\Epic Games\Epic Online Services\.egstore\old.ver` | 77.5 MB | EOS 旧版本回滚副本 |
| `C:\Program Files (x86)\Epic Games\Epic Online Services\.egstore\rollback` | 75.3 MB | EOS 回滚副本 |
| `C:\Program Files (x86)\Microsoft\EdgeUpdate\Download\*` | 53.6 MB | Edge 更新下载缓存 |
| `C:\Program Files (x86)\Adobe` | 37.1 MB | Adobe Sync / CoreSync 残留 |
| `C:\Program Files\Razer\RazerAppEngine Upgrade Setup` | 17.8 MB | 升级包缓存 |
| 其余 Razer `* Setup` / `Upgrade` 目录 | 1.2 MB | 安装包缓存 |
| `C:\Users\WINDOWS\PycharmProjects\PythonProject\.venv` | 307.0 MB | PyCharm 已卸载，虚拟环境随之作废 |
| `C:\Users\WINDOWS\PyCharmMiscProject\.venv` | 10.5 MB | 同上 |
| 工作区 `.tmp\MinGit.zip` + 运行时安装包 | 93.9 MB | 已用完的临时文件 |

保留（有依据）：

- `C:\Program Files\Razer\RzAppEngine` 379.7 MB —— `rzappengine.exe` 正在运行，属 Synapse 3 引擎
- `C:\Program Files (x86)\ASUS\ArmouryDevice` 523.4 MB —— `asus_framework.exe` 正在运行
- `C:\Program Files\Razer\RazerAppEngine` 462.3 MB —— Synapse 4 引擎，正在运行
- `C:\Program Files (x86)\SogouInput` 982.4 MB —— `SogouImeBroker.exe` / `SogouCloud.exe` 在跑，是现役输入法
- `C:\Users\WINDOWS\.trae-cn` 357.7 MB —— TRAE CN 已安装，属其数据目录
- `C:\Program Files (x86)\InstallShield Installation Information` 196.5 MB —— 卸载/修复要用
- `C:\Program Files\Windows Defender Advanced Threat Protection` 253.5 MB —— 系统组件

### 10.3 未处理的大件（需要你决定）

| 路径 | 体积 | 说明 |
| --- | --- | --- |
| `C:\Users\WINDOWS\xwechat_files` | 61,179.7 MB | 微信（Weixin，装在 `D:\Weixin`）的聊天文件。三个账号目录：`wxid_8c2ghxyvifod21_16ac` 58.5 GB / `wxid_a77ebpwhln7y22_3641` 2.6 GB / `wxid_g3cxrybujmt722_7520` 60.7 MB。**含聊天记录与接收的文件，不能盲删** |
| `C:\Program Files (x86)\Interhaptics` | 338.5 MB | Razer 触觉反馈组件，有 `Uninstall.exe` 但无卸载记录（疑似残留） |
| `C:\Program Files\Reference Assemblies` + `(x86)` | 76.7 MB | .NET Framework 参考程序集，随 SDK 装进来，现已无 SDK |
| `C:\Users\WINDOWS\Documents` | 3,042.2 MB | 个人文档，不动 |
| `C:\Users\WINDOWS\Desktop` | 660.2 MB | 含 4 个 80–90 MB 的 zip（学校资料），不动 |

### 10.4 结果

```
C:  可用 180.3 GB / 399 GB   （清理前 178.75）
D:  可用 229.5 GB / 531.2 GB
```

服务与进程复核：Razer Chroma/Stream/Elevation、ArmouryCrateService、AsusCertService、AsusFanControlService、OneDrive 全部仍在运行；RazerAppEngine.exe 与 rzappengine.exe 均存活。
