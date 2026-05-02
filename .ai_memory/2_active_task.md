# Active Task Snapshot

## 当前状态

- 已完成自定义工作台文案与行为校准：入口统一为“检查并安装/更新软件 / 套件 / Skill / MCP / CLI”。
- `开始执行` 只在已经选择软件或 Skill/MCP/CLI 后显示；点击后进入最终 `执行确认` 页，按 Enter 才真正返回执行参数。
- 默认安装输出标题改为 `步骤一：获取依赖`、`步骤二：应用安装`、`步骤三：配置导入`、`步骤四：插件安装`，最终完成提示为 `恭喜：安装流程完成`。
- 套件/Profile 页会展示 Bundle Skill、可选 Skill、本机已安装和可能新增数量。
- 单项 Skill 选择页已从只读 `RegistrySkills` 改为合并 `BundleSkills + RegistrySkills` 后去重，并显示 bundle / external 与已安装状态。
- MCP 选择页会显示已配置目标或未配置；CLI 选择页会显示检测状态。
- 已同步 `docs/operations.md`、`docs/installer-flow.md`、`docs/skill-import.md`、`docs/README.md`、`docs/roadmap.md` 和 `.ai_memory`。

## 当前未完成项

- 安装器仍缺少日志落盘、JSON 报告、bundle 签名 / checksum 等增强项。
- 当前 TUI 是 PowerShell 控制台拟似 TUI，不是独立 GUI；后续如需 GUI，应继续复用 `bootstrap.ps1` 的参数和安装内核。

## 最近验证

- `bootstrap.ps1` PowerShell parser 通过。
- `modules/common.psm1` PowerShell parser 通过。
- 本地缓存 `downloads/skills.zip` 验证：`BundleSkills=72`、`RegistrySkills=63`、`Profiles=8`、`Mcp=10`；此前显示 60 多的原因是 UI 只用了 registry-only 口径。

## 下一步

1. 运行 `git diff --check` 和文档过时措辞检查。
2. 提交并推送本轮 TUI / Skill 状态展示修复。
3. 手动触发 `Refresh bootstrap release assets` workflow，并关注 run 是否成功。

## 阻断

- 没有当前阻断。
