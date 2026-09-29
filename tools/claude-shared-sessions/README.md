# claude-shared-sessions

**Claude 桌面版换了账号，左侧栏的历史会话全不见了？** 这个工具让你所有的 Claude 账号 / 组织共用同一份侧栏会话列表：不管登录哪个账号，都能看到、继续所有项目的会话。

- 会话没丢：对话内容一直在本机，只是桌面版按账号分开登记，换号后看不到
- 一次设置，以后换任何账号都自动共享（新账号首次登录后用快捷方式重启一次即可）
- 改动前自动备份，随时可一键撤销；只在本机操作，不联网、不读对话内容

## 适用范围

| 项 | 要求 |
|---|---|
| 系统 | Windows 10 / 11 |
| 客户端 | Claude 桌面版（Code 页的会话）；微软商店版和官网安装版都支持 |
| PowerShell | 7.5 或更高（`pwsh`）。没有的话：`winget install --id Microsoft.PowerShell -e` |

## 快速开始（给人）

1. 下载 [share-claude-sessions.ps1](share-claude-sessions.ps1)
2. 在下载目录打开 PowerShell 7，运行：
   ```powershell
   Unblock-File .\share-claude-sessions.ps1    # 解除"从网上下载"的锁定，否则 Windows 不让运行
   pwsh -File .\share-claude-sessions.ps1 -InstallShortcut
   ```
3. 从托盘图标**完全退出** Claude，然后双击桌面上的「**Claude 共享会话**」

以后都用这个快捷方式打开 Claude。换了新账号：首次登录后退出一次，再用快捷方式打开，新账号就接进来了。

## 给 AI Agent 的执行步骤

> 你是被用户叫来安装这个工具的 agent。按顺序执行，每步检查通过再往下。
> 注意：如果你本身运行在 Claude 桌面版里，用户退出客户端时你也会被关掉——所以合并这一步必须交给用户双击快捷方式完成，不要自己去关客户端。

**1. 检查环境**

```powershell
[Environment]::OSVersion.Platform          # 必须是 Win32NT
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'   # 必须 ≥ 7.5
Test-Path "$env:APPDATA\Claude\claude-code-sessions"               # 应为 True
```

- 不是 Windows：告诉用户本工具只支持 Windows，停止
- 没有 pwsh 或版本低于 7.5：征得用户同意后运行 `winget install --id Microsoft.PowerShell -e`
- 最后一项为 False：说明用户还没在桌面版 Code 页用过会话，或装的不是 Claude 桌面版，向用户确认

**2. 下载脚本到本机固定位置**

```powershell
$dir = "$env:LOCALAPPDATA\claude-shared-sessions"; New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest 'https://raw.githubusercontent.com/Belinda9427/ai-toolbox/main/tools/claude-shared-sessions/share-claude-sessions.ps1' -OutFile "$dir\share-claude-sessions.ps1"
Unblock-File "$dir\share-claude-sessions.ps1"
```

下载后先通读脚本，确认它只操作 `claude-code-sessions` 目录。

**3. 预览（只读，不改任何文件）**

```powershell
pwsh -NoProfile -File "$env:LOCALAPPDATA\claude-shared-sessions\share-claude-sessions.ps1" -DryRun
```

把输出转述给用户：会合并几个账号目录、各有多少会话。输出「所有账号目录都已接入共享会话」说明已经装过，跳到第 5 步。

**4. 建快捷方式，并请用户完成合并**

```powershell
pwsh -NoProfile -File "$env:LOCALAPPDATA\claude-shared-sessions\share-claude-sessions.ps1" -InstallShortcut
```

然后告诉用户：**「请从右下角托盘图标完全退出 Claude，再双击桌面上的『Claude 共享会话』。它会先备份、再合并，完成后自动打开 Claude。」**

（如果你不是运行在 Claude 桌面版里，比如 Codex 或独立终端，也可以直接运行 `...share-claude-sessions.ps1 -WaitMinutes 10`，再请用户退出 Claude，脚本会等它退出后自动完成并重新打开。）

**5. 验证**（用户重新打开 Claude 之后）

```powershell
Get-Content "$env:LOCALAPPDATA\claude-shared-sessions\share-claude-sessions.log" -Tail 10
Get-ChildItem "$env:APPDATA\Claude\claude-code-sessions" -Directory | % { Get-ChildItem $_.FullName -Directory } | Select-Object Name, LinkType
```

日志最后应有「共享会话共 N 个」，每个目录的 LinkType 应为 `Junction`。请用户在侧栏筛选菜单里选「按项目分组」查看。

## 原理

桌面版把侧栏会话登记在：

```
%APPDATA%\Claude\claude-code-sessions\
├─ <账号A的ID>\<组织ID>\local_*.json    ← 每个文件是一条会话登记，指向 ~\.claude\projects\ 下的对话记录
└─ <账号B的ID>\<组织ID>\local_*.json
```

客户端只读当前登录账号的那个目录。本工具把所有 `<账号ID>\<组织ID>` 目录合并进 `_shared`，再把每个目录换成指向 `_shared` 的 junction（Windows 的目录快捷方式）。合并规则：

- 同一会话在多个账号下都有 → 保留最近活跃的那份
- 定时任务（`scheduled-tasks.json`）按任务 id 合并，同一任务保留最近运行过的那份

对话内容（`~\.claude\projects\*.jsonl`）、CLAUDE.md、记忆、技能本来就不分账号，本工具不碰。

## 参数

| 参数 | 作用 |
|---|---|
| `-DryRun` | 只预览，不改任何文件 |
| `-WaitMinutes N` | 客户端在运行时，最多等 N 分钟让它退出（默认 0 = 不等，直接提示） |
| `-InstallShortcut` | 把脚本装到 `%LOCALAPPDATA%\claude-shared-sessions\` 并在桌面建快捷方式 |
| `-ShortcutName 名字` | 自定义快捷方式名称（默认「Claude 共享会话」） |
| `-NoLaunch` | 完成后不自动打开客户端 |
| `-Unlink` | 撤销共享 |

## 撤销

```powershell
pwsh -File "$env:LOCALAPPDATA\claude-shared-sessions\share-claude-sessions.ps1" -Unlink -WaitMinutes 10
```

然后退出 Claude。每个账号恢复成独立目录，且各自保留完整的会话列表，不会丢会话。每次合并前的原始数据也备份在 `%APPDATA%\Claude\claude-code-sessions.bak-<时间>\`。

## 已知限制

- 依赖 Claude 桌面版**未公开的内部存储结构**，客户端更新后可能失效；失效时最坏情况是侧栏不共享，不会丢对话（有备份、有撤销）
- 在 A 账号里打开 B 账号建的会话，个别连接器（如 Figma、飞书）可能要在当前账号重新授权
- 定时任务会以当前登录的账号运行
- 只在命令行 `claude` 里建的会话，桌面版本来就没有登记，本工具管不到；用 `claude --resume` 找回
- 仅支持 Windows
