# Archive Context

## 2026-04-23 - README整理与fallback资产升级归档

### 核心议题背景

用户先要求梳理仓库主脚本逻辑、安装来源与回退来源，并汇总到 `README.md`；随后要求把 release 中的 fallback 安装包更新到官方最新版；最后要求更新 `README` 并做总结归档。

### Cognitive Evolution Path

1. 初始阶段先把仓库结构、主入口、manifest、模块逻辑读清楚，避免只看 `README` 做二手总结。
2. 发现主入口是 `bootstrap.ps1`，真正决定安装与 fallback 的核心在：
   - `manifest/apps.json`
   - `modules/common.psm1`
3. 文档阶段没有只做“怎么用”，而是按代码真实执行顺序重写了 `README`，把自举、提权、precheck、技能导入和 Provider 导入都讲清楚。
4. 更新 fallback 时，先核对每个安装项的官方最新版与官方资产命名，再回写 manifest，避免拍脑袋改文件名。
5. 在 Python 项上没有机械沿用旧方案，而是识别出 `python-manager-26.0.msix` 不是 `Python 3.13` 运行时本体，因此顺手把 fallback 改成真正的官方安装器并补静默参数。
6. 在 `Codex Desktop` 项上刻意保守：虽然拿到了 Store 包 ID 和本机版本，但没有确认稳定公开的官方 `Setup.exe` 来源，因此没有盲改，避免把 fallback 指到不可验证的文件名。
7. 远端 release 操作采取“新增新包、不删除旧包”的策略，降低回滚风险；同时在文档里明确说明“脚本只认 manifest 当前指向的文件名”。

### 关键决策

- 文档层面以代码为准，不以旧 `README` 为准。
- fallback 升级时同时更新三处：
  - `manifest/apps.json`
  - `README.md`
  - GitHub `bootstrap-assets` release
- 对缺乏稳定官方来源的包保持保守，不为了“全绿”而瞎改。

### 当前结论

- 主要 fallback 资产已升级并上传：
  - Git
  - Node.js
  - Python 3.13
  - Visual Studio Code
  - CC Switch
- 后续已完成 `Codex Desktop` fallback 收尾：
  - 不再维护 release 中会过期的 `Codex-*.Setup.exe`
  - 改为官方 Microsoft Store 协议和网页详情页作为 fallback
  - release 中旧的 `Codex-26.325.31654.Setup.exe` 已删除

### 后续行动指引

1. 如准备长期维护此仓库，建议补一个“同步官方最新版到 bootstrap-assets”的自动化脚本。
2. 如希望提升可验证性，可为 release 资产增加 checksum 记录与校验步骤。
3. 如未来再遇到没有稳定直链的桌面应用，优先考虑“官方 Store / 官方 URI fallback”而不是自托管易过期安装器。

## 2026-04-23 - Codex Desktop fallback 收尾归档

### 核心议题背景

在主安装项与 release 资产大体整理完成后，剩余唯一悬而未决的问题是 `Codex Desktop` 仍依赖仓库 release 中的旧版 `Setup.exe`。用户随后要求把这个 fallback 来源问题彻底解决。

### Cognitive Evolution Path

1. 先确认 `Codex` 在官方侧有哪些可验证来源。
2. 通过 `winget show --id 9PLM9XGG6VKS --source msstore` 与 OpenAI 官方页面，确认它的官方来源稳定落在 Microsoft Store，而不是公开 GitHub Release / 固定 exe 下载页。
3. 由此放弃“继续追 `Codex-*.Setup.exe` 文件名”的思路，改为在通用安装逻辑中增加 `uri` 型 fallback。
4. 最终把 `Codex Desktop` 的 fallback 改成：
   - `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`
   - `https://apps.microsoft.com/detail/9PLM9XGG6VKS`
5. 完成代码、manifest、README 的同步修改后，再删除 release 中旧的 `Codex-26.325.31654.Setup.exe`。

### 关键决策

- 对没有稳定公开安装器文件名的官方桌面应用，优先使用官方 Store / URI 作为 fallback。
- 不为了保留“静默 exe fallback”而继续维护一个高过期风险的自托管安装器。

### 当前结论

- `Codex Desktop` fallback 问题已经解决。
- 当前 `bootstrap-assets` release 中不再残留 `Codex` 旧安装包。

## 2026-04-23 - 仓库全量复读与 README 对账归档

### 核心议题背景

用户要求“完整读一遍仓库，理解脚本执行全逻辑、理解已安装应用的主来源与回退来源，并更新 README 后归档总结”。这次重点不再是继续改安装逻辑，而是确认文档是否和代码真实行为完全一致。

