# Project Context

## 项目目标

这个仓库用于在 Windows 上一键部署开发环境、桌面工具和 Skill 包，主入口是 `bootstrap.ps1`。当前分发模式是“在线安装 + Release fallback + Skill bundle 镜像”，不是纯离线打包仓库。

## Single Source of Truth

- 安装执行逻辑：`bootstrap.ps1`、`modules/common.psm1`
- 应用清单、版本门禁、fallback 文件名：`manifest/apps.json`
- GitHub 项目首页：`README.md`
- 二级文档导航：`docs/README.md`
- 安装流程说明：`docs/installer-flow.md`
- Skill 导入说明：`docs/skill-import.md`
- 资产刷新说明：`docs/asset-refresh.md`
- 本机运行命令：`docs/operations.md`
- 后续路线：`docs/roadmap.md`
- Skill / MCP / prereq / Profile 来源数据：`indieark/00000-model/00-编程配置/registry/*.yaml`
- TUI 现代化工作台计划：`plans/2026-04-30-tui-modernization-workbench.md`
- PAT / Secret 治理：`.agent/rules/pat-secret-governance.md`
- 文档治理规则：`.agent/rules/documentation-governance.md`

## 稳定事实

- 应用安装先做并行 precheck，再输出执行计划统计；缺失项不查版本并进入安装，已存在项才查目标版本并决定更新或跳过。跳过项和检查失败项只进入执行摘要，不再进入后续安装循环；计划明细只展示“安装 / 更新”项，避免跳过项刷屏。
- 前置自举标题按入口区分：只有进入 TUI 首屏前的共同自举显示 `获取依赖`；命令模式、默认安装、TUI 首屏选择默认安装后或 TUI 默认安装 UAC 续跑后的主流程显示 `步骤一：获取依赖`。`Sync-BootstrapDependencies` 即使复用本地 `modules/common.psm1` 与 `manifest/apps.json` 缓存，也会显示 `同步 ... 100% 2/2 个依赖已完成`。默认安装后续主流程从 `步骤二：应用安装`、`步骤三：配置导入`、`步骤四：插件安装` 继续展示，完成提示为 `恭喜：安装流程完成`；工作区准备、配置导入和插件安装不再额外输出 `[当前/总数]` 阶段提示；主流程大区域之间保留两行空白，区域内小分块保持一行空白。CC Switch 配置导入在 Skill / 套件导入前执行，执行摘要名称收敛为“配置导入”。
- `skills.zip` 独立于应用安装；只要未传 `-SkipSkills`，脚本会在需要读取 Profile / registry 或导入 Skill、MCP、CLI 时按需获取，并在配置导入后尝试导入。
- `skills.zip` 由 `indieark/00000-model` registry bundle 构建，经当前仓库 `bootstrap-assets` 镜像为公开资产后分发，终端用户机器不需要 PAT。
- `skills.zip` 刷新是两段链路：先由 `00000-model` 的 `build-bundle` workflow 生成私库 bundle，再由本仓库 `Refresh bootstrap release assets` workflow 镜像为公开 `bootstrap-assets/skills.zip`；只完成上游 build 不代表终端会拿到新 bundle。
- TUI 首屏不预取 `skills.zip`；只有进入套件、Skill、MCP、CLI 相关入口，或后续安装 / 演练实际要导入 Skill、MCP 或 CLI 时才按需获取。
- `modules/common.psm1` 与 `manifest/apps.json` 是自举依赖缓存；默认复用已存在文件，显式传 `-RefreshBootstrapDependencies` 会刷新；如果本地 `common.psm1` 缺少当前 TUI 组件进度能力，bootstrap 也会强制刷新依赖。本地 `downloads/skills.zip` 是 Skill bundle 缓存；旧缓存会导致 TUI 显示旧文案、旧 Skill 数量或旧 MCP / CLI 统计。排查时先确认 release asset 是否刷新，再删除本地缓存或使用 `-RefreshSkillBundle`。
- 下载、winget 下载 / 安装和 Skill bundle 解压统一使用脚本自绘同一行进度；应用 precheck 和 Skill / MCP / CLI 状态扫描也复用脚本自绘进度，其中组件扫描统一显示 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 标签；旧 `common.psm1` 兼容路径会由 bootstrap 输出新版预览并静默旧 Host 进度，避免套件页重复 MCP / CLI；winget 输出会过滤许可证、免责声明和重复进度行，并中文化常见状态；Skill bundle 解压不再调用 `Expand-Archive`，避免 PowerShell 宿主蓝色进度区域。非交互捕获输出不打印中间百分比，只保留完成行，避免 `\r` 被展开成多行刷屏。
- Skill 导入是“Profile 选择 + `.skill-meta.json` 来源判定 + 增量同步 + Skills Manager SQLite 注册”的组合流程。
- Skill 选择语义已经拆开：`全部 Skill` / `-AllSkills` 导入 registry 全部 Skill，bundle 内 custom / vendored 直接导入，external 按 `source` 自动拉取或复制；它不自动写入所有 MCP，也不安装所有 CLI。`所有套件` / `-AllSuites` 按所有 Profile 并集导入 Skill、external Skill、MCP 和前置 CLI。命令交互菜单和 TUI 都应明确显示 `全部 Skill`、`所有套件`、各套件自身的 Skill / MCP / CLI 数量；`全部 Skill` 的显示数量至少覆盖 registry 条目数、bundle 离线目录数和所有套件展开后的 Skill 并集，不能小于 `所有套件` 的 Skill 数。
- `00000-model` registry 约定：自创 `pro-*` / `use-*` Skill 统一归入 `AI 调用基础套件`，其它业务套件不重复挂这些通用自创能力。
- Profile 菜单顺序不在安装器中硬编码；安装器通过 `Read-SkillProfilesFromRegistry` 按 `skills.zip` 内 `registry.tar.gz/profiles.yaml` 的原始顺序展示。当前顺序来源由 `indieark/00000-model/00-编程配置/registry/profiles.yaml` 维护。
- 默认模式的插件安装输入区在交互终端中默认不安装任何 Profile；直接回车 / 不填会跳过 Skill 导入，只有输入 `0`、`00` 或具体套件序号 / 名称才安装。
- registry 驱动导入已经支持 registry 全量 Skill、bundled skill、external skill、MCP 和前置依赖。external skill 可从 `repo`、`archive_url` / `download_url`、`local_path` 自动导入；只有 `homepage` 的条目只提示人工处理。
- 前置依赖由 `registry/prereqs.yaml` 驱动，安装器按 `check` 先判定，再根据平台和 `command` / `npm` / `pipx` / `pip` / `brew` / `winget` / `scoop` 等安装方式处理；单项失败汇总告警，不阻断后续可安装项。
- MCP 写入由 `registry/mcp.yaml` 与 Profile 引用驱动，目前覆盖 Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI 和 Antigravity；Antigravity 的目标文件是 `~/.gemini/antigravity/mcp_config.json`。
- 同名 Skill 三态判定已经落地：`Tracked` 增量同步，`Orphan` 默认备份替换，`Foreign` 默认跳过。
- `CC Switch` Provider 导入只走 `ccswitch://v1/import` deep link，不写 SQLite。
- `CC Switch` Provider 配置区按“输入区 / 配置摘要”分块展示；输入区直接吞并默认值和 API Key。Provider 名称、Base URL、模型等预填值在真实控制台右侧以灰色占位显示，回车保持，输入则清除占位并覆盖。API Key 继续隐藏输入，预设密钥只显示来源不显示内容。
- 面向用户的脚本提示、日志、错误和执行摘要默认使用简体中文；为兼容 Windows PowerShell 5.1，脚本文案通过 UTF-8 base64 解码输出，源码文件保持 UTF-8 无 BOM。
- `bootstrap.ps1` 内置拟似 TUI 与自动化命令模式：无安装参数或显式 `-Tui` 时进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills` 等操作参数时继续走自动化模式；TUI 首屏保留“默认安装”“自定义模式”“安全演练”，其中自定义模式进入控制台工作台。
- 自定义模式聚焦任务动作：检查并安装/更新软件、检查并安装/更新套件、检查并安装/更新 Skill、检查并安装/更新 MCP、检查并安装/更新 CLI；工作台先显示 `[可执行动作]`，只有已有可执行选择后才在动作区下方显示 `[当前选择]` 与 `开始执行`，进入最终 `执行确认` 页后按 Enter 才返回执行参数。
- 自定义模式的 Skill / 套件 / MCP / CLI 相关读取结果会在本轮工作台中复用；Skill 入口只检查 Skill，MCP 入口只检查 MCP，CLI 入口只检查 CLI，套件入口才全量检查 Skill / MCP / CLI 并展示总览。套件页标题为“套件复选项”，列表行只显示名称，Bundle Skill、可选 Skill、本机已安装、可能新增以及当前项的 Skill / MCP / CLI 数量、说明、依赖放在顶部总览和当前项详情中；单项 Skill 选择页合并 `BundleSkills + RegistrySkills` 后去重展示，并显示 Skill 总数、已安装、未安装、bundle / external 统计；MCP 页显示 MCP 总数、已配置、未配置和已配置目标；CLI 页显示 CLI 总数、已检测到、未检测到和检测状态；MCP 状态读取异常会停在 TUI 错误页并返回工作台。
- 自定义模式的套件、Skill、MCP、CLI 长列表都按当前光标分页显示，顶部保留已选数量和已选摘要，底部展示当前项详情，避免长列表强制滚到底部导致方向键抽动；清屏使用 `[Console]::Clear()` + 光标归零，失败时再回退 `Clear-Host`。
- 默认模式和自定义模式的软件 precheck 都会在终端同一行刷新已完成数量，并在结束时刷新为完成行；Skill、MCP、CLI 状态扫描也同一行刷新完成数量，分别以 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 为进度标签，结束时只保留完成行。默认安装的插件安装段在交互式套件输入区前也会执行这组节能版状态扫描，并在 `全部 Skill`、`所有套件` 和各 Profile 行上标记已安装、部分安装、需更新、更新未知或未安装；其中 MCP 只参与已配置 / 未配置判断，不产生需更新状态。Skill 单项入口复用 `Get-SkillBundleComponentStatus -IncludeSkills`；MCP 使用 TUI 专用轻量延迟保证过程可见，但最后 `100%` 后不再额外等待。
- 自定义模式的组件“检查并安装/更新”是节能版本地状态检查：Skill 只比较当前 `skills.zip` 中 `.skill-meta.json` 的来源身份和 `source_revision` 与本机 Skill meta；MCP 只检查本机是否已配置对应 server，不把用户自有配置与 registry 做更新或同步判定；CLI 只执行 `prereqs.yaml` 的 `check` 命令判断是否存在，`UpdateKnown=false` 且不跑 `npm outdated`、`winget upgrade` 或 GitHub Release 查询。若未来要做真实维护型更新检查，应先扩展 registry schema 并设计缓存、超时和禁用策略。
- 自定义模式中单项 Skill / MCP / CLI 选择按类型累积，选择某一类不会清空其它类型已选项；最终统一进入 `执行确认`。
- winget 安装如果已经输出成功但进程迟迟不退出，脚本会短暂等待后结束卡住的 winget 外壳并继续后续检测；没有成功输出时仍按原始退出码处理失败。
- MCP 状态检查会一次性读取 Claude Code 的 `mcp list`，再在本轮状态循环里复用结果，避免每个 MCP 都调用一次 Claude Code 导致几十秒等待。
- 当前 registry 中飞书 CLI 的历史检测命令是 `lark --version`，但 `@larksuite/cli` 实际提供 `lark-cli`；安装器对该别名做兼容检测，避免状态页误判 lark 未安装。
- `-SkipApps` 可跳过应用安装阶段，支持命令模式或自定义模式只执行 Skill 导入。
- Skill 导入后不再默认把所有导入项堆到 Skills Manager 默认场景；`SkillsManagerScenarioMode` 支持 `prompt/default/custom/skip`，TUI 安装 Skill 时会选择默认场景、自定义场景或跳过场景注册。
- 进入 TUI 前会 best-effort 切换英文输入布局，并向前台终端窗口发送输入语言切换请求；该行为不修改用户系统默认输入法。
- Profile / 应用多选文本统一支持英文逗号、中文逗号和顿号分隔。

## 文档维护约定

- README 只做入口索引，不维护应用来源表、PAT 表或完整安装流程。
- 一个专题只能有一个说明入口；其它文件只链接，不复制完整规则。
- 修改应用安装项时，先改 `manifest/apps.json`，再按需要更新 `docs/installer-flow.md` 或 `docs/asset-refresh.md`。
- 修改 Skill / MCP / prereq / Profile 来源时，先更新 `00000-model/00-编程配置/registry/*.yaml`；修改安装器消费行为时，再更新 `docs/skill-import.md`、`docs/operations.md` 和 `.ai_memory/2_active_task.md`。
- 修改 registry bundle 内容后，必须检查 `docs/asset-refresh.md` 中的两段刷新链路；如果 Tauri 等 Profile 显示不符合 registry，优先怀疑旧 `skills.zip`。
- 修改 PAT / Secret 规则时，只更新 `.agent/rules/pat-secret-governance.md`，其它文档保留链接。
- 修改文档结构时，遵循 `.agent/rules/documentation-governance.md`。
