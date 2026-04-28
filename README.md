# Windows 一键部署脚本

这个仓库用于在 Windows 上一键拉起开发环境、桌面工具和技能包，主入口是 `bootstrap.ps1`，`bootstrap.cmd` 只是它的本地启动壳，`vibe-coding-setup.cmd` 是远程自举入口。

当前仓库的设计重点不是“纯离线安装”，而是把安装来源分成两层：

- 主来源：`winget`、上游 GitHub Releases、固定直链、自托管 GitHub Release 资产
- 回退来源：大多数应用退到 `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release 资产，`Codex Desktop` 退到官方 Microsoft Store 来源

## 当前包含

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

只要没有传 `-SkipSkills`，脚本就会先下载：

- `downloads/skills.zip`

来源固定为：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

这一步在正式安装应用前执行。

注意：

- 当前实现里，`skills.zip` 不依赖 `-Only` 是否包含 `skills-manager`
- 也就是说，就算这次只装 `git` / `nodejs`，只要没传 `-SkipSkills`，脚本仍会预取并在后面尝试导入技能包

### 5. 可选读取或跳过 CC Switch Provider 配置

如果本次选择了 `cc-switch`，且没有传 `-SkipCcSwitch`，脚本会先检查用户本机 `CC Switch` 的 `codex` provider 里是否已经存在同名配置：

- 默认检查名称是 `IndieArk API 2`
- 如果传了 `-CcSwitchProviderName` 或设置了 `VIBE_CODING_PROVIDER_NAME`，就检查那个名称

如果已经存在，脚本会：

- 直接跳过后续 Provider 询问
- 最终也跳过导入，summary 里显示 `precheck-skip`

如果不存在，脚本会按顺序逐项询问：

- Provider 名称，直接回车使用默认值 `IndieArk API 2`
- `base_url`，直接回车使用默认值 `https://api2.indieark.tech/v1`
- 默认模型，直接回车使用默认值 `gpt-5.5`
- `SK`，直接回车会自动写入默认值 `sk-`，避免 `CC Switch` 因为空值导入失败

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
- 如果 `winget show` 暂时拿不到版本，但 manifest 的 `fallback.releaseAsset` 文件名里带版本号，就退回用这个版本做比较
- `strategy = github-latest-tag` 时，用 GitHub `/releases/latest` 跳转结果解析 tag
- `strategy = release-asset` 时，从资产文件名里提取版本号
- 其它策略如果没有可比较版本，就会进入“目标版本不可比较”分支

precheck 决策规则：

- 未安装：安装
- 如果 manifest 开启 `installIfMissingOnly`：只要检测到已安装就直接跳过
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

这个仓库当前实际用到的是：

- `winget`
- `direct-url`
- `github-latest-tag`
- `release-asset`

`github-release` 目前属于通用能力，当前 manifest 没有实际使用。

统一逻辑是：

1. 先走主策略
2. 主策略失败则记录 warning
3. 如果不是 `-DryRun`，先做一次 post-check，重新检测应用是否其实已经装上；如果已装上，就直接记为 `*-postcheck`
4. 如果 manifest 定义了 `fallback.wingetId`，先退到备用 `winget`
5. 如果 manifest 定义了 `fallback.releaseAsset`，再退到 `bootstrap-assets` Release 资产
6. 如果 manifest 定义了 `fallback.uriCandidates`，则按顺序打开官方 URI / 页面
7. 回退也失败，则该应用标记为失败

下载的安装包统一落到：

- `downloads/`

安装器执行方式：

- `msi` 走 `msiexec.exe /i ... /qn /norestart`
- `exe` 直接静默参数启动
- `msix` 走 `Add-AppxPackage`
- `uri` 走 `Start-Process`，用于拉起官方 Store 协议或官方下载页面

### 9. 安装完应用后再导入 `skills.zip`

只要没有传 `-SkipSkills`，脚本就会在应用安装阶段结束后执行 `Install-SkillBundle`：

1. 解压 `downloads/skills.zip`
2. 递归查找所有包含 `SKILL.md` 的目录
3. 先比较技能目录内容是否已经同步
4. 如果 `~/.skills-manager/skills/<skill-name>` 缺失或内容不同，则复制过去
5. 如果本机存在以下目录，也会一起做同样的“缺失或内容不同才同步”检查：
   - `~/.claude/skills`
   - `~/.cursor/skills`
   - `~/.gemini/antigravity/global_skills`
   - `~/.gemini/skills`
   - `~/.copilot/skills`
