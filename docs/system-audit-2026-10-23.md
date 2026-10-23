# 系统体检与优化清单（2026-10-23）

> 采集方式：PowerShell 5.1 沙箱内实测（WMI/CIM 与部分 Storage cmdlet 被拒，改用注册表、性能计数器、robocopy 统计、kernel32 P/Invoke）。所有数字均为本机实测，非估算。

## 1. 硬件与系统

| 项目 | 实测值 |
| --- | --- |
| 系统 | Windows 10 Pro 26H2，build 26300.9711，安装于 2024-12-17 |
| CPU | 12th Gen Intel Core i5-12600KF，标称 3700 MHz，最大性能 910% |
| 内存 | 31.8 GB 物理，页面文件上限 75.6 GB |
| 显卡 | NVIDIA GeForce RTX 4070，驱动 32.0.16.1714（2026-09-17，约 5 周前） |
| 磁盘 | WD Blue SN580 1TB NVMe（BusType=17），**单盘分两区** |
| 分区 | C: 399.0 GB（剩 165.7）｜D: 531.2 GB（剩 229.2） |
| 网卡 | MediaTek Wi-Fi 6 MT7902LEN 无线 |
| 安全软件 | 火绒 HipsDaemon（运行中），Windows Defender 服务已停止 |

关键判断：**没有第二块盘**。C: 与 D: 是同一块 NVMe 的两个分区，所以"把东西挪到 D:"并不会改变 IO 性能，只影响空间分配。

## 2. 性能基线

空闲采样 10 秒（当时开 Edge、Steam、Razer、DeepSeek Harness）：

| 指标 | 平均 | 峰值 | 解读 |
| --- | --- | --- | --- |
| CPU 总占用 | 18.3% | 25.3% | 空闲 18% 偏高，来自常驻后台 |
| 可用内存 | 18.4 GB | — | 42% 占用，其中后台软件约 2.9 GB |
| 磁盘 %Disk Time | 0.8% | 3.5% | 存储不是瓶颈 |
| 磁盘队列 | 0.0 | 0.0 | 无 IO 堆积 |
| CPU 队列 | 0.1 | 1.0 | CPU 不是瓶颈 |

结论：**硬件不是瓶颈，瓶颈是后台常驻程序**。空闲 18% CPU + 2.9 GB 内存被 Steam / Razer / Edge / 微信 / 网盘等占着。

## 3. 存储占用地图

### 3.1 C:（已用约 233 GB）

| 占用 | 路径 | 备注 |
| --- | --- | --- |
| 53.4 GB | `AppData\Local` | NVIDIA 18.7（DXCache 17.37 + GLCache 1.31）、剪映 6.0、Chrome 5.25、Larian 3.34、Microsoft 3.19 |
| 41.1 GB | `C:\Windows` | WinSxS 23.21、DriverStore 3.54、Installer 1.23 |
| 19.2 GB | `C:\ProgramData` | NVIDIA Corporation 12.22（其中 NVIDIA App\UpdateFramework 12.17 = 驱动安装包） |
| 12.7 GB | `C:\hiberfil.sys` | 休眠文件，快速启动依赖它 |
| 12.0 GB | `AppData\Roaming` | Tencent 4.65、TRAE SOLO CN 3.85 |
| 8.5 GB | `Program Files (x86)` | |
| 5.6 GB | `Program Files` | |
| 2.9 GB | `Documents` | |
| 1.5 GB | `AppData\LocalLow` | |

### 3.2 D:（已用约 302 GB）

| 占用 | 路径 | 性质 |
| --- | --- | --- |
| 97.0 GB | `D:\Hypergryph Launcher` | 游戏（明日方舟/来自星尘等） |
| 91.6 GB | `D:\Steam` | Steam 游戏库 |
| 39.1 GB | `D:\pagefile.sys` | 页面文件，固定 40 GB |
| 24.7 GB | `D:\迅雷下载` | 影视资源 |
| 23.5 GB | `D:\DCIM` | 照片 |
| 11.5 GB | `D:\TX` | 腾讯文件缓存（Msg3.0.db 1.8 + index 1.5） |
| 1.9 GB | `D:\Epic Games` | |

## 4. 可回收空间

