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

## 当前未完成项

- `Codex Desktop` fallback 仍未升级
  - 现状：仍指向 `Codex-26.325.31654.Setup.exe`
  - 原因：尚未确认稳定、公开、可验证的官方安装器下载来源

## 立即下一步

1. 如果要继续完善 fallback，优先攻克 `Codex Desktop` 的官方安装器来源问题。
2. 如需清理 release，可在确认无回滚需求后删除旧版资产，避免 `bootstrap-assets` 中新旧并存。
3. 如需提高可维护性，可新增 checksum 校验和 release 资产同步脚本。

## 阻断

- 没有代码级阻断。
- 仅有一个资料来源阻断：`Codex Desktop` 的官方 Windows 安装器公开分发路径未确认。
