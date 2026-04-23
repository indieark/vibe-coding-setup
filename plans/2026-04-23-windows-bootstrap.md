# Windows 一键部署方案计划

日期：2026-04-23
主题：为同事提供 Windows 下一键部署最新环境、最新软件、工具与技能的安装方案

## 1. 目标

构建一个对同事足够简单、对你足够可维护的安装项目，满足以下目标：

- 在 Windows 上一键安装一组指定工具。
- 能优先从官方渠道或 GitHub Release 直链获取“最新版本”。
- 允许同事在安装过程中手动输入你提供的 OpenAI 兼容 `base_url` 和 `api_key`。
- 安装后自动把该 API 源添加到 `cc-switch`。
- 安装 `skills-manager` 后，自动把你提供的本地 `skill` 安装进去。
- 安装流程尽量可重复执行（idempotent），失败时容易定位，升级时尽量不需要你重新打包全部安装包。

## 2. 结论先行

首版最可靠、最简单的实现方式：

- 用一个公开或私有的 GitHub 项目承载整个安装器项目。
- 主体实现用 PowerShell 脚本，而不是先做 GUI 安装软件。
- 结构上采用：
  - `bootstrap.ps1` 作为入口
  - `manifest.json` / `apps.json` 作为软件清单
  - `modules/` 下的每个工具安装适配器
  - `assets/skills/` 存放你要下发的 skill

为什么这样选：

- Windows 原生可执行，部署门槛最低。
- PowerShell 对 MSI / EXE / ZIP / JSON / 注册表 / 快捷方式处理都够用。
- “最新版本”更适合通过脚本动态解析，而不是把版本写死在安装器里。
- GitHub 项目最适合做版本管理、Issue、同事自助下载、CI 验证与后续迭代。

不建议首版就做的方向：

- 先做 Electron / Tauri GUI 安装器。
- 先做 NSIS / Inno Setup 的复杂交互安装向导。
- 先做企业级 MDM / Intune / SCCM 方案。

这些方案不是不能做，而是首版复杂度更高，排障成本更高，且对“获取最新版”这件事没有本质优势。

## 3. 范围（Scope）

首版纳入范围：

- 安装基础开发工具：
  - `Git`
  - `Node.js`
  - `Python`
  - `VS Code`
  - `Codex`
- 安装目标应用：
  - `ChatGPT_x64.msi`（来源：`tw93/pake` 的 ChatGPT 安装包）
  - `CC-Switch`
  - `skills-manager`
- 安装本地 skill 包（当前工作区已有 `skills.zip`）。
- 交互式收集 API 信息并写入 `cc-switch`。
- 输出日志与安装结果汇总。

首版暂不纳入范围：

- 完整图形界面安装器。
- 多用户权限隔离。
- 域控 / 企业分发。
- 自动注册系统服务。
- 自动静默接管所有 AI 工具的现有配置。

## 4. 不变量（Invariants）

- 所有脚本与配置文件统一使用 UTF-8 without BOM。
- 所有下载优先走官方源、GitHub Release、或 `winget` 官方仓库。
- 安装逻辑必须支持重复执行，不因已安装而直接失败。
- 每个工具的安装与配置步骤必须独立，单个失败不应破坏已成功部分。
- 配置写入前必须先备份目标配置文件。
- 不在脚本中硬编码你的私密 `api_key`；由同事在运行时自行输入。
- 所有变更必须有日志，至少包含：下载 URL、版本、安装结果、配置写入结果。

## 5. 关键假设（Assumptions）

- 同事机器为 Windows 10 1809+ 或 Windows 11。
- 同事有本地管理员权限，至少能接受 UAC 提权。
- 网络能访问 GitHub Releases，且能访问你提供的 OpenAI 兼容 API。
- `cc-switch` 的配置结构可以通过文件层或导入机制稳定写入。
- `skills-manager` 支持本地 skill 安装或本地目录导入；若 GUI 首启必须确认，则需要增加一次后置脚本处理。

## 6. 核心架构

推荐项目结构：

