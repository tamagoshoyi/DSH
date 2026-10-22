# 社区插件榜（按 npm 周下载量）

采集时间：2026-10-22 23:0x（Asia/Shanghai）

## 数据来源与口径

- 候选集：社区维护的插件索引 [REALOIYO/dsh-plugin-market](https://github.com/REALOIYO/dsh-plugin-market) —— 7,275 个声明了 `dsh.bundle` 的 npm 包，其中 6,628 个带热度指标；
- 排序口径：**npm 官方 API 的最近一周下载量**（不采信索引自带的 star 数字，已发现明显异常值，例如多个包共用 257,706 这个数）；
- 交叉校验：逐个重新请求 `registry.npmjs.org` 与 `api.npmjs.org`，确认包存在、确实是 `dsh.bundle`、取到当前版本与描述。

## 榜单

| # | 包 | 周下载 | Stars | 用途 |
| --- | --- | --- | --- | --- |
| 1 | `billion-context` | 650,111 | 2,243 | 上下文压缩：小窗口也能跑长任务，号称省 5 倍 token |
| 2 | `dshmarket` | 163,589 | 7,743 | 装进 DSH 的图形化插件市场：浏览、搜索、一键装 |
| 3 | `dsh-whale-widget` | 55,568 | 0 | 右下角小鲸鱼挂件：余额、今日用量、峰谷价、点击彩蛋 |
| 4 | `dsh-better-sidebar` | 49,719 | 4,356 | 加强侧栏：文件树、编辑器、变更、任务、侧聊合一 |
| 5 | `dsh-context` | 43,362 | 2,481 | 上下文洞察与管理：仪表盘 + 上下文压缩 |
| 6 | `dsh-workbuddy-connect` | 28,594 | 1,567 | 把 WorkBuddy 桌面端的模型接进 DSH |
| 7 | `dsh-pet` | 28,181 | 3,063 | 桌面宠物（蓝胖子鱼），会跟着会话状态动 |
| 8 | `dsh-cost-meter` | 25,952 | 476 | 会话/当日费用统计，内置 170+ 模型价格表 |
| 9 | `dsh-plugin-wallpaper-engine` | 19,419 | 1,716 | 用 Wallpaper Engine 壁纸做 GUI 背景 |
| 10 | `dsh-ops` | 16,592 | 3,657 | Windows x64 / Linux / macOS 上的原生文件与 PTC 工具 |

功能性候选（未进前十，但值得看）：

| 包 | 周下载 | 用途 |
| --- | --- | --- |
| `cc-safety-net` | 14,786 | 拦截破坏性命令与密钥文件访问的 hooks |
| `dsh-free-search` | 14,286 | 免 key 的联网搜索，聚合 27 个引擎 |
| `dsh-mnemon` | 13,637 | 可组合的上下文来源与策略 |
| `dsh-univer-office` | 9,128 | 表格/文档的内联预览与协同 |

## 风险提示

这些是**第三方**包，装进 DSH 后与 agent 同权限运行：能读文件、发网络请求、注册工具。判断标准建议：

1. 看仓库是否有源码、star 是否真实、最近是否还在更新；
2. 涉及密钥/网络/命令执行的（如 `cc-safety-net`、`dsh-free-search`）优先看源码再装；
3. 不要在生产 profile 里一次装一堆，先装一个、跑几天。

## 装法

DSH 的插件挂在 profile 上，两条路：Web 侧边栏的 Plugins 页（官方路径，自带安装与回滚），
或者文件层——profile 的 `package.json` 依赖 + `dsh.profile.bundles` 列表，重启生效。
本次走的是文件层，实测可行，步骤见下一节。

## 已安装（2026-10-22 23:40）

安装到桌面 profile `C:\Users\WINDOWS\.dsh\profiles\desktop`：

| 包 | 版本 | 周下载 | bundle patch |
| --- | --- | --- | --- |
| `dshmarket` | 1.67.0 | 163,589 | `- id: dsh-market` |
| `dsh-whale-widget` | 0.4.2 | 55,568 | `- id: dsh-whale-widget` |

命令：`pnpm add dshmarket@1.67.0 dsh-whale-widget@0.4.2 --save-exact`（30.9 秒，5 个包），
然后把两个名字追加到 `package.json` 的 `dsh.profile.bundles`。

**需要重启 DSH 才会加载**——bundle 列表只在组合（composition）阶段读取。

回滚：删掉 backup 目录里的那份 `package.json` 覆盖回去，再在 profile 目录 `pnpm install`，
或直接 `pnpm remove dshmarket dsh-whale-widget` 并从 bundles 里删两行。

备份：`.tmp/profile-backup-20261022-232944/`（package.json / pnpm-workspace.yaml / cordis.patch.yml）。

风险：这两个包都以 agent 权限在进程内运行；`dshmarket` 还能继续装别的插件，等于把安装权也交给它。已核验：包来自 npm 官方源、有源码仓库、声明的 patch 只插入自己的条目。
