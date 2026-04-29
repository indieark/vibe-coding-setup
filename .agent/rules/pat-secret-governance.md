# PAT 与 GitHub Secret 规范

## 适用范围

本规则适用于 `vibe-coding-setup` 的 GitHub Actions、Release 镜像流程，以及后续所有需要跨私有仓库读取 release / asset 的自动化。

## 硬规则

- **一条跨仓库读取链路一个专用 secret**：不要把不同私库共用到同一个 PAT。
- **只用 GitHub Actions Secret 保存 PAT**：不得写入源码、README 示例值、日志、commit message、issue / PR 正文。
- **优先使用 fine-grained PAT**：只授予目标源仓库的 `Contents: Read-only`，除非 GitHub 功能限制明确要求 classic PAT。
- **不复用个人 `gh auth token` 做长期 secret**：本地登录 token 只能临时救火；救火后必须替换为专用 PAT。
- **当前仓库写 release / commit 只用 `GITHUB_TOKEN`**：不要给跨仓库 PAT 额外写权限。
- **缺 secret 必须 fail fast**：脚本不允许静默 fallback 到另一个 PAT，以免扩大权限边界。

## 当前 secret 清单

| Secret | 用途 | 最小权限 |
|--------|------|----------|
| `CODEX_PROVIDER_SYNC_TOKEN` | 读取 `indieark/codex-provider-sync` 私库 latest release asset | fine-grained PAT；仅该 repo；`Contents: Read-only` |
| `MODEL_00000_TOKEN` | 读取 `indieark/00000-model` 私库 `bundle-v*` release asset | fine-grained PAT；仅该 repo；`Contents: Read-only` |
| `GITHUB_TOKEN` | GitHub Actions 自动注入；写当前仓库 `bootstrap-assets` release、提交 manifest/README 更新 | workflow `permissions.contents: write` |

## 轮换与审计

- PAT 建议设置过期时间（优先 90 天，最长不超过 180 天）。
- 轮换时先新增/覆盖 GitHub Secret，再跑 `refresh-bootstrap-assets` dry-run 验证。
- 每次新增跨仓库 PAT 时，同步更新本文件与 README 的 secret 清单。
- 若临时使用了个人 token，完成后必须补一条 follow-up：创建专用 PAT、覆盖 secret、撤销临时 token。

## 验证命令

```powershell
gh secret list --repo indieark/vibe-coding-setup

gh workflow run refresh-bootstrap-assets.yml --ref main -f dry_run=true
gh run watch <run-id> --exit-status
```
