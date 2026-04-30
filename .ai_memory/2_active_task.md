# Active Task Snapshot

## 当前状态

- `vibe-coding-setup` 已完成按需装机器 Phase 1-4 主线合并。
- 当前 `main` 包含：私库 bundle 镜像为公开 `skills.zip`、Profile 选择、`.skill-meta.json` 透传到 Skills Manager SQLite、同名 Skill 三态去重。
- 最新文档已把安装器状态从“按内容同步”更新为“Profile 选择 + 来源判定 + 增量同步 + SQLite 注册”。
- README 已补充本机安全测试命令和“还能怎么更先进”的后续方向。

## 当前未完成项

- Phase 5 飞书只读镜像尚未实现；`00000-model` 已有执行计划分支 `plan/feishu-readonly-mirror`。
- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum、导入计数摘要等增强项。

## 立即下一步

1. 用户若要本机验证，先跑 `-DryRun -NoReplaceOrphan -SkipSkillsManagerLaunch`，确认三态判定日志。
2. 若继续推进路线图，优先实现 `00000-model` Phase 5：registry → 飞书 bitable 只读镜像。
3. 若继续增强安装器，优先做 `-ReportPath` / JSON summary 和 bundle manifest 校验。

## 阻断

- 没有当前阻断。
