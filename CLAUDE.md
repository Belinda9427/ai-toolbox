# ai-toolbox 仓库规则

公开仓库。收录 Claude / AI Agent 日常用到的小工具，每个工具都要能「把链接丢给 agent，agent 就能装好」。

## 目录结构

```
ai-toolbox/
├─ README.md          总目录：每个工具一行
├─ CLAUDE.md          本文件：仓库规则（AGENTS.md 指向这里）
├─ LICENSE            MIT
└─ tools/<tool-name>/ 每个工具一个文件夹，互不依赖
   ├─ README.md       必备，结构见下
   └─ 脚本 / 代码
```

- 工具文件夹名用小写 kebab-case，说清对象 + 动作，如 `claude-shared-sessions`
- 一个工具只解决一个问题；不同工具之间不共享代码，复制也比耦合好
- 新增、改名、删除工具时，同步更新根目录 README 的工具列表

## 工具 README 必备章节（按顺序）

1. 一句话：解决什么问题（用用户的话说，不用实现术语）
2. 适用范围：系统、依赖、版本
3. 快速开始（给人）：最少步骤
4. **给 AI Agent 的执行步骤**：编号步骤 + 可直接运行的命令 + 每步的检查点 + 哪一步必须由用户手动完成
5. 原理：路径和 ID 一律用占位符（`<账号ID>`、`%APPDATA%`）
6. 参数 / 撤销方法 / 已知限制与风险

## 代码要求

- 不写死任何本机信息：用户名、绝对路径、账号/组织 ID、邮箱、安装包版本号都在运行时探测
- 日志、备份、缓存写到用户本机目录（如 `%LOCALAPPDATA%\<tool-name>\`），不写进仓库目录
- 会改用户数据的工具必须：先备份、支持 `-DryRun` 预览、提供撤销方法
- 报错信息要告诉用户下一步怎么做，不只报错
- Windows PowerShell 脚本存成 UTF-8 **带 BOM**（否则 Windows PowerShell 5.1 读中文会乱码甚至解析失败）

## 发布前隐私检查（每次提交前必跑）

```bash
git grep -nIE '[A-Za-z]:\\\\Users\\\\[^%<$]|/Users/[a-z]|/home/[a-z]|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}|sk-[A-Za-z0-9]{10}' -- ':!LICENSE'
```

有命中就逐条确认是占位符/示例还是真实信息；真实信息一律删掉。另外确认：
- 没有日志、备份、`.lnk`、会话 json、`~/.claude` 下的任何文件被 `git add`
- 提交身份是 GitHub noreply 邮箱（本仓库 `git config user.email` 已设好），不用个人邮箱

## Git

- commit message 用英文，写变更意图
- push 只在仓库主人明确要求时执行
