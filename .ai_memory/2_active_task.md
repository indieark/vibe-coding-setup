# Active Task Snapshot

## 当前状态

- 已完整通读当前仓库的可执行脚本、manifest、入口壳脚本和现有归档文件。
- 已按代码事实重新核对 `README.md`，修正以下关键偏差：
  - `skills.zip` 的预取与导入不依赖 `skills-manager` 是否被选中
  - 当前实际使用到的主策略包含 `release-asset`，而不是 `github-release`
  - 主来源失败后会先做一次 post-check，再继续进入 fallback
- 当前仓库的核心执行真相仍然集中在：
  - `bootstrap.ps1`
  - `modules/common.psm1`
  - `manifest/apps.json`

## 当前未完成项

- 当前用户请求已基本完成，没有剩余必须继续执行的代码变更项。

## 立即下一步

1. 如需继续增强仓库，可新增 checksum / hash 校验，降低 release 资产漂移风险。
2. 可考虑把 `bootstrap-assets` 的更新流程脚本化，避免手工同步。
3. 若后续再改安装策略或技能导入行为，应先改代码，再同步 README 和 `.ai_memory`。

## 阻断

- 没有当前阻断。
