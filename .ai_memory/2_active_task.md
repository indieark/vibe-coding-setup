# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 GitHub 首页型 README + `docs/README.md` 二级导航 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- 脚本用户可见输出已中文化：自举提示、日志等级、预检查/安装/fallback/CC Switch/Skill 导入输出、错误信息和最终执行摘要均使用中文展示。
- `bootstrap.ps1` 现在同时支持原命令模式和拟似 TUI 模式，不再维护单独的 TUI 入口文件。
- 无安装参数或显式 `-Tui` 时会进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 等操作参数时继续按原自动化模式执行。
- TUI 首屏提供“默认安装（原来模式）”“自定义选择”“安全演练”；默认安装不写入 `-Only`，直接复用原脚本默认安装逻辑，自定义和安全演练才生成等价命令预览。
- 如果显式用 `-Tui -DryRun` 或 `-Tui -SkipSkills` 等命令进入 TUI，默认安装会保留这些原命令参数。
- TUI 自定义流程已支持 Skill Profile 复选；默认选“全部 Skill”，也可选择一个或多个 Profile，并生成等价 `-SkillProfile` 命令预览。
- TUI 首屏不再预取 `skills.zip`；只有进入 Skill 复选页或实际执行 Skill 导入时才按需获取 bundle。
- `bootstrap.cmd` 远程自举传入的内部参数不再导致跳过 TUI；UAC 提权交接窗口会提示“已打开管理员窗口继续安装”，不再误报“安装已完成”。
- UAC 重启时数组参数会压缩为逗号形式，避免 `cc-switch` 这类应用 key 被 PowerShell 误解析为位置参数。
- 命令模式启动时会输出“选中的安装应用清单”，按行列出应用名称与 key，便于确认本次实际安装范围。
- 安装执行阶段总进度使用 `[当前/总数] 当前步骤` 文字；应用内部下载和 winget 百分比使用脚本自绘进度条，静默 MSI/EXE 无真实百分比时显示运行中和耗时；不再调用 `Write-Progress` 绘制独立宿主进度区域。
- 自举依赖和 Release 资产下载也使用脚本自绘进度条，避免 `downloads/skills.zip` 这类大资产下载时看起来卡住。
- 真实安装触发 UAC 时会优先用 Windows Terminal 承载管理员 PowerShell；系统没有 `wt.exe` 时才回退经典 PowerShell 窗口。
- 进入 TUI 前会 best-effort 切换到英文键盘布局，并向前台终端窗口发送输入语言切换请求，减少中文输入法干扰方向键和快捷键。
- Skill 导入日志已从逐目标长路径明细收敛为按 skill 聚合的进度与结果，正常流程不再刷屏；警告和失败仍保留明确路径与原因。
- Profile 交互菜单提示已收敛为“可输入序号/名称，多个可用英文逗号、中文逗号或顿号分隔；直接回车安装全部 Skill”，不再在交互菜单里展示命令行参数说明。
- TUI 默认安装在未选择 Skill Profile 时不会再把空 `-SkillProfile` 带入 UAC / Windows Terminal 重启参数；空数组会被清洗并跳过。
- 本轮安装器体验修复已提交并推送到 `main`；最近提交覆盖默认安装逻辑、进度/终端体验、Skill 选择提示、空 `SkillProfile`、中文多选分隔符、TUI 英文输入布局增强和 Skill bundle 按需获取。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 立即下一步

1. 快速验证旧命令模式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
2. 快速验证默认安装绕过 TUI 后仍走原默认全量逻辑：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -BootstrapTuiResolved`。
3. 快速验证内部自举参数仍进入 TUI：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -BootstrapSourceRoot . -BootstrapAssetsRepo indieark/vibe-coding-setup -BootstrapAssetsTag bootstrap-assets`。
4. 快速验证数组参数逗号形式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only "git,nodejs,cc-switch"`。
5. 快速验证 Profile 选择命令模式：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件"`。
6. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验；GUI 可作为后续独立阶段处理。
7. 若继续现代化 TUI，优先重做 TUI 信息架构：顶层保留默认安装和安全演练，TUI 内聚焦状态检查、软件安装/更新、Skill 安装选择，避免把应用和行为都做成同一类复选项。

## 阻断

- 没有当前阻断。

## 最近验证

- `powershell -NoProfile -Command '& { $ErrorActionPreference = "Stop"; [void][scriptblock]::Create((Get-Content -LiteralPath ".\bootstrap.ps1" -Raw)); Import-Module .\modules\common.psm1 -Force; "parse-ok" }'`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui -DryRun -SkipSkills -SkipCcSwitch`，首屏默认 Enter 后直接执行，没有出现确认页。
- `ConvertTo-ArgumentTokens` 空 / 非空数组参数验证：空 `SkillProfile` 不输出参数，非空 `SkillProfile` 保留为逗号压缩参数。
- `-Only "git，nodejs、cc-switch"` dry-run 验证通过，中文逗号和顿号会正常解析为多个应用。
- `-SkillProfile "飞书办公套件，前端开发套件、GitHub 工作流套件"` dry-run 验证通过，Profile 多选支持英文逗号、中文逗号和顿号。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏可进入并退出，用于验证增强后的输入布局切换不会阻断 TUI。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏退出未触发 `skills.zip` 获取。
- TUI 自定义流程进入 Skill 复选页时才读取已缓存的 `downloads/skills.zip`。
- `git diff --check`
- `git status --short --branch` 当前为 `main...origin/main` 干净。