### Cognitive Evolution Path

1. 先列出整个仓库真实文件集合，确认可执行逻辑实际上集中在：
   - `bootstrap.ps1`
   - `modules/common.psm1`
   - `manifest/apps.json`
   - 两个 `.cmd` 入口壳
2. 虽然现有 `README.md` 已经很详细，但仍然按“代码优先、文档次之”的方式重读主入口和模块函数清单，避免把旧文档当真相源。
3. 在对账过程中发现最关键的偏差不是安装来源表，而是执行条件和控制流细节：
   - `skills.zip` 的预取和导入实际上只受 `-SkipSkills` 控制，不要求本次选择 `skills-manager`
   - 当前 manifest 实际使用了 `release-asset`，而不是 `github-release`
   - 主安装路径失败后，不是立刻 fallback，而是会先做一次 post-check 重新探测安装结果
4. 因此这次 README 更新不只是补充说明，而是做了一次“代码事实校正”，把文档重新拉回到和脚本一致的状态。

### 关键决策

- 对这个仓库，README 只能作为“对外说明”，不能替代 `bootstrap.ps1` + `modules/common.psm1` + `manifest/apps.json` 作为唯一真相源。
- 对用户要求的“完整理解”，优先提炼控制流、来源矩阵和特殊分支，而不是机械罗列每个函数。
- 归档时把“文档与代码对账”本身记为稳定流程，防止未来再次出现 README 慢于代码演化的问题。

### 当前结论

- 当前仓库体量很小，但核心行为并不简单，尤其体现在：
  - 自举依赖同步
  - precheck / version gate
  - primary install -> post-check -> fallback
  - `skills.zip` 独立导入链
  - `CC Switch` provider deep-link 导入
- `README.md` 已根据代码重新校准。
- `.ai_memory` 已同步记录这次确认下来的稳定事实与当前快照。

### 后续行动指引

1. 以后每次改 `manifest/apps.json` 或 `common.psm1`，都应同步回看 README 中的“执行顺序”和“来源/回退”章节。
2. 如果未来把 `skills.zip` 的触发条件改成“仅在选择 `skills-manager` 时运行”，需要同时改代码和 README，而不是只改文档。
3. 如果新增新的 fallback 类型，优先先补 `README` 的通用安装逻辑，再补应用级来源表。

## 2026-04-30 — 按需装机器 Phase 1-4 归档

本轮路线把 `vibe-coding-setup` 从普通 Windows 装机脚本推进到按需装机器底座。关键转折是：不再把 Skill 当作无来源的目录拷贝，而是把 `00000-model` registry bundle 镜像成公开 `skills.zip`，并在导入时读取 `.skill-meta.json`，让 Skills Manager 能识别真实上游来源。

核心决策：终端用户不需要 PAT；PAT 只存在于刷新 `bootstrap-assets` 的 GitHub Actions secret 中。安装路径只访问当前仓库公开 release 资产，避免把私库权限扩散到用户机器。

Skill 导入的安全边界已经收敛为三态：`Tracked` 表示 IndieArk 可追更目录，按内容增量同步；`Orphan` 表示旧版或手工拷贝目录，默认备份后替换；`Foreign` 表示第三方同名目录，默认跳过。用户测试时优先用 `-DryRun -NoReplaceOrphan -SkipSkillsManagerLaunch`，确认日志后再真实导入。

后续先进化方向不应继续堆安装项，而应增强可观测和可校验：日志落盘、JSON report、bundle manifest / checksum、导入结果计数、`-Plan` 或 `-ReportPath` 模式。路线图下一阶段是 `00000-model` Phase 5：registry → 飞书 bitable 只读镜像，继续保持 yaml 为 SSOT。

## 2026-04-30 — 文档结构治理归档

用户要求保证层层索引和单一信息源。审计后发现 README 同时承载安装流程、Skill 导入、PAT 规范、资产刷新和路线图，容易与 `.agent/rules`、`.ai_memory` 和代码事实源重复。

本次把 README 改为顶层入口，只保留项目定位、文档地图、快速开始、SSOT 约定和维护检查清单。详细说明按主题拆入 `docs/installer-flow.md`、`docs/skill-import.md`、`docs/asset-refresh.md`、`docs/operations.md`、`docs/roadmap.md`。

同时新增 `.agent/rules/documentation-governance.md`，把“README 只做索引、规则写在 rules、归档不当用户手册、代码配置是最终事实源”固化为仓库规则。后续修改文档时先找唯一入口，不要把同一张表复制到多个文件。

## 2026-04-30 — 脚本中文化与展示可读性归档

### 核心议题背景

