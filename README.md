# ai-toolbox

AI 工作流工具箱：Claude / AI Agent 日常用到的小工具合集。

每个工具都附一份「给 AI Agent 的执行步骤」——**把工具链接丢给你的 agent（Claude Code、Codex 等），说一句"帮我装上"，它就能照着做完。**

## 工具列表

| 工具 | 解决什么问题 | 适用 | 位置 |
|---|---|---|---|
| [claude-shared-sessions](tools/claude-shared-sessions/) ⚠️ **暂停使用** | Claude 桌面版换账号后，侧栏的历史会话"消失"了；让所有账号共用同一份会话列表。**已知缺陷：会导致新建会话在重启后从侧栏消失，请勿安装；已安装的请按其 README 撤销** | Windows · Claude 桌面版 | 本仓库 |
| [AgentQuota](https://github.com/Belinda9427/AgentQuota) | 同时用 Claude、Codex、Cursor，不知道哪个还有额度；桌面浮标 + 看板一眼看清各家剩余额度 | Windows 10/11 x64 | 独立仓库 · [下载](https://github.com/Belinda9427/AgentQuota/releases/latest) |

## 给 AI Agent

用户给你本仓库链接时：先看上表找到对应工具。
- 位置是「本仓库」：打开 `tools/<工具名>/README.md`，按「给 AI Agent 的执行步骤」执行。标注「暂停使用」的工具不要安装，把 README 顶部的说明转告用户；用户已经装过的，按其中的撤销步骤处理
- 位置是「独立仓库」：打开该仓库的 README，按其中的安装说明执行

每个工具独立，互不依赖。

## 许可

[MIT](LICENSE)