```text
repo/
  bootstrap.ps1
  manifest/
    apps.json
  modules/
    common.psm1
    install-git.ps1
    install-node.ps1
    install-python.ps1
    install-vscode.ps1
    install-codex.ps1
    install-chatgpt.ps1
    install-cc-switch.ps1
    install-skills-manager.ps1
    configure-cc-switch.ps1
    install-local-skills.ps1
  assets/
    skills/
      ...
  logs/
  plans/
```

实现原则：

- `bootstrap.ps1` 只做流程编排，不写具体工具逻辑。
- 每个安装器脚本负责：
  - 检查是否已安装
  - 解析最新版本来源
  - 下载
  - 静默安装
  - 安装后验证
- `apps.json` 负责声明：
  - 软件名
  - 检查方式
  - 最新版来源类型（`winget` / `github-release` / `direct-url`）
  - 静默参数
  - 安装后验证命令

## 7. 版本获取策略

按可靠性排序：

1. 优先 `winget`
2. 其次 GitHub Release API / `releases/latest`
3. 最后固定官网下载页解析或你自备兜底安装包

具体建议：

- `Git` / `Node.js` / `Python` / `VS Code`
  - 优先 `winget`
  - 原因：Windows 上维护成本最低，升级能力最好
- `ChatGPT_x64.msi`
  - 优先 GitHub `tw93/pake` Release 资产直链
  - 不建议你手动保存旧版本安装包作为主路径
- `CC-Switch`
  - 优先 GitHub `farion1231/cc-switch` Release 资产直链
- `skills-manager`
  - 优先 GitHub `xingkongliang/skills-manager` Release 资产直链
- `Codex`
  - 若存在稳定官方直链或 `winget` 包则优先；否则保留本地兜底安装包

## 8. 配置策略

### 8.1 API 输入

安装脚本运行时交互采集：

- `Provider Name`
- `Base URL`
- `API Key`
- 可选默认模型名

输入要求：

- `API Key` 用 `Read-Host -AsSecureString` 或等效安全输入方式采集。
- 在日志中只记录“已填写”，不记录明文。

### 8.2 自动写入 cc-switch

优先级方案：

1. 如果 `cc-switch` 有稳定 CLI / 导入文件格式 / 官方配置文件结构，则脚本直接写入。
2. 如果没有稳定 API，但配置文件结构明确，则脚本在备份后修改配置文件。
3. 如果配置结构不稳定，则退化为：
   - 生成一个待导入配置文件
   - 自动打开 `cc-switch`
   - 给用户明确提示进行最后一次点击确认

这里是本项目最大技术风险，实施前必须单独验证：

- `cc-switch` 的配置文件路径
- provider 的序列化结构
- 写入后是否需要重启应用
- 应用启动后是否会覆盖外部修改

### 8.3 自动安装本地 skill

优先路径：

1. 若 `skills-manager` 支持 CLI 安装本地目录或 zip，则直接调用 CLI。
2. 若仅支持读取本地目录，则脚本自动解压 `skills.zip` 到约定目录后执行导入。
3. 若必须经 GUI 导入，则脚本完成文件放置和应用启动，引导用户最后一步点击导入。

## 9. GitHub 项目建议

建议直接做成 GitHub 项目，原因：

- 方便同事始终下载最新脚本，而不是你手工发散装文件。
- 方便把“安装逻辑”和“资产清单”分离。
- 后续可以用 GitHub Actions 做：
  - PowerShell lint
  - 基础脚本测试
  - 版本来源连通性检查
  - Release 打包
- 可以把敏感信息完全排除在仓库之外，只保留交互输入逻辑。

建议仓库形态：

- 如果同事都能访问：公开仓库即可。
- 如果不希望暴露工具组合与内部说明：私有仓库更稳。

## 10. 实施阶段

### Phase 1：技术探针（Spike）

目标：验证最不确定的两个点。

- 验证 `cc-switch` 是否支持稳定自动写入 provider。
- 验证 `skills-manager` 是否支持非 GUI 的本地 skill 安装。