用户先提出希望脚本更结构化、支持中文显示并有现代化界面；随后明确收窄为“先把脚本中文化”。因此本轮没有继续推进 GUI，也没有拆分安装内核，而是优先处理终端用户实际看到的提示、日志、错误和最终 summary。

### Cognitive Evolution Path

1. 先确认当前仓库的安装核心仍是 `bootstrap.ps1` 与 `modules/common.psm1`，避免为了界面诉求直接大改安装流程。
2. 发现 Windows PowerShell 5.1 对无 BOM 中文源码不稳定，因此没有把大量中文直接写成源码字面量，而是沿用项目已有的 UTF-8 base64 解码输出方式。
3. 第一轮中文化覆盖自举、下载、winget、预检查、fallback、CC Switch、Skill 导入和执行摘要。
4. 用户追问“中文还能更优雅易读吗”后，进一步把日志等级从 `INFO/WARN/ERROR` 展示为“信息 / 警告 / 错误”，并把执行摘要中的内部 source 值翻译成用户语义，如“文件系统”“预检查跳过”。
5. 最小回归验证选用既有安全命令：`powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`，确认中文输出和退出码正常。

### 关键决策

- 本轮只做展示层中文化，不改变安装策略、状态值、fallback 顺序或 Skill 三态判定。
- 内部 `Status`、`Source` 等字段继续保留英文机器值，最终表格单独做中文展示映射，避免影响脚本逻辑。
- 为兼容旧版 PowerShell，中文提示继续通过 UTF-8 base64 解码，脚本文件保持 UTF-8 无 BOM。

### 当前结论

- 脚本已经能以中文输出主要用户可见流程。
- 执行摘要相比上一版更容易读：标题为“执行摘要”，日志等级为中文，执行路径以用户语义展示。
- 后续若做 GUI，应作为独立阶段，复用当前参数和安装内核，不要把 GUI 与安装逻辑重构绑在同一个变更里。

## 2026-04-30 — README 首页化调整

用户指出自有 README 过于简陋，希望参考 GitHub 上好的 README 结构。调整方向从“README 只是索引”改为“README 是项目首页，docs/README 是二级导航”。

新的 README 先回答项目价值、为什么需要它、它做什么、如何快速开始、核心能力和安全边界，再把详细流程链接到 docs。这样既符合 GitHub 项目首页阅读习惯，也不破坏单一信息源：版本、fallback、PAT 表、Skill 清单仍不在 README 复制维护。

## 2026-04-30 — 拟似 TUI 合并进主脚本归档

### 核心议题背景

用户先希望安装脚本更结构化、中文化、现代化，并提出“各种选择和安装可以拟似 TUI”。过程中曾短暂考虑单独入口文件，但用户明确收敛为：不要再起别的文件，而是在既有脚本里保留两个模式，一个是原来的，一个是拟似 TUI；进入脚本后再选择模式；无参数时默认进入 TUI；原来的安装模式也要包含在 TUI 内。

### Cognitive Evolution Path

1. 先保留前一轮中文化成果，不继续拆安装内核，避免把界面改造和安装行为重构绑在同一次变更里。
2. 删除单独 TUI 入口思路，把所有 TUI 函数收进 `bootstrap.ps1`，以 `-Tui` 参数和“无操作参数”检测作为入口条件。
3. 入口位置放在读取 manifest 后、UAC 提权前：这样 TUI 能展示真实应用清单，且用户选择正式安装时仍能走原来的提权流程。
4. 为避免 `bootstrap.cmd` 自带 `-PauseOnExit` 影响判断，将 `PauseOnExit`、`KeepShellOpen`、`UserHomeOverride` 视为非操作参数；只有 `-Only`、`-DryRun`、`-SkipSkills` 等安装参数才绕过 TUI。
5. TUI 首屏固定三种模式：
   - `默认安装（原来模式）`：选择 manifest 中全部应用，继续使用原安装内核。
   - `自定义选择`：应用多选 + 安装选项切换 + 执行确认。
   - `安全演练`：全量应用 dry-run，跳过 CC Switch Provider 导入，不替换旧 Skill，不启动 Skills Manager，并显式选择全部 Skill。
6. 为防止提权后管理员窗口再次进入 TUI，TUI 结果会写回 `$PSBoundParameters`，并移除 `Tui` 参数；默认安装模式内部转成显式 `-Only` 全量应用，行为等价但能稳定绕过二次菜单。

### 关键决策

