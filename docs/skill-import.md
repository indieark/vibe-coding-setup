# Skill 导入契约

> 本文是 `vibe-coding-setup` 侧 Skill 导入行为的唯一说明入口。Skill 清单、Profile 定义和 bundle 构建以 `indieark/00000-model` 的 `registry/*.yaml` 为准。

## 分发链路

1. `indieark/00000-model` 从 registry 构建 bundle release。
2. 当前仓库的 `refresh-bootstrap-assets.yml` 把 bundle 镜像为公开 `bootstrap-assets/skills.zip`。
3. 终端用户运行安装器时，只下载当前仓库公开 `skills.zip`。
4. 用户机器不需要 `indieark/00000-model` 私库 PAT。

安装器不会在 TUI 首屏预取 `skills.zip`。只有进入自定义模式的 Skill / 套件 / MCP / CLI 相关入口，或后续安装 / 演练实际要导入 Skill 时，才会按需获取 bundle；同一轮自定义模式会复用已读取的 registry / 状态结果。

`skills.zip` 是公开 release asset，不等于 `00000-model` 刚刚构建出的私库 bundle。改完 registry 后，必须等本仓库 `Refresh bootstrap release assets` workflow 镜像完成；本地 `downloads/skills.zip` 旧缓存也会导致 TUI 继续显示旧文案、旧 Skill 数量或旧 Profile 统计。排查和刷新步骤见 [资产刷新链路](asset-refresh.md)。

## Profile 选择

`Install-SkillBundle` 解压 `skills.zip` 后，会读取 bundle 内置的 `registry/profiles.yaml`：

- 自定义模式的“检查并安装套件”动作会先读取 `skills.zip` 中的 Profile 和 registry，并以复选项展示；默认选择“全部 Skill”，也可以选择“所有套件”或“跳过 Skill 导入”。
- 自定义模式的“检查并任选安装 Skill / MCP / CLI”动作读取 registry 或状态后进入分页复选列表，并分别写回等价的 `-SkillName`、`-McpName`、`-CliName` 参数；读取和状态扫描期间会同一行刷新完成数量，结束时只保留完成行。
- Skill / 套件入口使用轻量 Skill registry 读取路径，不检测 MCP / CLI；MCP / CLI 入口才读取 MCP 配置状态和 CLI 检测状态。
- “全部 Skill”导入 registry 中的全部 Skill：bundle 内已有的 custom / vendored 直接导入，不在 bundle 内的 external 按来源自动拉取或复制；它不会自动写入所有 MCP 或安装所有 CLI。
- “所有套件”按全部 Profile 的并集合并 Skill / MCP / CLI 前置依赖，并在终端显示套件数、Skill 数、MCP 数和 CLI 数。
- TUI 中选择任意 Profile 后，会取消“全部 Skill”，并在确认页生成等价 `-SkillProfile` 命令。
- 传 `-SkillProfile "名称"`：只导入指定 Profile 引用的 skill。
- 多个 Profile 可用英文逗号、中文逗号或顿号分隔。
- 传 `-AllSkills`：显式导入 registry 中全部 Skill；bundled 直接导入，external 按 `source` 自动拉取或复制。
- 传 `-AllSuites`：显式按所有 Profile 的并集导入 Skill、external Skill、MCP 和前置依赖。
- 传 `-SkillName "名称"`：显式导入一个或多个 registry skill；如果它是 bundled skill，则从离线 bundle 导入；如果它是 external skill，则按 `source` 自动拉取或复制。
- 传 `-McpName "名称"`：显式写入一个或多个 registry MCP，并自动安装这些 MCP 的前置 CLI / runtime。
- 传 `-CliName "名称"`：显式安装一个或多个 `prereqs.yaml` 前置依赖；这适合只安装 GitHub CLI、飞书 CLI、uv 等命令行工具。
- 传 `-SkipSkills`：完全跳过 `skills.zip` 下载和 Skill 导入。
- 传 `-SkipApps`：跳过软件安装阶段，可用于只导入 Skill 的命令模式或自定义模式路径。
- 不传 Profile 且处于交互式终端：显示中文选择菜单；输入 `0` 导入全部 Skill，输入 `00` 导入所有套件，直接回车跳过 Skill 导入。
- 非交互式且未传 Profile：自动回退为全部导入，保持自动化兼容。

Profile 交互菜单会把 `0`、`00` 和每个套件展示为两行：第一行是名称和暗灰色括号说明，说明过长时按当前终端宽度截断为 `...`；第二行是带不同颜色的 Skill / MCP / CLI 数量摘要。`0` 会显示全部 Skill 的有效导入数量、MCP 0、CLI 0；该数量至少覆盖 registry 条目数、bundle 离线目录数和所有套件展开后的 Skill 并集，不能小于 `00` 的 Skill 数。`00` 会显示 Profile 并集 Skill 数、MCP 数和 CLI 数。TUI 复选页光标停在某个套件时，会临时展示该套件将写入的 MCP 和将处理的 CLI 前置依赖；默认交互菜单在用户输入后、执行前也会输出同样摘要。可输入序号/名称，多个可用英文逗号、中文逗号或顿号分隔；输入 `0` 安装全部 Skill，输入 `00` 安装所有套件。

当前 registry 中 `Tauri 桌面开发套件` 的 MCP 数应为 0。若显示非 0，优先怀疑正在读取旧 `skills.zip` 或旧脚本，而不是修改 Tauri Profile。

单项安装与套件安装共用同一条执行路径：先解析 registry，汇总 Skill / MCP / CLI 数量，再安装前置依赖、导入 Skill、写入 MCP 配置。单项 MCP 或单项 CLI 即使不导入任何 Skill，执行摘要也会显示已处理的 MCP / CLI 数量。

