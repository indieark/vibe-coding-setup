# Work Log

## 2026-04-23

- 梳理了 `bootstrap.ps1`、`modules/common.psm1`、`manifest/apps.json` 的主安装链路与 precheck / fallback 机制。
- 重写并补强 `README.md`，加入主脚本执行顺序、来源/回退表、特殊行为说明。
- 将 fallback 资产升级到新版并同步到 `bootstrap-assets`：
  - Git `2.54.0`
  - Node.js `25.9.0`
  - Python `3.13.13`
  - VS Code `1.117.0`
  - CC Switch `3.14.0`
- 修正了 Python fallback 方案：由 `python-manager-26.0.msix` 切换为官方运行时安装包 `python-3.13.13-amd64.exe`，并补齐静默参数。
- 验证了更新后的 manifest 在 `-DryRun` 下可正常工作。
- 将 `Codex Desktop` fallback 从仓库 release 中的旧 `Setup.exe` 切换为官方 Microsoft Store 来源。
- 为通用安装逻辑补充 `uri` 型 fallback，支持拉起 `ms-windows-store://` 或官方网页详情页。
- 删除 release 中旧的 `Codex-26.325.31654.Setup.exe` 资产。