- 不新增 `setup-tui.ps1` 或 `setup-tui.cmd`，入口仍是 `bootstrap.ps1` / `bootstrap.cmd`。
- 显式参数命令继续作为自动化入口，不受 TUI 默认行为影响。
- TUI 只是选择层和命令预览层，不改变 `manifest/apps.json`、precheck、fallback、Skill 三态导入或 CC Switch deep-link 导入内核。
- 安全演练模式默认带 `-AllSkills`，避免在 dry-run 验证时再停在 Profile 交互输入。

### 当前结论

- 无参数运行会进入拟似 TUI。
- `-Tui` 可强制进入拟似 TUI。
- `-DryRun -SkipSkills -SkipCcSwitch -Only git` 等旧式参数仍直接执行，不进入 TUI。
- TUI 内“默认安装（原来模式）”已经包含原流程，确认页会展示等价的显式命令。
- `docs/operations.md` 已同步入口说明。

### 后续行动指引

1. 如果继续增强 TUI，优先补“窗口宽度自适应”和“更安静的 dry-run 进度显示”，不要先拆新入口。
2. 如果未来做真正 GUI，应调用同一套参数和安装内核，避免出现 GUI 专属安装路径。
3. 如新增安装选项，必须同时更新 TUI 选项页、`docs/operations.md` 和 `.ai_memory/2_active_task.md`。

## 2026-04-30 — TUI / Skill 复选与安装进度体验修复归档

用户反馈 `vibe-coding-setup.cmd` 打开后，非管理员窗口请求 UAC 后误报“安装已完成”，而管理员窗口直接进入命令模式安装，没有默认进入 TUI；同时希望选中的应用和安装进度更明确。

本次继续坚持“不新增入口文件”的约束，只在 `bootstrap.ps1` 与 `modules/common.psm1` 内修复体验。`BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag` 被识别为自举内部参数，不再导致跳过 TUI；UAC 交接后当前窗口提示已打开管理员窗口继续安装，不再显示完成文案。

TUI 自定义流程新增 Skill Profile 复选页，运行时从 `downloads/skills.zip` 的 registry 读取真实 Profile，默认选择“全部 Skill”，也可选择一个或多个 Profile 并生成 `-SkillProfile` 命令预览。Profile 交互菜单保持简洁，只提示可输入序号/名称、多个用逗号分隔、直接回车安装全部 Skill。

安装执行阶段新增总步骤进度：工作区准备、每个应用、Skill 导入和 CC Switch Provider 导入都会显示 `[当前/总数]`。Skill 导入日志从逐目标长路径明细收敛为按 skill 聚合的进度与结果，dry-run 的 skills-manager DB 注册也改为计数摘要。

验证覆盖脚本解析、模块导入、Profile 读取、旧命令模式 dry-run、`-SkillProfile "飞书办公套件"` dry-run、内部自举参数进入 TUI 并退出、`git diff --check`。

## 2026-04-30 — 默认安装模式回归原逻辑修复

用户实际运行 `vibe-coding-setup.cmd` 后发现：TUI 首屏选择“默认安装（原来模式）”仍进入执行确认页，并把默认全量应用改写成 `-Only git,nodejs,...`；UAC 提权后的管理员窗口报错“找不到接受实际参数 cc-switch 的位置形式参数”。这说明默认模式没有真正遵循原脚本默认逻辑，同时数组参数在 UAC 重启时被拆错。

本次修复把默认安装模式改为直接返回原默认流程：不展示二次确认页，不写入 `-Only`，只写入内部 `BootstrapTuiResolved` 标记防止 UAC 后重复进入 TUI。未指定 `-Only` 时仍由原脚本按 manifest 默认全量应用执行；如果进入 TUI 前显式带了 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 或 Skill 参数，默认安装会保留这些原命令参数。

同时修复 `ConvertTo-ArgumentTokens` 的数组序列化：数组参数会压缩成逗号形式，例如 `-Only "git,nodejs,cc-switch"`，避免 PowerShell `-File` 重启时把后续元素当作位置参数。

验证覆盖脚本解析、数组 token 生成、`-BootstrapTuiResolved` dry-run 默认全量路径、`-Only "git,nodejs,cc-switch"` dry-run、`-Tui -DryRun` 首屏默认选择和 `git diff --check`。

## 2026-04-30 — 提权窗口与进度显示体验修正

用户反馈 UAC 后打开经典蓝底 PowerShell 窗口观感较差，且 `Write-Progress` 会绘制独立蓝色进度区域。当前结论：非管理员终端不能原地升级为管理员终端，但提权后的新窗口可以优先由 Windows Terminal 承载。

