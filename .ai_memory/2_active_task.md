# Active Task Snapshot

## 当前状态

- 本轮目标是拆清“全部 Skill”和“所有套件”的运行语义，并补齐 TUI 中单项 Skill / MCP / CLI 安装与状态检查。
- `全部 Skill` 保持既有行为：只导入 bundle 内离线 Skill，并在终端写明 Skill 数、MCP 0、CLI 0。
- 新增 `所有套件` / `-AllSuites`：按所有 Profile 并集合并 Skill、external Skill、MCP 和前置 CLI。
- TUI 选择页会显示“全部 Skill”“所有套件”和每个单独套件的 Skill / MCP / CLI 数量。
- 命令交互 Profile 菜单也会把 `0`、`00` 和普通套件分行展示：名称、数量摘要、说明；`0` 显示全部离线 Skill 数且 MCP/CLI 为 0，`00` 显示套件数与 Profile 并集 Skill/MCP/CLI 数。
- TUI 光标停在具体套件时，下方详情区会展示将安装的 MCP 和相关 CLI 依赖；默认交互菜单在用户输入后、执行前也会输出同样摘要。
- TUI 工作台现支持“安装套件”“任选安装 Skill”“任选安装 MCP”“任选安装 CLI”；单项选择写回 `-SkillName` / `-McpName` / `-CliName`。
- TUI 软件入口已合并“检查状态”和“安装 / 更新”：先检查，再默认勾选需要处理的建议项，用户可用空格去除。
- TUI Skill 状态页只解析 bundled / external Skill 是否存在，不检测套件 / MCP / CLI；Profile / MCP / CLI 总览迁移到新增“检查所有套件”入口，读取前会显示提示。
- 命令交互菜单中 `0` 表示全部 Skill，`00` 表示所有套件；每个套件行也显示 Skill / MCP / CLI 数量。
- `docs/skill-import.md` 已同步该语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 下一步

1. 后续若继续调整 Profile 菜单，保持 `docs/skill-import.md` 为行为说明入口。
2. 本轮已进入验证、归档、提交、推送收口。

## 阻断

- 没有当前阻断。
