# 环境体检记录

采集时间：2026-10-22（Asia/Shanghai，VPN 已开启）
采集方式：`.\scripts\check.cmd` + 逐项探测

## 结果

| 工具 | 版本 | 来源 | 状态 |
| --- | --- | --- | --- |
| node | v24.21.0 | DSH 内置运行时 | 可用（经 `scripts/env.ps1` 注入） |
| pnpm | 11.28.5 | DSH 内置运行时 | 可用（经 `scripts/env.ps1` 注入） |
| git | 2.56.0.windows.2 | 便携版 `.tools\git`（MinGit） | 可用（经 `scripts/env.ps1` 注入） |
| python | 3.14.5 | 系统安装 | 可用 |

内置运行时实际路径：

```
%DSH_HOME%\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe
%DSH_HOME%\dsh-runtimes\dsh-primary-runtime\dependencies\pnpm\bin\pnpm.mjs
```

## 为什么用注入而不是装到系统

内置 Node/pnpm 已够用，重装只会让两套版本打架；便携 git 同理，不写注册表、不改系统 PATH，删目录即卸载。

不动系统环境变量的两个额外原因：

1. 写用户级环境变量在工作区之外，受沙箱限制，需要额外授权；
2. 系统 PATH 是全局副作用，升级/卸载后容易留下死路径。

## 网络：schannel 不可用，改用 Node 的 TLS 栈

现象（VPN 开启后仍然）：

```text
curl https://github.com  → curl: (35) schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS
Invoke-WebRequest        → 基础连接已经关闭: 接收时发生错误
```

排查结论：

- DNS 与 TCP 443 正常（`Test-NetConnection github.com -Port 443` 为 True）；
- 系统代理指向 VPN 本地端口 `127.0.0.1:7078`，WinHTTP 未设代理；
- `curl -x http://127.0.0.1:7078` 能拿到 `HTTP/1.1 200 Connection established`，说明隧道通了，**失败发生在 TLS 握手阶段**——沙箱进程拿不到 schannel 凭据；
- 同样的地址用内置 **Node（OpenSSL）请求成功**（GitHub API 返回 200）。

因此本机访问 HTTPS 的统一走法：`node scripts/fetch.mjs <url> <输出路径>`。

速度实测（40 MB 的 MinGit）：

| 源 | 速度 |
| --- | --- |
| GitHub 直连 | ~16 KB/s（约 40 分钟，已放弃） |
| 清华 TUNA 镜像 | ~2.3 MB/s（约 17 秒） |

故 git 从 TUNA 镜像取得：`https://mirrors.tuna.tsinghua.edu.cn/github-release/git-for-windows/git/LatestRelease/MinGit-<ver>-64-bit.zip`

### git 要能连 GitHub，需要两个条件同时满足

1. **TLS 后端换成 OpenSSL**：MinGit 的 git 默认也用 schannel，会撞上同样的 `SEC_E_NO_CREDENTIALS`。
   仓库级已配置 `http.sslBackend=openssl`（`git config http.sslBackend openssl`）。
2. **走 VPN 的本地代理**：直连 `github.com:443` 会 21 秒后 `curl 28` 超时；加上
   `http.proxy=http://127.0.0.1:7078` 立刻通。

`scripts/env.ps1` 会从注册表 `HKCU:\...\Internet Settings` 实时读取代理并导出
`HTTP_PROXY` / `HTTPS_PROXY`（大小写各一份）和 `DSH_PROXY`，所以 VPN 开着时 git 自动走代理，VPN 关掉也不会留脏值。

实测：`git ls-remote https://github.com/git/git HEAD` 通过代理约 13–15 秒返回，直连必失败。

如果哪天代理端口变了，不用改脚本——改 Windows 的 Internet 代理设置即可。

### SSH 到 GitHub：用 Windows 自带的 OpenSSH

MinGit 里也带 `usr\bin\ssh.exe`，但它在沙箱里跑不起来：

```text
ssh.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
```

（MSYS/Cygwin 运行时需要创建命名管道，被沙箱拒绝。）