本次修复新增 Windows Terminal 优先提权路径：非管理员执行真实安装时，脚本先尝试用 `wt.exe` 以管理员身份启动 `powershell.exe` 并传入原参数；若系统没有 Windows Terminal 或启动失败，再回退经典 PowerShell。总进度保持 `[当前/总数] 当前步骤` 文字；应用内部下载和 winget 百分比改为脚本自绘进度条，静默 MSI/EXE 无真实百分比时显示运行中和耗时。进入 TUI 前会 best-effort 切到英文键盘布局，降低中文输入法对快捷键的干扰。

## 2026-04-30 — 本轮安装器体验修复最终闭环

本轮最终收敛为三组提交：恢复 TUI 默认安装的原逻辑、优化安装进度和提权终端体验、精简 Skill Profile 交互提示。关键用户可见行为：默认安装首屏确认后直接执行，不再展示“执行确认”；总进度只显示 `[当前/总数] 当前步骤`；应用内部下载和 winget 百分比才显示自绘进度条；UAC 后优先使用 Windows Terminal 承载管理员 PowerShell；Profile 交互菜单不再展示 `-SkillProfile` / `-AllSkills` / `-SkipSkills` 参数说明。

最终验证覆盖脚本解析、模块导入、`-Only git` dry-run、`-Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏默认执行、`git diff --check` 和 `git status --short --branch`。截至本归档，`main` 已推送且工作区干净。

## 2026-04-30 — 默认模式空 SkillProfile 提权报错修复

用户继续反馈默认模式打开 Windows Terminal 后立刻报 `缺少参数“SkillProfile”的某个参数`。这不是安装内核问题，而是 TUI 默认模式在未选择 Profile 时仍可能把空 SkillProfile 写回 `$PSBoundParameters`，提权重启时被拼成裸 `-SkillProfile`。

本次修复增加双层兜底：`bootstrap.ps1` 在 TUI 初始参数和结果写回时清洗空 Skill Profile；`modules/common.psm1` 的 `ConvertTo-ArgumentTokens` 对所有数组参数过滤空元素，并在数组为空时不输出参数名。这样默认安装、空 Skill 选择和后续数组参数重启都不会再生成缺值参数。

验证覆盖空数组 token、非空数组 token、脚本解析、`-Only git` dry-run、`-Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏默认 Enter 后完整执行，以及 `git diff --check`。

## 2026-04-30 — 安装器交互体验阶段最终归档

### 核心议题背景

这一阶段从“中文化、结构化、拟似 TUI”逐步收敛到几个明确的用户可见问题：默认模式必须沿用原安装逻辑，UAC 后不能进入错误命令模式，安装进度不能依赖 PowerShell 蓝色进度区域，Skill 选择应更人性化，中文输入法和中文标点不能干扰 TUI / 命令输入。

### Cognitive Evolution Path

1. 先修正默认模式语义：TUI 首屏选择“默认安装（原来模式）”后不再展示执行确认，也不把默认全量应用改写成 `-Only`，只写入内部 `BootstrapTuiResolved` 防止 UAC 后二次进入 TUI。
2. 修复 UAC 参数传递：数组参数压缩成逗号形式，空数组和空字符串不再输出参数名，避免 `cc-switch` 被当成位置参数或生成裸 `-SkillProfile`。
3. 改善终端体验：真实安装提权时优先用 Windows Terminal 承载管理员 PowerShell；总进度改为 `[当前/总数]` 文本，下载和 winget 这类有真实百分比的应用内部步骤才显示自绘进度条。
4. 精简 Skill 交互：Profile 菜单只保留序号/名称、多选和回车默认全部 Skill，不再把命令行参数说明塞进 TUI。
5. 提升中文环境兼容性：Profile / app 多选解析统一支持英文逗号、中文逗号和顿号；进入 TUI 前 best-effort 激活英文输入布局，并向前台终端窗口发送输入语言切换请求。

### 当前结论

