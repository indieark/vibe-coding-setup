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
- `Codex Desktop` 仍是唯一明确未完成项。

### 后续行动指引

1. 如继续推进，优先研究 `Codex Desktop` 的官方安装器分发来源或 Store offline package 获取路径。
2. 如准备长期维护此仓库，建议补一个“同步官方最新版到 bootstrap-assets”的自动化脚本。
3. 如准备清理 release，先确认是否需要保留旧版资产作回滚，再决定是否删除旧文件。
