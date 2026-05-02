# 资产刷新链路

> 本文解释 `bootstrap-assets` 如何刷新。PAT / Secret 的权限、命名和轮换规则只在 [`.agent/rules/pat-secret-governance.md`](../.agent/rules/pat-secret-governance.md) 维护。

## 目标

终端用户安装时只访问当前仓库公开 Release 资产；私有仓库访问只发生在 GitHub Actions 刷新镜像资产阶段。

## 关键文件

- `.github/workflows/refresh-bootstrap-assets.yml`
- `scripts/Update-BootstrapAssets.ps1`
- `manifest/apps.json`
- `README.md`

## 刷新流程

1. workflow 触发 `scripts/Update-BootstrapAssets.ps1`。
2. 脚本检查 manifest 和 managed asset 定义。
3. 对公开上游资产，直接解析 latest 或固定 URL。
4. 对私库资产，通过专用 GitHub Actions Secret 读取 release asset。
5. 下载后的资产上传到当前仓库 `bootstrap-assets` Release。
6. 如文件名变化，同步更新 `manifest/apps.json` 或相关 README 说明。
7. dry-run 模式只报告计划，不上传、不提交。

## 当前私库镜像边界

- `indieark/codex-provider-sync`：镜像安装包到当前仓库公开 Release。
- `indieark/00000-model`：镜像 registry bundle 为公开 `skills.zip`；bundle 内包含 Skill 实体、registry yaml、Profile、MCP/prereq 镜像资产。

Secret 名称、权限和轮换要求见 [PAT / Secret 规则](../.agent/rules/pat-secret-governance.md)。

## 安装侧边界

安装器不读取私库 release，也不要求用户提供 PAT。安装侧只依赖：

- 当前仓库 `bootstrap-assets` Release
- manifest 中定义的公开主来源
- 官方 Store / 公开网页 fallback

## 验证命令

```powershell
gh workflow run refresh-bootstrap-assets.yml --ref main -f dry_run=true
gh run watch <run-id> --exit-status
```

## 单一信息源边界

- 资产文件名：以 `manifest/apps.json` 和 refresh 脚本实际输出为准。
- Secret 治理：以 `.agent/rules/pat-secret-governance.md` 为准。
- Skill bundle 内容：以 `indieark/00000-model` registry bundle 为准。
- 安装行为：以 `bootstrap.ps1` 和 `modules/common.psm1` 为准。
