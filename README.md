# Windows 一键部署脚本

这个仓库用于在 Windows 上一键拉起开发环境、桌面工具和技能包，主入口是 `bootstrap.ps1`，`bootstrap.cmd` 只是它的本地启动壳，`run-remote-bootstrap.cmd` 是远程自举入口。

当前仓库的设计重点不是“纯离线安装”，而是把安装来源分成两层：

- 主来源：`winget`、上游 GitHub Releases、固定直链、自托管 GitHub Release 资产
- 回退来源：大多数应用退到 `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release 资产；`PowerShell 7`、`Codex Desktop` 会退到官方 `winget` / Microsoft Store 来源

## 当前包含

- `PowerShell 7`
- `Git`
- `Node.js`
- `Python 3.13`
- `Visual Studio Code`
- `Codex Desktop`
- `ChatGPT (Pake)`
- `CC Switch`
- `Codex Provider Sync`
- `Skills Manager`

## 主脚本逻辑

下面是 `bootstrap.ps1` 的实际执行顺序，按代码路径整理。

### 1. 先决定自举来源

脚本先确认 `modules/common.psm1` 和 `manifest/apps.json` 从哪里来：

- 如果当前目录已经有这两个文件，`BootstrapSourceRoot` 默认就是本地仓库根目录
- 如果当前目录不完整，默认改为：
  - `https://raw.githubusercontent.com/indieark/vibe-coding-setup/main`

然后同步这两个依赖：

- `modules/common.psm1`
- `manifest/apps.json`

`-RefreshBootstrapDependencies` 会强制刷新；远程 HTTP 源也会默认刷新。

### 2. 导入模块并处理管理员权限

`bootstrap.ps1` 导入 `modules/common.psm1` 后，如果不是 `-DryRun` 且当前没有管理员权限，会保留原参数并自动用 UAC 重新拉起自身。

### 3. 读取安装清单并过滤目标

脚本从 `manifest/apps.json` 读取全部应用定义，然后根据：

- `-Only git,nodejs,...`

过滤出本次要处理的应用集合，最后按 `order` 字段顺序执行。

### 4. 预取 `skills.zip`

如果本次选择了 `skills-manager`，且没有传 `-SkipSkills`，脚本会先下载：

- `downloads/skills.zip`

来源固定为：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

这一步在正式安装应用前执行。

### 5. 可选读取 CC Switch Provider 输入

如果本次选择了 `cc-switch`，且没有传 `-SkipCcSwitch`，脚本会先读取用户输入：

- Provider 名称，默认 `IndieArk API 2`
- `base_url`，默认 `https://api2.indieark.tech/v1`
- 默认模型，默认 `gpt-5.4`
- `api_key`

### 6. 创建 Codex 默认工作目录

脚本会创建工作目录：

- 优先 `D:\Vibe Coding\Chat`
- 如果没有 `D:` 盘，则回退到 `C:\Vibe Coding\Chat`

### 7. 每个应用都会先做版本门禁

`Install-AppFromDefinition` 不会无脑安装，而是先执行 precheck：

- 先检测当前是否已安装
- 再解析目标版本
- 决定是 `skip` 还是继续安装/更新

当前安装检测顺序是：

1. `command` 检测
2. `appx` 检测
3. 卸载注册表检测

也就是说，一个应用如果同时定义了多种检测方式，命令行检测优先，找不到再看 Appx，再看注册表。

目标版本来源规则如下：

- 如果 manifest 里显式写了 `targetVersion`，优先用它
- `strategy = winget` 时，优先用 `winget show --id ...` 解析最新版本
- `strategy = github-latest-tag` 时，用 GitHub `/releases/latest` 跳转结果解析 tag
- `strategy = release-asset` 时，从资产文件名里提取版本号
- 其它策略如果没有可比较版本，就会进入“目标版本不可比较”分支

precheck 决策规则：

- 未安装：安装
- 已安装但版本低于目标：更新
- 已安装且版本不低于目标：跳过
- 已安装但当前版本或目标版本无法比较：继续安装，让上游来源自行处理

### 8. 应用安装的主来源与回退逻辑

当前代码支持这些安装策略：

- `winget`
- `direct-url`
- `github-latest-tag`
- `github-release`
- `release-asset`

这个仓库当前实际用到的是前四种。

统一逻辑是：

1. 先走主策略
2. 主策略失败则记录 warning
3. 如果 manifest 定义了 `fallback.releaseAsset`，再退到 `bootstrap-assets` Release 资产
4. 如果 manifest 定义了 `fallback.uriCandidates`，则按顺序打开官方 URI / 页面
5. 回退也失败，则该应用标记为失败

下载的安装包统一落到：

- `downloads/`

安装器执行方式：

- `msi` 走 `msiexec.exe /i ... /qn /norestart`
- `exe` 直接静默参数启动
- `msix` 走 `Add-AppxPackage`
- `uri` 走 `Start-Process`，用于拉起官方 Store 协议或官方下载页面

### 9. 安装完应用后再导入 `skills.zip`

