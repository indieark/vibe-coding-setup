# 桌面安装器

## 范围

Windows 桌面界面使用 Tauri 2、React 和 TypeScript。软件清单与安装策略仍由 `manifest/apps.json` 和 `modules/common.psm1` 维护。无操作参数的启动脚本默认进入桌面界面。

窗口使用一体化顶栏，支持拖动、双击最大化或还原、主题切换、最小化和关闭；执行中关闭仍由宿主拦截。软件与扩展列表采用紧凑双行布局，套件、Skills、MCP、CLI 和配置字段使用统一语义图标。软件品牌图标随程序打包，来源与许可见 [软件图标](../desktop/src/assets/apps/README.md)。

扩展列表的名称与描述间距固定为 3px，描述最多显示两行；完整说明在右侧详情中展示。列表行高随内容自然增长，长清单在区块内滚动。

桌面界面支持软件选择、环境检查、安全演练、应用安装、CC Switch Provider 导入、逐项结果、失败重试、停止后续任务、亮暗主题和脱敏诊断导出。“扩展组件”页直接选择和安装套件、Skills、MCP、CLI，并配置来源冲突策略及 Skills Manager 场景。软件、API 配置与扩展统一组成一次执行计划。

## 构建与启动

运行机器需要 Windows PowerShell 5.1 与 WebView2 Runtime；无需安装编译工具。本地源码目录缺少 exe 时，启动脚本自动下载已发布的 GUI。需要修改和构建界面时，开发机器才需要 Node.js、Rust MSVC 工具链、Visual Studio C++ Build Tools。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Desktop.ps1
```

当前构建产物为 `desktop/bin/IndieArkSetup-0.2.3.exe`，版本取自 `tauri.conf.json`，不进入版本控制。再次构建可传 `-SkipInstall` 复用已安装的 npm 依赖；依赖变化时重新运行完整构建。

发布构建按 [Tauri 官方体积建议](https://tauri.app/concept/size/) 使用 `opt-level = "s"`、LTO、单代码生成单元和符号剥离，优先减小 exe。`panic = "abort"` 移除 Rust panic 展开代码；不可恢复的 Rust panic 会终止进程，安装与配置的常规错误仍通过现有结果和事件返回。界面与完整脚本仍内嵌，体积优化不依赖额外解压工具。

构建同时生成本地 `desktop/bin/IndieArkSetup.exe` 兼容副本，供内容固定的旧 `.cmd` 识别本地仓库，再由主脚本选择当前版本。发布只上传带版本的 exe 与 SHA256，不覆盖公开 Release 中原有的未版本化安装包。

更早的远程启动器把主脚本保存为 `vibe-bootstrap.ps1`；进入桌面界面前，主脚本会同步一份 `bootstrap.ps1`，保证交给宿主的目录含有完整运行资源。旧 `.cmd` 无需更新。

- 双击 `bootstrap.cmd`：无操作参数时打开本地 GUI，启动时申请管理员权限。
- 双击仓库中的 `vibe-coding-setup.cmd`：检测到本地 GUI 后使用同目录主脚本；独立下载的启动器从 GitHub 获取已发布版本。
- `bootstrap.cmd -Gui`：显式打开 GUI。
- `bootstrap.cmd -Gui -DryRun`：打开强制演练模式，软件与扩展组件均不执行真实安装，也不申请管理员权限。
- `bootstrap.cmd -GuiCheck`：检查可执行文件和入口路径，不打开窗口、不申请权限。
- `bootstrap.cmd -Tui`：显式打开旧终端工作台。
- `bootstrap.cmd -DryRun ...` 等原有参数：保留命令模式，不启动 GUI。

直接运行 exe 时可以安全演练；真实安装需要通过启动脚本申请管理员权限。启动器把原用户主目录显式传入，避免提权后将配置导入到另一个默认目录。

## 执行链路

| 层次 | 文件 | 职责 |
|---|---|---|
| 入口 | 原有 `.cmd`、`bootstrap.ps1` | 本地 / 远程路由、获取 GUI、申请权限 |
| 界面 | `desktop/src/` | 软件与扩展清单、配置表单、任务状态和诊断入口 |
| 宿主 | `desktop/src-tauri/src/main.rs` | 固定命令、子进程 stdin、事件转发、并发任务互斥 |
| 协议适配 | `scripts/DesktopWorker.ps1` | 校验计划、调用共享安装模块、发送 JSON Lines 事件 |
| 安装内核 | `modules/common.psm1` | 检测、版本门禁、安装、回退、CC Switch 与扩展导入 |

启动器通过 `--source-root` 把本轮获取的主脚本、模块、安装清单和 Worker 交给 GUI，再复制到本轮独立运行目录。这样更新安装清单不必重建界面，也不会复用 exe 内旧的 fallback 文件名。直接运行 exe 时，才使用构建时嵌入的完整资源。

API Key 从界面经 stdin 传入 PowerShell Worker，Worker 启动参数和任务文件不含 Key；前端不持久化，诊断报告也不记录明文。CC Switch 最终导入仍沿用现有 deep link 协议。界面只持久化主题；结构化事件在离开 Worker 前同时屏蔽原始、JSON 转义和 URL 编码的 Key。执行日志和最终结果按事件传递，不从终端文字推断成功。

运行目录位于 `%LOCALAPPDATA%/IndieArk/Setup/runs/<本轮标识>/`，内含本轮脚本、应用下载缓存和用户主动导出的脱敏诊断。扩展包缓存在 `%LOCALAPPDATA%/IndieArk/Setup/cache/skills.zip`。没有后台服务。已运行的界面使用本轮文件，更新后需要重新打开。

停止操作只阻止后续任务；当前下载、安装器或配置步骤会继续完成。Skill、CLI 在单项之间响应停止，MCP 配置按一次客户端写入批次完成。执行中阻止直接关闭窗口，避免失去任务状态。CC Switch 的 deep link 只能证明导入窗口已打开，界面标为“待外部确认”，最终保存由用户在 CC Switch 确认。

## 统一计划与功能覆盖

底部“执行本次计划”或“安全演练”处理当前选择的软件、API 和扩展；执行前，后端先验证整个计划，再进行安装或配置写入。“计划与结果”页列出逐项状态、错误和备份路径，日志独立折叠。API 配置区的“仅处理 API 配置”不安装软件或扩展。

| 原安装器操作 | 桌面入口 |
|---|---|
| 推荐安装、指定应用、不装应用 | 软件复选、恢复推荐、全选或清空 |
| 检查已安装版本与目标版本 | 检查环境；版本注明为检查时的快照 |
| 单独导入 API；已有同名 Provider 跳过 | 仅处理 API 配置；“已有则保留”或“重新导入” |
| 全部 Skills、所有套件、单项组件 | 扩展分类、筛选结果全选、全部 Skills、全部套件 |
| Orphan / Foreign 保留、替换、改名 | 扩展页“导入与场景设置”；替换前需明确勾选确认 |
| Skills Manager 默认、自定义或跳过场景 | 扩展导入设置；可选择是否允许初始化并打开管理器 |
| 安全演练、失败重试、停止、诊断 | 固定操作栏与逐项结果页 |

默认保留已有同名 Provider，不回传数据库中的 Key。选择重新导入时使用用户填写的新参数；实际执行前再次查询，界面的检查快照不会替代后端判断。场景注册沿用内核及其 Python / Skills Manager 数据库前置条件；条件不满足时显示提示，不声称注册成功。

## 扩展组件

首次进入扩展页时才按需获取公开 Release 的 `skills.zip`，随后读取真实 registry 清单和本机状态。“检查状态”复用本地缓存，“更新清单”重新下载扩展包；未进入该页的普通软件安装无需下载扩展包。

扩展页提供套件、Skills、MCP、CLI 分类和搜索。默认不选扩展，可混选套件和单项；右侧显示实际展开的 Skill 成员、MCP 和 CLI 依赖，执行前后端再次验证全部组件 ID，再合并、去重并调用 `Install-SkillBundle`。空选择或失效 ID 均不进入安装。

Skill 状态沿用本机中央目录与 bundle 元数据对比；MCP 的“已有配置”只表示某个支持的客户端存在配置，详情列出客户端，不代表连接成功；CLI 只检测本地命令，不推断版本最新。真实执行后将检查结果标为需要重新检查；演练不会把组件状态改为已安装。

GUI 默认保留来源不明和其他来源的同名 Skill；可改为备份后替换，Foreign 还支持新版本改名导入。实际替换必须确认策略，安全演练不需要确认也不会写入目录。默认跳过 Skills Manager 场景注册且不启动它，可显式选择默认或自定义场景并允许初始化。来源识别、去重和备份仍由共享内核执行；真实备份路径和演练中的计划备份路径分别标注，失败、保留、需手动处理与成功不混用。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-BootstrapDownloads.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Desktop.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-DesktopComponents.ps1
```

