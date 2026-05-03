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
6. 用户选择运行模式。默认安装会按默认配置继续执行；自定义模式进入控制台工作台；安全演练走顶层独立 dry-run 路径。
7. 自定义模式的软件、套件、Skill、MCP、CLI 入口统一采用“检查并安装/更新 ...”路径：先检查本机或配置状态，再选择本次要处理的项；工作台先显示可执行动作，只有有可执行选择后才在动作区下方显示当前选择并显示“开始执行”，最终执行确认页把选择结果写回等价参数。
8. 只有进入 Skill / 套件 / MCP / CLI 相关入口，或后续安装 / 演练实际要导入 Skill 时，才按需获取 `skills.zip` 并读取 Profile；TUI 首屏不再预取 Skill bundle，读取结果会在本轮自定义模式中复用，读取前会先显示正在读取提示，并在 Skill / MCP / CLI 状态扫描期间分别以 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 标签同一行刷新完成数量，结束时只保留完成行。套件页展示 Bundle Skill、可选 Skill、本机已安装和可能新增数量；单项 Skill 选择页合并 `BundleSkills + RegistrySkills` 后去重展示，并显示 Skill 总数、已安装、未安装、bundle / external 统计；MCP / CLI 单项页显示总数、已配置或已检测到数量，以及未配置或未检测到数量。这里的更新检查采用低开销本地对比：Skill 比较当前 bundle meta 与本机 meta，MCP 只检查是否已配置并保留用户自有配置语义，CLI 只做本地命令检测并把更新状态标为未知。MCP 状态读取异常会显示 TUI 错误页并返回工作台。
9. 非 `-DryRun` 且非管理员时，通过 UAC 保留当前参数重新拉起；UAC 交接窗口只提示后续在管理员窗口继续。提权后优先用 Windows Terminal 承载管理员 PowerShell，系统没有 `wt.exe` 时才回退到经典 PowerShell。
10. 如果没有 `-SkipApps`，按 `-Only` 过滤应用，并按 `order` 排序。
11. 对选中的应用先做并行预检查：先判断是否存在；缺失项不查最新版本，后续直接安装；已存在项才查询目标版本并决定更新或跳过。
12. 预检查完成后立即输出执行计划统计；只有安装 / 更新项会逐项显示，跳过项只进入执行摘要，不在计划里逐项刷屏。
13. 记录是否需要配置导入和插件安装；此时不预先下载 `skills.zip`。
14. 如选择 `cc-switch` 且没有 `-SkipCcSwitch`，配置导入会在应用阶段结束后读取或询问 Provider 配置。
15. 创建 Codex 默认工作目录。
16. 按 `order` 串行消费预检查结果；安装项显示“准备安装”，更新项显示“准备更新”，检查失败项直接进入失败摘要。
17. 应用阶段结束后，如果本次选择了 `cc-switch` 且没有 `-SkipCcSwitch`，先执行配置导入。
18. 如果没有 `-SkipSkills`，再执行插件安装：获取 `skills.zip`，导入 Skill / 套件 / MCP / CLI 前置依赖；交互式默认安装在套件输入区前会先执行节能版 Skill / MCP / CLI 状态扫描，并把 `全部 Skill`、`所有套件` 和各 Profile 标记为已安装、部分安装、需更新、更新未知或未安装；其中 MCP 只参与已配置 / 未配置判断，不产生需更新状态。
19. 输出 Summary；任一项失败则退出码为 `1`，否则为 `0`。

