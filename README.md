# Windows 一键部署脚本

> 给后续 AI / 维护者：先读本 README 的“文档地图”，再按专题进入 `docs/`。不要把同一套规则重复写在多个文件里。

这个仓库用于在 Windows 上一键拉起开发环境、桌面工具和 Skill 包。主入口是 `bootstrap.ps1`，`bootstrap.cmd` 是本地启动壳，`vibe-coding-setup.cmd` 是远程自举入口。

## 当前定位

安装器已经从“批量拷贝工具和技能”升级为“按需装机器”底座：

- 应用安装以 `manifest/apps.json` 为唯一安装清单。
- 主来源优先使用 `winget`、上游 GitHub Releases、固定直链或当前仓库自托管 Release 资产。
- 回退来源主要使用 `indieark/vibe-coding-setup` 的公开 `bootstrap-assets` Release。
- `skills.zip` 来自 `indieark/00000-model` registry bundle，经当前仓库镜像后分发。
- Skill 导入支持 Profile 选择、`.skill-meta.json` 来源追踪、三态去重和 Skills Manager SQLite 注册。

## 文档地图

| 主题 | 唯一说明入口 | 说明 |
| --- | --- | --- |
| 安装执行顺序 | [`docs/installer-flow.md`](docs/installer-flow.md) | 自举、应用安装、fallback、summary 退出码 |
| Skill 导入契约 | [`docs/skill-import.md`](docs/skill-import.md) | Profile、`.skill-meta.json`、三态判定、SQLite 注册 |
| 资产刷新链路 | [`docs/asset-refresh.md`](docs/asset-refresh.md) | `bootstrap-assets` 自动刷新、私库资产镜像、workflow 边界 |
| PAT / Secret 规则 | [`.agent/rules/pat-secret-governance.md`](.agent/rules/pat-secret-governance.md) | Secret 命名、最小权限、轮换与验证规则 |
| 本机运行命令 | [`docs/operations.md`](docs/operations.md) | 本地运行、远程自举、安全 dry-run、常见参数 |
| 后续路线 | [`docs/roadmap.md`](docs/roadmap.md) | 可观测、校验、报告和装机体验增强 |
| 当前任务快照 | [`.ai_memory/2_active_task.md`](.ai_memory/2_active_task.md) | 当前状态、下一步、阻断 |

## 单一信息源约定
- 应用名称、安装策略、版本门禁和 fallback 文件名只在 `manifest/apps.json` 定义。
- 安装执行行为以 `bootstrap.ps1` 和 `modules/common.psm1` 为准，文档只解释已实现行为。
- PAT / Secret 治理只在 `.agent/rules/pat-secret-governance.md` 维护；其它文档只链接它。
- Skill registry / Profile / bundle 来源以 `indieark/00000-model` 的 `registry/*.yaml` 和 bundle 构建结果为准。
- `.ai_memory/` 只记录阶段状态和接手上下文，不作为用户手册或安装规则源。

## 快速开始

本地仓库运行：

```powershell
Set-Location "C:\Vibe_Coding\IndieArk\gadget\vibe-coding-setup"
.\bootstrap.cmd
```

远程自举入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

本机安全演练 Skill 导入，不替换旧目录、不拉起 UI：

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
```

更多命令见 [`docs/operations.md`](docs/operations.md)。

## 当前关键状态

- `main` 已包含按需装机器 Phase 1-4：私库 bundle 镜像、Profile 选择、Skill meta 透传、三态去重。
- 终端用户安装不需要私库 PAT；PAT 只用于 GitHub Actions 刷新公开镜像资产。
- Phase 5 飞书只读镜像仍在 `indieark/00000-model` 侧按计划推进。

## 维护检查清单

改动前后至少确认：

- 修改应用安装项时，同步检查 `manifest/apps.json`，不要在 README 手写第二份应用清单。
- 修改 Skill 导入行为时，同步更新 `docs/skill-import.md` 和 `.ai_memory/2_active_task.md`。
- 修改跨仓库资产读取时，同步更新 `.agent/rules/pat-secret-governance.md`，不要只改 workflow。
- 修改自举或 fallback 行为时，同步更新 `docs/installer-flow.md` 和 `docs/asset-refresh.md`。
