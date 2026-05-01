# Active Task Snapshot

## 当前状态

- 本轮目标是拆清“全部 Skill”和“所有套件”的运行语义，并补齐 TUI 中单项 Skill / MCP / CLI 安装与状态检查。
- `全部 Skill` 保留旧逻辑：只导入 bundle 内离线 Skill，并在终端写明 Skill 数、MCP 0、CLI 0。
- 新增 `所有套件` / `-AllSuites`：按所有 Profile 并集合并 Skill、external Skill、MCP 和前置 CLI。
- TUI 选择页会显示“全部 Skill”“所有套件”和每个单独套件的 Skill / MCP / CLI 数量。
- TUI 工作台现支持“安装套件”“任选安装 Skill”“任选安装 MCP”“任选安装 CLI”；单项选择写回 `-SkillName` / `-McpName` / `-CliName`。
- TUI Skill 状态页会汇总 Skill / MCP / CLI 数量，并显示 MCP 配置状态和 CLI 检测状态；CLI check 失败只标记未检测到，不中断状态页。
- 命令交互菜单中 `0` 表示全部 Skill，`00` 表示所有套件；每个套件行也显示 Skill / MCP / CLI 数量。
- `docs/skill-import.md` 已同步该语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 下一步

1. 若用户要求提交推送，先跑 `git diff --check` 和最终 `git status`。
2. 按当前改动单独提交并推送。

## 阻断

- 没有当前阻断。
