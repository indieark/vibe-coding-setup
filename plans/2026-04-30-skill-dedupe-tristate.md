# Skill 去重三态判定执行计划

## Scope

本计划覆盖 Phase 4：在 `vibe-coding-setup` 导入 `skills.zip` 时，对目标目录中已存在的同名 skill 做 Tracked / Orphan / Foreign 三态判定，并选择安全动作。

涉及范围：

- `modules/common.psm1` 的 `Install-SkillBundle` / `Copy-SkillDirectory` 周边逻辑
- Skills Manager central root：`~/.skills-manager/skills/<name>`
- 可选目标：`~/.codex/skills`、`~/.claude/skills`、`~/.cursor/skills`、`~/.gemini/...`、`~/.copilot/skills`
- `.skill-meta.json` 中的 `source_ref`、`source_subpath`、`source_branch`、`source_revision`、`registry_entry_name`

不覆盖：

- MCP 安装落地
- prereq 自动安装
- GUI 装机器
- 真正删除用户目录
## Invariants

- 不自动删除任何用户已有 skill 目录；替换前必须备份。
- 备份目录格式固定为 `<name>.legacy.YYYYMMDD-HHMMSS`，与原 `<name>` 平级。
- `DryRun` 必须只打印计划，不创建、移动、删除、覆盖任何文件。
- 对 `source_ref` 不匹配的 Foreign skill，默认不覆盖。
- 非交互式环境不能卡在 prompt；Foreign 默认跳过，Orphan 默认备份替换可由参数控制。
- 旧 bundle 没有 `.skill-meta.json` 或没有 `registry_entry_name` 时，必须保持现有导入路径可用。
- Skills Manager DB 同步只登记最终导入的 skill，不登记被跳过的 Foreign skill。

## Assumptions

- IndieArk bundle 中每个 skill 均带 `.skill-meta.json`。
- `source_ref` 是判定 Tracked / Foreign 的主键；`registry_entry_name` 只用于 profile 父项展开。
- central root 是源真相目录，可选目标从 central root 复制。
- Windows PowerShell 5.1 仍是支持目标，新增字符串需避免 UTF-8 无 BOM 中文字面量解析问题。
## Implementation Checklist

1. 新增 `Get-SkillInstallState`：读取目标目录与源 meta，返回 `Missing` / `Tracked` / `Orphan` / `Foreign`。
2. 新增 `Backup-SkillDirectory`：把现有目录移动到 `.legacy.<timestamp>`，支持 `DryRun`。
3. 新增参数：
   - `-NoReplaceOrphan`：Orphan 也不替换。
   - `-ReplaceForeign`：显式允许 Foreign 备份后替换。
   - `-RenameForeign`：Foreign 导入为 `<name>-indieark`，不覆盖原目录。
4. central root 导入先跑三态判定，再决定 copy / skip / backup。
5. 可选目标同步复用 central root 的最终结果；如果 central root 被跳过，目标也跳过。
6. 日志输出固定包含：skill 名、目标路径、状态、动作、备份路径。
7. `ImportedSkills` 只包含实际导入或已同步的 IndieArk skill。

## Validation

- `git diff --check`
- PowerShell 5.1：`Import-Module .\modules\common.psm1 -Force`
- `-DryRun -SkillProfile "飞书办公套件"`：验证 Tracked/Missing 正常路径。
- 构造临时 `UserHomeOverride`：
  - 无目录 -> Missing copy
  - 有 `SKILL.md` 无 meta -> Orphan backup replace
  - 有 meta 且 `source_ref` 匹配 -> Tracked sync
  - 有 meta 且 `source_ref` 不匹配 -> Foreign skip
- 验证 `-NoReplaceOrphan`、`-ReplaceForeign`、`-RenameForeign` 参数行为。
## Rollback Notes

- 若导入逻辑异常，回滚 `modules/common.psm1` 中三态判定相关提交即可恢复现有覆盖式同步。
- 已生成的 `.legacy.<timestamp>` 备份目录不自动回滚；需要人工把备份目录改回原 `<name>`。
- 若 Skills Manager DB 同步了错误条目，可重新运行上一版安装脚本覆盖登记，或删除 DB 后让 Skills Manager 重建。

## Pause Gate

该阶段会改变用户已有 skill 目录的处理方式，属于状态同步与文件移动高风险改动。按仓库规则，本计划写入后暂停，下一轮再按 checklist 实施。
