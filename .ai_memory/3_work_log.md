# Work Log

## 2026-04-23

- 梳理了 `bootstrap.ps1`、`modules/common.psm1`、`manifest/apps.json` 的主安装链路与 precheck / fallback 机制。
- 重写并补强 `README.md`，加入主脚本执行顺序、来源/回退表、特殊行为说明。
- 将 fallback 资产升级到新版并同步到 `bootstrap-assets`：
  - Git `2.54.0`
  - Node.js `25.9.0`
  - Python `3.13.13`
  - VS Code `1.117.0`
  - CC Switch `3.14.0`
- 修正了 Python fallback 方案：由 `python-manager-26.0.msix` 切换为官方运行时安装包 `python-3.13.13-amd64.exe`，并补齐静默参数。
- 验证了更新后的 manifest 在 `-DryRun` 下可正常工作。
- 将 `Codex Desktop` fallback 从仓库 release 中的旧 `Setup.exe` 切换为官方 Microsoft Store 来源。
- 为通用安装逻辑补充 `uri` 型 fallback，支持拉起 `ms-windows-store://` 或官方网页详情页。
- 删除 release 中旧的 `Codex-26.325.31654.Setup.exe` 资产。
- 重新通读整个仓库后，修正了 `README.md` 中三处与代码不一致的描述：`skills.zip` 触发条件、实际使用策略集合、以及 primary failure 后的 post-check / fallback 顺序。

## 2026-04-30

- 完成并合并 Phase 4：Skill 三态去重判定，PR #6 合入 `main`，merge commit `85aea1b`。
- 验证通过：`git diff --check`、PowerShell 5.1 / 7 模块导入、飞书办公套件 dry-run（`-NoReplaceOrphan -SkipSkillsManagerLaunch`）。
- 更新 README：补充当前路线状态、本机安全测试命令、`.skill-meta.json` 来源判定、三态默认策略和后续先进化方向。
- 更新 `.ai_memory`：记录当前安装器真实状态、下一步 Phase 5 边界和安装器增强建议。

## 2026-04-30

- 重构文档结构：README 收敛为顶层入口和文档地图，详细说明拆入 `docs/installer-flow.md`、`docs/skill-import.md`、`docs/asset-refresh.md`、`docs/operations.md`、`docs/roadmap.md`。
- 新增 `.agent/rules/documentation-governance.md`，明确层层索引、单一信息源和修改要求。
- 精简 `.ai_memory/1_project_context.md`，改为记录 SSOT 地图和稳定事实，不再复制完整应用来源表。

## 2026-04-30

- 完成脚本中文化：覆盖 `bootstrap.ps1` 和 `modules/common.psm1` 的主要用户可见提示、日志、错误和执行摘要。
- 为兼容 Windows PowerShell 5.1，中文文案采用 UTF-8 base64 解码输出，保持脚本文件无 BOM。
- 优化执行摘要可读性：日志等级显示为“信息 / 警告 / 错误”，内部 source 展示为“文件系统 / 预检查跳过 / Release 回退 / CC Switch 导入”等用户语义。
- 验证通过：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。

## 2026-04-30

- 参考 GitHub README 常见结构后，重写顶层 README 为项目首页型：补充问题背景、核心能力、安全边界、快速开始和文档中心入口。
- 新增 `docs/README.md` 二级导航，按终端用户、维护者、后续 AI 三类读者分流。

## 2026-04-30

- 将拟似 TUI 合并进 `bootstrap.ps1`，未新增独立入口文件；新增 `-Tui` 参数，并让无操作参数启动时默认进入 TUI。
- TUI 首屏加入“默认安装（原来模式）”“自定义选择”“安全演练”三种模式，其中原来模式仍复用原安装内核，只是由 TUI 内部选择进入。
- 保留显式参数的旧自动化行为：`-DryRun -SkipSkills -SkipCcSwitch -Only git` 这类命令不会进入 TUI。
- 更新 `docs/operations.md`，说明无参默认 TUI、`-Tui` 强制入口和旧式参数命令的关系。
- 验证通过：脚本解析、显式参数 dry-run、`-Tui` 退出、无参 TUI 退出、默认安装确认页退出、安全演练命令预览。

## 2026-04-30

- 将 Skill 选择从文档说明推进为运行时功能：TUI 自定义流程新增 Skill Profile 复选页，默认选择“全部 Skill”，也可选择一个或多个 Profile 并生成 `-SkillProfile` 命令预览。
- 新增 `Get-SkillBundleProfiles`，从 `downloads/skills.zip` 的 registry 中读取 `profiles.yaml`，供 TUI 展示真实 Profile 清单。
- 修复 `bootstrap.cmd` 传入内部自举参数时误跳过 TUI 的问题；`BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag` 不再视为用户操作参数。
- 修复 UAC 提权交接后的误导文案：非管理员窗口现在提示已打开管理员窗口继续安装，不再显示“安装已完成”。
- 命令模式输出改为“选中的安装应用清单”，逐行列出应用名称与 key。
- 安装执行阶段新增总步骤进度：工作区、应用安装、Skill 导入和 CC Switch Provider 导入会显示 `[当前/总数]`，并同步使用 PowerShell `Write-Progress`。
- Skill 导入输出从逐目标长路径明细收敛为按 skill 聚合的进度和结果；dry-run 注册 skills-manager DB 也改为计数摘要。
- 验证通过：脚本解析、模块导入、Profile 读取、旧命令模式 dry-run、`-SkillProfile "飞书办公套件"` dry-run、内部自举参数进入 TUI 并可退出、`git diff --check`。

## 2026-04-30

- 修复 TUI 默认安装模式：选择“默认安装（原来模式）”后不再进入执行确认页，也不再写入 `-Only` 全量应用清单，而是直接沿用原脚本未指定 `-Only` 时的默认全量安装逻辑。
- 默认安装模式会保留进入 TUI 前显式传入的 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 和 Skill 参数，避免 `-Tui -DryRun` 被吞参数后触发 UAC。
- 新增内部 `BootstrapTuiResolved` 标记，用于 UAC 提权后跳过二次 TUI；该标记不改变安装集合。
- 修复 UAC 重启时数组参数被拆成多个位置参数的问题：`ConvertTo-ArgumentTokens` 会把数组压缩成逗号形式，例如 `-Only "git,nodejs,cc-switch"`。
- 验证通过：脚本解析、数组参数 token 生成、默认安装内部标记 dry-run 全量路径、`-Only "git,nodejs,cc-switch"` dry-run、`-Tui` 首屏退出、`git diff --check`。
