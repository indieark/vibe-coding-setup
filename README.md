# Windows 一键部署脚本

这个项目用于给同事在 Windows 上一键安装开发环境、桌面工具和技能包。

当前实现策略：

- 基础工具优先走 `winget`
- 开源桌面工具优先走 GitHub Releases 最新版
- 自动创建 `D:\Vibe Coding\Chat`，作为 `Codex` 的默认工作目录
- 支持远程自举：即使用户只拿到 `bootstrap.ps1`，脚本也会自动拉取 `modules/common.psm1`、`manifest/apps.json` 和 `packages/skills.zip`
- `CC Switch` 的 Provider 导入优先走官方 `ccswitch://` deep link
- `skills.zip` 自动解包到 `~/.skills-manager/skills`，并同步到 `~/.codex/skills`
- 如果本机已存在 `.claude`、`.cursor`、`.gemini`、`.copilot`，也会顺带同步过去

目录约定：

- `packages/`：脚本当前实际引用的本地兜底安装包与 `skills.zip`
- `.local/unused/`：当前脚本未引用、且不希望进入 Git 的安装包暂存目录
- `downloads/`：脚本运行时临时下载的最新版安装包，已加入 `.gitignore`

## 当前包含

- `Git`
- `Node.js`
- `Python 3.13`
- `Visual Studio Code`
- `Codex`
- `ChatGPT (Pake)`
- `CC Switch`
- `Skills Manager`

## 安装时会额外创建

- `D:\Vibe Coding\Chat`
  - 用途：作为 `Codex` 的默认工作目录

## 使用方式

### 本地仓库运行

普通安装：

```powershell
Set-Location "D:\AI Coding\Vibe Coding Setup"
.\bootstrap.cmd
```

只安装部分工具：

```powershell
.\bootstrap.cmd -Only git,nodejs,python,vscode,codex
```

跳过 `CC Switch` Provider 导入：

```powershell
.\bootstrap.cmd -SkipCcSwitch
```

跳过 `skills.zip` 导入：

```powershell
.\bootstrap.cmd -SkipSkills
```

只做演练，不真正安装：

```powershell
.\bootstrap.cmd -DryRun
```

### 公开 GitHub 仓库一键启动

目标仓库：

- `https://github.com/indieark/vibe-coding-setup`

推荐入口命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

这个命令只负责：

1. 下载 `bootstrap.ps1`
2. 执行它

后续依赖文件与安装流程由脚本自己完成。

公开仓库发布说明：

- 公开 GitHub 仓库默认只提交脚本、清单、文档和 `packages/skills.zip`
- `packages/` 里的本地 fallback 安装包属于维护者本地资源，不会进入公开 Git 历史
- 远程一键启动模式依赖：
  - `winget`
  - 上游 GitHub Releases
  - 当前仓库里的 `packages/skills.zip`
- 如果你需要真正离线分发，应改用维护者本地完整目录，或把 fallback 安装包放到 GitHub Releases 再由脚本下载

## 远程模式说明

当用户不是从完整仓库运行，而是只运行远程下载的 `bootstrap.ps1` 时：

- `bootstrap.ps1` 会自动拉取：
  - `modules/common.psm1`
  - `manifest/apps.json`
  - `packages/skills.zip`
- 软件安装仍优先使用：
  - `winget`
  - 上游 GitHub 最新版
- 本地 `packages/` 里的 fallback 安装包主要用于完整仓库场景，不是远程模式的主要依赖
- 公开仓库默认不会包含这些大体积 fallback 安装包

## 已确认的自动化入口

### CC Switch

优先走官方 deep link 导入，而不是直接改 SQLite。

原因：

- 官方文档明确支持 `ccswitch://v1/import`
- 对版本演进更稳
- 不依赖内部表结构

当前脚本会要求用户手动输入：

- Provider 名称
- `base_url`
- `api_key`
- 默认模型名

然后自动生成并触发 Codex Provider 导入。

### Skills Manager

当前脚本通过文件层导入：

1. 解压 `skills.zip`
2. 识别包含 `SKILL.md` 的目录
3. 复制到 `~/.skills-manager/skills/<skill-name>`
4. 复制到 `~/.codex/skills/<skill-name>`
5. 如果检测到其它工具目录，也同步过去

这个方案的前提是 `skills-manager` 以技能文件目录为中心仓库，SQLite 主要保存元数据。

## 已验证的外部来源

- `Git.Git`
- `OpenJS.NodeJS`
- `Python.Python.3.13`
- `Microsoft.VisualStudioCode`
- `OpenAI.Codex`
- `tw93/pake` latest release asset
- `farion1231/cc-switch` latest release asset
- `xingkongliang/skills-manager` latest release asset

## 建议后续

建议把这个目录初始化成 Git 仓库并推到 GitHub。

推荐下一步：

1. 增加日志落盘
2. 增加安装结果 JSON 报告
3. 增加 checksum / 版本校验
4. 研究 `CC Switch` 是否支持无 URI 暴露的更安全导入方式
5. 研究 `Skills Manager` 是否存在稳定 CLI 或显式 rescan 命令