默认安装用 `步骤一：获取依赖`、`步骤二：应用安装`、`步骤三：配置导入`、`步骤四：插件安装` 承载阶段语义，最终完成提示为 `恭喜：安装流程完成`；只有进入 TUI 首屏前的共同自举使用无编号 `获取依赖` 标题。工作区准备、配置导入和插件安装不再额外输出 `[当前/总数] 当前步骤` 阶段提示。主流程大区域之间保留两行空白，区域内的输入区 / 配置摘要等小分块保持一行空白。应用预检查、Skill / MCP / CLI 状态扫描和应用内部可量化进度才输出脚本自绘进度条；组件扫描统一显示 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 标签，下载、winget 下载 / 安装和 Skill bundle 解压继续使用各自进度文案。不再调用 `Write-Progress` 绘制宿主进度条，也不使用会触发宿主进度区域的 `Expand-Archive`。自举依赖会在复用本地缓存时显示同步完成进度，Release 资产下载同样使用脚本自绘进度条；如果服务器没有返回文件大小，则只显示完成状态。

`PauseOnExit`、`KeepShellOpen`、`UserHomeOverride`、`BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag`、`RefreshBootstrapDependencies` 属于启动或自举参数，不会单独触发命令模式。

TUI 默认安装模式只写入内部的 `BootstrapTuiResolved` 标记，用于防止 UAC 提权后重复进入 TUI；它不会写入 `-Only`，因此会使用默认全量应用。如果启动 TUI 时已经显式带了 `-DryRun`、`-SkipSkills`、`-SkipCcSwitch` 或 Skill 相关参数，默认安装会保留这些命令参数。自定义模式和安全演练涉及应用集合时，会把数组参数压缩成逗号形式传递，避免 UAC 重启后出现位置参数解析错误；读取多选文本时兼容英文逗号、中文逗号和顿号。

## 应用安装门禁

应用 precheck 会按所选应用并行执行，但实际安装仍按 `order` 串行执行，避免多个安装器同时运行产生锁冲突。预检查后会先展示带模式的应用清单；实际安装阶段只处理“安装 / 更新”项。单个应用的门禁规则是：

并行预检查会在终端同一行刷新已完成数量，最后刷新为完成行；默认模式和自定义模式的软件入口使用同一套进度提示。Skill / MCP / CLI 状态扫描也采用同一行刷新，并分别显示 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 标签：真实终端动态覆盖，Codex、CI 或日志重定向只保留完成行。bootstrap 会在本地 `common.psm1` 缺少 TUI 进度支持时刷新依赖；旧模块兜底路径会先输出新版预览，再静默旧模块自身 Host 进度，避免套件页重复显示 MCP / CLI。winget 安装如果已经输出成功但外层进程未退出，脚本会短暂等待后结束卡住的 winget 外壳并继续后续检测；没有成功输出时仍按原始退出码处理失败。

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

应用内部下载、winget 下载 / 安装和 Skill bundle 解压会显示脚本自绘进度条；静默 MSI/EXE 无法读取真实百分比时显示运行中和耗时。脚本不调用 PowerShell 原生 `Write-Progress`，Skill bundle 解压也不再调用 `Expand-Archive`，避免不同宿主额外绘制独立进度区域。winget 原始输出会先过滤许可证、免责声明和重复进度行，再把常见状态翻译为中文；真实终端中下载进度通过回车覆盖保持单行刷新。若输出被 Codex、CI 或日志重定向捕获，脚本会跳过中间百分比，只输出完成行，避免捕获器把回车覆盖展开成多行。

默认安装的终端输出按四段展示：`步骤一：获取依赖`、`步骤二：应用安装`、`步骤三：配置导入`、`步骤四：插件安装`。应用阶段开始前只在存在安装 / 更新项时输出“准备安装或更新的应用清单”，逐行列出应用名称和 key。配置导入阶段先处理 CC Switch Provider，并在执行摘要中显示为“配置导入”；插件安装阶段再下载 / 复用 `skills.zip`，并按 skill 聚合展示进度和结果，不再默认输出每个目标目录的长路径复制明细；被跳过、警告或失败的情况仍保留原因。

如果传入 `-SkipApps`，应用阶段会显示“跳过软件安装”，不会按 manifest 安装或更新任何应用。这个参数主要由自定义模式的“只安装 Skill”路径生成，也可用于命令模式自动化。

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
