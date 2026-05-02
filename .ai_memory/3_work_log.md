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
- 安装执行阶段新增总步骤进度：工作区、应用安装、Skill 导入和 CC Switch Provider 导入会显示 `[当前/总数]` 文本日志。
- Skill 导入输出从逐目标长路径明细收敛为按 skill 聚合的进度和结果；dry-run 注册 skills-manager DB 也改为计数摘要。
- 验证通过：脚本解析、模块导入、Profile 读取、旧命令模式 dry-run、`-SkillProfile "飞书办公套件"` dry-run、内部自举参数进入 TUI 并可退出、`git diff --check`。

## 2026-04-30

- 修复 TUI 默认安装模式：选择“默认安装（原来模式）”后不再进入执行确认页，也不再写入 `-Only` 全量应用清单，而是直接沿用原脚本未指定 `-Only` 时的默认全量安装逻辑。
- 默认安装模式会保留进入 TUI 前显式传入的 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 和 Skill 参数，避免 `-Tui -DryRun` 被吞参数后触发 UAC。
- 新增内部 `BootstrapTuiResolved` 标记，用于 UAC 提权后跳过二次 TUI；该标记不改变安装集合。
- 修复 UAC 重启时数组参数被拆成多个位置参数的问题：`ConvertTo-ArgumentTokens` 会把数组压缩成逗号形式，例如 `-Only "git,nodejs,cc-switch"`。
- 验证通过：脚本解析、数组参数 token 生成、默认安装内部标记 dry-run 全量路径、`-Only "git,nodejs,cc-switch"` dry-run、`-Tui` 首屏退出、`git diff --check`。
- 调整提权窗口与进度显示体验：UAC 后优先用 Windows Terminal 承载管理员 PowerShell；关闭 `Write-Progress`；总进度保留文字，应用内部下载和 winget 百分比显示自绘进度条，静默 MSI/EXE 显示运行中和耗时；进入 TUI 前 best-effort 切换英文键盘布局。
- 精简 Profile 交互菜单提示：移除 `-SkillProfile` / `-AllSkills` / `-SkipSkills` 参数说明，只保留序号/名称、逗号多选和回车安装全部 Skill。
- 最终归档闭环：补充 active task 最新状态和 archive 总结；验证脚本解析、dry-run、TUI 默认直接执行、`git diff --check` 和工作区状态后提交推送。

## 2026-04-30

- 修复默认 TUI 模式进入 UAC / Windows Terminal 后立刻报 `缺少参数“SkillProfile”的某个参数` 的问题。
- 根因是未选择 Skill Profile 时仍可能把空数组或空元素带入提权重启参数，导致生成裸 `-SkillProfile`。
- `bootstrap.ps1` 在 TUI 初始参数和结果写回时统一清洗空 Skill Profile；`modules/common.psm1` 的 `ConvertTo-ArgumentTokens` 也会跳过空数组和空字符串元素。
- 验证通过：空/非空数组 token 单元验证、脚本解析、`-Only git` dry-run、`-Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏默认 Enter 后完整执行、`git diff --check`。

## 2026-04-30

- 提升多选输入兼容性：Profile / app 选择解析现在支持英文逗号 `,`、中文逗号 `，` 和顿号 `、`。
- 同步更新 Profile 交互提示与 `docs/skill-import.md`，避免文档仍只写“逗号分隔”。

## 2026-04-30

- 强化 TUI 进入前的英文输入布局切换：保留 `LoadKeyboardLayout` / `ActivateKeyboardLayout` 当前进程路径，并补充向前台终端窗口发送 `WM_INPUTLANGCHANGEREQUEST`。
- 该实现仍按 Windows 会话和焦点限制做 best-effort，不改用户系统输入法配置；验证通过脚本解析和 `-Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏退出。

## 2026-04-30

- 完成本轮安装器体验修复最终归档：同步 README、运行命令、安装流程、Skill 导入契约和 `.ai_memory`。
- 明确后续现代化 TUI 信息架构重做作为下一阶段，不混入本轮 bugfix / 体验修复闭环。

## 2026-04-30

- 优化 `skills.zip` 获取时机：TUI 首屏不再预取 Skill bundle，只有进入 Skill 复选页或实际导入 Skill 时才按需获取。
- 自举下载函数改为流式下载并显示脚本自绘进度条，Release 资产下载不再只显示一行“正在获取”。

## 2026-04-30

- 写入下一阶段 TUI 现代化工作台重做计划：顶层保留默认安装、TUI 模式、安全演练；TUI 内部聚焦状态检查、软件安装 / 更新、Skill 状态和 Skill 安装选择。
- 修复 Skill bundle 解压进度：`Install-SkillBundle` 不再调用 `Expand-Archive`，改为 .NET ZipFile 流式解压并复用脚本自绘同一行进度，避免 PowerShell 宿主蓝色进度区域。
- 解压路径加入 zip-slip 越界写出防护，避免恶意 zip 条目逃出临时解压目录。

## 2026-04-30

