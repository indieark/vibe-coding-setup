# Skill 导入契约

> 本文是 `vibe-coding-setup` 侧 Skill 导入行为的唯一说明入口。Skill 清单、Profile 定义和 bundle 构建以 `indieark/00000-model` 的 `registry/*.yaml` 为准。

## 分发链路

1. `indieark/00000-model` 从 registry 构建 bundle release。
2. 当前仓库的 `refresh-bootstrap-assets.yml` 把 bundle 镜像为公开 `bootstrap-assets/skills.zip`。
3. 终端用户运行安装器时，只下载当前仓库公开 `skills.zip`。
4. 用户机器不需要 `indieark/00000-model` 私库 PAT。

## Profile 选择

`Install-SkillBundle` 解压 `skills.zip` 后，会读取 bundle 内置的 `registry/profiles.yaml`：

- 传 `-SkillProfile "名称"`：只导入指定 Profile 引用的 skill。
- 多个 Profile 可用逗号分隔。
- 传 `-AllSkills`：显式导入 bundle 内全部 skill。
- 不传 Profile 且处于交互式终端：显示中文选择菜单。
- 非交互式且未传 Profile：自动回退为全部导入，保持旧逻辑可用。

## 目标目录

central root 固定为：

- `~/.skills-manager/skills/<skill-name>`

始终启用的工具目标：

- `~/.codex/skills/<skill-name>`

如果对应宿主目录已存在，也会同步：

- `~/.claude/skills/<skill-name>`
- `~/.cursor/skills/<skill-name>`
- `~/.gemini/antigravity/global_skills/<skill-name>`
- `~/.gemini/skills/<skill-name>`
- `~/.copilot/skills/<skill-name>`

## 三态判定

导入 central root 前，安装器会读取源目录和目标目录的 `.skill-meta.json`，得到状态和动作：

| 状态 | 判定 | 默认动作 |
| --- | --- | --- |
| `Missing` | 目标目录不存在 | 复制导入 |
| `Tracked` | 目标有 `.skill-meta.json`，且来源字段与 bundle 匹配 | 内容一致则跳过，内容不同则同步 |
| `Orphan` | 目标有 `SKILL.md`，但没有 `.skill-meta.json` | 备份为 `<name>.legacy.<时间>` 后替换 |
| `Foreign` | 目标有 `.skill-meta.json`，但来源字段不匹配 | 跳过，避免覆盖第三方同名 skill |

可调整参数：

- `-NoReplaceOrphan`：孤儿目录不备份替换，只跳过。
- `-ReplaceForeign`：第三方同名目录也备份替换。
- `-RenameForeign`：第三方同名目录保留，IndieArk 版本改名为 `<name>-indieark` 导入。
- `-SkipSkillsManagerLaunch`：同步后不自动拉起 Skills Manager，适合测试和自动化。

## SQLite 注册

非 `-DryRun` 时，安装器会把实际导入或已跟踪的 IndieArk skill 写入：

- `~/.skills-manager/skills-manager.db`

写入字段来自 `.skill-meta.json`，包括上游 git URL、branch、subpath、revision 等。缺少 meta 时，会回退为 local 行为，保持旧 bundle 兼容。

被跳过的 `Orphan` 或 `Foreign` 不会登记到 DB。

## 安全测试命令

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
```