- 当前 `main` 上的安装器已完成本轮体验修复并推送。
- 用户手册入口已同步：`README.md`、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md`。
- 稳定事实已同步到 `.ai_memory/1_project_context.md`，当前任务快照已同步到 `.ai_memory/2_active_task.md`。
- 这一阶段没有把用户后续提出的“完整现代化 TUI 信息架构重做”混进补丁；后续应作为单独设计阶段处理。

### 验证闭环

- 脚本解析：`bootstrap.ps1` / `modules/common.psm1`。
- 旧命令模式 dry-run：`-Only git`。
- 默认 TUI dry-run：`-Tui -DryRun -SkipSkills -SkipCcSwitch`。
- 中文分隔符 dry-run：`-Only "git，nodejs、cc-switch"`。
- Profile 中文分隔符 dry-run：`-SkillProfile "飞书办公套件，前端开发套件、GitHub 工作流套件"`。
- `git diff --check`。

## 2026-04-30 — Skill bundle 按需获取与下载进度修复

用户指出 TUI 一开始显示“正在获取 Release 资产：downloads/skills.zip”会显得卡住。根因是旧流程为了在 TUI 自定义页展示 Profile，进入 TUI 前就同步下载 `skills.zip`；这个动作发生在用户做出选择之前，且 bootstrap 自举下载函数没有自绘进度。

本次修复把 Skill bundle 获取改为按需：TUI 首屏只展示运行模式，不再预取 `skills.zip`；只有用户走到自定义流程的 Skill 复选页时，才获取并读取 Profile。默认安装、安全演练或命令模式如果最终需要导入 Skill，则仍在安装阶段按需获取 bundle。

同时把 `Invoke-BootstrapDownloadFile` 从 `Invoke-WebRequest -OutFile` 改为流式下载，按 `ContentLength` 输出脚本自绘进度条。这样 Release 资产下载会显示百分比；如果服务器没有返回文件大小，则至少会显示完成状态。这个改动不引入 PowerShell `Write-Progress`，保持终端输出风格统一。

验证覆盖脚本解析、TUI 首屏退出不触发 `skills.zip` 获取、自定义流程进入 Skill 复选页才读取缓存 bundle、旧命令模式 dry-run 和 `git diff --check`。

## 2026-04-30 — TUI 现代化计划与 Skill bundle 解压进度修复

用户重新收敛下一阶段目标：把现有“自定义选择”改名并重做为 TUI 模式 / 控制台工作台；默认安装和安全演练保持顶层入口，TUI 内部不再把软件、行为和 Skill 都做成同一种复选。复选主要用于 Skill / Profile，软件和行为应改成任务式菜单，支持检查当前版本、判断新增内容或可更新内容，并选择安装或更新。

本次先把该方向写入 `plans/2026-04-30-tui-modernization-workbench.md`，不立即展开大重构。计划明确不新增入口文件，继续复用 `bootstrap.ps1` / `bootstrap.cmd` 和现有安装内核；TUI 首屏仍不预取 `skills.zip`，只有 Skill 状态检查或 Skill 安装选择需要时才按需获取。

同时修复当前最影响观感的问题：Skill bundle 下载已有脚本自绘进度，但解压仍走 `Expand-Archive`，会触发 PowerShell 宿主蓝色进度区域。`Install-SkillBundle` 现在改为调用 .NET `System.IO.Compression.ZipFile` 流式解压，复用 `Write-OperationProgress` 同一行刷新，并加入 zip-slip 路径越界防护。

后续若继续现代化 TUI，应先按计划重做信息架构，而不是继续在旧“自定义选择”里增加复选项。

## 2026-04-30 — TUI 现代化工作台落地

本次按前一阶段计划重做 TUI 信息架构：顶层仍保留“默认安装（原来模式）”和“安全演练”，中间入口从“自定义选择”改为“TUI 模式”。进入 TUI 模式后，不再把软件、行为和 Skill 全部做成同一种复选，而是进入控制台工作台。

工作台内的动作是：检查软件状态、安装 / 更新软件、检查 Skill 状态、安装 Skill、执行摘要。软件状态页复用现有版本门禁判断，展示当前版本、目标版本和建议动作；软件安装动作页提供建议项、全部应用和手动选择。Skill 状态页按需读取 `skills.zip`，展示 bundle skill、本机已安装、可能新增和 Profile 数量；Skill 安装页继续使用 Profile 复选，这是当前主要复选入口。

为了让“只安装 Skill”成为真实路径，而不是被迫携带一个软件项，本次新增 `-SkipApps`。命令模式和 TUI 工作台都可以用它跳过应用安装阶段，只保留工作区准备、Skill 导入和其它被选中的阶段。

验证覆盖脚本解析、模块导入、`-SkipApps` Skill dry-run、TUI 工作台 Skill 复选到执行摘要 dry-run、TUI 软件状态页展示和 `git diff --check`。
## 2026-04-30 — winget 输出收敛与 Skills Manager 场景注册修复

用户在真实安装截图中指出 winget 原始英文输出太多，下载进度会连续刷多行；随后进一步指出 Skill 不应默认写入 Skills Manager 的默认场景，否则所有 Skill 都会堆在一起，同时怀疑已有 Skill 场景下可能误装全部。

本次把 winget 输出层收敛在 `Write-WingetOutputLines`：过滤许可证、免责声明、URL 和重复进度行，常见状态翻译为中文，并把 `1024 KB / 149 MB` 这类下载输出解析为百分比，复用 `Write-OperationProgress` 同一行刷新。未知耗时进度也改为回车覆盖，避免长时间安装时反复刷屏。

Skill 导入侧新增 Skills Manager 场景注册策略：`prompt/default/custom/skip`。TUI 安装 Skill 后会让用户选择写入当前默认场景、写入自定义场景，或跳过场景注册只复制 Skill 文件；命令模式对应 `-SkillsManagerScenarioMode` 与 `-SkillsManagerScenarioName`。DB 同步仍会维护 `skills` 和 `skill_targets`，但只有选择 `default` 或 `custom` 时才写 `scenario_skills` 和 `scenario_skill_tools`。

同时修复误导入全部的风险：TUI Skill 复选页新增“跳过 Skill 导入”；用户清空 Profile 后回车不再等价为全部 Skill，而是提示必须选择全部、至少一个 Profile 或跳过。命令模式交互选择中输入 `0` 才导入全部，直接回车改为跳过 Skill 导入；非交互式环境仍保留旧兼容，未指定 Profile 时默认导入全部。

文档同步到 `README.md`、`docs/README.md`、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md` 和 `docs/roadmap.md`；稳定事实同步到 `.ai_memory/1_project_context.md`，当前状态同步到 `.ai_memory/2_active_task.md`，流水追加到 `.ai_memory/3_work_log.md`。

