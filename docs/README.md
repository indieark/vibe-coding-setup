# 文档中心

这里是 `vibe-coding-setup` 的二级文档入口。README 负责项目首页，本目录负责按读者任务分流。

## 按角色阅读

### 终端用户

你只想安装或验证本机行为：

1. 先看 [运行命令](operations.md)。
2. 如果要交互选择应用、Skill Profile 或 Skills Manager 场景，使用默认 TUI 入口。
3. 如果只想预览 Skill 导入风险，直接跑安全演练命令。
4. 如果看到 Skill 被跳过或备份，再看 [Skill 导入契约](skill-import.md)。

### 仓库维护者

你要改安装项、fallback 或 release 资产：

1. 先确认 `manifest/apps.json` 是否是唯一需要改的事实源。
2. 看 [安装执行顺序](installer-flow.md) 理解安装器如何处理 precheck / fallback。
3. 看 [资产刷新链路](asset-refresh.md) 理解 `bootstrap-assets` 和私库镜像边界。
4. 改 Skill、MCP、前置依赖或 Profile 时，先改 `00000-model/00-编程配置/registry/*.yaml`，再同步 [Skill 导入契约](skill-import.md) 的安装器行为说明。
5. 涉及 PAT 或 Secret 时，按 [PAT / Secret 治理](../.agent/rules/pat-secret-governance.md) 执行。

### 后续 AI / 代理

你要继续改代码或文档：

1. 先读顶层 [README](../README.md) 的“单一信息源”。
2. 再读 [文档治理规则](../.agent/rules/documentation-governance.md)。
3. 最后读 `.ai_memory/2_active_task.md` 获取当前任务快照。

## 专题目录

| 文档                              | 适合什么时候读                                                                                                                                  | 不维护什么                       |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| [运行命令](operations.md)         | 要本地运行、远程自举、TUI、dry-run 或按 Profile 导入 Skill                                                                                      | 不解释内部状态机                 |
| [安装执行顺序](installer-flow.md) | 要理解 bootstrap、TUI 入口、precheck、fallback、进度和退出码                                                                                    | 不列应用版本和 fallback 文件名   |
| [Skill 导入契约](skill-import.md) | 要理解 TUI 复选、全部 Skill、命令 Profile、bundled / external Skill、MCP 写入、前置依赖、`.skill-meta.json`、三态去重和 Skills Manager 场景注册 | 不维护 Skill / MCP / prereq 清单 |
| [资产刷新链路](asset-refresh.md)  | 要维护 `bootstrap-assets`、私库镜像或 workflow                                                                                                  | 不维护 PAT 最小权限表            |
| [后续路线](roadmap.md)            | 要继续增强安装器能力                                                                                                                            | 不记录当前任务快照               |

## 最终事实源

| 事实                                         | 唯一来源                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------- |
| 应用 key、名称、安装策略、fallback asset     | `manifest/apps.json`                                                      |
| 安装器真实行为                               | `bootstrap.ps1`、`modules/common.psm1`                                    |
| Skill / MCP / prereq / Profile / bundle 内容 | `indieark/00000-model` 的 `00-编程配置/registry/*.yaml` 与 release bundle |
| Skill / MCP / prereq 安装器行为说明          | `docs/skill-import.md`                                                    |
| PAT / Secret 规则                            | `.agent/rules/pat-secret-governance.md`                                   |
| 文档治理规则                                 | `.agent/rules/documentation-governance.md`                                |
| 当前接手状态                                 | `.ai_memory/2_active_task.md`                                             |

## 更新文档前检查

- README 是否仍是项目首页，而不是完整手册？
- 新内容是否已经有专题文档入口？
- 有没有把 `manifest/apps.json` 或 PAT 表复制到 Markdown？
- 相对链接是否能从 GitHub 页面正常打开？
- `.ai_memory` 是否只记录状态，不替代用户文档？