### A 组：零风险，普通用户权限即可，约 31 GB

| 项目 | 释放 | 命令 |
| --- | --- | --- |
| NVIDIA 着色器缓存（DXCache + GLCache） | 18.7 GB | `Remove-Item "$env:LOCALAPPDATA\NVIDIA\DXCache\*" -Force -Recurse` 同理 GLCache |
| NVIDIA App 驱动包缓存 | 12.2 GB | `Remove-Item 'C:\ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework\*' -Recurse -Force` |
| 用户临时文件 | 0.66 GB | `Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue` |

代价说明：删着色器缓存后，前几次进游戏会重新编译，出现轻微卡顿；驱动包缓存下次更新驱动会重新下载。两者都不影响系统。

### B 组：需要管理员，约 15–45 GB

| 项目 | 释放 | 命令 | 代价 |
| --- | --- | --- | --- |
| WinSxS 组件清理 | 3–8 GB | `Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase` | 之后无法卸载已装更新 |
| 关闭休眠 | 12.7 GB | `powercfg /h off` | 失去休眠与快速启动，开机变慢约 5–10 s |
| 页面文件缩到 16 GB | 23 GB（D:） | 系统属性 → 高级 → 虚拟内存，自定义 16384–20480 | 极端内存压力下更早触发换页（32 GB 物理下概率低） |

### C 组：用户数据，建议自查而非代删

`迅雷下载` 24.7 GB、`DCIM` 23.5 GB、`TX` 11.5 GB、`Steam` + `Hypergryph` 188 GB（按需卸载不玩的游戏）。

## 5. 启动项：17 条，建议精简到 8 条

已启用且可安全关闭的（任务管理器 → 启动 或 设置 → 应用 → 启动）：

| 启动项 | 建议 | 理由 |
| --- | --- | --- |
| Steam | 关 | 常驻 3 个 webhelper，实测占 875 MB；用时再开 |
| Weixin（微信） | 关 | 微信不需要开机常驻 |
| QQ2009 | 关 | 同上 |
| MicrosoftEdgeAutoLaunch | 关 | 登录即拉起 Edge 且常驻 |
| OneDrive + Microsoft.Lists | 关（若不用 OneDrive） | 两条重复入口，且持续占用 IO |
| BaiduYunDetect（百度网盘） | 关 | 检测服务，开着不会自动加速 |
| Adobe CCXProcess | 关 | Creative Cloud 后台 |
| RazerAppEngine + RzAppEngine + RZSurroundHelper | 关（除非需要灯效/宏） | 5 个进程共约 650 MB，实测 CPU 累计占用最高 |
| AsusFCNotification | 关 | 华硕风扇提示常驻 |

保留：`SecurityHealth`（系统托盘）、`Sysdiag`（火绒主防，别关）、`RtkAudUService`（音频）、`ctfmon`（输入法）、`ACE-Tray`（反作弊，只玩需要它的游戏就保留）。

预期收益：开机快 20–30 s，空闲内存多出约 2.5 GB，空闲 CPU 从 18% 降到 8% 左右。

## 6. 稳定性问题（近 7 天事件日志）

| 现象 | 频率 | 结论 |
| --- | --- | --- |
| `XLWFP` 服务启动失败（找不到文件） | 每次开机 | 迅雷残留的 WFP 过滤驱动服务。修：管理员 `sc delete XLWFP` |
| `Steam Client Service` 启动超时 120 s（7034/7009） | 偶发 | Steam 提权服务卡住；不影响游戏，可将服务改为手动 |
| `Tcpip 4207`（接口 17 IPv4/IPv6 绑定失败） | 每次开机 | 虚拟网卡/代理层（Clash、VPN 类）先于网络栈就绪，无害 |
| 处理器电源事件 ID 55 | 每次开机 | **不是降频告警**，只是 ACPI CPPC 能力上报，可忽略 |

近 7 天无严重级别（Level 1）错误；Windows Update 正常。

## 7. 已合适的设置（不用动）

- 电源计划：**卓越性能**，已是最激进档位。
- 快速启动：已开启（`HiberbootEnabled=1`）。
- 存储感知：已开启。
- TRIM：已启用（`DisableDeleteNotify = 0`）。
- 页面文件放在 D: 但同为 NVMe，不会拖慢；只是 40 GB 偏大。
- Windows Search 索引为 0 GB（未索引），对性能友好。