产出：

- 两个最小复现脚本
- 一份配置路径与导入方式说明

### Phase 2：基础安装器

目标：先打通安装，不处理高级配置。

- 建立 GitHub 项目结构
- 实现公共日志与下载模块
- 实现 `winget` 安装路径
- 实现 GitHub Release 下载路径
- 实现静默安装与版本校验

### Phase 3：后置配置

目标：把“可用”推进到“可直接用”。

- 交互收集 API 信息
- 备份并写入 `cc-switch`
- 解压并安装本地 skill
- 生成安装完成摘要

### Phase 4：分发与升级

目标：降低你后续维护成本。

- 加 `README.md`
- 加 `config.example.json`
- 加 GitHub Release
- 可选加一个 `bootstrap.cmd`，让同事双击即可调用 PowerShell

## 11. 实施清单（Checklist）

- [ ] 建立 GitHub 仓库
- [ ] 创建 `bootstrap.ps1`
- [ ] 创建 `apps.json`
- [ ] 实现公共函数：日志、下载、版本比较、管理员检测、重试
- [ ] 实现 `winget` 安装适配器
- [ ] 实现 GitHub Release 解析适配器
- [ ] 实现 `Git` / `Node.js` / `Python` / `VS Code` / `Codex` 安装模块
- [ ] 实现 `ChatGPT` / `CC-Switch` / `skills-manager` 安装模块
- [ ] 研究并固定 `cc-switch` 配置写入方案
- [ ] 研究并固定 `skills-manager` 本地 skill 导入方案
- [ ] 完成 `skills.zip` 解压与安装逻辑
- [ ] 增加日志目录和失败摘要
- [ ] 编写同事使用文档
- [ ] 在干净 Windows 环境验证完整流程

## 12. 验证策略

先窄后宽：

1. 单模块验证
   - 每个安装器单独执行一次
   - 验证退出码、版本、可执行文件路径
2. 配置验证
   - 验证 `cc-switch` 中 provider 是否出现
   - 验证 API 测试请求是否可通
   - 验证 `skills-manager` 中 skill 是否可见
3. 端到端验证
   - 在一台干净 Windows 虚拟机或 Sandbox 跑完整流程
4. 重跑验证
   - 在同一机器重复执行一次，确认不会重复破坏安装

推荐验证环境：

- Windows Sandbox
- Hyper-V / VMware / VirtualBox 干净镜像

## 13. 回滚说明（Rollback）

- 所有下载文件落临时目录，不覆盖仓库文件。
- 所有配置改写前先备份原文件到 `backup/<timestamp>/`。
- 某个工具安装失败时，只中断当前工具，保留已成功安装项并输出失败清单。
- `cc-switch` 配置写坏时，允许一键恢复备份文件。

## 14. 风险点

最高风险：

- `cc-switch` 的配置结构可能版本变动快，直接改配置文件有回归风险。
- `skills-manager` 的本地 skill 导入能力如果缺少稳定 CLI，自动化会受限。

中风险：

- `winget` 在某些新装系统中注册未完成，需要补注册或等待 App Installer。
- GitHub Release 命名规则变化会导致资产匹配失败。
- 某些 EXE 安装器静默参数不一致，需逐个确认。

低风险：

- PowerShell 执行策略限制，可通过 `Set-ExecutionPolicy` 提示或 `-ExecutionPolicy Bypass` 入口解决。

## 15. 建议的下一步

下一会话应只做 Phase 1 的技术探针，不直接铺开全量实现。

建议顺序：

1. 先验证 `cc-switch` 的 provider 自动写入方案。
2. 再验证 `skills-manager` 的本地 skill 自动安装方案。
3. 两者都确认后，再开始写安装器主干。

如果其中任一项自动化不可控，则调整策略为：

- 安装自动化
- 配置半自动化（生成配置 + 自动打开应用 + 明确提示用户完成最后一步）

这个降级路线仍然是可交付的，而且比一开始追求“100% 全自动”更稳。
