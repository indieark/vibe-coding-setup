# Active Task Snapshot

## 当前状态

- 本轮目标是拆清“全部 Skill”和“所有套件”的运行语义。
- `全部 Skill` 保留旧逻辑：只导入 bundle 内离线 Skill，并在终端写明 Skill 数、MCP 0、CLI 0。
- 新增 `所有套件` / `-AllSuites`：按所有 Profile 并集合并 Skill、external Skill、MCP 和前置 CLI。
- TUI 选择页会显示“全部 Skill”“所有套件”和每个单独套件的 Skill / MCP / CLI 数量。
- 命令交互菜单中 `0` 表示全部 Skill，`00` 表示所有套件；每个套件行也显示 Skill / MCP / CLI 数量。
- `docs/skill-import.md` 已同步该语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 下一步

1. 运行模块导入、脚本解析和 `-AllSuites` dry-run。
2. 若用户要求提交推送，再按当前改动单独提交。

## 阻断

- 没有当前阻断。
