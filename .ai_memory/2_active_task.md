# Active Task Snapshot

## 当前状态

- 默认模式的交互式套件输入区已接入节能版 Skill / MCP / CLI 状态扫描。
- 默认 Profile 菜单中的 `全部 Skill`、`所有套件` 和各 Profile 行会显示已安装、部分安装、部分安装且需更新、需更新、更新未知或未安装。
- 默认模式进入套件输入区前会显示 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 进度。
- 自定义模式和默认模式共享同一套低开销本地状态语义：Skill 对比当前 bundle meta 与本机 meta，MCP 对比 registry 期望配置与本机配置，CLI 只检测是否存在并显示更新未知。
- 前置自举依赖标题已按入口区分：只有进入 TUI 首屏前显示无编号 `获取依赖`；命令模式、默认安装、TUI 首屏选择默认安装后或 TUI 默认安装 UAC 续跑后显示 `步骤一：获取依赖`。
- `Sync-BootstrapDependencies` 即使复用本地 `modules/common.psm1` 与 `manifest/apps.json` 缓存，也会输出同步完成进度。
- 历史 PSScriptAnalyzer 自动变量 warning 已清理：`$args` 改为 `$wingetArgs` / `$msiArgs` / `$commandArgs`，`$profile` 改为 `$profileEntry`。
- README、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md` 和 `.ai_memory` 已同步当前语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 如需真实维护型 CLI / MCP 包版本检查，需要先扩展 registry schema，并为联网检查提供缓存、超时和禁用策略。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。
- `Ensure-*` 函数仍会触发 PSScriptAnalyzer unapproved verb 风格 warning；本轮未扩大重命名，避免影响多处调用。
## 最近验证

- PowerShell Parser 检查通过：`bootstrap.ps1`、`modules/common.psm1`。
- `Import-Module modules/common.psm1` 通过。
- `git diff --check` 通过。
- 默认 / 命令模式 smoke 显示 `== 步骤一：获取依赖 ==` 和 `[bootstrap] 同步 ... 100% 2/2 个依赖已完成`。
- 只读组件状态 smoke 显示：
  - `[检查] Skill ... 105/105 个 Skill 已完成`
  - `[检查] MCP ... 10/10 个 MCP 已完成`
  - `[检查] CLI ... 12/12 个 CLI 已完成`

## 下一步

1. 如用户继续反馈 TUI / 默认模式进度异常，优先确认是否运行最新 `bootstrap.ps1` 与刷新后的 `modules/common.psm1`。
2. 如果显示的 Skill / MCP / CLI 数量不符合 registry，优先检查公开 `bootstrap-assets/skills.zip` 与本地 `downloads/skills.zip` 缓存。
3. 后续新增组件类型时，需要同时补状态检测、选择页详情、执行确认参数和文档进度说明。

## 阻断

- 没有当前阻断。

## 2026-05-04 Hotfix

- 用户实测发现默认模式套件输入区仍未显示 `[检查] Skill/MCP/CLI` 和状态标记。
- 根因是 `Install-SkillBundle` 用数组包装统计空 `SkillProfile`，`@($null).Count` 结果为 1，误判为已有请求 Profile，跳过交互菜单前状态扫描。
- 已改为用 `Split-SelectionTokens` 归一化 `$SkillProfiles`，并基于 `$requestedProfiles.Count` 判断是否需要在默认交互菜单前扫描状态。

## 2026-05-04 Hotfix 2

- 其他机器反馈 `skills.zip 导入失败：在此对象上找不到属性“Count”`，根因是模块启用 `Set-StrictMode -Version Latest`，直接访问可能为空值 / 标量的 `$requestedProfiles.Count` 不安全。
- 已改为显式 `[string[]]$requestedProfiles` 并使用 `$requestedProfileCount`；同时扩展 `Test-BootstrapCommonModuleTuiProgressSupport`，把默认模式状态扫描 hotfix 纳入自举依赖能力探针，避免继续复用旧 `common.psm1`。

## 2026-05-04 Hotfix 3

- 用户反馈默认模式状态扫描警告：`检索不到变量“$profileEntrys”`。
- 根因是历史自动变量 warning 清理时误把集合 `$profiles` 改成了不存在的 `$profileEntrys`。
- 已恢复两个 inventory/profile enrichment 循环为 `foreach ($profileEntry in $profiles)`，并通过 `Get-SkillBundleComponentStatus` smoke 验证 Profiles=8、Skill=105、MCP=10、CLI=12。
