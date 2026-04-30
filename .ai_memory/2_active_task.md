# Active Task Snapshot

## 当前状态

- 本轮目标是让 `vibe-coding-setup` 真正消费 `00000-model` registry，而不是只导入离线 bundled skills。
- 安装器已经支持 registry 驱动的 bundled skill、external skill、前置 CLI 依赖和 MCP 写入。
- external skill 支持 `repo`、`archive_url` / `download_url`、`local_path` 自动导入；只有 `homepage` 的条目只提示人工处理。
- MCP 写入目标覆盖 Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI、Antigravity。
- `VIBE_CODING_USER_HOME` 隔离环境下会跳过 Claude Code CLI 注册，避免真实用户配置被测试污染。
- README、`docs/README.md`、`docs/skill-import.md` 已同步索引与单一事实源说明。
- 本文件随提交记录本轮闭环；验证通过后提交并推送 `main`。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 下一步

1. 运行 `Import-Module .\modules\common.psm1 -Force` 验证模块可加载。
2. 配合 `00000-model` registry dry-run 与安装器 Profile dry-run 做最终验证。
3. 提交并推送 `main`。

## 阻断

- 没有当前阻断。

## 最近验证

- `Import-Module modules/common.psm1 -Force` 已在本轮通过。
- `build-bundle.py --dry-run` 已在 `00000-model` 侧通过。
- 前端、中文办公自动化、媒体创作、演示文稿与文档 Profile dry-run 已通过。
- 隔离 `VIBE_CODING_USER_HOME` 下已验证 Codex / Claude Desktop / Cursor / Gemini CLI / Antigravity MCP 配置写入。
- 临时 bundle 已验证 `local_path` 和 `archive_url` external skill 可真实导入。
