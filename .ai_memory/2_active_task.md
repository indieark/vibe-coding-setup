# Active Task Snapshot

## 当前状态

- 已整理主脚本逻辑并更新 `README.md`
- 已整理每个安装项的主来源 / 回退来源并更新 `README.md`
- 已将以下 fallback 资产升级到官方最新版并上传到 `bootstrap-assets`：
  - Git
  - Node.js
  - Python 3.13
  - Visual Studio Code
  - CC Switch
- 已把 `Python` fallback 从 manager 型安装器改为真正的运行时安装器
- 已完成一次 `-DryRun` 验证，脚本可正常读取更新后的 manifest
- 已将 `Codex Desktop` fallback 从过期的 release `Setup.exe` 切换到官方 Microsoft Store 来源
- 已删除 release 中旧的 `Codex-26.325.31654.Setup.exe`

## 当前未完成项

- 当前没有必须立即处理的阻断项

## 立即下一步

1. 如需提高可维护性，可新增 checksum 校验和 release 资产同步脚本。
2. 可考虑把 `bootstrap-assets` 的同步过程脚本化，避免手工上传和手工清理。
3. 如需继续归档，可把这次 `Codex Desktop` fallback 方案补进下一轮长期总结。

## 阻断

- 没有当前阻断。
