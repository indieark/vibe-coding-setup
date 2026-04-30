# Archive Context

## 2026-04-23 - README整理与fallback资产升级归档

### 核心议题背景

用户先要求梳理仓库主脚本逻辑、安装来源与回退来源，并汇总到 `README.md`；随后要求把 release 中的 fallback 安装包更新到官方最新版；最后要求更新 `README` 并做总结归档。

### Cognitive Evolution Path

1. 初始阶段先把仓库结构、主入口、manifest、模块逻辑读清楚，避免只看 `README` 做二手总结。
2. 发现主入口是 `bootstrap.ps1`，真正决定安装与 fallback 的核心在：
   - `manifest/apps.json`
   - `modules/common.psm1`
3. 文档阶段没有只做“怎么用”，而是按代码真实执行顺序重写了 `README`，把自举、提权、precheck、技能导入和 Provider 导入都讲清楚。
4. 更新 fallback 时，先核对每个安装项的官方最新版与官方资产命名，再回写 manifest，避免拍脑袋改文件名。
5. 在 Python 项上没有机械沿用旧方案，而是识别出 `python-manager-26.0.msix` 不是 `Python 3.13` 运行时本体，因此顺手把 fallback 改成真正的官方安装器并补静默参数。
6. 在 `Codex Desktop` 项上刻意保守：虽然拿到了 Store 包 ID 和本机版本，但没有确认稳定公开的官方 `Setup.exe` 来源，因此没有盲改，避免把 fallback 指到不可验证的文件名。
7. 远端 release 操作采取“新增新包、不删除旧包”的策略，降低回滚风险；同时在文档里明确说明“脚本只认 manifest 当前指向的文件名”。

### 关键决策

- 文档层面以代码为准，不以旧 `README` 为准。
- fallback 升级时同时更新三处：
  - `manifest/apps.json`
  - `README.md`
  - GitHub `bootstrap-assets` release
- 对缺乏稳定官方来源的包保持保守，不为了“全绿”而瞎改。

### 当前结论

- 主要 fallback 资产已升级并上传：
  - Git
  - Node.js
  - Python 3.13
  - Visual Studio Code
  - CC Switch
- 后续已完成 `Codex Desktop` fallback 收尾：
  - 不再维护 release 中会过期的 `Codex-*.Setup.exe`
  - 改为官方 Microsoft Store 协议和网页详情页作为 fallback
  - release 中旧的 `Codex-26.325.31654.Setup.exe` 已删除

### 后续行动指引

1. 如准备长期维护此仓库，建议补一个“同步官方最新版到 bootstrap-assets”的自动化脚本。
2. 如希望提升可验证性，可为 release 资产增加 checksum 记录与校验步骤。
3. 如未来再遇到没有稳定直链的桌面应用，优先考虑“官方 Store / 官方 URI fallback”而不是自托管易过期安装器。

## 2026-04-23 - Codex Desktop fallback 收尾归档

### 核心议题背景

在主安装项与 release 资产大体整理完成后，剩余唯一悬而未决的问题是 `Codex Desktop` 仍依赖仓库 release 中的旧版 `Setup.exe`。用户随后要求把这个 fallback 来源问题彻底解决。

### Cognitive Evolution Path

1. 先确认 `Codex` 在官方侧有哪些可验证来源。
2. 通过 `winget show --id 9PLM9XGG6VKS --source msstore` 与 OpenAI 官方页面，确认它的官方来源稳定落在 Microsoft Store，而不是公开 GitHub Release / 固定 exe 下载页。
3. 由此放弃“继续追 `Codex-*.Setup.exe` 文件名”的思路，改为在通用安装逻辑中增加 `uri` 型 fallback。
4. 最终把 `Codex Desktop` 的 fallback 改成：
   - `ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS`
   - `https://apps.microsoft.com/detail/9PLM9XGG6VKS`
5. 完成代码、manifest、README 的同步修改后，再删除 release 中旧的 `Codex-26.325.31654.Setup.exe`。

### 关键决策

- 对没有稳定公开安装器文件名的官方桌面应用，优先使用官方 Store / URI 作为 fallback。
- 不为了保留“静默 exe fallback”而继续维护一个高过期风险的自托管安装器。

### 当前结论

- `Codex Desktop` fallback 问题已经解决。
- 当前 `bootstrap-assets` release 中不再残留 `Codex` 旧安装包。

## 2026-04-23 - 仓库全量复读与 README 对账归档

### 核心议题背景

用户要求“完整读一遍仓库，理解脚本执行全逻辑、理解已安装应用的主来源与回退来源，并更新 README 后归档总结”。这次重点不再是继续改安装逻辑，而是确认文档是否和代码真实行为完全一致。

