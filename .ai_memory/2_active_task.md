# Active Task Snapshot

## 当前状态

- 已修复自定义模式“检查并安装/更新 Skill / MCP”进度显示不一致问题。
- `Get-SkillBundleComponentStatus` 现在为 Skill 状态扫描补充 `Skill` 标签进度条，并将 MCP 状态扫描标签统一为 `MCP`。
- `Get-BootstrapTuiSkillOnlySummary` 已改为复用 `Get-SkillBundleComponentStatus -IncludeSkills`，不再维护一套手写 Skill 进度。
- MCP 状态扫描会在执行具体配置检测前刷新进度，避免检测耗时时用户看不到反馈。
- Skill 导入循环也使用 `Write-OperationProgress -Label 'Skill'` 显示导入完成数量。
- README、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md` 已同步当前进度显示语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 最近验证

- PowerShell parser 检查通过：`bootstrap.ps1`、`modules/common.psm1`。
- `Import-Module .\modules\common.psm1 -Force` 通过。
- 只读 smoke test 显示 `Skill=105`、`MCP=10`、`CLI=12` 均能输出进度。
- 文档一致性检查已覆盖 README、docs 和 `.ai_memory` 中的 Skill / MCP / CLI 进度描述。

## 下一步

1. 如用户继续反馈 TUI 显示与预期不一致，先确认是否使用最新脚本，再确认公开 `bootstrap-assets/skills.zip` 与本地 `downloads/skills.zip` 缓存。
2. 若继续调整 TUI 文案，避免新增裸中文源码字符串；保持 UTF-8 Base64 文案约束。
3. 若新增组件类型，需要同时补状态检测、选择页详情、执行确认参数和文档进度说明。

## 阻断

- 没有当前阻断。
