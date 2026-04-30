# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 文档结构已收敛为 README 顶层入口 + `docs/` 专题说明 + `.agent/rules/` 规则源。
- README 不再维护完整流程、PAT 表、应用来源表或后续路线细节，只做文档地图和快速开始。
- 新增 `.agent/rules/documentation-governance.md`，用于约束层层索引和单一信息源。
- 本轮完成脚本中文化：自举提示、日志等级、预检查/安装/fallback/CC Switch/Skill 导入输出、错误信息和最终执行摘要已改为中文展示。
- 为提升可读性，执行摘要将内部 source 值展示为“文件系统 / 预检查跳过 / Release 回退 / CC Switch 导入”等用户语义；内部状态值仍保持原样用于流程判断。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum、导入计数摘要等增强项。
- 脚本还没有 GUI；本轮已明确先收敛到中文化，不做界面或安装内核结构拆分。

## 立即下一步

1. 用户若要快速验证中文展示，先跑 `powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun -SkipSkills -SkipCcSwitch -Only git`。
2. 用户若要验证 Skill 中文日志，跑 `-DryRun -NoReplaceOrphan -SkipSkillsManagerLaunch`，确认三态判定和执行摘要。
3. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验；GUI 可作为后续独立阶段处理。

## 阻断

- 没有当前阻断。
