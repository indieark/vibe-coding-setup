# Vibe Coding Setup

面向 Windows 的 IndieArk 一键装机器：安装开发工具、同步公开镜像资产，并按 Profile 导入可追更的 AI Skills。

> 这个 README 是项目首页。详细流程、维护规则和路线图请从 [文档中心](docs/README.md) 进入，避免同一事实在多个文件里重复维护。

## 为什么需要它

新机器或重装环境时，手工安装工具、配置 CC Switch、同步 Skills 往往会遇到三个问题：

- 安装来源分散，某个上游 release 不可用时容易卡住。
- 私库资产不能直接暴露给终端用户机器。
- Skill 目录容易重复、覆盖或丢失上游来源，后续不可追更。

本仓库把这些步骤收敛成一个可审计的 PowerShell 安装器。

## 它做什么

- 安装常用 Windows 开发工具：Git、Node.js、Python、VS Code、Codex Desktop、ChatGPT、CC Switch、Codex Provider Sync、Skills Manager。
- 先走公开主来源，失败后按 `bootstrap-assets` fallback。
- 从公开 `skills.zip` 按 registry / Profile 导入 Skill；`-AllSkills` 代表 registry 全部 Skill，bundled 直接导入，external 按来源拉取。
- 默认进入拟似 TUI，可在进入脚本后选择默认安装、自定义模式或安全演练。
- TUI 会尽量切换英文输入布局，Profile / 应用多选支持英文逗号、中文逗号和顿号。
- `skills.zip` 不在 TUI 首屏预取；只有进入套件、Skill、MCP、CLI 相关入口或实际导入组件时才按需获取。
- 应用安装前会并行检查本机是否已安装，并持续显示已完成检查数量；只有已安装项才查目标版本并判断是否需要更新。
- Skill / MCP / CLI 状态读取会显示与应用检查一致的逐项完成进度；winget 已报告安装完成但进程未退出时会自动收尾，避免终端停在“仍在运行”。

- 使用 `.skill-meta.json` 识别 Skill 来源，并由用户选择是否写入 Skills Manager 默认场景或自定义场景。
- 对同名 Skill 做安全三态判定：已跟踪、旧孤儿、第三方同名。
- 按 `00000-model` registry 自动处理全部 Skill、bundled / external 来源、MCP 配置和前置 CLI 依赖。

## 快速开始

### 本地仓库运行

```powershell
Set-Location "C:\Vibe_Coding\IndieArk\gadget\vibe-coding-setup"
.\bootstrap.cmd
```

### 远程自举运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

### 安全演练 Skill 导入

先观察本机判定，不替换旧目录、不拉起 UI：

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
```

更多命令见 [运行命令](docs/operations.md)。

## 核心能力

| 能力             | 当前实现                                                                                                                                                                               |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 应用安装         | `manifest/apps.json` 驱动，先并行 precheck；缺失则安装，已存在才查目标版本并决定更新或跳过                                                                                             |
| 失败回退         | 主来源失败后 post-check，仍失败才使用 fallback                                                                                                                                         |
| 资产镜像         | 私库资产只在 GitHub Actions 中读取，终端用户只访问公开 `bootstrap-assets`                                                                                                              |
| TUI 入口         | 无安装参数默认进入拟似 TUI；显式参数继续支持旧命令模式                                                                                                                                 |
| Skill / MCP 导入 | `skills.zip` 内置 registry 和 Profile，TUI 与命令模式都支持全部 Skill、按 Profile、按单项导入 bundled / external Skill、前置 CLI 依赖和 MCP 配置，并可选择 Skills Manager 场景注册方式 |
| 输入兼容         | TUI 进入前 best-effort 切英文输入布局；多选分隔支持 `,`、`，`、`、`                                                                                                                    |
| 去重安全         | `Tracked / Orphan / Foreign` 三态判定，默认备份不删除                                                                                                                                  |
| 进度展示         | 应用 precheck、Skill / MCP / CLI 状态扫描、下载、winget 下载 / 安装和 Skill bundle 解压使用脚本自绘同一行进度；winget 输出会过滤噪音并中文化常见状态                                   |
| 可追更           | `.skill-meta.json` 字段透传到 Skills Manager DB                                                                                                                                        |

## 安全边界

- 终端用户安装不需要 `indieark/00000-model` 或其它私库 PAT。
- PAT 只用于 GitHub Actions 刷新公开镜像资产，规则见 [PAT / Secret 治理](.agent/rules/pat-secret-governance.md)。
- Skill 默认不会覆盖第三方同名目录。
- 旧版无来源标记 Skill 默认先备份为 `<name>.legacy.<时间>`，再导入 IndieArk 版本。
- `-DryRun` 用于预览行为，不写入系统状态。

## 文档中心

| 你想做什么                                         | 去哪里看                                                 |
| -------------------------------------------------- | -------------------------------------------------------- |
| 第一次使用安装器                                   | [运行命令](docs/operations.md)                           |
| 理解完整执行顺序                                   | [安装执行顺序](docs/installer-flow.md)                   |
| 理解 Skill/Profile/三态去重                        | [Skill 导入契约](docs/skill-import.md)                   |
| 维护 release asset、刷新 `skills.zip` 或排查旧缓存 | [资产刷新链路](docs/asset-refresh.md)                    |
| 查看后续增强路线                                   | [后续路线](docs/roadmap.md)                              |
| 了解文档如何维护                                   | [文档治理规则](.agent/rules/documentation-governance.md) |

完整目录见 [文档中心首页](docs/README.md)。

## 单一信息源

- 应用名称、安装策略、版本门禁和 fallback 文件名只在 `manifest/apps.json` 定义。
- 安装执行行为以 `bootstrap.ps1` 和 `modules/common.psm1` 为准。
- Skill / MCP / prereq / Profile / bundle 来源以 `indieark/00000-model` 的 `00-编程配置/registry/*.yaml` 和 bundle 构建结果为准；安装器行为说明入口是 [Skill 导入契约](docs/skill-import.md)。
- PAT / Secret 规则只在 `.agent/rules/pat-secret-governance.md` 维护。
- `.ai_memory/` 只记录接手上下文，不作为用户手册或规则源。

## 当前状态

- `main` 已包含按需装机器 Phase 1-4：私库 bundle 镜像、Profile 选择、Skill meta 透传、三态去重，以及 registry 驱动的全部 Skill / external Skill / prereq / MCP 写入。
- 安装器已包含集成拟似 TUI 自定义模式、运行时套件 / Skill / MCP / CLI 复选、UAC 交接提示和安装进度展示。
- Phase 5 飞书只读镜像在 `indieark/00000-model` 侧按计划推进。
- 下一步安装器增强应优先围绕可观测、可校验、可回滚，而不是继续堆安装项。

## 维护提示

改动前先判断事实源：

- 改应用安装项：先改 `manifest/apps.json`。
- 改 Skill 导入行为：同步更新 [Skill 导入契约](docs/skill-import.md)。
- 改资产刷新链路：同步更新 [资产刷新链路](docs/asset-refresh.md)。
- 改文档结构：遵守 [文档治理规则](.agent/rules/documentation-governance.md)。