- 将顶层“自定义选择”改为“TUI 模式”，并重做为控制台工作台。
- TUI 工作台新增软件状态页、软件安装 / 更新动作页、Skill 状态页、Skill Profile 复选页和执行摘要页。
- 新增 `-SkipApps`，支持只执行 Skill 导入；TUI 工作台选择 Skill 后不再被迫带软件安装项。
- 验证通过：脚本解析、模块导入、`-SkipApps` Skill dry-run、TUI 工作台 Skill 复选到执行摘要 dry-run、TUI 软件状态页展示。
- 收敛 winget 输出：过滤许可证 / 免责声明 / 重复进度行，常见状态中文化，下载进度复用同一行自绘进度。
- 调整 Skills Manager 场景注册：Skill 导入后可选择默认场景、自定义场景或跳过场景注册；TUI Skill 复选页新增跳过 Skill 导入，并修复空 Profile 选择误导入全部的问题。
- 同步 README、docs 索引、Skill 导入契约、安装流程、运行命令、路线图和 `.ai_memory` 归档，保证当前交互语义一致。
- 修复捕获输出中的进度刷屏：真实交互终端仍用单行动态刷新，Codex / CI / 重定向环境只输出完成行，避免 `\r` 覆盖被展开成多行。

## 2026-04-30

- 应用安装前新增并行预检查：先判断所选应用是否存在；缺失项不查最新版本，后续直接安装；已存在项才查询目标版本并决定更新或跳过。
- 主安装循环复用预检查结果，实际安装仍按 manifest `order` 串行执行，避免多个安装器同时运行产生锁冲突。
- TUI 软件状态页复用批量预检查结果；工作台菜单、执行确认页和 CC Switch Provider 输入流程增加分段标题、默认值来源和密钥摘要显示。
- 验证通过：缺失项单项/批量决策不会查询 latest，`-DryRun -SkipSkills -SkipCcSwitch -Only git` 主流程 dry-run，`git diff --check`。

## 2026-04-30

- 扩展 Skill bundle 消费逻辑：安装器读取 registry 中的 skills / mcp / prereqs / profiles，支持 bundled skill、external skill、前置 CLI 依赖和 MCP 写入。
- external skill 支持 git repo、zip/tar archive、local_path 三类自动来源；homepage-only 只告警提示人工处理。
- MCP 写入覆盖 Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI、Antigravity；隔离用户目录时跳过 Claude Code CLI 注册，避免污染真实配置。
- 同步 README、docs 索引、Skill 导入契约和 `.ai_memory`，把 `00000-model/00-编程配置/registry/*.yaml` 明确为 Skill / MCP / prereq / Profile 唯一来源。

## 2026-04-30

- 重排应用安装顺序：预检查后立即输出“安装计划”，逐项标明安装、更新、跳过或检查失败，并给出统计。
- 跳过项和检查失败项不再进入后续安装循环，只进入 Summary；实际安装阶段只处理安装 / 更新项，并区分“准备安装应用”和“准备更新应用”。
- Skill 安装路径新增 `Skill Bundle 准备` 分区，先显示下载 / 读取 bundle 的阶段，再进入 Skill Profile 选择。
- TUI 工作台、执行摘要和 CC Switch Provider 配置区补齐标题与分块说明；Provider 名称、Base URL、模型等预填值直接出现在输入提示里，回车保持、输入覆盖。
- 同步 `docs/installer-flow.md` 和 `.ai_memory`，准备提交推送。

## 2026-04-30

- 收敛应用计划播报：预检查后只输出执行计划统计，只有安装 / 更新项才逐项显示，跳过项不再刷屏。
- 合并 CC Switch Provider 的当前默认值和 API Key 区域到“输入区”；真实控制台中默认值以右侧灰色占位显示，回车保持，输入覆盖。
- 修复自绘输入行清理逻辑，改为清到当前行尾，避免中文占位或长默认值残留。
- 同步 `docs/operations.md`、`docs/installer-flow.md` 和 `.ai_memory`，准备文档一致性检查后提交推送。

## 2026-04-30

- 保留“全部 Skill”旧语义，只导入 bundle 内离线 Skill。
- 新增“所有套件” / `-AllSuites`，按所有 Profile 并集合并 Skill、external Skill、MCP 和前置 CLI。
- TUI 选择页、命令交互菜单和执行日志都会显示 Skill / MCP / CLI 数量，避免把“全部 Skill”和“所有套件”混淆。

## 2026-05-01

- 补齐 TUI 工作台单项安装入口：在“安装套件”之外新增“任选安装 Skill”“任选安装 MCP”“任选安装 CLI”。
- 新增命令模式参数 `-SkillName`、`-McpName`、`-CliName`，TUI 单项选择会写回这些参数并继续走原有 UAC、dry-run、Skill bundle、MCP 写入和前置依赖安装路径。
- 新增 bundle 组件状态读取：状态页汇总 Profile、Skill、MCP、CLI 数量，展示 MCP 配置目标和 CLI 检测结果；缺失 CLI 的 check 命令返回未检测到，不中断状态页。
- 验证通过：脚本解析、模块导入、单项 Skill dry-run、单项 MCP dry-run、单项 CLI dry-run、`-AllSuites` dry-run、组件状态读取。

## 2026-05-01

