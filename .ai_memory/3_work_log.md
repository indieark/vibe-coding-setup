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
- 重新通读整个仓库后，修正了 `README.md` 中三处与代码不一致的描述：`skills.zip` 触发条件、实际使用策略集合、以及 primary failure 后的 post-check / fallback 顺序。

## 2026-04-30

- 完成并合并 Phase 4：Skill 三态去重判定，PR #6 合入 `main`，merge commit `85aea1b`。
- 验证通过：`git diff --check`、PowerShell 5.1 / 7 模块导入、飞书办公套件 dry-run（`-NoReplaceOrphan -SkipSkillsManagerLaunch`）。
- 更新 README：补充当前路线状态、本机安全测试命令、`.skill-meta.json` 来源判定、三态默认策略和后续先进化方向。
- 更新 `.ai_memory`：记录当前安装器真实状态、下一步 Phase 5 边界和安装器增强建议。

## 2026-04-30

- 重构文档结构：README 收敛为顶层入口和文档地图，详细说明拆入 `docs/installer-flow.md`、`docs/skill-import.md`、`docs/asset-refresh.md`、`docs/operations.md`、`docs/roadmap.md`。
- 新增 `.agent/rules/documentation-governance.md`，明确层层索引、单一信息源和修改要求。
- 精简 `.ai_memory/1_project_context.md`，改为记录 SSOT 地图和稳定事实，不再复制完整应用来源表。
