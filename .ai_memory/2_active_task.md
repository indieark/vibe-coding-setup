# Active Task Snapshot

## 当前状态

- 本轮确认 Profile 套件显示顺序由 `00000-model` 的 `profiles.yaml` 唯一驱动，安装器读取 registry 时保留源顺序，不需要在 `vibe-coding-setup` 中硬编码排序。
- 已补默认模式插件安装输入区提示：菜单明确写出 `输入 0 安装全部 Skill；输入 00 安装所有套件；`，并新增 `不填直接回车则跳过插件安装。`
- 当前交互逻辑已经是空输入 `return @()`，即跳过 Skill 导入；本次只补用户可见提示，不改变执行语义。
- `docs/skill-import.md` 与 `docs/operations.md` 已存在“直接回车跳过 Skill 导入”的说明，本轮无需重复修改对外文档。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。
- 公开 `bootstrap-assets/skills.zip` 的 Profile 顺序刷新依赖 `00000-model` push 后的 `build-bundle` Action，以及本仓库 `refresh-bootstrap-assets` Action。

## 下一步

1. 提交并推送本仓库 `modules/common.psm1` 与 `.ai_memory` 归档改动。
2. 等 `00000-model` bundle 发布后，观察 `refresh-bootstrap-assets` 是否把公开 `skills.zip` 更新到新 digest。

## 阻断

- 没有当前阻断。
