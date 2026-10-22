# default-workspace

DeepSeek Harness 桌面版的默认工作区：放临时实验、脚本、文档和一次性任务。

## 快速开始

本机执行策略禁止直接跑 `.ps1`，二选一：

```powershell
# 方式一：在当前会话载入 node / pnpm，后续命令可直接用
powershell -NoProfile -NoExit -ExecutionPolicy Bypass -Command ". .\scripts\env.ps1"

# 方式二：双击或用 .cmd 包装器
.\scripts\env.cmd
```

环境体检：

```powershell
.\scripts\check.cmd
```

## 结构

```
AGENTS.md            项目规则（Agent 首次请求时自动加载）
README.md            本文件
docs/
  environment.md     环境体检记录与 git 缺失说明
  dsh-config.md      DSH 配置现状与修改方式
  plugins-shortlist.md  社区插件榜（按周下载）+ 已安装记录
scripts/
  env.ps1 / env.cmd     注入内置 node / pnpm
  check.ps1 / check.cmd 环境体检，缺失必需项时退出码 1
  fetch.mjs             用 Node 的 TLS 栈下载文件（本机 schannel 不可用）
src/                 可复用代码
tests/               测试
.tools/              便携工具链（gitignore）
.tmp/                一次性产物（gitignore）
```

## 环境现状

| 工具 | 状态 |
| --- | --- |
| node | v24.21.0（DSH 内置，经 `env.ps1` 注入） |
| pnpm | 11.28.5（DSH 内置，经 `env.ps1` 注入） |
| python | 3.14.5（系统安装，已在 PATH） |
| git | 2.56.0.windows.2（便携版 `.tools\git`，经 `env.ps1` 注入） |

网络限制（schannel 不可用、走 Node 下载）与 git 便携版细节见 [docs/environment.md](docs/environment.md)。

## 已完成的初始化

- [x] 全局人格与行动模式：`%DSH_HOME%\AGENTS.md`（所有会话生效）
- [x] 项目规则：`AGENTS.md`（本工作区生效）
- [x] 目录骨架 + `.gitignore` + `.gitattributes`
- [x] 工具链入口：`scripts/env.ps1`（实测 node / pnpm / git 可用）
- [x] 环境体检脚本：`scripts/check.ps1` / `check.cmd`（实测退出码 0）
- [x] DSH 配置梳理：`docs/dsh-config.md`
- [x] 插件：周下载前五（billion-context / dshmarket / dsh-whale-widget / dsh-better-sidebar / dsh-context）装入桌面 profile（重启后生效）
- [x] git 便携版：MinGit 2.56 装入 `.tools\git`（经 TUNA 镜像下载，见 `docs/environment.md`）
- [x] `git init` 建仓（分支 `main`，13 个文件已 stage）
- [x] SSH 密钥：`.tools\ssh\id_ed25519`（Windows OpenSSH，公钥见 `id_ed25519_pub.txt`）
- [x] 首次 commit：作者 tamagoshoyi &lt;tamagoshoyi@gmail.com&gt;
- [ ] 添加远端并 push（等 GitHub 空仓库地址）