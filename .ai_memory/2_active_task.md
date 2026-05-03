# Active Task Snapshot

## 当前状态

- 已完成 TUI Skill / MCP / CLI 组件检查进度统一。
- 套件页、Skill 单项页、MCP 单项页、CLI 单项页的组件扫描统一使用 `[检查] Skill`、`[检查] MCP`、`[检查] CLI` 格式。
- `modules/common.psm1` 的 `Write-OperationProgress` 支持 `-Prefix`，`Get-SkillBundleComponentStatus` 在 Skill / MCP / CLI 状态扫描中传入 `[检查]` 前缀。
- `bootstrap.ps1` 的 `Write-BootstrapDownloadProgress` 支持可选 `-Prefix`，普通下载仍保留 `[bootstrap]` 格式，组件检查预览使用 `[检查]`。
- MCP 状态扫描增加 TUI 专用轻量延迟，避免 10 个本地配置检查瞬间拉满；最后 `100%` 后不再额外等待。
- bootstrap 会检测本地 `common.psm1` 是否支持当前 TUI 组件进度能力；旧模块会触发依赖刷新。兼容兜底路径会输出新版预览进度并静默旧模块自身 Host 进度，避免套件页重复显示旧风格 MCP / CLI。
- README、`docs/operations.md`、`docs/installer-flow.md` 和 `.ai_memory` 已同步当前进度语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。
## 最近验证

- PowerShell Parser 检查通过：`bootstrap.ps1`、`modules/common.psm1`。
- `git diff --check` 通过。
- 只读 suite smoke 显示：
  - `[检查] Skill ... 105/105 个 Skill 已完成`
  - `[检查] MCP ... 10/10 个 MCP 已完成`
  - `[检查] CLI ... 12/12 个 CLI 已完成`
- 最新推送前工作区与 `origin/main` 同步；最近代码修复提交为 `e7242f1 fix(tui): suppress legacy component progress`。

## 下一步

1. 如用户继续反馈 TUI 进度显示异常，优先确认是否使用最新 `bootstrap.ps1`，再确认本地 `modules/common.psm1` 是否被刷新。
2. 如果显示的 Skill / MCP / CLI 数量不符合 registry，优先检查公开 `bootstrap-assets/skills.zip` 与本地 `downloads/skills.zip` 缓存。
3. 若继续调整 TUI 文案，避免新增裸中文源码字符串；保持 UTF-8 Base64 文案约束。
4. 若新增组件类型，需要同时补状态检测、选择页详情、执行确认参数和文档进度说明。

## 阻断

- 没有当前阻断。