验证覆盖脚本解析、模块导入、`git diff --check`、旧 `-Only git` dry-run、`-SkillsManagerScenarioMode skip` dry-run、`-SkillsManagerScenarioMode custom` dry-run，以及 TUI 工作台从 Skill 复选到场景注册和执行摘要的冒烟验证。

## 2026-04-30 — 捕获输出中的进度刷屏修复

用户发现 `skills.zip` 解压进度在 Codex 输出里又变成多段连续文本。根因不是重新调用了 `Expand-Archive`，而是脚本自绘进度使用 `\r` 回车覆盖，真实终端会覆盖同一行，但 Codex / CI / 日志重定向这类捕获环境会把每次刷新保留下来，看起来像多行刷屏。

本次在 `modules/common.psm1` 的 `Write-OperationProgress` 和 `bootstrap.ps1` 的 `Write-BootstrapDownloadProgress` 增加输出环境判断：只有交互式且 stdout 未重定向时才使用回车覆盖动态刷新；非交互或捕获输出环境跳过中间百分比，只打印完成行。这样真实 Windows Terminal 仍保持现代化单行进度，聊天 / 日志捕获里不会再展开 4%、9%、14% 等中间状态。

文档同步到 `docs/operations.md` 和 `docs/installer-flow.md`，长期事实同步到 `.ai_memory/1_project_context.md`，当前状态与流水同步到 `.ai_memory/2_active_task.md` 和 `.ai_memory/3_work_log.md`。

## 2026-04-30 — registry 驱动 Skill / MCP 安装闭环

### 核心议题背景

用户指出 `vibe-coding-setup` 的来源应是 `00000-model`，而 `00000-model` 里额外整理的视频、办公等 Skill 套件没有被安装器正常打包安装；同时 CLI 依赖、GitHub / 飞书工具、MCP 和 Antigravity 也需要纳入后续可扩展安装边界。

### Cognitive Evolution Path

1. 先确认根因不是单个 Profile 漏选，而是旧安装器主要消费离线 bundled skills，没有完整消费 `registry.tar.gz` 里的 external skills、MCP 和 prereqs。
2. 把来源责任收敛到 `00000-model/00-编程配置/registry/*.yaml`：profiles 只引用 skill / mcp 名称，requires 只引用 prereqs，安装器不再维护另一份清单。
3. 扩展安装器行为：external skill 支持 git repo、archive、local_path；homepage-only 只提示人工处理，避免把不可安装来源伪装成成功。
4. 扩展 prereq / CLI 处理：按 `check` 先判定缺失，再走平台字段或通用包管理器命令；单项失败汇总告警，不阻断其它可安装项。
5. 扩展 MCP 写入目标：Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI、Antigravity。Antigravity 独立写入 `~/.gemini/antigravity/mcp_config.json`。
6. 测试路径引入 `VIBE_CODING_USER_HOME` 隔离；在隔离环境下跳过 Claude Code CLI 注册，防止真实用户配置被测试污染。

### 当前结论

- `vibe-coding-setup` 现在是 registry 消费者；Skill / MCP / prereq / Profile 来源仍由 `00000-model` 维护。
- 用户手册入口已同步到 `README.md`、`docs/README.md` 和 `docs/skill-import.md`，不复制 registry 清单。
- 下一步若新增 github、飞书或其它 CLI，只应先加 `00000-model` 的 `prereqs.yaml` 和引用方 `requires`。

### 验证闭环

