# 大文件扫描报告（2026-10-23）

## 扫描方法与覆盖

- 脚本 `.tmp/bigfiles.ps1`：C# 递归枚举（跳过 reparse point），阈值 **1 GB**，覆盖 `C:\` 与 `D:\`。
- 共遍历 **914,823 个文件**，无权限跳过 742 个，耗时 2.6 分钟。
- 命中 **62 个 ≥1GB 文件，合计 200.14 GB**。
- 目录级体积用 `robocopy /L /BYTES` 汇总补充。

当前磁盘：C: 已用约 201 GB / 399 GB，D: 已用约 302 GB / 531 GB，合计约 503 GB。

## 一、按类别归总

| 类别 | 体积 | 位置 | 说明 |
| --- | ---: | --- | --- |
| 游戏 | **152.9 GB** | `D:\Hypergryph Launcher\games\Endfield Game` 70.79<br>`D:\Steam\steamapps\common` 82.09 | 明日方舟终末地 + Steam 库 |
| 系统文件 | **56.5 GB** | `D:\pagefile.sys` 39.06<br>`C:\hiberfil.sys` 12.73<br>`C:\pagefile.sys` 4.75 | 页面文件 / 休眠文件 |
| 迅雷下载 | **24.7 GB** | `D:\迅雷下载` | 影视资源 |
| QQ 数据 | **11.5 GB** | `D:\TX` | 聊天数据库 + 群文件 |
| Chrome 端侧模型 | **4.0 GB** | `AppData\Local\Google\Chrome\User Data\OptGuideOnDeviceModel` | Gemini Nano 权重 |
| ASUS 诊断日志 | **2.2 GB** | `C:\ProgramData\ASUS\ARMOURY CRATE Diagnosis\AsusLog` | 单个 `RF_RSSITool.log` 就有 1.84 GB |

## 二、最大的 12 个单文件

| 大小 | 路径 |
| ---: | --- |
| 39.06 GB | `D:\pagefile.sys` |
| 22.85 GB | `D:\Steam\steamapps\common\Gray Zone Warfare\GZW\Content\Paks\GZW-WindowsClient.ucas` |
| 17.71 GB | `D:\Steam\steamapps\common\The Invincible\TheInvincible\Content\Paks\pakchunk1-WindowsNoEditor.pak` |
| 12.73 GB | `C:\hiberfil.sys` |
| 10.65 GB | `D:\迅雷下载\...\Carry-On.2024.2160p.NF.WEB-DL.H265.DDP5.1.Atmos-SONYHD.mkv` |
| 6.46 GB | `D:\Steam\steamapps\common\Menace\Menace_Data\resources.assets.resS` |
| 5.22 GB | `D:\Steam\steamapps\common\The Invincible\...\pakchunk0-WindowsNoEditor.pak` |
| 5.07 GB | 同上 `pakchunk7` |
| 4.75 GB | `C:\pagefile.sys`（配置里 C 盘是「无分页文件」，这是 Windows 开机自建的临时页面文件） |
| 3.98 GB | `Chrome\User Data\OptGuideOnDeviceModel\2025.8.8.1141\weights.bin` |
| 3.50 GB | 同上 `pakchunk8` |
| 3.17 GB | `D:\TX\1032477536\FileRecv\暴食的怪兽公主.zip` |

## 三、Steam 游戏明细

| 体积 | 游戏 | 判断 |
| ---: | --- | --- |
| 38.80 GB | The Invincible（无敌号） | 单机剧情向，通关后可卸 |
| 25.72 GB | Gray Zone Warfare | 在线射击，赛季制 |
| 11.15 GB | Menace | 抢先体验，内容还会长 |
| 4.61 GB | Mount & Blade Warband | 老游戏，体积小 |
| 1.15 GB | Barotrauma | 同上 |

`D:\Steam\steamapps\downloading` 与 `shadercache` 均为 0，没有下载残留。

## 四、可回收空间（按风险从低到高）

| 操作 | 可释放 | 风险 |
| --- | ---: | --- |
| 删 `C:\ProgramData\ASUS\...\AsusLog` 日志 | 2.2 GB | 无，Armoury Crate 会自己重建目录 |
| 删 Chrome `OptGuideOnDeviceModel` | 4.0 GB | 无影响，Chrome 需要时会重新下载；可在 `chrome://flags` 关掉优化指南模型避免重下 |
| 删 `D:\迅雷下载` 里看完的影视 | 24.7 GB | 无，只是要重新下载 |
| 清 `D:\TX` 群文件缓存（保留 Msg3.0.db 则只能省 3.2 GB） | 3.2–11.5 GB | 删 `.db` 会丢聊天记录 |
| 关休眠 `powercfg /h off` | 12.7 GB | 失去休眠与快速启动 |
| 页面文件从 40 GB 缩到 8–16 GB | 23–32 GB | 需确认不再出现内核崩溃转储需求 |
| 卸载 The Invincible | 38.8 GB | 存档在 `%USERPROFILE%\AppData` 或游戏目录，需先备份 |

低风险三项合计 **约 31 GB**（ASUS 日志 + Chrome 模型 + 迅雷影视）；
加系统项总计可到 **约 65–75 GB**。
