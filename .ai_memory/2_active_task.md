# Active Task Snapshot

## 当前状态

- 本轮已把 TUI 用户入口从“TUI 模式”改名为“自定义模式”。
- 自定义模式已合并检查与安装入口：检查并安装 / 更新软件、检查并安装套件、检查并任选安装 Skill、检查并任选安装 MCP、检查并任选安装 CLI。
- “检查 Skill 状态”和“检查所有套件”不再作为独立入口存在；对应检查分别在 Skill / 套件 / MCP / CLI 安装选择前执行。
- 套件、Skill、MCP、CLI 长列表改为分页渲染，不再全量刷屏；顶部显示已选数量和摘要，底部显示当前项详情。
- 自定义模式内会复用本轮已读取的 Skill registry / MCP / CLI 状态，减少反复进入不同入口时的等待。
- 默认模式和自定义模式的软件预检查都会同一行刷新已完成数量；Skill / MCP / CLI 状态扫描也同一行刷新完成数量，结束时只保留完成行。
- winget 成功输出后如果外层进程不退出，会自动收尾并继续后续检测，避免停在“winget install ... 仍在运行”。
- 本轮 debug 继续修复两个状态检查问题：Claude Code MCP 列表改为一次读取复用；飞书 CLI 兼容 `lark --version` registry 旧检测命令与实际 `lark-cli` 可执行名。
- 文档入口已同步到 README、`docs/installer-flow.md`、`docs/operations.md`、`docs/skill-import.md`、`docs/roadmap.md`。
- 默认安装输出已按 `获取依赖`、`应用安装`、`配置导入`、`插件安装` 四段重排；CC Switch 配置导入在插件安装前执行；工作区、配置导入、插件安装不再输出重复的 `[当前/总数]` 阶段提示。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 下一步

1. 后续若继续调整 Skill / MCP / CLI registry，保持 `00000-model/00-编程配置/registry/*.yaml` 为唯一来源。
2. 后续若继续调整安装器行为，优先同步 `docs/installer-flow.md` 和 `docs/skill-import.md`。

## 阻断

- 没有当前阻断。
