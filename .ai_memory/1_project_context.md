# Project Context

## 项目目标

这个仓库用于在 Windows 上一键部署开发环境、桌面工具和技能包，主入口是 `bootstrap.ps1`。本仓库当前的分发模式是“在线安装 + Release fallback”，而不是纯离线打包仓库。

## Single Source of Truth

- 主安装逻辑：
  - `bootstrap.ps1`
  - `modules/common.psm1`
- 安装清单与 fallback 指针：
  - `manifest/apps.json`
- 面向人类的维护说明：
  - `README.md`

## 稳定事实

- 安装来源分两层：
  - 主来源：`winget`、上游 GitHub Releases、固定直链
  - 回退来源：`indieark/vibe-coding-setup` 的 `bootstrap-assets` Release
- 应用安装前一定先做 precheck：
  - 检测已安装版本
  - 解析目标版本
  - 决定 `skip` 或继续安装/更新
- 检测顺序固定为：
  1. `command`
  2. `appx`
  3. registry uninstall entries
- `skills.zip` 独立于应用安装，只有在选中 `skills-manager` 且未 `-SkipSkills` 时才会预取并导入。
- `CC Switch` Provider 导入只走 `ccswitch://v1/import` deep link，不写 SQLite。
- fallback 安装包统一下载到仓库内 `downloads/`，运行安装器时根据 `installerType` 分流到 `msi` / `exe` / `msix`。

## 当前 fallback 资产共识

- 已更新并上传到 `bootstrap-assets` 的新版包：
  - `Git-2.54.0-64-bit.exe`
  - `node-v25.9.0-x64.msi`
  - `python-3.13.13-amd64.exe`
  - `VSCodeUserSetup-x64-1.117.0.exe`
  - `CC-Switch-v3.14.0-Windows.msi`
- `PowerShell-7.6.1-win-x64.msi`、`skills-manager_1.14.3_x64_en-US.msi`、`ChatGPT_x64.msi`、`skills.zip` 已在 release 中可用。
- `Python 3.13` 的 fallback 已从 `python-manager-26.0.msix` 改为真正的官方运行时安装包 `python-3.13.13-amd64.exe`，并带静默安装参数。
- `Codex Desktop` 仍未完成 fallback 升级：
  - 已确认 Microsoft Store 包 `9PLM9XGG6VKS`
  - 已确认本机安装版本 `26.421.620.0`
  - 但尚未确认稳定、公开、可验证的官方 `Setup.exe` 直链或命名规则

## 文档维护约定

- 每次 manifest 中的 fallback 文件名变动，都应同步更新 `README.md` 的来源/回退表。
- 若 release 中允许新旧资产并存，文档中应明确说明“脚本只认 manifest 当前指向的文件名”。
