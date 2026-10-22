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

## 已安装（前五名，2026-10-23 00:05）

桌面 profile `C:\Users\WINDOWS\.dsh\profiles\desktop`，`dsh.profile.bundles` 顺序：

```
dsh-base → dsh-web-app → dshmarket → dsh-whale-widget → billion-context → dsh-better-sidebar → dsh-context
```

| 包 | 版本 | 周下载 | patch 插入的条目 |
| --- | --- | --- | --- |
| `billion-context` | 0.1.204 | 650,111 | `bili-native`、`bili-compaction-gate`＋改写 `compaction-basic` / `preset-*` / `llm-deepseek` |
| `dshmarket` | 1.67.0 | 163,589 | `dsh-market` |
| `dsh-whale-widget` | 0.4.2 | 55,568 | `dsh-whale-widget` |
| `dsh-better-sidebar` | 0.28.0 | 49,719 | `better-sidebar` |
| `dsh-context` | 0.74.0 | 43,362 | `dsh-context` |

安装方式：`pnpm add <pkg>@<ver> --save-exact` 在 profile 目录执行，再把包名追加到 `dsh.profile.bundles`。
dshmarket 那批 5 个包用了 30.9 秒；后三个（含 better-sidebar 的 codemirror 全家桶）装了约 3 分钟，node_modules 约 251 MB。

### 需要知道的副作用

`billion-context` 不是纯增量插件，它的 patch 会**改写核心行为**：

- 关闭宿主层的 `compaction-basic`（`auto: false`），改由自己的 `bili-compaction-gate` 接管压缩；
- 给 4 个 preset（standard / ptc / minimal / cordis）各注入 `biliBasicCompactionPolicy`；
- 重写 `llm-deepseek` 与 `llm-deepseek-account` 的 `retryPolicy`，把 `MALFORMED_RESPONSE` 加进重试白名单。

另外 `billion-context` 和 `dsh-context` 都在管上下文/压缩，职责有重叠；如果重启后出现压缩异常或会话创建卡住，
**第一个要摘掉的就是 `billion-context`**（它的 patch 也写了：出问题要从 `dsh.profile.bundles` 里删它，而不是只禁用某个条目）。

### 回滚

- 第二份备份：`.tmp/profile-backup-20261022-235425/`（package.json / pnpm-lock.yaml / pnpm-workspace.yaml / cordis.patch.yml）；
- 第一份备份：`.tmp/profile-backup-20261022-232944/`；
- 只摘一个：从 `dsh.profile.bundles` 删名字 + `pnpm remove <pkg>`。

**要重启 DSH 才生效**——bundle 列表只在组合阶段读取。
