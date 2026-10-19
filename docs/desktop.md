# 桌面安装器

## 范围

Windows 桌面界面使用 Tauri 2、React 和 TypeScript。软件清单与安装策略仍由 `manifest/apps.json` 和 `modules/common.psm1` 维护。无操作参数的启动脚本默认进入桌面界面。

桌面界面支持软件选择、环境检查、安全演练、应用安装、CC Switch Provider 导入、逐项结果、失败重试、停止后续任务、亮暗主题和脱敏诊断导出。“扩展组件”页直接选择和安装套件、Skills、MCP、CLI，选择过程与执行结果都在 Tauri 内显示。

## 构建与启动

运行机器需要 Windows PowerShell 5.1 与 WebView2 Runtime；无需安装编译工具。本地源码目录缺少 exe 时，启动脚本自动下载已发布的 GUI。需要修改和构建界面时，开发机器才需要 Node.js、Rust MSVC 工具链、Visual Studio C++ Build Tools。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Desktop.ps1
```

构建产物固定为 `desktop/bin/IndieArkSetup.exe`，不进入版本控制。再次构建可传 `-SkipInstall` 复用已安装的 npm 依赖；依赖变化时重新运行完整构建。

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

停止操作只阻止后续任务；当前下载、安装器或配置导入会继续完成。执行中阻止直接关闭窗口，避免失去任务状态。CC Switch 的 deep link 只能证明导入窗口已打开，最终保存由用户在 CC Switch 确认。

## 扩展组件

首次进入扩展页时才按需获取公开 Release 的 `skills.zip`，随后读取真实 registry 清单和本机状态。“检查状态”复用本地缓存，“更新清单”重新下载扩展包；未进入该页的普通软件安装无需下载扩展包。

扩展页提供套件、Skills、MCP、CLI 分类和搜索。默认不选扩展，可混选套件和单项；右侧显示实际展开的 Skill 成员、MCP 和 CLI 依赖，执行前后端再次验证全部组件 ID，再合并、去重并调用 `Install-SkillBundle`。空选择或失效 ID 均不进入安装。

Skill 状态沿用本机中央目录与 bundle 元数据对比；MCP 的“已有配置”只表示某个支持的客户端存在配置，详情列出客户端，不代表连接成功；CLI 只检测本地命令，不推断版本最新。真实执行后将检查结果标为需要重新检查；演练不会把组件状态改为已安装。

GUI 导入保留来源不明和其他来源的同名 Skill，更新继续使用内核的来源识别和备份策略。默认跳过 Skills Manager 场景注册且不启动它。扩展批次作为一个完整安装步骤，开始后停止请求不会中断批次内部正在执行的动作。内核产生的警告会显示提示数量，并在执行记录及诊断中保留。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-BootstrapDownloads.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Desktop.ps1
```

桌面检查包含隔离安装函数的 Worker 协议验证、失效选择拦截、失败继续、停止边界、Key 脱敏、扩展清单、套件成员展开、混选去重、CLI 单独安装计划、空选择保护、两个旧 `.cmd` 的 GUI 路由，以及 exe 自带真实 Worker 的安全演练和原生扩展协议。验证不安装软件、不打开 GUI 或 CC Switch、不改用户配置。前端状态测试使用 `desktop` 下的 `npm test`。

人工验收：

1. 双击任意本地 `.cmd` 并确认权限请求，应进入同一个桌面界面。
2. 推荐应用应选中，Skills Manager 默认不选中；检查环境后，软件状态应反映本机结果。
3. 点击“安全演练”，应持续显示进度和结果，不执行真实安装，也不弹出 CC Switch。
4. 点击“扩展组件”，应在同一窗口显示四类组件，不弹出终端；搜索并混选套件与单项，右侧应显示合并后的清单。点击“安全演练”，应显示扩展进度和结果，不写用户配置。
5. 切换亮暗主题、缩放窗口、用键盘访问字段，检查布局、焦点和滚动。
6. 实际安装与 CC Switch 最终保存由用户单独执行验收；自动检查不代替这一步。

## 发布与更新

旧的独立远程 `.cmd` 每次从 GitHub `main` 下载主脚本，并获取公开的 GUI 资产。桌面发布必须同时交付：

- 新版 `bootstrap.ps1`、共享模块、`scripts/DesktopWorker.ps1`。
- `bootstrap-assets/IndieArkSetup.exe` 公开资产。

发布 workflow 为 `.github/workflows/publish-desktop.yml`。推送 `release/desktop-*` 分支，或手动运行该 workflow 后，Windows runner 使用锁定依赖构建、检查两种旧启动脚本与打包 Worker，再用 Actions 的 `GITHUB_TOKEN` 上传 `IndieArkSetup.exe` 及 SHA256 文件。它只更新这两个资产，保留其它旧安装包。

首次切换默认入口时，先推送发布分支并确认 workflow 成功，再核验公开下载与安全演练，最后把同一提交快进到 `main`。后续桌面更新也先验证发布资产，再推进入口代码；远程资产下载失败时明确报错，不静默使用残留文件。完整资产管理规则见 [资产刷新链路](asset-refresh.md)。

桌面程序通过固定命令调用后端，不开放任意 shell、文件写入或远程页面。当前 exe 尚未进行代码签名；正式对外分发前需核对 Windows 分发体验和签名方案。