- 兼容 external skill 下载 URL 没有归档扩展名的来源：当下载路径不以 `.zip`、`.tar.gz` 或 `.tgz` 结尾时，安装器按 `.zip` 保存后再进入既有解压流程。
- 该兼容用于 OpenClaw/ClawHub `chinese-office-automation` 下载端点；已验证下载产物是 zip 且包含 `SKILL.md`。
- 使用刷新后的 registry bundle 执行 `-AllSuites -DryRun`，三条办公 external skill 均进入自动安装计划：`chinese-office-automation`、`running-effective-meetings`、`daily-feishu-cli-export`。

## 2026-05-02

- 优化命令交互 Profile 菜单排版：`0`、`00` 和普通套件统一分为名称、数量摘要、说明三行，避免长描述挤在同一行。
- `0` 现在明确显示全部离线 Skill 数、MCP 0、CLI 0；`00` 明确显示所有套件数量以及 Profile 并集的 Skill / MCP / CLI 数。
- TUI 光标停在套件时新增当前项详情，展示将安装的 MCP 和将处理的 CLI 依赖；默认交互菜单在输入后、执行前输出同样摘要。
- 同步 `docs/skill-import.md` 和 `.ai_memory`；验证通过脚本解析、交互菜单预览、`-AllSkills` dry-run 和 `-AllSuites` dry-run。

## 2026-05-02

- 收敛 TUI 工作台软件入口：移除单独“检查软件状态”动作，改为“检查并安装 / 更新软件”，进入后先跑 precheck，再默认勾选所有需要安装或更新的建议项，用户可用空格去除。
- 拆清 Skill 状态与套件状态：Skill 状态页只解析 Skill 清单和本机 Skill 安装状态，不再检测 MCP / CLI；新增“检查所有套件”承载 Profile、MCP 配置和 CLI 检测总览。
- 所有会读取 `skills.zip` 或组件状态的 TUI 路径先显示读取提示，避免下载 / 解析期间无反馈。

## 2026-05-02

- 清理当前用户可见入口中的历史默认安装措辞：TUI 首屏改为“默认安装”，说明改为按默认配置安装应用并导入 Skill 与 CC Switch。
- `全部 Skill` 的说明改为中性描述：只导入 bundle 内离线 Skill，不安装 MCP / CLI。
- 重新验证 TUI：软件入口会先检查状态并展示建议项复选；Skill 状态页快速返回 Skill-only 清单；所有套件状态页展示 Profile / MCP / CLI 总览。

## 2026-05-02

- 将顶层“TUI 模式”和工作台标题统一改名为“自定义模式 / 自定义工作台”。
- 合并自定义模式检查与安装入口：移除独立“检查 Skill 状态”“检查所有套件”，改为“检查并安装套件”“检查并任选安装 Skill / MCP / CLI”。
- 自定义模式内新增 Skill registry 与组件状态缓存；Skill / 套件入口走轻量 Skill-only 读取，MCP / CLI 入口才读取 MCP 配置和 CLI 检测状态，并在本轮复用。
- 套件、Skill、MCP、CLI 长列表改为分页渲染；顶部显示已选数量与摘要，底部显示当前项详情，避免长列表强制滚到底部导致方向键抽动。
- 默认模式和自定义模式的软件 precheck 增加完成数量进度；Skill / MCP / CLI 状态扫描增加完成数量进度；generic prereq 命令也显示执行中提示。
- 修复 winget 成功后不退出的卡住体验：已看到成功输出后短暂等待，如果外层 winget 仍不退出则自动收尾并继续后续检测。
- 验证通过：脚本解析、模块导入、`git diff --check`、`-DryRun -SkipSkills -SkipCcSwitch -Only git,nodejs`、`-DryRun -SkipApps -SkipCcSwitch -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip -AllSuites`。

## 2026-05-02

- 继续 debug 自定义模式慢的问题：确认 MCP 状态检查原先每个条目都会调用一次 `claude mcp list`，10 个 MCP 会被 Claude Code CLI 拖到几十秒。
- 将 Claude Code MCP 列表改为一次读取并缓存到哈希表，MCP 状态循环只做本地匹配；本机验证 10 个 MCP 进度在同一秒内完成。
- 修复飞书 CLI 状态误判：当前 registry 仍写 `lark --version`，但 `@larksuite/cli` 实际安装 `lark-cli`；安装器兼容该别名后，lark 状态可识别为已安装。
- 实测 `npm i -g @larksuite/cli --loglevel=error` 成功，`lark-cli --version` 为 `1.0.23`；`yt-dlp --version` 为 `2026.03.17`。

## 2026-05-02

- 将应用并行预检查的 `检查进度：N/M 个应用已完成` 从逐条日志改为 `Write-OperationProgress` 单行刷新。
- 完成时刷新为 `检查 ... 100% N/M 个应用已完成`，随后再输出原有 `预检查完成` 汇总。
- 验证通过：`bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git,nodejs` 只保留最终完成进度行。
- 继续统一所有检查进度：Skill-only 状态扫描、MCP 状态扫描、CLI 状态扫描也改为同一行刷新，真实终端动态覆盖，捕获输出只保留完成行。
