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
- TUI 现代化工作台计划：`plans/2026-04-30-tui-modernization-workbench.md`
- PAT / Secret 治理：`.agent/rules/pat-secret-governance.md`
- 文档治理规则：`.agent/rules/documentation-governance.md`

## 稳定事实

- 应用安装先做 precheck，再按主来源 / fallback 执行；主安装失败后会先 post-check，再决定是否 fallback。
- `skills.zip` 独立于应用安装；只要未传 `-SkipSkills`，脚本会在需要读取 Profile 或导入 Skill 时按需获取，并在应用阶段后尝试导入。
- `skills.zip` 由 `indieark/00000-model` registry bundle 构建，经当前仓库 `bootstrap-assets` 镜像为公开资产后分发，终端用户机器不需要 PAT。
- TUI 首屏不预取 `skills.zip`；只有进入 Skill 复选页需要读取 Profile，或后续安装 / 演练实际要导入 Skill 时才按需获取。
- 下载、winget 百分比和 Skill bundle 解压统一使用脚本自绘同一行进度；Skill bundle 解压不再调用 `Expand-Archive`，避免 PowerShell 宿主蓝色进度区域。
- Skill 导入是“Profile 选择 + `.skill-meta.json` 来源判定 + 增量同步 + Skills Manager SQLite 注册”的组合流程。
- 同名 Skill 三态判定已经落地：`Tracked` 增量同步，`Orphan` 默认备份替换，`Foreign` 默认跳过。
- `CC Switch` Provider 导入只走 `ccswitch://v1/import` deep link，不写 SQLite。
- 面向用户的脚本提示、日志、错误和执行摘要默认使用简体中文；为兼容 Windows PowerShell 5.1，脚本文案通过 UTF-8 base64 解码输出，源码文件保持 UTF-8 无 BOM。
- `bootstrap.ps1` 内置拟似 TUI 与原命令模式：无安装参数或显式 `-Tui` 时进入 TUI；带 `-Only`、`-DryRun`、`-SkipSkills` 等操作参数时继续走原自动化模式；TUI 首屏保留“默认安装（原来模式）”“TUI 模式”“安全演练”，其中 TUI 模式进入控制台工作台。
- TUI 工作台聚焦任务动作：检查软件状态、安装 / 更新软件、检查 Skill 状态、安装 Skill、执行摘要；复选主要用于 Skill Profile，软件选择放在安装 / 更新软件动作下。
- `-SkipApps` 可跳过应用安装阶段，支持命令模式或 TUI 工作台只执行 Skill 导入。
- 进入 TUI 前会 best-effort 切换英文输入布局，并向前台终端窗口发送输入语言切换请求；该行为不修改用户系统默认输入法。
- Profile / 应用多选文本统一支持英文逗号、中文逗号和顿号分隔。

## 文档维护约定
- README 只做入口索引，不维护应用来源表、PAT 表或完整安装流程。
- 一个专题只能有一个说明入口；其它文件只链接，不复制完整规则。
- 修改应用安装项时，先改 `manifest/apps.json`，再按需要更新 `docs/installer-flow.md` 或 `docs/asset-refresh.md`。
- 修改 Skill 导入行为时，更新 `docs/skill-import.md` 和 `.ai_memory/2_active_task.md`。
- 修改 PAT / Secret 规则时，只更新 `.agent/rules/pat-secret-governance.md`，其它文档保留链接。
- 修改文档结构时，遵循 `.agent/rules/documentation-governance.md`。
