# 安装执行顺序

> 本文解释 `bootstrap.ps1` / `modules/common.psm1` 的当前行为。应用清单、目标版本和 fallback 文件名不要写在这里，统一以 `manifest/apps.json` 为准。

## 执行入口

- `bootstrap.ps1`：主脚本，承载参数解析、自举、提权、安装和汇总。
- `bootstrap.cmd`：本地启动壳，使用 Windows PowerShell 5.1 执行主脚本。
- `vibe-coding-setup.cmd`：远程自举入口，拉取 GitHub `main` 上的脚本依赖后运行。

## 执行顺序

1. 决定 `BootstrapSourceRoot`：本地仓库完整时使用本地文件，否则使用 GitHub raw `main`。
2. 同步自举依赖：`modules/common.psm1` 和 `manifest/apps.json`。
3. 导入模块并读取 `manifest/apps.json`。
4. 判断是否进入 TUI：无操作参数或显式 `-Tui` 时进入；`-Only`、`-DryRun`、`-SkipSkills` 等命令参数会沿用旧命令模式。
5. 如进入 TUI，先 best-effort 切换英文输入布局，并向前台终端窗口请求切换输入语言。
6. 用户选择运行模式。默认安装会直接回到原默认流程；自定义选择和安全演练会继续选择应用、安装选项和 Skill Profile，并把选择结果写回等价参数。
7. 如果自定义流程进入 Skill 复选页，才按需获取 `skills.zip` 并读取 Profile；TUI 首屏不再预取 Skill bundle。
8. 非 `-DryRun` 且非管理员时，通过 UAC 保留当前参数重新拉起；UAC 交接窗口只提示后续在管理员窗口继续。提权后优先用 Windows Terminal 承载管理员 PowerShell，系统没有 `wt.exe` 时才回退到经典 PowerShell。
9. 按 `-Only` 过滤应用，并按 `order` 排序。
10. 如果没有 `-SkipSkills`，按需获取公开 `bootstrap-assets/skills.zip`。
11. 如选择 `cc-switch` 且没有 `-SkipCcSwitch`，读取或询问 Provider 配置。
12. 创建 Codex 默认工作目录。
13. 对每个应用做版本门禁和安装。
14. 应用阶段结束后，如果没有 `-SkipSkills`，执行 Skill bundle 导入。
15. 最后导入 CC Switch Provider deep link。
16. 输出 Summary；任一项失败则退出码为 `1`，否则为 `0`。

安装阶段总进度输出简洁文字，例如 `[当前/总数] 当前步骤`；应用内部可量化进度才输出脚本自绘进度条，例如下载和 winget 百分比。不再调用 `Write-Progress` 绘制宿主进度条。自举依赖和 Release 资产下载同样使用脚本自绘进度条；如果服务器没有返回文件大小，则只显示完成状态。

`PauseOnExit`、`KeepShellOpen`、`UserHomeOverride`、`BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag`、`RefreshBootstrapDependencies` 属于启动或自举参数，不会单独触发命令模式。

TUI 默认安装模式只写入内部的 `BootstrapTuiResolved` 标记，用于防止 UAC 提权后重复进入 TUI；它不会写入 `-Only`，因此仍遵循原脚本“未指定 `-Only` 时使用默认全量应用”的行为。如果启动 TUI 时已经显式带了 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 或 Skill 相关参数，默认安装会保留这些原命令参数。自定义选择和安全演练涉及应用集合时，会把数组参数压缩成逗号形式传递，避免 UAC 重启后出现位置参数解析错误；读取多选文本时兼容英文逗号、中文逗号和顿号。

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

## 进度展示

执行阶段会计算总步骤，并显示 `[当前/总数] 当前步骤` 文本进度，便于复制、截图和远程排障。应用内部下载和 winget 百分比会显示脚本自绘进度条；静默 MSI/EXE 无法读取真实百分比时显示运行中和耗时。脚本不调用 PowerShell 原生 `Write-Progress`，避免不同宿主额外绘制独立进度区域。

计入总步骤的项目包括：

- Codex 工作区准备。
- 每个选中的应用。
- Skill bundle 导入，除非传了 `-SkipSkills`。
- CC Switch Provider 导入，前提是本次选择了 `cc-switch` 且没有 `-SkipCcSwitch`，并且现有 provider 预检查没有跳过。

应用阶段开始前会输出“选中的安装应用清单”，逐行列出应用名称和 key。Skill 导入阶段按 skill 聚合展示进度和结果，不再默认输出每个目标目录的长路径复制明细；被跳过、警告或失败的情况仍保留原因。

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