6. `~/.codex/skills/<skill-name>` 也按同样规则同步
7. 如果不是 `-DryRun`，并且这次确实有技能被导入，才写入 `~/.skills-manager/skills-manager.db`
8. 如果这次确实导入了技能，且找到 `skills-manager.exe`，最后会自动拉起它

也就是说，`skills.zip` 不再是“只要运行就整包重拷”；现在是按技能目录内容做增量同步，已经一致的技能会直接跳过。

这里也有一个和直觉不完全一致的点：

- 当前代码不会检查这次是否同时安装了 `skills-manager`
- 只要 `skills.zip` 存在且未 `-SkipSkills`，它就会尝试同步到 `~/.skills-manager/skills`、`~/.codex/skills` 以及已启用的其它目标目录

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
| `Git` | `winget install --id Git.Git` | `winget show Git.Git` | `git --version`，失败后看注册表 `^Git$` | `indieark/vibe-coding-setup@bootstrap-assets/Git-2.54.0-64-bit.exe` |
| `Node.js` | `winget install --id OpenJS.NodeJS` | `winget show OpenJS.NodeJS` | `node --version`，失败后看注册表 `Node.js` | `indieark/vibe-coding-setup@bootstrap-assets/node-v25.9.0-x64.msi` |
| `Python 3.13` | `winget install --id Python.Python.3.13` | `winget show Python.Python.3.13` | `py -V` | `indieark/vibe-coding-setup@bootstrap-assets/python-3.13.13-amd64.exe` |
| `Visual Studio Code` | `winget install --id Microsoft.VisualStudioCode` | `winget show Microsoft.VisualStudioCode` | `code --version`，失败后看注册表 `Microsoft Visual Studio Code` | `indieark/vibe-coding-setup@bootstrap-assets/VSCodeUserSetup-x64-1.117.0.exe` |
| `Codex Desktop` | `winget install --id 9PLM9XGG6VKS --source msstore` | `winget show 9PLM9XGG6VKS --source msstore`；但实际按 presence-only 预检，检测到已安装即跳过 | `Get-AppxPackage -Name OpenAI.Codex` | 官方 Microsoft Store：优先 `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`，失败再开 `https://apps.microsoft.com/detail/9PLM9XGG6VKS` |
| `ChatGPT (Pake)` | `https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x64.msi` | 无稳定可比较目标版本；实际按 presence-only 预检 | 注册表精确匹配 `ChatGPT` | `indieark/vibe-coding-setup@bootstrap-assets/ChatGPT_x64.msi` |
| `CC Switch` | `farion1231/cc-switch` 的 latest tag，对应资产模板 `CC-Switch-{tag}-Windows.msi` | GitHub latest tag | 注册表精确匹配 `CC Switch` | `indieark/vibe-coding-setup@bootstrap-assets/CC-Switch-v3.14.1-Windows.msi` |
| `Codex Provider Sync` | 当前仓库镜像资产：`indieark/vibe-coding-setup@bootstrap-assets/Codex.Provider.Sync_0.2.0_x64-setup.exe` | 从当前仓库 release 资产文件名提取版本 | 注册表包含匹配 `Codex Provider Sync` | 无；主来源已经是当前仓库的自托管镜像资产 |
| `Skills Manager` | 上游 `xingkongliang/skills-manager` latest tag，对应资产模板 `skills-manager_{version}_x64_en-US.msi` | GitHub latest tag | 注册表正则匹配 `^(Skills Manager&#124;skills-manager)$`；检测到旧版本时按 GitHub latest tag 升级 | 当前仓库镜像资产：`indieark/vibe-coding-setup@bootstrap-assets/skills-manager_1.15.1_x64_en-US.msi` |

补充两个“非应用安装项”：

| 项目 | 主来源 | 回退来源 |
| --- | --- | --- |
| `modules/common.psm1`、`manifest/apps.json` 自举依赖 | 当前完整仓库；否则 `https://raw.githubusercontent.com/indieark/vibe-coding-setup/main` | 无单独二级回退 |
| `skills.zip` | `indieark/vibe-coding-setup@bootstrap-assets/skills.zip` | 无单独二级回退 |

## 特殊行为说明

### Codex Desktop 和 ChatGPT 现在按 presence-only 处理

这两个应用都能稳定检测“是否已安装”，但当前都没有可靠、稳定、可比较的目标版本门禁：

- `Codex Desktop` 走 Microsoft Store，`winget show` 不稳定返回可用于脚本比较的版本
- `ChatGPT (Pake)` 当前走固定 latest 直链，没有 manifest 固定 `targetVersion`

因此脚本现在对它们采用同一条务实策略：

- 只要检测到已安装，就直接 `precheck-skip`
- 不再因为“目标版本不可比较”而每次强行重装

