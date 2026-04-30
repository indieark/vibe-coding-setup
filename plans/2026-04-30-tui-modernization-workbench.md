# TUI 现代化工作台重做计划

## Scope

本计划覆盖下一阶段 TUI 信息架构重做。目标是把现有“自定义选择”改成真正的 TUI 模式 / 控制台工作台，而不是把软件、行为和 Skill 全部做成同一种复选列表。

涉及范围：

- `bootstrap.ps1` 的 TUI 入口、菜单、状态页和结果写回。
- `modules/common.psm1` 中可复用的软件版本检测、Skill bundle / Profile 读取和 Skill 导入逻辑。
- `README.md`、`docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md`。
- `.ai_memory` 当前状态和归档。

不覆盖：

- 独立 GUI。
- 新增安装应用清单。
- 改写应用安装内核。
- 改写 Skill 三态判定策略。

## Invariants

- 不新增独立入口文件；继续复用 `bootstrap.ps1` / `bootstrap.cmd`。
- 默认安装必须保持原脚本默认逻辑，不改写成 `-Only` 全量列表。
- 安全演练是顶层入口，不再在 TUI 内部重复作为行为复选项。
- 复选主要用于 Skill / Profile 选择；软件和任务行为优先用任务式菜单和动作语义。
- TUI 首屏不预取 `skills.zip`；只有 Skill 状态检查或 Skill 安装选择需要时才按需获取。
- 命令模式和旧自动化参数必须继续可用。
- Windows PowerShell 5.1 仍是支持目标。

## Target Information Architecture

顶层入口：

1. 默认安装：直接沿用原默认安装逻辑。
2. TUI 模式：进入现代化控制台工作台。
3. 安全演练：顶层独立 dry-run 路径。

TUI 模式内部：

1. 检查软件状态：展示已安装、当前版本、目标 / 最新版本、建议动作。
2. 安装 / 更新软件：选择建议项、缺失项、全部项或跳过软件安装。
3. 检查 Skill 状态：读取 bundle / 本机状态，展示 Profile、已安装、可能新增或可更新内容。
4. 安装 Skill：这里使用复选，支持全部 Skill 或多个 Profile。
5. 执行摘要：展示选中动作、应用清单、Skill 清单和等价命令。

## Implementation Checklist

1. 将 `custom` 模式命名和文案改为 `TUI 模式`。
2. 移除 TUI 内部安装复选项里的安全演练重复入口。
3. 新增 TUI 工作台菜单，不再直接串联“应用复选 -> 行为复选 -> Skill 复选”。
4. 新增软件状态扫描 helper，复用现有 precheck/version 判断。
5. 新增软件安装动作选择 helper，避免把软件选择和安装行为混成一组复选。
6. 新增 Skill 状态页，按需获取 `skills.zip`，展示 Profile / 本机状态摘要。
7. 保留 Skill/Profile 复选页，作为安装 Skill 的唯一复选入口。
8. 更新等价命令生成和执行摘要。
9. 同步 README / docs / `.ai_memory`。

## Validation

- `git diff --check`
- `bootstrap.ps1` 解析
- `modules/common.psm1` 解析
- 旧命令模式：`-DryRun -SkipSkills -SkipCcSwitch -Only git`
- 默认模式：`-Tui -DryRun -SkipSkills -SkipCcSwitch` 首屏默认执行
- TUI 模式：进入后可查看软件状态并退出
- TUI 模式：进入 Skill 页时才获取 / 读取 `skills.zip`
- TUI 模式：Skill Profile 复选可生成正确 `-SkillProfile`

## Current First Fix

先处理当前最影响观感的问题：`skills.zip` 解压阶段仍触发 PowerShell 蓝色进度条。方案是把 `Install-SkillBundle` 中的 `Expand-Archive` 替换为 .NET ZipArchive 流式解压，并使用项目自建的 `Write-OperationProgress`。

