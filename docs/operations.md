# 运行命令

## 本地仓库运行

本地手动装机直接进入拟似 TUI，可用方向键选择运行模式、应用和安装选项：

```powershell
Set-Location "C:\Vibe_Coding\IndieArk\gadget\vibe-coding-setup"
.\bootstrap.cmd
```

无安装参数时会先进入 TUI；“默认安装（原来模式）”已经包含在 TUI 里，选择后不再改写为 `-Only`，而是直接继续原脚本默认流程：安装默认全量应用、导入 Skill 和 CC Switch。

```powershell
.\bootstrap.cmd -Tui
```

`-Tui` 可在已有参数场景下强制打开 TUI。自动化或旧式命令继续直接传参数，例如 `.\bootstrap.cmd -Only git,nodejs`。

TUI 自定义模式包含三类选择：

- 应用复选：选择本次要安装或检查的应用。
- 安装复选项：演练、跳过 CC Switch、跳过 Skill、保留旧 Skill 等。
- Skill 复选项：默认“全部 Skill”，也可按 Profile 选择一个或多个 Skill 套件。

`bootstrap.cmd` 使用 Windows PowerShell 5.1 启动。如果过程中触发 UAC 提权，当前窗口只提示已打开管理员窗口继续安装；脚本会优先用 Windows Terminal 承载管理员 PowerShell，避免经典蓝底 PowerShell 窗口。若系统没有 `wt.exe`，才回退到经典 PowerShell 窗口。新开的管理员终端会继续后续 TUI 或安装流程，并在执行完成后保持打开，方便查看 summary 或错误。

总进度使用简洁文字，例如 `[3/10] 准备安装应用：Node.js (2/9)`；应用内部进度才使用自绘进度条，例如下载和 winget 百分比会显示 `下载 ██████░░░░░░░░░░░░░░ 30%`。静默安装器无法读取真实百分比时，只显示运行中和耗时。脚本不调用 PowerShell `Write-Progress`，避免宿主额外绘制独立进度区域。

进入 TUI 前，脚本会尽量把当前进程输入布局切到英文键盘，减少中文输入法干扰快捷键。这个动作受 Windows 当前会话和输入法设置影响，失败不会阻断安装。

默认安装模式进入 UAC 后不会再次显示 TUI，也不会把应用清单拆成多个位置参数；自定义选择和安全演练才会生成显式命令预览。如果你显式用 `.\bootstrap.cmd -Tui -DryRun` 这类命令进入 TUI，选择默认安装后仍会保留这些命令参数。

## 远程自举

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

这个命令下载 `bootstrap.ps1`，再由脚本自己同步 `modules/common.psm1` 和 `manifest/apps.json`。

远程入口会传入 `BootstrapSourceRoot`、`BootstrapAssetsRepo`、`BootstrapAssetsTag`、`RefreshBootstrapDependencies` 等自举内部参数。这些参数不算安装选择；如果没有 `-Only`、`-DryRun`、`-SkipSkills` 等操作参数，脚本仍会进入 TUI。

## 常用参数

只安装部分工具：

```powershell
.\bootstrap.cmd -Only git,nodejs,python,vscode,codex
```

跳过 Skill 导入：

```powershell
.\bootstrap.cmd -SkipSkills
```

跳过 `CC Switch` Provider 导入：

```powershell
.\bootstrap.cmd -SkipCcSwitch
```
按 Profile 导入 Skill：

```powershell
.\bootstrap.cmd -SkillProfile "飞书办公套件"
```

多个 Profile（英文逗号、中文逗号和顿号都可解析）：

```powershell
.\bootstrap.cmd -SkillProfile "飞书办公套件","前端开发套件"
```

显式导入全部 Skill：

```powershell
.\bootstrap.cmd -AllSkills
```

只做演练，不改系统：

```powershell
.\bootstrap.cmd -DryRun
```

命令模式默认行为：

- 未传 `-SkipSkills` 时会导入 Skill。
- 未传 `-SkillProfile` 且未传 `-AllSkills` 时，交互式终端会提示选择 Profile；非交互式环境默认导入全部 Skill。
- 传 `-SkipSkills` 会完全跳过 Skill 导入。
- 传 `-SkipCcSwitch` 会跳过 CC Switch Provider 导入。

执行开始后，日志会先输出“选中的安装应用清单”，再按 `[当前/总数]` 显示工作区、应用、Skill 和 CC Switch Provider 阶段进度。

## Skill 安全演练

推荐先跑这条，观察本机三态判定，不替换旧目录、不拉起 UI：

```powershell
.\bootstrap.cmd -DryRun -SkipCcSwitch -Only git -SkillProfile "飞书办公套件" -NoReplaceOrphan -SkipSkillsManagerLaunch
```

## 三态策略参数

```powershell
.\bootstrap.cmd -NoReplaceOrphan
.\bootstrap.cmd -ReplaceForeign
.\bootstrap.cmd -RenameForeign
.\bootstrap.cmd -SkipSkillsManagerLaunch
```

详细语义见 [`skill-import.md`](skill-import.md)。
