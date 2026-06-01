# Active Task Snapshot

## 当前状态

- 2026-06-01 已修复用户反馈的 winget “退出码 unknown 但实际已安装”体验问题：主安装器返回异常后，`Resolve-PrimaryInstallFailure` 会先做安装后复查；复查确认已安装时按成功处理，不再先输出“winget 路径处理 ... 出错”的警告。
- 执行摘要中 `winget-postcheck` 等来源现在显示为“安装后复查”，避免误解为前置预检查恢复。
- README、`docs/installer-flow.md`、`docs/operations.md` 和 `.ai_memory` 已同步新的 winget 成功判定语义。
- 本次没有改应用清单、fallback 安装包或 Skill / MCP / CLI registry 数据。

## 当前未完成项

- 安装器仍缺少 JSON 报告、bundle 签名 / checksum 等增强项。
- 如需真实维护型 CLI / MCP 包版本检查，需要先扩展 registry schema，并为联网检查提供缓存、超时和禁用策略。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。
- `Ensure-*` 函数仍会触发 PSScriptAnalyzer unapproved verb 风格 warning；本轮未扩大重命名，避免影响多处调用。

## 最近验证

- 2026-06-01 验证通过：`bootstrap.ps1`、`modules/common.psm1`、`scripts/Update-BootstrapAssets.ps1` PowerShell Parser。
- 2026-06-01 验证通过：`Import-Module .\modules\common.psm1 -Force`。
- 2026-06-01 验证通过：模拟 `winget install Git.Git` 返回 `退出码=unknown` 但安装后复查成功，结果为 `Status=ok`、`Source=winget-postcheck`。
- 2026-06-01 验证通过：`git diff --check`。
- 未运行真实 `winget install`，避免改动当前机器已安装软件状态。

## 下一步

1. 如果用户继续反馈 winget 显示异常，先确认运行的是更新后的 `modules/common.psm1` 和 `bootstrap.ps1`。
2. 如果复查仍误判，应优先检查对应应用在 `manifest/apps.json` 的 `detect` 规则，而不是直接扩大 winget 成功输出匹配。
3. 后续新增 winget 应用时仍需显式设置 `wingetSource`，并确保安装后检测规则能稳定识别命令、Appx 或注册表版本。

## 阻断

- 没有当前阻断。