如果本次安装包含 `skills-manager` 且没有 `-SkipSkills`，脚本会在应用安装阶段结束后执行 `Install-SkillBundle`：

1. 解压 `downloads/skills.zip`
2. 递归查找所有包含 `SKILL.md` 的目录
3. 复制到 `~/.skills-manager/skills/<skill-name>`
4. 同步复制到 `~/.codex/skills/<skill-name>`
5. 如果本机存在以下目录，也会一起同步：
   - `~/.claude/skills`
   - `~/.cursor/skills`
   - `~/.gemini/antigravity/global_skills`
   - `~/.gemini/skills`
   - `~/.copilot/skills`
6. 如果不是 `-DryRun`，再写入 `~/.skills-manager/skills-manager.db`
7. 如果找到 `skills-manager.exe`，最后会自动拉起它

### 10. 最后导入 CC Switch Provider

`CC Switch` 的 Provider 导入不直接写 SQLite，而是调用官方 deep link：

- `ccswitch://v1/import?...`

执行前会先检查 `ccswitch://` 协议是否已注册；未注册时会报错，提示先启动一次 `CC Switch`。

### 11. 汇总结果并决定退出码

脚本最后会输出 Summary 表，字段包括：

- `Name`
- `Status`
- `Source`
- `Detail`

只要有任意一项 `Status = failed`，脚本退出码就是 `1`；否则退出码为 `0`。

## 安装来源与回退来源总表

下面这张表按当前 `manifest/apps.json` 精确整理。

| 应用 | 主来源 | 目标版本来源 | 安装检测 | 回退来源 |
| --- | --- | --- | --- | --- |
| `PowerShell 7` | `indieark/vibe-coding-setup@bootstrap-assets/PowerShell-7.6.1-win-x64.msi` | manifest 固定 `7.6.1` | `Get-AppxPackage -Name Microsoft.PowerShell` | `winget install --id 9MZ1SNWT0N5D --source msstore` |
| `Git` | `winget install --id Git.Git` | `winget show Git.Git` | `git --version`，失败后看注册表 `^Git$` | `indieark/vibe-coding-setup@bootstrap-assets/Git-2.54.0-64-bit.exe` |
| `Node.js` | `winget install --id OpenJS.NodeJS` | `winget show OpenJS.NodeJS` | `node --version`，失败后看注册表 `Node.js` | `indieark/vibe-coding-setup@bootstrap-assets/node-v25.9.0-x64.msi` |
| `Python 3.13` | `winget install --id Python.Python.3.13` | `winget show Python.Python.3.13` | `py -V` | `indieark/vibe-coding-setup@bootstrap-assets/python-3.13.13-amd64.exe` |
| `Visual Studio Code` | `winget install --id Microsoft.VisualStudioCode` | `winget show Microsoft.VisualStudioCode` | `code --version`，失败后看注册表 `Microsoft Visual Studio Code` | `indieark/vibe-coding-setup@bootstrap-assets/VSCodeUserSetup-x64-1.117.0.exe` |
| `Codex Desktop` | `winget install --id 9PLM9XGG6VKS --source msstore` | `winget show 9PLM9XGG6VKS --source msstore` | `Get-AppxPackage -Name OpenAI.Codex` | 官方 Microsoft Store：优先 `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`，失败再开 `https://apps.microsoft.com/detail/9PLM9XGG6VKS` |
| `ChatGPT (Pake)` | `https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x64.msi` | 无稳定可比较目标版本 | 注册表精确匹配 `ChatGPT` | `indieark/vibe-coding-setup@bootstrap-assets/ChatGPT_x64.msi` |
| `CC Switch` | `farion1231/cc-switch` 的 latest tag，对应资产模板 `CC-Switch-{tag}-Windows.msi` | GitHub latest tag | 注册表精确匹配 `CC Switch` | `indieark/vibe-coding-setup@bootstrap-assets/CC-Switch-v3.14.0-Windows.msi` |
| `Codex Provider Sync` | `indieark/vibe-coding-setup@bootstrap-assets/Codex.Provider.Sync_0.1.4_x64-setup.exe` | 从 release 资产文件名提取版本 | 注册表包含匹配 `Codex Provider Sync` | 无单独二级回退；主来源就是自托管 release 资产 |
| `Skills Manager` | `xingkongliang/skills-manager` 的 latest tag，对应资产模板 `skills-manager_{version}_x64_en-US.msi` | GitHub latest tag | 注册表正则匹配 `^(Skills Manager|skills-manager)$`；检测到后按 presence-only 跳过 | `indieark/vibe-coding-setup@bootstrap-assets/skills-manager_1.14.3_x64_en-US.msi` |

补充两个“非应用安装项”：

| 项目 | 主来源 | 回退来源 |
| --- | --- | --- |
| `modules/common.psm1`、`manifest/apps.json` 自举依赖 | 当前完整仓库；否则 `https://raw.githubusercontent.com/indieark/vibe-coding-setup/main` | 无单独二级回退 |
| `skills.zip` | `indieark/vibe-coding-setup@bootstrap-assets/skills.zip` | 无单独二级回退 |

## 特殊行为说明

### ChatGPT (Pake) 的版本门禁是弱的

