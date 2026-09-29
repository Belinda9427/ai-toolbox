# ai-toolbox

AI 工作流工具箱：Claude / AI Agent 日常用到的小工具合集。

每个工具都附一份「给 AI Agent 的执行步骤」——**把工具链接丢给你的 agent（Claude Code、Codex 等），说一句"帮我装上"，它就能照着做完。**

## 工具列表

| 工具 | 解决什么问题 | 适用 |
|---|---|---|
| [claude-shared-sessions](tools/claude-shared-sessions/) | Claude 桌面版换账号后，侧栏的历史会话"消失"了；让所有账号共用同一份会话列表 | Windows · Claude 桌面版 |

## 给 AI Agent

用户给你本仓库链接时：先看上表找到对应工具，打开 `tools/<工具名>/README.md`，按其中「给 AI Agent 的执行步骤」执行。每个工具独立，互不依赖。

## 许可

[MIT](LICENSE)