### Python 现在支持命令检测回退

`Python 3.13` 的安装检测仍然优先走命令行版本探测，但不再只依赖单一的 `py -V`。

现在的顺序是：

- 先尝试 `py -V`
- 如果该命令不存在，或者调用阶段直接抛错，再尝试 `python --version`

这样可以避免某些机器上 `py.exe` 本身异常时，整条 `Python` precheck 直接失败。

### Python fallback 现在改为真正的运行时安装包

之前 fallback 指向 `python-manager-26.0.msix`，更接近 Python 安装管理器，而不是 `Python 3.13` 本体。

现在改为官方：

- `python-3.13.13-amd64.exe`

并补了静默安装参数，保证 fallback 仍然符合一键安装语义。

### CC Switch Provider 导入没有回退实现

当前只支持官方 deep link：

- `ccswitch://v1/import`

如果协议没注册，脚本不会退回到 SQLite 直写。

不过现在脚本只会在“本机还没有同名 provider”时才继续导入；如果已存在同名 `codex` provider，会直接跳过导入。

真正需要导入时，脚本在首次安装或更新 `CC Switch` 后，会先自动 warm up 一次应用，再等待 `ccswitch://` 协议完成注册，然后继续导入 provider。

如果 Windows 还没完成应用初始化，仍可能需要手动再打开一次 `CC Switch` 后重试。

### Codex Provider Sync 安装时直接走自托管 release

安装脚本不会直接从上游安装 `Codex Provider Sync`，而是只访问当前仓库的公开镜像资产。

当前 manifest 直接把主来源指向：

- `indieark/vibe-coding-setup@bootstrap-assets/Codex.Provider.Sync_0.2.0_x64-setup.exe`

这样远程自举时不需要拥有 `indieark/codex-provider-sync` 的访问权限，也不会因为上游 release 不可见而在安装路径上失败。

### `skills.zip` 也没有第二来源

当前 `skills.zip` 的来源只有：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

如果这个资产不存在或下载失败，技能导入阶段会直接失败。

### `skills.zip` 现在按内容同步，不是无脑重导

`Install-SkillBundle` 现在会先把 `skills.zip` 解到临时目录，再逐个技能比较源目录和目标目录内容。

判定范围包括：

- `~/.skills-manager/skills/<skill-name>`
- `~/.codex/skills/<skill-name>`
- 如果目录存在，也包括：
  - `~/.claude/skills`
  - `~/.cursor/skills`
  - `~/.gemini/antigravity/global_skills`
  - `~/.gemini/skills`
  - `~/.copilot/skills`

只有某个技能在任一启用目标中缺失，或者文件内容不一致时，脚本才会重新同步该技能。

如果某个目标目录本质上只是另一个目标的软链接 / junction（例如 `~/.codex/skills` 指向 `~/.skills-manager/skills`），脚本会在 central import 之后重新做一次同步检查；如果内容已经一致，就跳过第二次复制，避免把刚导入的 central skill 又删掉。

如果所有目标都已经和 `skills.zip` 一致，日志会显示：

- `Skill already synchronized, skip: <skill-name>`

最后 summary 会显示：

- `All skills already synchronized`

### Skills Manager 按 GitHub latest tag 自动升级

`Skills Manager` 当前安装后的注册表元数据并不稳定：

- 实际 `DisplayName` 可能是 `skills-manager`
- 实际 `DisplayVersion` 可能不会跟 GitHub release tag 对齐

因此脚本对它的检测和升级拆开处理：

- 先用正则同时匹配 `Skills Manager` / `skills-manager`
- 再解析 `xingkongliang/skills-manager` 的 GitHub latest tag
- 如果已安装版本低于 latest tag，则下载 `skills-manager_{version}_x64_en-US.msi` 并安装升级
- 如果已安装版本不低于 latest tag，才会 `precheck-skip`

如果注册表版本号无法比较，脚本会保守地重新安装 latest MSI，避免长期停留在旧版本。

### 本地 `packages/` 目录已经不再使用

当前回退安装不走仓库内 `packages/`，统一依赖：

- `indieark/vibe-coding-setup` 的 `bootstrap-assets` Release

例外：

- `Codex Desktop` 不再依赖仓库 release 里的旧版 `Setup.exe`
- 当 `winget` 的 `msstore` 安装路径失败时，脚本会退回到官方 Microsoft Store 协议或其网页详情页

### 当前仓库 release 资产更新状态

截至本次整理，`bootstrap-assets` Release 已补齐这些安装资产：

