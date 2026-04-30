# 文档治理规则

## 目标

保持层层索引和单一信息源，避免 README、docs、规则文件和归档文件互相复制同一套事实。

## 层级

1. `README.md` 是顶层入口，只放项目定位、文档地图、快速开始和维护检查清单。
2. `docs/` 是人类说明文档，按专题拆分；每个专题只能有一个唯一入口。
3. `.agent/rules/` 是代理执行规则，规则类内容只写在这里。
4. `.ai_memory/` 是接手上下文和阶段快照，不作为用户手册或安装规则源。
5. 代码和配置文件是最终事实源；文档只解释当前实现。

## 单一信息源

- 应用安装清单、版本、fallback 文件名：只在 `manifest/apps.json` 定义。
- 安装流程：以 `bootstrap.ps1` 和 `modules/common.psm1` 为准，说明入口是 `docs/installer-flow.md`。
- Skill 导入策略：说明入口是 `docs/skill-import.md`，Skill 清单和 Profile 以 `indieark/00000-model` registry 为准。
- 资产刷新：说明入口是 `docs/asset-refresh.md`。
- PAT / Secret 治理：只在 `.agent/rules/pat-secret-governance.md` 维护。

## 修改要求

- 新增或修改功能时，先判断所属专题，不要直接把细节堆进 README。
- 若一个事实已经有唯一入口，其它文件只能链接，不要复制表格或完整规则。
- 修改文档后必须检查 README 文档地图、相对链接、过时引用和重复定义。
