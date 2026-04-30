# 后续路线

当前安装过程已经具备主来源 / 回退来源、Profile 选择、Skill 来源追踪和三态去重。后续不应继续单纯堆安装项，而应优先增强可观测、可校验、可回滚。

## P0：可观测

- 增加日志落盘，保留关键步骤、版本门禁、fallback 决策和失败原因。
- 增加安装结果 JSON 报告，便于远程排障和批量装机留痕。
- 把 Skill 导入 summary 拆成 `Imported / Skipped / BackedUp / Foreign` 计数。

## P1：可校验

- 为直链或 Release 资产增加 checksum / 版本校验。
- 为 `skills.zip` 增加 bundle manifest 或签名校验。
- 为 `refresh-bootstrap-assets` 增加更明确的 dry-run diff 输出。

## P2：可回滚

- 增加 `-Plan` 或 `-ReportPath` 模式，输出将要安装和将要替换的完整计划，不触碰系统状态。
- 为 Skill 备份目录写入 `.legacy.json`，记录备份原因、原路径、来源判定和时间。
- 在 summary 中明确列出备份路径，方便用户自行恢复。

## P3：体验增强

- 为 `Codex Desktop` / `ChatGPT (Pake)` 增加稳定版本来源，未来从 presence-only 回到可比较版本门禁。
- 继续观察 `Skills Manager` 是否提供稳定 CLI、可靠版本号或显式 rescan 命令。
- Phase 6 再处理独立 GUI 装机器和装机命令汉化。
