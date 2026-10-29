<div align="center">

# Vibe Coding Setup

**IndieArk 的 Windows 装机器：装好常用工具、配好 API，Skills 按需再装。**

`一键装常用软件` · `主来源失败自动换镜像` · `按套件导入 Skill` · `同名 Skill 不乱覆盖` — 有桌面界面，也能纯命令行跑。

[![License](https://img.shields.io/badge/license-not%20specified-blue?style=flat-square)](#license)
[![Stack](https://img.shields.io/badge/stack-PowerShell%20%2B%20Tauri-5391FE?style=flat-square)](#开发栈)
[![Install](https://img.shields.io/badge/install-bootstrap.cmd-orange?style=flat-square)](#启动)
[![Apps](https://img.shields.io/badge/apps-7%20default%20%2B%201%20optional-brightgreen?style=flat-square)](#核心能力)
[![Modes](https://img.shields.io/badge/modes-GUI%20%2F%20TUI%20%2F%20CLI-yellow?style=flat-square)](#使用流程)
[![Platform](https://img.shields.io/badge/platform-Windows-ff69b4?style=flat-square)](#启动)

[核心能力](#核心能力) · [启动](#启动) · [使用流程](#使用流程) · [配置](#配置) · [安全边界](#安全边界) · [协同关系](#协同关系)

</div>

> 本 README 是项目首页。详细流程、维护规则和路线图从 [文档中心](docs/README.md) 进；AI 协作规则在 [.agent/rules/](.agent/rules/documentation-governance.md)（[PAT / Secret 治理](.agent/rules/pat-secret-governance.md)、[文档治理](.agent/rules/documentation-governance.md)），接手上下文在 [.ai_memory/](.ai_memory/1_project_context.md)，它不是用户手册也不是规则源。

---

<p align="center">
  <img src="./assets/hero.webp" alt="一朵发光的云把一个个立方体组件投放到中央的电脑底座上，周围漂着几卷清单，表示从云端按清单把软件和 Skill 装进本机" width="80%">
</p>

> 新电脑或重装系统时，要手动装一堆工具、配 CC Switch、同步 Skills，安装来源又分散，Skill 目录还容易重复或被覆盖。这个仓库把这些步骤收成一个能看清楚每一步做了什么的 PowerShell 安装器。

---

## 核心能力

| 能力 | 实现 |
|---|---|
| **装常用软件** | 默认装 Git、Node.js、Python 3.14、Visual Studio Code、Codex Desktop、ChatGPT (Pake)、CC Switch；Skills Manager 默认不装，可以选装。清单在 [apps.json](manifest/apps.json) |
| **先查再装** | 装之前并行检查本机已经装了哪些，并显示查完了几个；只对已装的去查目标版本，再决定更新还是跳过，见 [安装执行顺序](docs/installer-flow.md#应用安装门禁) |
| **主来源失败就换镜像** | 先走公开的主来源，失败后复查一遍，仍然失败才用公开的 `bootstrap-assets` 镜像，见 [主来源和回退来源](docs/installer-flow.md#主来源和回退来源) |
| **私库资产不下发** | 私库资产只在 GitHub Actions 里读，用户机器只访问公开的 `bootstrap-assets`，见 [资产刷新链路](docs/asset-refresh.md) 和 [refresh-bootstrap-assets.yml](.github/workflows/refresh-bootstrap-assets.yml) |
| **按需导入 Skill / MCP / CLI** | 从公开 `skills.zip` 按 registry / Profile 导入；`-AllSkills` 是 registry 里的全部 Skill，bundled 直接导入，external 按来源拉取。见 [Skill 导入契约](docs/skill-import.md) |
| **同名 Skill 不乱覆盖** | 用 `.skill-meta.json` 认来源，按 `Tracked / Orphan / Foreign` 三种情况处理，默认先备份不删除，见 [三态判定](docs/skill-import.md#三态判定) |
| **能追更新** | `.skill-meta.json` 字段传进 Skills Manager 的数据库；Skill 是否要更新，用当前 `skills.zip` 的 `source_revision` 和本机 meta 对比，不实时联网查 |
| **桌面界面** | 不带参数双击就打开 Tauri 界面：选软件、填 CC Switch Provider、检查环境、安全演练、安装、看脱敏诊断，扩展组件页选套件、Skill、MCP、CLI。源码在 [desktop/](desktop/src/main.tsx)，说明见 [桌面安装器](docs/desktop.md) |
| **终端工作台** | `-Tui` 打开终端界面，有默认安装、自定义模式、安全演练三个入口。进入前会尽量切到英文输入法；多选可以用 `,`、`，`、`、` 分隔 |
| **进度显示** | 预检查、Skill / MCP / CLI 状态扫描、下载、winget 安装和解压都在同一行刷新进度，组件扫描统一带 `[检查]` 标签；winget 的噪音输出会过滤，常见状态翻成中文。见 [进度展示](docs/installer-flow.md#进度展示) |

---

## 启动

这是安装脚本，不是服务，没有端口。运行要 Windows PowerShell 5.1 和 WebView2 Runtime，不用装编译工具。

### 从仓库运行

```powershell
git clone https://github.com/indieark/vibe-coding-setup.git
cd vibe-coding-setup
.\bootstrap.cmd
```

双击 [bootstrap.cmd](bootstrap.cmd) 或 [vibe-coding-setup.cmd](vibe-coding-setup.cmd) 也行。本地没有桌面程序时，会自动下载已发布的版本。

### 不下载仓库，直接远程运行

在 PowerShell 里粘贴这一行，拿最新的启动器：

```powershell
& { $ErrorActionPreference='Stop'; $launcher=Join-Path $env:TEMP ('vibe-coding-setup-'+[guid]::NewGuid().ToString('N')+'.cmd'); Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/indieark/vibe-coding-setup/main/vibe-coding-setup.cmd' -OutFile $launcher; & $launcher }
```

远程入口每次都会重新拿 GitHub `main` 上的脚本、模块和安装清单，以及公开的桌面程序；本地入口只跑当前文件。怎么确认用的是新版见 [运行命令](docs/operations.md#如何确认使用新版)，发布方式见 [发布与更新](docs/desktop.md#发布与更新)。

### 先演练再装

只看会做什么，不改系统：

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch
```

只演练 Skill 导入，看本机的判定结果，不替换旧目录、不打开 Skills Manager：

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
```

### 修改和构建桌面界面

要改界面的开发机才需要 Node.js、Rust MSVC 工具链和 Visual Studio C++ Build Tools：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Desktop.ps1
```

产物在 `desktop/bin/`，版本取自 [tauri.conf.json](desktop/src-tauri/tauri.conf.json)，不进版本控制。构建脚本是 [Build-Desktop.ps1](scripts/Build-Desktop.ps1)，验收步骤见 [桌面安装器](docs/desktop.md#验证)。

---

## 使用流程

### 1 · 选入口

| 怎么启动 | 打开什么 |
|---|---|
| 不带参数 | Tauri 桌面界面，真实安装时申请管理员权限 |
| `-Gui` / `-Gui -DryRun` | 显式打开桌面界面；加 `-DryRun` 是强制演练，不申请管理员权限 |
| `-GuiCheck` | 只检查桌面入口，不开窗口 |
| `-Tui` | 终端工作台 |
| 其他参数，比如 `-Only git,nodejs` | 命令模式，不开界面 |

### 2 · 默认只做最少的事

默认装常用软件、配 CC Switch。不建工作目录，不装 Skills Manager，不导入 Skill / MCP / CLI；要这些就去桌面的「扩展组件」页选，或者传参数。

### 3 · 需要时再装扩展组件

- 套件、Skill、MCP、CLI 可以搜索、全选、混选，能预览依赖、选冲突策略和 Skills Manager 场景注册方式。
- 和软件、API 配置一起组成一个计划，逐项显示结果和备份位置。
- `skills.zip` 不会一开始就下载，只有进入套件、Skill、MCP、CLI 入口或真要导入时才拿。
- 终端的自定义模式里，有了可执行的选择后「开始执行」会排在第一项，选了就直接执行，不再弹确认页。

### 4 · 状态怎么判断

| 类型 | 怎么查 |
|---|---|
| Skill | 本地对比 `skills.zip` 和 `.skill-meta.json`，开销小 |
| MCP | 只看有没有配置，用户自己的配置不当成要更新 |
| CLI | 只看在不在，更新状态显示「未知」 |
| winget | 已报告装完，或返回异常但复查确认已装上，都按成功处理 |

全部参数见 [运行命令](docs/operations.md#常用参数)。

---

## 配置

| 文件 / 参数 | 说明 |
|---|---|
| [manifest/apps.json](manifest/apps.json) | 应用名称、安装策略、版本门禁和 fallback 文件名只在这里定义 |
| [bootstrap.ps1](bootstrap.ps1) / [common.psm1](modules/common.psm1) | 安装实际怎么执行，以这两个文件为准 |
| `-SkillProfile` / `-AllSkills` / `-AllSuites` | 选哪些 Skill 套件导入 |
| `-NoReplaceOrphan` / `-ReplaceForeign` / `-RenameForeign` | 遇到旧孤儿或第三方同名 Skill 怎么处理，见 [三态策略参数](docs/operations.md#三态策略参数) |
| `-CcSwitchProviderName` / `-CcSwitchBaseUrl` / `-CcSwitchModel` / `-CcSwitchApiKey` | CC Switch Provider 配置 |
| `-SkipApps` / `-SkipSkills` / `-SkipCcSwitch` | 跳过对应步骤 |
| `-BootstrapAssetsRepo` / `-BootstrapAssetsTag` | 镜像资产位置，默认 `indieark/vibe-coding-setup` 的 `bootstrap-assets` |

Skill、MCP、prereq、Profile 和 bundle 的来源，以上游 registry 仓库 `indieark/00000-model` 里 `00-编程配置/registry/*.yaml` 和 bundle 构建结果为准；安装器这边的说明见 [Skill 导入契约](docs/skill-import.md)。

---

## 安全边界

- 用户装机不需要任何私库 PAT。
- PAT 只给 GitHub Actions 刷新公开镜像资产用，规则见 [PAT / Secret 治理](.agent/rules/pat-secret-governance.md)。
- 默认不覆盖第三方同名 Skill 目录。
- 没有来源标记的旧 Skill，默认先备份成 `<name>.legacy.<时间>`，再导入 IndieArk 版本。
- `-DryRun` 只预览，不写系统状态。
- 桌面程序只通过固定命令调用后端，不开放任意 shell、文件写入或远程页面。exe 目前还没有代码签名。

---

## 当前状态

| 项 | 情况 |
|---|---|
| 已完成 | Phase 1–4：私库 bundle 镜像、Profile 选择、Skill meta 透传、三态去重，以及 registry 驱动的全部 Skill / external Skill / prereq / MCP 写入 |
| 已有 | 桌面界面、终端自定义模式、运行时套件 / Skill / MCP / CLI 复选、UAC 提权后带参数续跑、统一的 `[检查]` 进度 |
| 已精简 | 默认只装常用应用和配 CC Switch；建工作目录和 Codex Provider Sync 已去掉，Skills Manager 与 Skill / MCP / CLI 保留按需入口 |
| 在推进 | Phase 5 飞书只读镜像，在上游 registry 仓库那边做 |
| 下一步 | 优先做可观测、可校验、可回滚，不再继续加安装项，见 [后续路线](docs/roadmap.md) |

---

## 开发栈

| 用途 | 技术 |
|---|---|
| **安装器** | Windows PowerShell 5.1：[bootstrap.ps1](bootstrap.ps1)、[common.psm1](modules/common.psm1) |
| **软件安装** | winget，加公开镜像兜底 |
| **桌面界面** | Tauri + React + TypeScript，源码在 [desktop/](desktop/src/main.tsx)，后端调用走 [DesktopWorker.ps1](scripts/DesktopWorker.ps1) |
| **测试** | [Test-Bootstrap.ps1](scripts/Test-Bootstrap.ps1)、[Test-Desktop.ps1](scripts/Test-Desktop.ps1) 等脚本，以及 [desktop/tests/](desktop/tests/state.test.mjs) |
| **发布** | GitHub Actions：[publish-desktop.yml](.github/workflows/publish-desktop.yml) 发桌面程序，[refresh-bootstrap-assets.yml](.github/workflows/refresh-bootstrap-assets.yml) 刷新镜像资产 |

---

## 目录结构

```text
vibe-coding-setup/
├─ bootstrap.cmd / bootstrap.ps1   # 入口和主脚本
├─ vibe-coding-setup.cmd           # 可单独下载的启动器
├─ modules/common.psm1             # 共享模块
├─ manifest/apps.json              # 应用清单
├─ desktop/                        # Tauri 桌面界面
│  ├─ src/                         # React 前端
│  ├─ src-tauri/                   # Rust 外壳
│  └─ tests/
├─ scripts/                        # 构建、Worker、测试、刷新资产
├─ docs/                           # 运行命令、执行顺序、Skill 导入、资产刷新、路线
├─ plans/                          # 计划
├─ .agent/rules/                   # AI 协作规则
├─ .ai_memory/                     # 接手上下文
└─ .github/workflows/              # 桌面发布、资产刷新
```

---

## 文档导航

| 想做什么 | 去哪看 |
|---|---|
| 第一次用安装器 | [运行命令](docs/operations.md) |
| 构建、运行和验收桌面界面 | [桌面安装器](docs/desktop.md) |
| 了解完整执行顺序 | [安装执行顺序](docs/installer-flow.md) |
| 了解 Skill / Profile / 三态去重 | [Skill 导入契约](docs/skill-import.md) |
| 维护 release asset、刷新 `skills.zip`、排查旧缓存 | [资产刷新链路](docs/asset-refresh.md) |
| 看后续路线 | [后续路线](docs/roadmap.md) |
| 文档怎么维护 | [文档治理规则](.agent/rules/documentation-governance.md) |

完整目录见 [文档中心](docs/README.md)。

---

## 协同关系

| 关联 | 关系 |
|---|---|
| `indieark/00000-model`（私有） | 上游：Skill / MCP / prereq / Profile / bundle 的 `registry/*.yaml` 和 bundle 构建结果 |
| Skills Manager | 下游：`.skill-meta.json` 字段写进它的数据库，支持场景注册 |
| CC Switch | 默认安装并配置 Provider |
| `bootstrap-assets`（本仓库公开 Release） | 用户机器的兜底资产来源，私库 PAT 不会下发 |

---

## License

仓库是公开的，但还没有 LICENSE 文件，所以默认保留全部权利。要允许别人复用，需要先选定并加上许可证。
