# packages

这个目录存放脚本当前会引用的本地资源，分为两类：

## 主资源

这些文件不是“兜底”，而是脚本的正常输入之一。

- `skills.zip`
  - 用途：批量导入本地 skill bundle
  - 使用位置：`bootstrap.ps1`
  - 说明：脚本会解压并识别其中包含 `SKILL.md` 的目录，然后同步到 `~/.skills-manager/skills`、`~/.codex/skills`，以及本机已存在的其它技能目录
  - 发布方式：公开仓库运行时从 `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release 下载

## Fallback 资源

这些文件默认不会优先使用。
脚本会先尝试 `winget` 或线上最新版下载，只有失败时才回退到这里。

- `Git-2.53.0.2-64-bit.exe`
  - 主路径：`winget` (`Git.Git`)
- `node-v24.14.0-x64.msi`
  - 主路径：`winget` (`OpenJS.NodeJS`)
- `python-manager-26.0.msix`
  - 主路径：`winget` (`Python.Python.3.13`)
- `VSCodeUserSetup-x64-1.112.0.exe`
  - 主路径：`winget` (`Microsoft.VisualStudioCode`)
- `Codex-26.325.31654.Setup.exe`
  - 主路径：`winget` (`OpenAI.Codex`)
- `ChatGPT_x64.msi`
  - 主路径：GitHub latest direct download
  - URL：`https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x64.msi`
- `CC-Switch-v3.11.1-Windows.msi`
  - 主路径：GitHub latest tag download
  - Repo：`farion1231/cc-switch`
- `skills-manager_1.9.0_x64-setup.exe`
  - 主路径：GitHub latest tag download
  - Repo：`xingkongliang/skills-manager`

## 设计原则

- 能从官方渠道或 GitHub Release 拉最新版时，优先在线获取
- 本地安装包主要用于：
  - 网络不可用
  - `winget` 不可用
  - GitHub 下载失败
  - 需要离线应急安装

## 远程启动模式

如果用户是通过公开 GitHub 仓库的一条 PowerShell 命令启动：

- 脚本会优先在线安装软件
- 远程模式默认会从 `bootstrap-assets` Release 主动拉取 `skills.zip`
- 这里的本地 fallback 安装包更适合完整仓库或离线分发场景
- 公开 GitHub 仓库默认只保留脚本和说明文档，这里的本地安装包与 `skills.zip` 由维护者本地保存，不进入 Git 历史

## 维护建议

- 如果更新某个本地 fallback 包，记得同时更新 `manifest/apps.json` 里的 `fallback.localFile`
- 如果更新公开分发使用的 fallback 包或 `skills.zip`，记得同步更新 `bootstrap-assets` Release 资产
- 如果将某个工具改成纯在线安装、不再需要本地兜底，可以把对应文件移到 `.local/unused/`
