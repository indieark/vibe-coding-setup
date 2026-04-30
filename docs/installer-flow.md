# 安装执行顺序

> 本文解释 `bootstrap.ps1` / `modules/common.psm1` 的当前行为。应用清单、目标版本和 fallback 文件名不要写在这里，统一以 `manifest/apps.json` 为准。

## 执行入口

- `bootstrap.ps1`：主脚本，承载参数解析、自举、提权、安装和汇总。
- `bootstrap.cmd`：本地启动壳，使用 Windows PowerShell 5.1 执行主脚本。
- `vibe-coding-setup.cmd`：远程自举入口，拉取 GitHub `main` 上的脚本依赖后运行。

## 执行顺序

1. 决定 `BootstrapSourceRoot`：本地仓库完整时使用本地文件，否则使用 GitHub raw `main`。
2. 同步自举依赖：`modules/common.psm1` 和 `manifest/apps.json`。
3. 导入模块；非 `-DryRun` 且非管理员时，通过 UAC 保留原参数重新拉起。
4. 读取 `manifest/apps.json`，按 `-Only` 过滤应用，并按 `order` 排序。
5. 如果没有 `-SkipSkills`，预取公开 `bootstrap-assets/skills.zip`。
6. 如选择 `cc-switch` 且没有 `-SkipCcSwitch`，读取或询问 Provider 配置。
7. 创建 Codex 默认工作目录。
8. 对每个应用做版本门禁和安装。
9. 应用阶段结束后，如果没有 `-SkipSkills`，执行 Skill bundle 导入。
10. 最后导入 CC Switch Provider deep link。
11. 输出 Summary；任一项失败则退出码为 `1`，否则为 `0`。

## 应用安装门禁
每个应用都会先做 precheck：

- 未安装：进入安装。
- `installIfMissingOnly` 为真且已安装：跳过。
- 已安装且版本低于目标：更新。
- 已安装且版本不低于目标：跳过。
- 版本无法可靠比较时，按该应用的策略保守处理。

检测顺序固定为：

1. `command`
2. `appx`
3. registry uninstall entries

## 主来源和回退来源

安装器优先使用 manifest 中定义的主来源。主来源失败后，会先做一次 post-check；只有仍无法确认安装成功，才继续 fallback。

当前支持的安装来源类型包括：

- `winget`
- `direct-url`
- `github-latest-tag`
- `release-asset`

fallback 安装包统一下载到仓库内 `downloads/`，再根据 `installerType` 分流：

- `msi`：`msiexec.exe /i ... /qn /norestart`
- `exe`：按 manifest 静默参数执行
- `msix`：`Add-AppxPackage`
- `uri`：`Start-Process`，用于 Store 协议或官方网页

## 特殊行为索引

- `Codex Desktop` 和 `ChatGPT (Pake)` 当前按 presence-only 处理：检测到已安装即跳过。
- `Python 3.13` 优先 `py -V`，失败后回退 `python --version`。
- `Codex Provider Sync` 安装时访问当前仓库公开镜像资产，不直接访问私库。
- `CC Switch` Provider 导入只走 `ccswitch://v1/import` deep link，不写 SQLite。
- `Skills Manager` 按上游 GitHub latest tag 判断是否需要升级。

## 相关文档

- Skill 导入细节：[`skill-import.md`](skill-import.md)
- 资产刷新链路：[`asset-refresh.md`](asset-refresh.md)
- 本机命令：[`operations.md`](operations.md)
