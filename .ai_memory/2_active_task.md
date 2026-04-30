# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 README 顶层入口 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- README 不再维护完整流程、PAT 表、应用来源表或后续路线细节，只做文档地图和快速开始。
- 新增 `.agent/rules/documentation-governance.md`，用于约束层层索引和单一信息源。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum、导入计数摘要等增强项。

## 立即下一步

1. 用户若要本机验证，先跑 `-DryRun -NoReplaceOrphan -SkipSkillsManagerLaunch`，确认三态判定日志。
2. 若继续推进路线图，优先实现 `00000-model` Phase 5：registry → 飞书 bitable 只读镜像。
3. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验。

## 阻断

- 没有当前阻断。
