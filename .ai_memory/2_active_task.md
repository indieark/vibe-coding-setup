# Active Task Snapshot

## 当前状态

- 已将前置自举依赖开屏标题从 `步骤一：获取依赖` 改为 `获取依赖`，避免 TUI / 自定义入口显示默认模式专用编号。
- 默认安装后续阶段仍从 `步骤二：应用安装`、`步骤三：配置导入`、`步骤四：插件安装` 继续，完成提示保持 `恭喜：安装流程完成`。
- `Sync-BootstrapDependencies` 已改为默认复用本地 `modules/common.psm1` 与 `manifest/apps.json`，即使源是 HTTP 也不重复下载。
- 只有显式传 `-RefreshBootstrapDependencies` 时才刷新自举依赖。
- 已同步 `.ai_memory` 记录本次开屏文案与缓存复用语义。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 最近验证

- `bootstrap.ps1` PowerShell parser 通过。
- `git diff` 确认代码只改动自举依赖刷新条件和前置开屏标题。
- 待推送代码提交：本次自举依赖开屏与缓存复用修正。

## 下一步

1. 如用户继续反馈 TUI 显示与预期不一致，先确认是否使用最新脚本，再确认公开 `bootstrap-assets/skills.zip` 与本地 `downloads/skills.zip` 缓存。
2. 若继续调整 TUI 文案，避免新增裸中文源码字符串；保持 UTF-8 Base64 文案约束。
3. 若需要强制刷新自举依赖，使用 `-RefreshBootstrapDependencies`。

## 阻断

- 没有当前阻断。
