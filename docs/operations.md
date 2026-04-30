# 运行命令

## 本地仓库运行

本地手动装机直接进入拟似 TUI，可用方向键选择运行模式、应用和安装选项：

```powershell
Set-Location "C:\Vibe_Coding\IndieArk\gadget\vibe-coding-setup"
.\bootstrap.cmd
```

无安装参数时会先进入 TUI；“默认安装（原来模式）”已经包含在 TUI 里，选择后仍按原脚本流程安装全部应用、导入 Skill 和 CC Switch。

```powershell
.\bootstrap.cmd -Tui
```

`-Tui` 可在已有参数场景下强制打开 TUI。自动化或旧式命令继续直接传参数，例如 `.\bootstrap.cmd -Only git,nodejs`。

`bootstrap.cmd` 使用 Windows PowerShell 5.1 启动。如果过程中触发 UAC 提权，新开的管理员窗口会在执行完成后保持打开，方便查看 summary 或错误。

## 远程自举

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root='https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'; $script=Join-Path $env:TEMP 'vibe-bootstrap.ps1'; iwr ($root + '/bootstrap.ps1') -OutFile $script; & $script -BootstrapSourceRoot $root -RefreshBootstrapDependencies"
```

这个命令下载 `bootstrap.ps1`，再由脚本自己同步 `modules/common.psm1` 和 `manifest/apps.json`。

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

显式导入全部 Skill：

```powershell
.\bootstrap.cmd -AllSkills
```

只做演练，不改系统：

```powershell
.\bootstrap.cmd -DryRun
```

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
