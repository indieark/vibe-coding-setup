# Active Task Snapshot

## 当前状态

- 已完成自定义模式组件检查拆分：Skill 入口只检查 Skill，MCP 入口只检查 MCP，CLI 入口只检查 CLI；套件入口才全量检查 Skill / MCP / CLI 并展示总览。
- 套件/Profile 页已改为“套件复选项”，列表行只显示名称；数量、说明、MCP 和 CLI 依赖放在顶部总览与当前项详情中。
- 单项 Skill / MCP / CLI 选择保持跨类型累积，不会因为选择某一类而清空其它类型已选项，最后统一进入 `执行确认`。
- MCP 状态扫描已修正为与应用和 CLI 一致的同一行逐项完成进度，格式为 `检查 ... N/M 个 MCP 已完成`，不新增阶段提示。
- 已修复 Windows PowerShell 5.1 真实启动路径中的裸中文解析崩溃；新增中文文案继续使用 UTF-8 Base64 解码输出。
- 已同步 README、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md` 和 `.ai_memory`。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 最近验证

- `cmd.exe /d /c "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...\bootstrap.ps1 -DryRun -SkipApps -SkipSkills"` 启动验证通过。
- `modules/common.psm1` PowerShell parser 通过。
- Base64 字面量检查通过。
- MCP-only 状态检查输出验证为 `检查 ... 10/10 个 MCP 已完成`。
- 最新已推送代码提交：`36f9b88 fix: show mcp status progress per item`。

## 下一步

1. 如用户继续反馈 TUI 显示与预期不一致，先确认是否使用最新脚本与最新公开 `bootstrap-assets/skills.zip`，再检查本地 `downloads/skills.zip` 缓存。
2. 若继续调整 TUI 文案，避免新增裸中文源码字符串；保持 UTF-8 Base64 文案约束。
3. 后续安装器增强优先考虑可观测、可校验、可回滚能力。

## 阻断

- 没有当前阻断。