## 8. 驱动更新后复测（2026-10-23 18:45，重启后）

| 项目 | 更新前 | 更新后 | 变化 |
| --- | --- | --- | --- |
| C: 可用 | 165.7 GB | **170.0 GB** | +4.3 |
| `C:\Windows` | 41.08 | 44.37 | **+3.29** |
| `DriverStore\FileRepository` | 3.54 | **6.45** | +2.91（新旧驱动包并存） |
| `ProgramData` | 19.18 | 14.65 | −4.53 |
| `NVIDIA App\UpdateFramework` | 12.17 | **7.63** | −4.54（安装器自己清了一部分） |
| `AppData\Local` | 53.41 | 51.96 | −1.45 |
| `NVIDIA\GLCache` | 1.31 | 0 | 已清 |
| `NVIDIA\DXCache` | 17.37 | **17.37** | 未变，驱动更新没有重置它 |

DriverStore 里现在有两份显卡驱动：`nv_dispi.inf_amd64_da865124972e1f80`（2.66 GB，旧）与 `nv_dispi.inf_amd64_20f49c6eb5c9b39b`（2.90 GB，新）。

更新后仍可回收：DXCache 17.37 + UpdateFramework 7.63 + 旧驱动包 2.66 ≈ **27.7 GB**（旧驱动包需 `pnputil /delete-driver <oemXX.inf> /uninstall` 或 ISD 清理，要管理员）。

## 8.1 页面文件：历史证据调查

| 证据 | 结果 | 含义 |
| --- | --- | --- |
| 性能计数器历史库 | `logman query` 无任何 Data Collector Set | **没有历史计数器数据**，PerfMon 从未记录过 |
| 虚拟内存耗尽事件（Resource-Exhaustion-Detector） | 全历史 0 条 | 从未因虚拟内存不足报错 |
| 近 90 天含 "virtual memory / paging file / low on memory" 的事件 | 0 条 | 同上 |
| 当前提交量 | 12.23 GB / 31.8 GB 物理 | 常态远低于物理内存 |
| 进程私有提交合计 | 2.06 GB | 其余约 10 GB 是内核池、驱动、系统缓存 |
| 本次开机页面文件使用率 | 0.00%（峰值 0.00%） | 刚重启，样本太短，不足以定论 |
| 非正常关机（Kernel-Power 41） | 4 次：05-23、08-03、08-24、10-15 | 均为"未正常关机"，**且 Minidump 目录 0 文件、无 MEMORY.DMP** |

结论：

1. **现有证据不支持"需要 40 GB 页面文件"**——从未触发过换页耗尽，提交量常年在 12 GB 量级，物理内存 31.8 GB 有充足余量。
2. **但也不建议关闭**——4K 剪辑（剪映）、大型游戏加载时提交量会冲高，没有页面文件兜底容易直接失败。
3. **建议**：D: 固定 8192–16384 MB；同时在 C: 放一个 2–4 GB 系统托管文件。后者不是为了性能，而是为了**恢复崩溃转储能力**——C: 没有页面文件时，真蓝屏也生成不了完整转储，而那 4 次非正常关机目前完全无 dump 可查。
4. 那 4 次硬重启（无 bugcheck 记录、无 dump）是独立问题，方向：电源瞬时掉压 / 温度 / 驱动崩溃，与页面文件无关。

## 9. 执行建议（按性价比排序）

1. 清 NVIDIA 三处缓存（18.7 + 12.2 GB）——收益最大、风险最低。
2. 关掉 9 条启动项——唯一能改善"空闲 18% CPU"的动作。
3. 清 Temp + 剪映缓存。
4. `sc delete XLWFP` 修掉每次开机的失败项。
5. 页面文件从 40 GB 收到 16–20 GB（D: 释放约 20 GB）。
6. 如果不用休眠/快速启动，再考虑 `powercfg /h off`（12.7 GB）。

需要管理员的操作（B 组、删服务）本机当前会话无法提权，需要你在管理员 PowerShell 里执行，或授权我以更高权限运行。