因为它当前走的是固定直链：

- `https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x64.msi`

但 manifest 里没有可比较的 `targetVersion`，所以一旦机器上已经安装了它，precheck 仍然会进入：

- `unknown-target-version`

也就是不会稳定命中“已是最新版本就跳过”。

### Python fallback 现在改为真正的运行时安装包

之前 fallback 指向 `python-manager-26.0.msix`，更接近 Python 安装管理器，而不是 `Python 3.13` 本体。

现在改为官方：

- `python-3.13.13-amd64.exe`

并补了静默安装参数，保证 fallback 仍然符合一键安装语义。

### CC Switch Provider 导入没有回退实现

当前只支持官方 deep link：

- `ccswitch://v1/import`

如果协议没注册，脚本不会退回到 SQLite 直写；当前仍需要先手动启动一次 `CC Switch`，让 `ccswitch://` 协议完成注册后再重试。

### Codex Provider Sync 直接走自托管 release

因为 `indieark/codex-provider-sync` 是私有仓库，这里没有再走“先访问上游、失败后 fallback”的双层策略。

当前 manifest 直接把主来源指向：

- `indieark/vibe-coding-setup@bootstrap-assets/Codex.Provider.Sync_0.1.4_x64-setup.exe`

这样远程自举时不需要拥有私有仓库访问权限，也不会因为上游 release 不可见而在主路径上失败。

### `skills.zip` 也没有第二来源

当前 `skills.zip` 的来源只有：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

如果这个资产不存在或下载失败，技能导入阶段会直接失败。

### Skills Manager 按 presence-only 处理

`Skills Manager` 当前安装后的注册表元数据并不稳定：

- 实际 `DisplayName` 可能是 `skills-manager`
- 实际 `DisplayVersion` 可能不会跟 GitHub release tag 对齐

因此脚本现在对它采用 presence-only 预检：

- 先用正则同时匹配 `Skills Manager` / `skills-manager`
- 只要检测到已经安装，就不再按 GitHub latest tag 做版本升级判断

这样可以避免同一台机器在第二次、第三次运行时反复重装 `Skills Manager`。

### 本地 `packages/` 目录已经不再使用

当前回退安装不走仓库内 `packages/`，统一依赖：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

例外：

- `Codex Desktop` 不再依赖仓库 release 里的旧版 `Setup.exe`
- 当 `winget` 的 `msstore` 安装路径失败时，脚本会退回到官方 Microsoft Store 协议或其网页详情页

### 当前仓库 release 资产更新状态

截至本次整理，`bootstrap-assets` Release 已补齐这些安装资产：

- `PowerShell-7.6.1-win-x64.msi`
- `Git-2.54.0-64-bit.exe`
- `node-v25.9.0-x64.msi`
- `python-3.13.13-amd64.exe`
- `VSCodeUserSetup-x64-1.117.0.exe`
- `CC-Switch-v3.14.0-Windows.msi`
- `Codex.Provider.Sync_0.1.4_x64-setup.exe`
- `skills-manager_1.14.3_x64_en-US.msi`
- `ChatGPT_x64.msi`
- `skills.zip`

`Codex Desktop` 的 fallback 现在也已切到官方来源：

- `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`
- `https://apps.microsoft.com/detail/9PLM9XGG6VKS`

这样不再需要维护会过期的 `Codex-*.Setup.exe` 文件名。

另外，当前 release 中如果仍有旧资产，脚本只会按 `manifest/apps.json` 当前指向的新来源走 fallback。

## 使用方式

### 本地仓库运行

普通安装：

```powershell
Set-Location "D:\AI Coding\Vibe Coding Setup"
.\bootstrap.cmd
```

远程自举入口：

```powershell
Set-Location "D:\AI Coding\Vibe Coding Setup"
.\run-remote-bootstrap.cmd
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

- [indieark/vibe-coding-setup](https://github.com/indieark/vibe-coding-setup)

推荐入口命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

这个命令只做两件事：

1. 下载 `bootstrap.ps1`
2. 执行 `bootstrap.ps1`

后续依赖同步、版本门禁、安装和回退都由脚本自己处理。

## 当前确认过的外部来源

- `Git.Git`
- `OpenJS.NodeJS`
- `Python.Python.3.13`
- `Microsoft.VisualStudioCode`
- `PowerShell` Microsoft Store 包 `9MZ1SNWT0N5D`
- `Codex Desktop` Microsoft Store 包 `9PLM9XGG6VKS`
- `tw93/Pake` latest release asset
- `farion1231/cc-switch` latest release asset
- `indieark/codex-provider-sync` private release asset（镜像到 `bootstrap-assets` 后对外安装）
- `xingkongliang/skills-manager` latest MSI release asset

## 建议后续

- 增加日志落盘
- 增加安装结果 JSON 报告
- 为直链或 Release 资产增加 checksum / 版本校验
- 为 `ChatGPT (Pake)` 增加稳定版本来源，避免每次都进入重新安装路径
- 继续观察 `Skills Manager` 后续是否提供稳定 CLI、可靠版本号或显式 rescan 命令