- `Git-2.54.0-64-bit.exe`
- `node-v25.9.0-x64.msi`
- `python-3.13.13-amd64.exe`
- `VSCodeUserSetup-x64-1.117.0.exe`
- `CC-Switch-v3.14.1-Windows.msi`
- `Codex.Provider.Sync_0.2.0_x64-setup.exe`
- `skills-manager_1.15.1_x64_en-US.msi`
- `ChatGPT_x64.msi`
- `skills.zip`

`Codex Desktop` 的 fallback 现在也已切到官方来源：

- `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`
- `https://apps.microsoft.com/detail/9PLM9XGG6VKS`

这样不再需要维护会过期的 `Codex-*.Setup.exe` 文件名。

另外，当前 release 中如果仍有旧资产，脚本只会按 `manifest/apps.json` 当前指向的新来源走 fallback。

### Release 资产自动刷新

仓库新增 GitHub Actions：

- `.github/workflows/refresh-bootstrap-assets.yml`

它会每天 09:00（北京时间）运行一次，也可以在 GitHub Actions 页面手动触发。执行内容是：

1. 检查可公开追踪上游版本的安装包是否已有新版
2. 如果新版资产不存在于 `bootstrap-assets` Release，就下载并上传新版
3. 新版上传成功后，删除同类旧 fallback 资产
4. 同步更新 `manifest/apps.json` 里的 `fallback.releaseAsset` 或主 `assetName`
5. 如果 `manifest` 有变化，自动提交 `chore: refresh bootstrap release assets`

当前自动维护这些资产：

- `Git`
- `Node.js`
- `Python 3.13`
- `Visual Studio Code`
- `ChatGPT (Pake)`
- `CC Switch`
- `Codex Provider Sync`
- `Skills Manager`

这些资产暂不自动维护：

- `skills.zip`：是自托管技能包，没有可直接判断“最新版”的公开来源

`Codex Provider Sync` 的安装主来源仍然是当前仓库的 `bootstrap-assets` Release；但每日自动化会去上游 `indieark/codex-provider-sync` 的 latest release 查找 `Codex.Provider.Sync_*_x64-setup.exe`，把新版镜像到当前仓库的 release，并同步更新 manifest 的主 `assetName`。

`Skills Manager` 安装时优先走公开上游 `xingkongliang/skills-manager` latest release；如果该路径失败，再回退到当前仓库 `bootstrap-assets` Release 里的镜像 MSI。每日自动化同样会检查上游 latest MSI，把新版镜像到当前仓库 release，并同步更新 manifest 的 `fallback.releaseAsset`。

因为 `indieark/codex-provider-sync` 是私有仓库，Actions 需要配置一个可读取该私库 release 的仓库 secret：

- `CODEX_PROVIDER_SYNC_TOKEN`

workflow 会把它注入为 `SOURCE_GITHUB_TOKEN`，只用于读取上游私库 release；当前仓库 release 的上传、删除和 manifest 提交仍使用默认 `GITHUB_TOKEN`。

也就是说，安装代码里的 fallback 或自托管主资产会跟着自动更新后的 Release 最新文件名走；但 `skills.zip` 这种没有可追踪上游的自托管资产仍需要手动发布。

## 使用方式

### 本地仓库运行

普通安装：

```powershell
Set-Location "D:\AI Coding\Vibe Coding Setup"
.\bootstrap.cmd
```

`bootstrap.cmd` 使用系统自带的 Windows PowerShell 5.1（`powershell.exe`）启动。如果过程中触发 UAC 提权，新开的管理员窗口会在执行完成后保持打开，你可以手动关闭它，方便完整查看最后的错误或 summary。

远程自举入口：

```powershell
Set-Location "D:\AI Coding\Vibe Coding Setup"
.\vibe-coding-setup.cmd
```

它也会使用系统自带的 Windows PowerShell 5.1（`powershell.exe`）启动。

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
- `Codex Desktop` Microsoft Store 包 `9PLM9XGG6VKS`
- `tw93/Pake` latest release asset
- `farion1231/cc-switch` latest release asset
- `indieark/codex-provider-sync` private release asset（镜像到 `bootstrap-assets` 后对外安装）
- `xingkongliang/skills-manager` latest MSI release asset

## 建议后续

- 增加日志落盘
- 增加安装结果 JSON 报告
- 为直链或 Release 资产增加 checksum / 版本校验
- 为 `Codex Desktop` / `ChatGPT (Pake)` 增加稳定版本来源，便于未来从 presence-only 回到可比较版本门禁
- 继续观察 `Skills Manager` 后续是否提供稳定 CLI、可靠版本号或显式 rescan 命令
