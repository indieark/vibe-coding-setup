# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 GitHub 首页型 README + `docs/README.md` 二级导航 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- 脚本用户可见输出已中文化：自举提示、日志等级、预检查/安装/fallback/CC Switch/Skill 导入输出、错误信息和最终执行摘要均使用中文展示。
- `bootstrap.ps1` 现在同时支持原命令模式和拟似 TUI 模式，不再维护单独的 TUI 入口文件。
- 无安装参数或显式 `-Tui` 时会进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 等操作参数时继续按原自动化模式执行。
- TUI 首屏提供“默认安装（原来模式）”“TUI 模式”“安全演练”；默认安装不写入 `-Only`，直接复用原脚本默认安装逻辑，TUI 模式和安全演练才生成等价命令预览。
- TUI 模式已重做为控制台工作台：检查软件状态、安装 / 更新软件、检查 Skill 状态、安装 Skill、执行摘要。
- 新增 `-SkipApps`，支持跳过应用安装阶段，TUI 工作台可只执行 Skill 导入。
- 如果显式用 `-Tui -DryRun` 或 `-Tui -SkipSkills` 等命令进入 TUI，默认安装会保留这些原命令参数。
- TUI 工作台的“安装 Skill”动作支持 Skill Profile 复选；默认选“全部 Skill”，也可选择一个或多个 Profile，并生成等价 `-SkillProfile` 命令预览。
- 安装 Skill 时会选择 Skills Manager 场景注册方式：默认场景、自定义场景或跳过场景注册只复制 Skill 文件；命令模式对应 `-SkillsManagerScenarioMode prompt|default|custom|skip` 和 `-SkillsManagerScenarioName`。
- TUI Skill 复选页新增“跳过 Skill 导入”，并修复清空 Profile 后回车会误回落成全部 Skill 的问题；命令模式交互选择中输入 `0` 才导入全部，直接回车跳过。
- TUI 首屏不再预取 `skills.zip`；只有进入 Skill 复选页或实际执行 Skill 导入时才按需获取 bundle。
- `bootstrap.cmd` 远程自举传入的内部参数不再导致跳过 TUI；UAC 提权交接窗口会提示“已打开管理员窗口继续安装”，不再误报“安装已完成”。
- UAC 重启时数组参数会压缩为逗号形式，避免 `cc-switch` 这类应用 key 被 PowerShell 误解析为位置参数。
- 命令模式启动时会输出“选中的安装应用清单”，按行列出应用名称与 key，便于确认本次实际安装范围。
- 安装执行阶段总进度使用 `[当前/总数] 当前步骤` 文字；应用内部下载、winget 下载 / 安装和 Skill bundle 解压使用脚本自绘进度条，静默 MSI/EXE 无真实百分比时显示运行中和耗时；不再调用 `Write-Progress` 绘制独立宿主进度区域。winget 输出会过滤许可证、免责声明和重复进度行，并中文化常见状态。
- 自举依赖和 Release 资产下载也使用脚本自绘进度条，避免 `downloads/skills.zip` 这类大资产下载时看起来卡住。
- Skill bundle 解压已从 `Expand-Archive` 改为 .NET `ZipFile` 流式解压，并复用脚本自绘同一行进度；同时加入 zip-slip 越界路径防护，避免 PowerShell 宿主蓝色进度区域。
- 真实安装触发 UAC 时会优先用 Windows Terminal 承载管理员 PowerShell；系统没有 `wt.exe` 时才回退经典 PowerShell 窗口。
- 进入 TUI 前会 best-effort 切换到英文键盘布局，并向前台终端窗口发送输入语言切换请求，减少中文输入法干扰方向键和快捷键。
- Skill 导入日志已从逐目标长路径明细收敛为按 skill 聚合的进度与结果，正常流程不再刷屏；警告和失败仍保留明确路径与原因。
- Profile 交互菜单提示已收敛为“可输入序号/名称，多个可用英文逗号、中文逗号或顿号分隔；输入 0 安装全部 Skill”，不再在交互菜单里展示命令行参数说明；直接回车会跳过 Skill 导入。
- TUI 默认安装在未选择 Skill Profile 时不会再把空 `-SkillProfile` 带入 UAC / Windows Terminal 重启参数；空数组会被清洗并跳过。
- 本轮安装器体验修复正在收尾；最近改动覆盖默认安装逻辑、进度/终端体验、Skill 选择提示、空 `SkillProfile`、中文多选分隔符、TUI 英文输入布局增强、Skill bundle 按需获取、winget 输出收敛和 Skills Manager 场景注册选择。当前待完成最终验证、提交和推送。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。
- TUI 现代化工作台重做计划已实施，状态记录在 `plans/2026-04-30-tui-modernization-workbench.md`。

## 立即下一步

1. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验；GUI 可作为后续独立阶段处理。
2. 若继续打磨 TUI，优先优化状态扫描等待提示、窄窗口表格截断和执行摘要的命令复制显示。

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
- TUI 工作台进入 Skill 状态页或 Skill 复选页时才读取已缓存的 `downloads/skills.zip`。
- `powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\bootstrap.ps1), [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 1 }; "bootstrap.ps1 parse ok"'`
- `powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\modules\common.psm1), [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 1 }; Import-Module .\modules\common.psm1 -Force; "common.psm1 parse/import ok"'`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch -BootstrapTuiResolved`，验证 Skill bundle 解压显示脚本自绘同一行进度；Codex 捕获输出中会展开 `\r`，真实终端为单行刷新。
- 临时恶意 zip 演练：`Install-SkillBundle -ZipPath bad.zip -AllSkills -DryRun -SkipSkillsManagerLaunch` 会拦截 `../evil.txt`，输出 `zip-slip guard ok`。
- 文档入口路径检查：README、docs、规则文档、`.ai_memory/2_active_task.md` 和 TUI 计划文件均存在。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipApps -SkipCcSwitch -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch -BootstrapTuiResolved`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui -DryRun -SkipCcSwitch`，验证 TUI 模式进入工作台、Skill Profile 复选、执行摘要生成 `-SkipApps` 并完成 dry-run。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Tui -DryRun -SkipSkills -SkipCcSwitch`，验证 TUI 模式软件状态页可展示当前版本、目标版本和建议动作。
- `git diff --check`
- `git status --short --branch` 当前为 `main...origin/main` 干净。