全部 Skill、单项 Skill 和 Profile 可以同时覆盖 bundled skill、external skill、MCP 和前置依赖：

- bundled skill：`skills.zip` 内已有 `SKILL.md` 的 custom / vendored 离线目录，直接走三态导入。
- external skill：`registry/skills.yaml` 中 `external` 段的条目；安装器支持 `repo`（git clone）、`archive_url` / `download_url`（zip / tar.gz / tgz）、`local_path`（本地目录）三类自动来源，并按 `subpath` 或 `SKILL.md` 自动定位后导入；只有 `homepage`、没有可执行来源的条目只提示，不能假装安装成功。
- MCP：安装器会把 registry 中可配置的 MCP 写入 Codex、Claude Desktop、Claude Code、Cursor、Gemini CLI、Antigravity；stdio 走本地 `command + args`，HTTP / SSE 走 `url`，涉及 OAuth / token 的值只写环境变量占位符，不写密钥。
- 前置依赖：安装器会按 `registry/prereqs.yaml` 先执行 `check`，缺失时优先使用当前平台字段，再回退到 `command` / `npm` / `pipx` / `pip` / `brew` / `winget` / `scoop`；`manual: true` 和商业软件只提示人工安装。单个 CLI 安装失败会汇总告警，不再挡住后续可安装项。

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

## MCP 配置目标

非 `-DryRun` 且 Profile 引用了 MCP 时，安装器会按 registry 自动写入：

- Codex：`~/.codex/config.toml`
- Claude Desktop：`~/AppData/Roaming/Claude/claude_desktop_config.json`
- Claude Code：通过 `claude mcp add-json <name> <json> --scope user` 注册；未安装 `claude` CLI 时只告警。
- Cursor：`~/.cursor/mcp.json`
- Gemini CLI：`~/.gemini/settings.json`
- Antigravity：`~/.gemini/antigravity/mcp_config.json`

写入前会备份已有配置，写入后会做 TOML / JSON 语法校验。

## 三态判定

导入 central root 前，安装器会读取源目录和目标目录的 `.skill-meta.json`，得到状态和动作：

| 状态      | 判定                                                | 默认动作                             |
| --------- | --------------------------------------------------- | ------------------------------------ |
| `Missing` | 目标目录不存在                                      | 复制导入                             |
| `Tracked` | 目标有 `.skill-meta.json`，且来源字段与 bundle 匹配 | 内容一致则跳过，内容不同则同步       |
| `Orphan`  | 目标有 `SKILL.md`，但没有 `.skill-meta.json`        | 备份为 `<name>.legacy.<时间>` 后替换 |
| `Foreign` | 目标有 `.skill-meta.json`，但来源字段不匹配         | 跳过，避免覆盖第三方同名 skill       |

可调整参数：

- `-NoReplaceOrphan`：孤儿目录不备份替换，只跳过。
- `-ReplaceForeign`：第三方同名目录也备份替换。
- `-RenameForeign`：第三方同名目录保留，IndieArk 版本改名为 `<name>-indieark` 导入。
- `-SkipSkillsManagerLaunch`：同步后不自动拉起 Skills Manager，适合测试和自动化。

## SQLite 注册

非 `-DryRun` 时，安装器会把实际导入或已跟踪的 IndieArk skill（包括 external skill）写入：

- `~/.skills-manager/skills-manager.db`

写入字段来自 `.skill-meta.json`，包括上游 git URL、branch、subpath、revision 等。缺少 meta 时，会回退为 local 行为，保持旧 bundle 兼容。是否把这些 skill 启用到 Skills Manager 场景由 `-SkillsManagerScenarioMode` 控制：

- `prompt`：交互式终端询问；非交互式环境跳过场景注册。
- `default`：写入当前默认 / 当前启用场景。
- `custom`：写入 `-SkillsManagerScenarioName` 指定的自定义场景；场景不存在时创建。
- `skip`：跳过 Skills Manager 场景注册，只复制 Skill 文件和其它宿主目标。

被跳过的 `Orphan` 或 `Foreign` 不会登记到 DB。

## 进度与日志

Skill 导入开始前会输出选中的 Profile / 套件、Skill 数量、MCP 数量和前置 CLI 数量摘要。
单项安装开始前会输出 `单项选择：Skill X 个；MCP Y 个；CLI Z 个`，随后分别列出选中的 skill、MCP 和解析到的前置依赖。

导入过程中按 skill 聚合显示：

- `Skill 进度：当前/总数 名称`
- `Skill 已同步：名称；动作=...；目标=... 个`
- `Skill 已跳过：名称`
- `[演练] 安装 external skill：名称 -> 来源`
- `[演练] 写入 Codex MCP 配置：名称`
- `[dry-run] write Claude Desktop / Cursor / Gemini CLI MCP config: 名称 -> 路径`
- `[dry-run] write Antigravity MCP config: 名称 -> 路径`
- `[dry-run] register Claude Code user MCP: 名称`

正常流程不再逐条打印每个目标目录的复制和备份路径，避免安装窗口刷屏。遇到 `Orphan` / `Foreign` 被策略跳过、警告或失败时，仍会输出明确路径和原因。最终执行摘要以 `skills.zip` 一行呈现导入结果。

## 安全测试命令

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -AllSkills -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -AllSuites -SkipSkillsManagerLaunch

.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -SkillName "lark-shared" -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -McpName "context7" -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -CliName "gh" -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -SkillProfile "媒体创作套件" -SkipSkillsManagerLaunch
.\bootstrap.cmd -DryRun -SkipApps -SkipCcSwitch -SkillProfile "演示文稿与文档套件" -SkipSkillsManagerLaunch
```
