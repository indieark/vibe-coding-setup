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
- `skills.zip` 独立于应用安装；只要未传 `-SkipSkills`，脚本会在需要读取 Profile 或导入 Skill 时按需获取，并在应用阶段后尝试导入。
- `skills.zip` 由 `indieark/00000-model` registry bundle 构建，经当前仓库 `bootstrap-assets` 镜像为公开资产后分发，终端用户机器不需要 PAT。
- TUI 首屏不预取 `skills.zip`；只有进入 Skill 复选页需要读取 Profile，或后续安装 / 演练实际要导入 Skill 时才按需获取。
- 下载、winget 下载 / 安装和 Skill bundle 解压统一使用脚本自绘同一行进度；winget 输出会过滤许可证、免责声明和重复进度行，并中文化常见状态；Skill bundle 解压不再调用 `Expand-Archive`，避免 PowerShell 宿主蓝色进度区域。非交互捕获输出不打印中间百分比，只保留完成行，避免 `\r` 被展开成多行刷屏。
- Skill 导入是“Profile 选择 + `.skill-meta.json` 来源判定 + 增量同步 + Skills Manager SQLite 注册”的组合流程。
- Skill 选择语义已经拆开：`全部 Skill` 只导入 bundle 内离线 Skill；`所有套件` / `-AllSuites` 按所有 Profile 并集导入 Skill、external Skill、MCP 和前置 CLI。命令交互菜单和 TUI 都应明确显示 `全部 Skill`、`所有套件`、各套件自身的 Skill / MCP / CLI 数量；TUI 光标停在套件时展示该套件将写入的 MCP 和将处理的 CLI 依赖，默认交互菜单在输入后、执行前输出同样摘要。
- registry 驱动导入已经支持 bundled skill、external skill、MCP 和前置依赖。external skill 可从 `repo`、`archive_url` / `download_url`、`local_path` 自动导入；只有 `homepage` 的条目只提示人工处理。
- 前置依赖由 `registry/prereqs.yaml` 驱动，安装器按 `check` 先判定，再根据平台和 `command` / `npm` / `pipx` / `pip` / `brew` / `winget` / `scoop` 等安装方式处理；单项失败汇总告警，不阻断后续可安装项。
- MCP 写入由 `registry/mcp.yaml` 与 Profile 引用驱动，目前覆盖 Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI 和 Antigravity；Antigravity 的目标文件是 `~/.gemini/antigravity/mcp_config.json`。
- 同名 Skill 三态判定已经落地：`Tracked` 增量同步，`Orphan` 默认备份替换，`Foreign` 默认跳过。
- `CC Switch` Provider 导入只走 `ccswitch://v1/import` deep link，不写 SQLite。
- `CC Switch` Provider 配置区按“说明 / 输入区 / 配置摘要”分块展示；输入区直接吞并默认值和 API Key。Provider 名称、Base URL、模型等预填值在真实控制台右侧以灰色占位显示，回车保持，输入则清除占位并覆盖。API Key 继续隐藏输入，预设密钥只显示来源不显示内容。
- 面向用户的脚本提示、日志、错误和执行摘要默认使用简体中文；为兼容 Windows PowerShell 5.1，脚本文案通过 UTF-8 base64 解码输出，源码文件保持 UTF-8 无 BOM。
- `bootstrap.ps1` 内置拟似 TUI 与自动化命令模式：无安装参数或显式 `-Tui` 时进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills` 等操作参数时继续走自动化模式；TUI 首屏保留“默认安装”“自定义模式”“安全演练”，其中自定义模式进入控制台工作台。
- 自定义模式聚焦任务动作：检查并安装 / 更新软件、检查并安装套件、检查并任选安装 Skill、检查并任选安装 MCP、检查并任选安装 CLI、执行摘要；独立“检查 Skill 状态 / 检查所有套件”已合并进对应安装入口，因为安装前必然检查。
- 自定义模式的 Skill / 套件 / MCP / CLI 相关读取结果会在本轮工作台中复用；Skill / 套件入口只做轻量 Skill registry 与本机 Skill 状态读取，MCP / CLI 入口才读取 MCP 配置状态和 CLI 检测状态。
- 自定义模式的套件、Skill、MCP、CLI 长列表都按当前光标分页显示，顶部保留已选数量和已选摘要，底部展示当前项详情，避免长列表强制滚到底部导致方向键抽动。
- 默认模式和自定义模式的软件 precheck 都会在终端同一行刷新已完成数量，并在结束时刷新为完成行；Skill、MCP、CLI 状态扫描也同一行刷新完成数量，结束时只保留完成行。
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
- 修改 Skill / MCP / prereq / Profile 来源时，先更新 `00000-model/00-编程配置/registry/*.yaml`；修改安装器消费行为时，再更新 `docs/skill-import.md` 和 `.ai_memory/2_active_task.md`。
- 修改 PAT / Secret 规则时，只更新 `.agent/rules/pat-secret-governance.md`，其它文档保留链接。
- 修改文档结构时，遵循 `.agent/rules/documentation-governance.md`。
