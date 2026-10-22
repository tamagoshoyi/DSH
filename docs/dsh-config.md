# DSH 配置现状

## 配置文件在哪

| 层 | 路径 | 作用 |
| --- | --- | --- |
| 全局人格 | `%DSH_HOME%\AGENTS.md` | 所有会话继承的人格与行动模式 |
| 项目规则 | `<项目根>\AGENTS.md` | 项目级约定，优先级高于全局 |
| Profile 补丁 | `%DSH_PROFILE_DIR%\cordis.patch.yml` | 模型、UI、插件等加载项配置 |
| 凭据 | `%DSH_HOME%\.credentials.yaml` | 账号凭据，勿外传 |

当前 `%DSH_HOME%` = `C:\Users\WINDOWS\.dsh`，`%DSH_PROFILE_DIR%` = `C:\Users\WINDOWS\.dsh\profiles\desktop`。

## 已生效的配置

来自 `cordis.patch.yml`：

```yaml
- id: agent-default-model
  config: { provider: deepseek-account, model: deepseek-flash, reasoningEffort: high }
- id: ui-settings-account   # 引导流程已标记完成
- id: ui-chat               # transcriptView / performanceUsage = detailed
- id: ui-settings           # enabled: true
```

即：默认模型 `deepseek-flash`，推理强度 `high`，界面显示详细的用量与过程信息。

## 人格是怎么生效的（已验证）

`@deepseek-ai/dsh-agent-instructions` 在**第一次请求**时加载指令链：

1. 全局链：`%DSH_HOME%\AGENTS.md` → `<agentsHome>\AGENTS.md`
2. 项目链：从项目根到当前工作目录，逐级的 `AGENTS.md` / `CLAUDE.md`（内容重复的只渲染一次）

实测：写入文件后，**下一次请求**就带上了指令（无需重启）。深度目录中的文件在首次读取该目录后追加。

因此想改人格/行为，改 `AGENTS.md` 即可，不必碰 profile。

## 权限与沙箱

- 文件策略：`workspace-write` —— 工作区内随意读写，工作区外需授权。
- 审批策略：`ask` —— 越界操作会弹审批，不会静默失败。
- 本次初始化中，写 `%DSH_HOME%\AGENTS.md` 走了一次授权，其余文件都在工作区内完成。

## 怎么改

- **改人格/行为**：编辑 `%DSH_HOME%\AGENTS.md`（全局）或项目 `AGENTS.md`，下一次请求生效。
- **改模型/界面**：编辑 `cordis.patch.yml`，重启 DSH 生效。
- **加插件/服务**：同样走 `cordis.patch.yml` 的 patch 条目（`id` + `name` + `config`），改完重启。
- **改权限策略**：在 DSH 设置或启动参数里调整，不要在项目里硬编码绕过。
