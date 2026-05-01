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
4. 判断是否进入 TUI：无操作参数或显式 `-Tui` 时进入；`-Only`、`-DryRun`、`-SkipSkills` 等命令参数会沿用自动化命令模式。
5. 如进入 TUI，先 best-effort 切换英文输入布局，并向前台终端窗口请求切换输入语言。
6. 用户选择运行模式。默认安装会按默认配置继续执行；TUI 模式进入控制台工作台；安全演练走顶层独立 dry-run 路径。
7. TUI 工作台的软件入口会先检查本机状态，再默认勾选需要安装 / 更新的建议项，用户可用空格去除本次不处理的项；Skill 状态只检查 Skill 是否存在，所有套件状态页才展示 Profile / MCP / CLI 总览；安装动作仍可选择套件或任选安装单项 Skill / MCP / CLI，并在执行摘要页把选择结果写回等价参数。
8. 只有进入 Skill 状态页、所有套件状态页、Skill 复选页或实际执行 Skill 导入时，才按需获取 `skills.zip` 并读取 Profile；TUI 首屏不再预取 Skill bundle，读取前会先显示正在读取提示。
9. 非 `-DryRun` 且非管理员时，通过 UAC 保留当前参数重新拉起；UAC 交接窗口只提示后续在管理员窗口继续。提权后优先用 Windows Terminal 承载管理员 PowerShell，系统没有 `wt.exe` 时才回退到经典 PowerShell。
10. 如果没有 `-SkipApps`，按 `-Only` 过滤应用，并按 `order` 排序。
11. 对选中的应用先做并行预检查：先判断是否存在；缺失项不查最新版本，后续直接安装；已存在项才查询目标版本并决定更新或跳过。
12. 预检查完成后立即输出执行计划统计；只有安装 / 更新项会逐项显示，跳过项只进入执行摘要，不在计划里逐项刷屏。
13. 如果没有 `-SkipSkills`，按需获取公开 `bootstrap-assets/skills.zip`。
14. 如选择 `cc-switch` 且没有 `-SkipCcSwitch`，读取或询问 Provider 配置。
15. 创建 Codex 默认工作目录。
16. 按 `order` 串行消费预检查结果；安装项显示“准备安装”，更新项显示“准备更新”，检查失败项直接进入失败摘要。
17. 应用阶段结束后，如果没有 `-SkipSkills`，执行 Skill bundle 导入。
18. 最后导入 CC Switch Provider deep link。
19. 输出 Summary；任一项失败则退出码为 `1`，否则为 `0`。

安装阶段总进度输出简洁文字，例如 `[当前/总数] 当前步骤`；应用内部可量化进度才输出脚本自绘进度条，例如下载、winget 下载 / 安装和 Skill bundle 解压。不再调用 `Write-Progress` 绘制宿主进度条，也不使用会触发宿主进度区域的 `Expand-Archive`。自举依赖和 Release 资产下载同样使用脚本自绘进度条；如果服务器没有返回文件大小，则只显示完成状态。

`PauseOnExit`、`KeepShellOpen`、`UserHomeOverride`、`BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag`、`RefreshBootstrapDependencies` 属于启动或自举参数，不会单独触发命令模式。

TUI 默认安装模式只写入内部的 `BootstrapTuiResolved` 标记，用于防止 UAC 提权后重复进入 TUI；它不会写入 `-Only`，因此会使用默认全量应用。如果启动 TUI 时已经显式带了 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 或 Skill 相关参数，默认安装会保留这些命令参数。TUI 模式和安全演练涉及应用集合时，会把数组参数压缩成逗号形式传递，避免 UAC 重启后出现位置参数解析错误；读取多选文本时兼容英文逗号、中文逗号和顿号。

## 应用安装门禁
应用 precheck 会按所选应用并行执行，但实际安装仍按 `order` 串行执行，避免多个安装器同时运行产生锁冲突。预检查后会先展示带模式的应用清单；实际安装阶段只处理“安装 / 更新”项。单个应用的门禁规则是：

- 未安装：进入安装，不查询目标版本。
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

执行阶段会计算总步骤，并显示 `[当前/总数] 当前步骤` 文本进度，便于复制、截图和远程排障。应用内部下载、winget 下载 / 安装和 Skill bundle 解压会显示脚本自绘进度条；静默 MSI/EXE 无法读取真实百分比时显示运行中和耗时。脚本不调用 PowerShell 原生 `Write-Progress`，Skill bundle 解压也不再调用 `Expand-Archive`，避免不同宿主额外绘制独立进度区域。winget 原始输出会先过滤许可证、免责声明和重复进度行，再把常见状态翻译为中文；真实终端中下载进度通过回车覆盖保持单行刷新。若输出被 Codex、CI 或日志重定向捕获，脚本会跳过中间百分比，只输出完成行，避免捕获器把回车覆盖展开成多行。

计入总步骤的项目包括：

- Codex 工作区准备。
- 每个选中的应用。
- Skill bundle 导入，除非传了 `-SkipSkills`。
- CC Switch Provider 导入，前提是本次选择了 `cc-switch` 且没有 `-SkipCcSwitch`，并且现有 provider 预检查没有跳过。

应用阶段开始前只在存在安装 / 更新项时输出“准备安装或更新的应用清单”，逐行列出应用名称和 key。Skill 导入阶段按 skill 聚合展示进度和结果，不再默认输出每个目标目录的长路径复制明细；被跳过、警告或失败的情况仍保留原因。

如果传入 `-SkipApps`，应用阶段会显示“跳过软件安装”，不会按 manifest 安装或更新任何应用。这个参数主要由 TUI 工作台的“只安装 Skill”路径生成，也可用于命令模式自动化。

Skill 文件复制完成后，`-SkillsManagerScenarioMode` 决定是否写入 Skills Manager 场景启用：`default` 写入当前默认场景，`custom` 写入或创建指定自定义场景，`skip` 只复制文件不写场景，`prompt` 在交互式终端询问并在非交互式环境跳过场景注册。

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
