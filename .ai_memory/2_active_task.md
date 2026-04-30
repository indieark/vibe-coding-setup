# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 GitHub 首页型 README + `docs/README.md` 二级导航 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- 脚本用户可见输出已中文化：自举提示、日志等级、预检查/安装/fallback/CC Switch/Skill 导入输出、错误信息和最终执行摘要均使用中文展示。
- `bootstrap.ps1` 现在同时支持原命令模式和拟似 TUI 模式，不再维护单独的 TUI 入口文件。
- 无安装参数或显式 `-Tui` 时会进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 等操作参数时继续按原自动化模式执行。
- TUI 首屏提供“默认安装（原来模式）”“自定义选择”“安全演练”；默认安装会选择 manifest 中全部应用并复用原安装内核，自定义和安全演练会生成等价命令预览。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum、导入计数摘要等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 立即下一步

1. 快速验证旧命令模式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
2. 快速验证 TUI 入口：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui`，或直接无参运行 `.\bootstrap.cmd`。
3. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验；GUI 可作为后续独立阶段处理。

## 阻断

- 没有当前阻断。