### Cognitive Evolution Path

1. 先列出整个仓库真实文件集合，确认可执行逻辑实际上集中在：
   - `bootstrap.ps1`
   - `modules/common.psm1`
   - `manifest/apps.json`
   - 两个 `.cmd` 入口壳
2. 虽然现有 `README.md` 已经很详细，但仍然按“代码优先、文档次之”的方式重读主入口和模块函数清单，避免把旧文档当真相源。
3. 在对账过程中发现最关键的偏差不是安装来源表，而是执行条件和控制流细节：
   - `skills.zip` 的预取和导入实际上只受 `-SkipSkills` 控制，不要求本次选择 `skills-manager`
   - 当前 manifest 实际使用了 `release-asset`，而不是 `github-release`
   - 主安装路径失败后，不是立刻 fallback，而是会先做一次 post-check 重新探测安装结果
4. 因此这次 README 更新不只是补充说明，而是做了一次“代码事实校正”，把文档重新拉回到和脚本一致的状态。

### 关键决策

- 对这个仓库，README 只能作为“对外说明”，不能替代 `bootstrap.ps1` + `modules/common.psm1` + `manifest/apps.json` 作为唯一真相源。
- 对用户要求的“完整理解”，优先提炼控制流、来源矩阵和特殊分支，而不是机械罗列每个函数。
- 归档时把“文档与代码对账”本身记为稳定流程，防止未来再次出现 README 慢于代码演化的问题。

### 当前结论

- 当前仓库体量很小，但核心行为并不简单，尤其体现在：
  - 自举依赖同步
  - precheck / version gate
  - primary install -> post-check -> fallback
  - `skills.zip` 独立导入链
  - `CC Switch` provider deep-link 导入
- `README.md` 已根据代码重新校准。
- `.ai_memory` 已同步记录这次确认下来的稳定事实与当前快照。

### 后续行动指引

1. 以后每次改 `manifest/apps.json` 或 `common.psm1`，都应同步回看 README 中的“执行顺序”和“来源/回退”章节。
2. 如果未来把 `skills.zip` 的触发条件改成“仅在选择 `skills-manager` 时运行”，需要同时改代码和 README，而不是只改文档。
3. 如果新增新的 fallback 类型，优先先补 `README` 的通用安装逻辑，再补应用级来源表。

## 2026-04-30 — 按需装机器 Phase 1-4 归档

本轮路线把 `vibe-coding-setup` 从普通 Windows 装机脚本推进到按需装机器底座。关键转折是：不再把 Skill 当作无来源的目录拷贝，而是把 `00000-model` registry bundle 镜像成公开 `skills.zip`，并在导入时读取 `.skill-meta.json`，让 Skills Manager 能识别真实上游来源。

核心决策：终端用户不需要 PAT；PAT 只存在于刷新 `bootstrap-assets` 的 GitHub Actions secret 中。安装路径只访问当前仓库公开 release 资产，避免把私库权限扩散到用户机器。

Skill 导入的安全边界已经收敛为三态：`Tracked` 表示 IndieArk 可追更目录，按内容增量同步；`Orphan` 表示旧版或手工拷贝目录，默认备份后替换；`Foreign` 表示第三方同名目录，默认跳过。用户测试时优先用 `-DryRun -NoReplaceOrphan -SkipSkillsManagerLaunch`，确认日志后再真实导入。

后续先进化方向不应继续堆安装项，而应增强可观测和可校验：日志落盘、JSON report、bundle manifest / checksum、导入结果计数、`-Plan` 或 `-ReportPath` 模式。路线图下一阶段是 `00000-model` Phase 5：registry → 飞书 bitable 只读镜像，继续保持 yaml 为 SSOT。

## 2026-04-30 — 文档结构治理归档

用户要求保证层层索引和单一信息源。审计后发现 README 同时承载安装流程、Skill 导入、PAT 规范、资产刷新和路线图，容易与 `.agent/rules`、`.ai_memory` 和代码事实源重复。

本次把 README 改为顶层入口，只保留项目定位、文档地图、快速开始、SSOT 约定和维护检查清单。详细说明按主题拆入 `docs/installer-flow.md`、`docs/skill-import.md`、`docs/asset-refresh.md`、`docs/operations.md`、`docs/roadmap.md`。

同时新增 `.agent/rules/documentation-governance.md`，把“README 只做索引、规则写在 rules、归档不当用户手册、代码配置是最终事实源”固化为仓库规则。后续修改文档时先找唯一入口，不要把同一张表复制到多个文件。
