# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 GitHub 首页型 README + `docs/README.md` 二级导航 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- 脚本用户可见输出已中文化：自举提示、日志等级、预检查/安装/fallback/CC Switch/Skill 导入输出、错误信息和最终执行摘要均使用中文展示。
- `bootstrap.ps1` 现在同时支持原命令模式和拟似 TUI 模式，不再维护单独的 TUI 入口文件。
- 无安装参数或显式 `-Tui` 时会进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 等操作参数时继续按原自动化模式执行。
- TUI 首屏提供“默认安装（原来模式）”“自定义选择”“安全演练”；默认安装会选择 manifest 中全部应用并复用原安装内核，自定义和安全演练会生成等价命令预览。
- TUI 自定义流程已支持 Skill Profile 复选；默认选“全部 Skill”，也可选择一个或多个 Profile，并生成等价 `-SkillProfile` 命令预览。
- `bootstrap.cmd` 远程自举传入的内部参数不再导致跳过 TUI；UAC 提权交接窗口会提示“已打开管理员窗口继续安装”，不再误报“安装已完成”。
- 命令模式启动时会输出“选中的安装应用清单”，按行列出应用名称与 key，便于确认本次实际安装范围。
- 安装执行阶段已加入总步骤进度：工作区、每个应用、Skill 导入和 CC Switch Provider 导入都会显示 `[当前/总数]`，并同步更新 PowerShell 进度条。
- Skill 导入日志已从逐目标长路径明细收敛为按 skill 聚合的进度与结果，正常流程不再刷屏；警告和失败仍保留明确路径与原因。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum、导入计数摘要等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 立即下一步

1. 快速验证旧命令模式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
2. 快速验证内部自举参数仍进入 TUI：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -BootstrapSourceRoot . -BootstrapAssetsRepo indieark/vibe-coding-setup -BootstrapAssetsTag bootstrap-assets`。
3. 快速验证 Profile 选择命令模式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件"`。
4. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验；GUI 可作为后续独立阶段处理。

## 阻断

- 没有当前阻断。