- `modules/common.psm1` import 通过。
- 多个 Profile dry-run 通过：前端开发套件、中文办公自动化套件、媒体创作套件、演示文稿与文档套件。
- 隔离用户目录下 MCP 写入覆盖 Codex、Claude Desktop、Cursor、Gemini CLI、Antigravity。
- 临时 bundle 验证 `local_path` 和 `archive_url` external skill 可真实导入。

## 2026-04-30 — 安装计划顺序与分区显示重排

### 核心议题背景

用户在并行预检查落地后继续指出，安装器虽然已经先检查是否存在、已存在才查版本，但整体顺序和显示仍不够清晰：Skill 下载应在 Skill 选择前可见；预检查后的选中安装清单应立即展示每项模式；跳过项不应继续出现后续安装提示；每个区域都应有标题、分块和必要播报，特别是 CC Switch Provider 的地址、API、名称等输入区。

### Cognitive Evolution Path

1. 先保留既有核心约束：应用预检查并行，但实际安装继续按 manifest `order` 串行，避免多个安装器同时竞争锁。
2. 把预检查结果前置为用户可见的“安装计划”：逐项输出安装、更新、跳过或检查失败，并统计四类数量。
3. 把跳过和检查失败从安装循环中剥离：它们只写入 Summary，不再占用实际安装进度，也不再打印“准备安装”提示。
4. 区分安装与更新的执行播报：安装项显示“准备安装应用”，更新项显示“准备更新应用”，避免用户把更新误读为重装。
5. 重排 Skill 安装入口：进入 Skill Profile 选择前先展示 `Skill Bundle 准备` 分区，让下载 / 读取 bundle 的动作有明确阶段。
6. 补齐分区显示：TUI 工作台、执行摘要和 CC Switch Provider 配置区都增加标题与说明；Provider 预填值直接进入输入提示，回车保持，输入覆盖；API Key 仍保持隐藏和脱敏。

### 当前结论

- 预检查现在不仅决定执行策略，也成为后续安装计划的唯一来源。
- “跳过”语义已经从后续安装流程中移出，只保留在计划和 Summary 中。
- CC Switch Provider 配置区已经按说明、默认值、输入区、API Key、配置摘要拆分，减少阅读压力。
- `docs/installer-flow.md` 已同步新的阶段顺序。

### 验证闭环

- `Import-Module .\modules\common.psm1 -Force`。
- `bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
- `bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only codex-provider-sync`。
- `Read-CodexProviderInput` 预设值显示验证，未打印 API Key 明文。
- `git diff --check`。

## 2026-04-30 — 播报降噪与 Provider 输入区合并

### 核心议题背景

用户继续基于真实运行日志指出：虽然预检查和跳过逻辑已经正确，但 9 个应用全跳过时仍逐项输出 `Git：跳过`、`Node.js：跳过` 等内容，前置播报不够舒服。用户希望保留“预检查完成”和“应用执行计划统计”，只在真正需要安装或更新时显示应用明细。同时，CC Switch Provider 配置不应分成“当前默认值 / 输入区 / API Key”三段，而应把默认值和 API Key 直接吞并进输入区。

### Cognitive Evolution Path

1. 将应用计划播报从“逐项列所有模式”收敛为“先统计，后仅列安装 / 更新项”。跳过项和检查失败项仍进入 Summary，保留审计原因，但不再占据前置执行播报。
2. 删除 `安装计划` 与解释性日志行，避免在每次运行时重复提示规则。
3. 保留安装 / 更新项的可见性：只有存在待执行项时，才输出“准备安装或更新的应用清单”。
4. 合并 Provider 配置区域：保留“说明 / 输入区 / 配置摘要”，去掉单独的“当前默认值”和“API Key”区。
5. Provider 名称、Base URL、模型改为右侧灰色占位；回车保留默认值，开始输入后清掉占位并覆盖。
6. API Key 在同一个输入区中处理，输入时隐藏；预设 API Key 只显示来源，不打印明文。
7. 自绘输入行按当前行尾清理，避免中文占位或长默认值在 Windows Terminal 中残留。

### 当前结论

- 预检查阶段现在只负责输出统计；跳过明细只保留在执行摘要。
- Provider 配置区的信息架构已经收敛为一个输入区，不再拆散默认值和 API Key。
- `docs/operations.md` 和 `docs/installer-flow.md` 已同步当前行为。

### 验证闭环

- `Import-Module .\modules\common.psm1 -Force`。
- `git diff --check`。
- `bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
- `bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch`。
- Provider 输入 TTY 冒烟：回车保留默认值、输入覆盖、API Key 只显示星号 / 状态，不明文输出。