桌面检查包含隔离安装函数的 Worker 协议验证、失效选择拦截、失败继续、停止边界、Key 脱敏、扩展清单、套件成员展开、混选去重、CLI 单独安装计划、空选择保护、两个旧 `.cmd` 的 GUI 路由，以及 exe 自带真实 Worker 的安全演练和原生扩展协议。验证不安装软件、不打开 GUI 或 CC Switch、不改用户配置。前端状态测试使用 `desktop` 下的 `npm test`。

人工验收：

1. 双击任意本地 `.cmd` 并确认权限请求，应进入同一个桌面界面。
2. 推荐应用应选中，Skills Manager 默认不选中；检查环境后，软件状态应反映本机结果。
3. 点击“安全演练”，应持续显示进度和结果，不执行真实安装，也不弹出 CC Switch。
4. 点击“扩展组件”，应在同一窗口显示四类组件，不弹出终端；搜索并混选套件与单项，右侧应显示合并后的清单。点击“安全演练”，应显示扩展进度和结果，不写用户配置。
5. 清空软件和扩展，仅处理 API；已有同名 Provider 应保留且不要求 Key。选择重新导入后应允许填写新参数。
6. 在扩展设置中选择不同冲突策略及场景，先演练；结果页应列出每项状态及计划备份。选择备份后替换但未确认时，真实执行应被拦截。
7. 切换亮暗主题、缩放窗口、用键盘访问字段，检查字号、整行选择、折叠清单、焦点和内部滚动。视觉和真实操作由用户实机验收。
   拖动顶栏空白或品牌区、双击顶栏，并测试最小化、最大化、还原和关闭；应只有一层顶栏，主题和窗口按钮可独立点击，软件图标在两种主题下清晰可见。