改用系统自带的 `C:\WINDOWS\System32\OpenSSH\ssh.exe`（OpenSSH_for_Windows_9.5p2），握手正常。
相关文件都放在 `.tools\ssh\`：

| 文件 | 说明 |
| --- | --- |
| `id_ed25519` | 私钥（ed25519，无口令；`.tools/` 已 gitignore） |
| `id_ed25519_pub.txt` | 公钥，粘到 GitHub → Settings → SSH and GPG keys |
| `known_hosts` | 主机指纹，避免写 `~/.ssh`（工作区外） |

坑：`ssh-keygen` 生成密钥时写 `.pub` 会被拒绝（`Bad file descriptor` / 访问被拒绝），
所以公钥是用 `ssh-keygen -y -f id_ed25519` 导出后另存为 `id_ed25519_pub.txt`。

git 侧的连接命令已写入仓库配置：

```text
core.sshCommand = C:/WINDOWS/System32/OpenSSH/ssh.exe
```

只写一个路径、不带参数是有原因的：`core.sshCommand` 带参数时 git 会交给 MSYS 的 `sh.exe` 去解析，
而 `sh.exe` 在沙箱里同样起不来（还是那个 `signal pipe, Win32 error 5`）。所以参数全部下沉到
`%USERPROFILE%\.ssh\config`：

```text
Host github.com
    HostName github.com
    User git
    IdentityFile C:/Users/WINDOWS/Documents/deepseek-harness/default-workspace/.tools/ssh/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile C:/Users/WINDOWS/Documents/deepseek-harness/default-workspace/.tools/ssh/known_hosts
```

`UserKnownHostsFile` 指向工作区内，是因为 `~/.ssh` 在工作区外、沙箱不允许写入
（首次会报 `Failed to add the host to the list of known hosts`）。

验证记录（2026-10-22 22:34）：

```text
$ ssh -T git@github.com
Hi tamagoshoyi! You've successfully authenticated, but GitHub does not provide shell access.
```

（`ssh -T` 返回退出码 1 属正常，GitHub 不提供 shell。）

提交身份写在仓库局部配置里（未污染全局配置）：

```text
user.name  = tamagoshoyi
user.email = tamagoshoyi@gmail.com
```

## git 便携版的来龙去脉

已排除：`where git` 无结果、`Program Files\Git` 不存在、`winget.exe` 是 0 字节占位符（App Execution Alias 空壳）。

最终做法：

1. 用 Node 从 TUNA 下载 `MinGit-2.56.0.2-64-bit.zip`（38 MiB）；
2. 解压到 `.tools\git`（入口 `.tools\git\cmd\git.exe`）；
3. `scripts/env.ps1` 检测到便携版就把它加到 PATH 最前，并导出 `$env:DSH_GIT`；
4. `scripts/check.ps1` 在 PATH 找不到 git 时回落到 `.tools\git`。

`.tools/` 已在 `.gitignore` 中，不进版本库。注意：MinGit 不含 `git-lfs`，需要 LFS 时要另装。

## PowerShell 的三处坑（已处理）

1. **执行策略**：本机策略禁止运行脚本，直接 `.\scripts\check.ps1` 会报「因为在此系统上禁止运行脚本」。
   不改系统策略，用进程级绕过：`powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check.ps1`，或直接用 `scripts\check.cmd`。

2. **编码**：本机是 Windows PowerShell 5.1，它把无 BOM 的 `.ps1` 按 GBK 解析，中文会乱码并撑破字符串。
   所有 `.ps1` 必须存为 **UTF-8 with BOM**。

3. **编辑会丢 BOM**：任何文本编辑器/工具重写 `.ps1` 后都可能把 BOM 抹掉，症状是 `Unexpected token` 或 `Missing terminator`。
   改完 `.ps1` 先检查首三字节是否为 `EF BB BF`，不是就补：

   ```powershell
   $b = [IO.File]::ReadAllBytes('.\scripts\env.ps1')
   if (-not ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) {
     [IO.File]::WriteAllBytes('.\scripts\env.ps1', [byte[]](0xEF,0xBB,0xBF) + $b)
   }
   ```

## 坑 4：不要清空整个 `%TEMP%`

`C:\Users\WINDOWS\AppData\Local\Temp` 里有 DSH 沙箱运行器的工作目录（`Temp\dsh-XXXXXX`）。
把它整体清空后，所有 `workspace-write` 命令立刻失败：

```text
sandbox mode "workspace-write" is requested but no sandbox backend is usable ...
Runner failure: windows-acl-run: --temp is not an existing directory: ...\Temp\dsh-2NXHjZ
```

修复：重建那个目录（名字从报错信息里读），或用一次 `danger-full-access` 执行
`New-Item -ItemType Directory -Force`。教训：清理临时文件只删自己的 `.tmp\` 和明确的应用缓存，
不要 `Remove-Item $env:TEMP\*`。

另：沙箱是 `workspace-write` 时，工作区之外的路径（如 `C:\ProgramData`、`%LOCALAPPDATA%`）
一律不可写，删缓存类操作需要在调用时显式申请 `danger-full-access`。

## 复验

```powershell
.\scripts\check.cmd
powershell -NoProfile -NoExit -ExecutionPolicy Bypass -Command ". .\scripts\env.ps1"
```

期望：`node` / `pnpm` / `git` / `python` 全为 `OK`，退出码 0；注入后 `git` 指向 `.tools\git\cmd\git.exe`。
