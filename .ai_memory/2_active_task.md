# Active Task Snapshot

## 当前状态

- `AllSkills` 已改为 registry 全部 Skill：bundle 内 custom / vendored 直接导入，external 按 `source` 自动拉取或复制。
- `AllSkills` 不自动写入所有 MCP，也不安装所有 CLI；MCP / CLI 仍由 `AllSuites`、Profile 或单项 `-McpName` / `-CliName` 触发。
- TUI “全部 Skill”数量优先显示 registry Skill 总数，而不是 bundle 内离线目录数。
- README、`docs/skill-import.md`、`docs/operations.md`、`docs/asset-refresh.md`、`docs/README.md` 已同步最新语义。
- 已提交并推送：`b355455 feat(skills): install all registry skills`。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 最近验证

- `modules/common.psm1` PowerShell parser 通过。
- `bootstrap.ps1` PowerShell parser 通过。
- `git diff --check` 通过。
- `main...origin/main` 已同步。

## 下一步

1. 观察 `bootstrap-assets/skills.zip` 是否在 `00000-model` bundle 刷新后同步到最新 registry bundle。
2. 如用户反馈“全部 Skill”仍显示旧数量，优先检查本地缓存 `downloads/skills.zip` 与远端 release asset 是否刷新。

## 阻断

- 没有当前阻断。