8. 实际安装与 CC Switch 最终保存由用户单独执行验收；自动检查不代替这一步。

## 发布与更新

旧的独立远程 `.cmd` 每次从 GitHub `main` 下载主脚本，并获取公开的 GUI 资产。桌面发布必须同时交付：

- 新版 `bootstrap.ps1`、共享模块、`scripts/DesktopWorker.ps1`。
- `bootstrap-assets/IndieArkSetup-0.2.3.exe` 及对应 SHA256 公开资产。

发布 workflow 为 `.github/workflows/publish-desktop.yml`。推送 `release/desktop-*` 分支，或手动运行该 workflow 后，Windows runner 使用锁定依赖构建、检查两种旧启动脚本与打包 Worker，再用 Actions 的 `GITHUB_TOKEN` 上传带版本的 exe 和 SHA256 文件。它只更新该版本的两个资产，保留其它旧安装包，包括原来的 0.1 GUI。

入口固定引用匹配协议的 GUI 版本；0.2 使用 Worker 协议 2。先发布新版本资产，再更新 `main` 的脚本与 Worker，避免发布期间旧 Worker 配到新界面。构建目录也按版本隔离，不覆盖仍在运行的旧 exe。

首次切换默认入口时，先推送发布分支并确认 workflow 成功，再核验公开下载与安全演练，最后把同一提交快进到 `main`。后续桌面更新也先验证发布资产，再推进入口代码；远程资产下载失败时明确报错，不静默使用残留文件。完整资产管理规则见 [资产刷新链路](asset-refresh.md)。

桌面程序通过固定命令调用后端，不开放任意 shell、文件写入或远程页面。当前 exe 尚未进行代码签名；正式对外分发前需核对 Windows 分发体验和签名方案。
