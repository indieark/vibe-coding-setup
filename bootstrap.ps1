[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Only,
    [switch]$SkipCcSwitch,
    [switch]$SkipApps,
    [switch]$SkipSkills,
    [string[]]$SkillProfile,
    [string[]]$SkillName,
    [string[]]$McpName,
    [string[]]$CliName,
    [switch]$AllSkills,
    [switch]$AllSuites,
    [switch]$NoReplaceOrphan,
    [switch]$ReplaceForeign,
    [switch]$RenameForeign,
    [switch]$SkipSkillsManagerLaunch,
    [ValidateSet('prompt', 'default', 'custom', 'skip')]
    [string]$SkillsManagerScenarioMode = 'prompt',
    [string]$SkillsManagerScenarioName,
    [switch]$Tui,
    [switch]$PauseOnExit,
    [switch]$KeepShellOpen,
    [string]$UserHomeOverride,
    [string]$CcSwitchProviderName,
    [string]$CcSwitchBaseUrl,
    [string]$CcSwitchModel,
    [string]$CcSwitchApiKey,
    [string]$BootstrapSourceRoot,
    [string]$BootstrapAssetsRepo = 'indieark/vibe-coding-setup',
    [string]$BootstrapAssetsTag = 'bootstrap-assets',
    [switch]$RefreshBootstrapDependencies,
    [switch]$BootstrapTuiResolved
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:BootstrapAdminHandoffStarted = $false
$script:BootstrapUserCancelled = $false
$script:BootstrapProgressLastLineLength = 0

function ConvertFrom-BootstrapUtf8Base64String {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function ConvertTo-DisplaySource {
    param(
        [string]$Source
    )

    switch -Regex ($Source) {
        '^filesystem$' { return (ConvertFrom-BootstrapUtf8Base64String -Value '5paH5Lu257O757uf') }
        '^precheck-skip$' { return (ConvertFrom-BootstrapUtf8Base64String -Value '6aKE5qOA5p+l6Lez6L+H') }
        '^winget$' { return 'winget' }
        '^winget-fallback$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'd2luZ2V0IOWbnumAgA==') }
        '^release-fallback$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'UmVsZWFzZSDlm57pgIA=') }
        '^uri-fallback$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'VVJJIOWbnumAgA==') }
        '^release-asset$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'UmVsZWFzZSDotYTkuqc=') }
        '^github-latest-tag$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'R2l0SHViIGxhdGVzdCB0YWc=') }
        '^github-release$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'R2l0SHViIFJlbGVhc2U=') }
        '^direct-url$' { return (ConvertFrom-BootstrapUtf8Base64String -Value '55u06ZO+5LiL6L29') }
        '^local-zip$' { return (ConvertFrom-BootstrapUtf8Base64String -Value '5pys5ZywIHppcA==') }
        '^ccswitch-deeplink$' { return (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIOWvvOWFpQ==') }
        'postcheck$' { return (ConvertFrom-BootstrapUtf8Base64String -Value '6aKE5qOA5p+l5oGi5aSN') }
        default {
            if ([string]::IsNullOrWhiteSpace($Source)) {
                return (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq55+l5p2l5rqQ')
            }
            return $Source
        }
    }
}

function ConvertTo-BootstrapDisplayStatus {
    param(
        [string]$Status
    )

    if ($Status -eq 'failed') {
        return (ConvertFrom-BootstrapUtf8Base64String -Value '5aSx6LSl')
    }

    return (ConvertFrom-BootstrapUtf8Base64String -Value '5oiQ5Yqf')
}

function Write-BootstrapProgress {
    param(
        [Parameter(Mandatory)]
        [int]$CompletedSteps,
        [Parameter(Mandatory)]
        [int]$TotalSteps,
        [Parameter(Mandatory)]
        [string]$Status,
        [switch]$Completed
    )

    if ($TotalSteps -le 0) {
        return
    }

    $safeCompleted = if ($Completed) { $TotalSteps } else { [Math]::Min($TotalSteps, [Math]::Max(0, $CompletedSteps + 1)) }

    Write-Host ('[{0}/{1}] {2}' -f $safeCompleted, $TotalSteps, $Status) -ForegroundColor Cyan
}

function Write-BootstrapMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ('[bootstrap] {0}' -f $Message)
}

function Write-BootstrapSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [string]$Detail
    )

    $sectionRenderedVariable = Get-Variable -Name 'BootstrapSectionRendered' -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $sectionRenderedVariable -and [bool]$sectionRenderedVariable.Value) {
        Write-Host ''
        Write-Host ''
    }
    else {
        Write-Host ''
        $script:BootstrapSectionRendered = $true
    }
    Write-Host ('== {0} ==' -f $Title) -ForegroundColor Cyan
    Write-Host ('-' * 64) -ForegroundColor DarkGray
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        Write-Host ('  {0}' -f $Detail) -ForegroundColor DarkGray
    }
}

function Test-BootstrapProgressRendering {
    try {
        return ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected)
    }
    catch {
        return $false
    }
}

function Write-BootstrapProgressLine {
    param(
        [Parameter(Mandatory)]
        [string]$Line,
        [switch]$Completed,
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::Cyan
    )

    $canRenderInPlace = Test-BootstrapProgressRendering
    if (-not $canRenderInPlace) {
        if ($Completed) {
            Write-Host $Line -ForegroundColor $ForegroundColor
        }
        return
    }

    $clearLength = [Math]::Max(0, $script:BootstrapProgressLastLineLength - $Line.Length)
    $script:BootstrapProgressLastLineLength = $Line.Length
    $displayLine = if ($clearLength -gt 0) { $Line + (' ' * $clearLength) } else { $Line }

    if ($Completed) {
        Write-Host ("`r{0}" -f $displayLine) -ForegroundColor $ForegroundColor
        $script:BootstrapProgressLastLineLength = 0
    }
    else {
        Write-Host ("`r{0}" -f $displayLine) -ForegroundColor $ForegroundColor -NoNewline
    }
}

function Get-CurrentPowerShellExecutable {
    try {
        $currentProcess = Get-Process -Id $PID -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($currentProcess.Path)) {
            return $currentProcess.Path
        }
    }
    catch {
    }

    return 'powershell.exe'
}

function Get-WindowsTerminalExecutable {
    $wtCommand = Get-Command 'wt.exe' -ErrorAction SilentlyContinue
    if ($wtCommand -and -not [string]::IsNullOrWhiteSpace($wtCommand.Source)) {
        return $wtCommand.Source
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $windowsAppsPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
        if (Test-Path -LiteralPath $windowsAppsPath) {
            return $windowsAppsPath
        }
    }

    return $null
}

function Set-BootstrapEnglishInputLayout {
    try {
        if (-not ('BootstrapKeyboardLayout' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class BootstrapKeyboardLayout
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);

    [DllImport("user32.dll")]
    public static extern IntPtr ActivateKeyboardLayout(IntPtr hkl, uint Flags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam);
}
'@
        }

        $klfActivate = 0x00000001
        $klfSubstituteOk = 0x00000002
        $klfReorder = 0x00000008
        $klfSetForProcess = 0x00000100
        $wmInputLangChangeRequest = 0x0050
        $inputLangChangeSysCharset = [UIntPtr]::new(0x0001)

        $englishLayout = [BootstrapKeyboardLayout]::LoadKeyboardLayout('00000409', ($klfActivate -bor $klfSubstituteOk -bor $klfReorder -bor $klfSetForProcess))
        if ($englishLayout -ne [IntPtr]::Zero) {
            [void][BootstrapKeyboardLayout]::ActivateKeyboardLayout($englishLayout, ($klfReorder -bor $klfSetForProcess))

            $foregroundWindow = [BootstrapKeyboardLayout]::GetForegroundWindow()
            if ($foregroundWindow -ne [IntPtr]::Zero) {
                [void][BootstrapKeyboardLayout]::PostMessage($foregroundWindow, $wmInputLangChangeRequest, $inputLangChangeSysCharset, $englishLayout)
            }
        }
    }
    catch {
    }
}

function Start-BootstrapElevatedShell {
    param(
        [Parameter(Mandatory)]
        [string[]]$PowerShellArguments
    )

    $terminalExe = Get-WindowsTerminalExecutable
    if ($terminalExe) {
        $terminalArguments = New-Object System.Collections.Generic.List[string]
        $terminalArguments.Add('-d')
        $terminalArguments.Add(('"{0}"' -f (Get-Location).Path))
        $terminalArguments.Add('powershell.exe')
        foreach ($argument in $PowerShellArguments) {
            $terminalArguments.Add($argument)
        }

        try {
            Start-Process -FilePath $terminalExe -Verb RunAs -ArgumentList $terminalArguments.ToArray() | Out-Null
            return
        }
        catch {
            Write-BootstrapMessage ((ConvertFrom-BootstrapUtf8Base64String -Value 'V2luZG93cyBUZXJtaW5hbCDmj5DmnYMg5ZCv5Yqo5aSx6LSl77yM5Zue6YCA5Yiw57uP5YW4IFBvd2VyU2hlbGw77yaezB9') -f $_.Exception.Message)
        }
    }

    Start-Process -FilePath (Get-CurrentPowerShellExecutable) -Verb RunAs -ArgumentList $PowerShellArguments | Out-Null
}

function Get-OriginalUserHomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($UserHomeOverride)) {
        return $UserHomeOverride
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }

    return $HOME
}

function Invoke-BootstrapExit {
    param(
        [Parameter(Mandatory)]
        [int]$Code
    )

    if ($script:BootstrapUserCancelled) {
        exit $Code
    }

    if ($KeepShellOpen) {
        Write-Host ''
        if ($script:BootstrapAdminHandoffStarted) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5omT5byA566h55CG5ZGY56qX5Y+j57un57ut5a6J6KOF44CC6L+Z5Liq56qX5Y+j5Y+v5Lul5YWz6Zet77yb6K+35Zyo566h55CG5ZGY56qX5Y+j5Lit5p+l55yL5ZCO57ut6L+b5bqm44CC')
        }
        elseif ($script:BootstrapUserCancelled) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5Y+W5raI44CC56qX5Y+j5bCG5L+d5oyB5omT5byA77yM5Y+v5omL5Yqo5YWz6Zet44CC')
        }
        elseif ($Code -eq 0) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bey5a6M5oiQ44CC566h55CG5ZGY56qX5Y+j5Lya5L+d5oyB5omT5byA77yM56Gu6K6k6L6T5Ye65ZCO5Y+v5omL5Yqo5YWz6Zet44CC')
        }
        else {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF57uT5p2f5L2G5a2Y5Zyo6ZSZ6K+v44CC566h55CG5ZGY56qX5Y+j5Lya5L+d5oyB5omT5byA77yM6K+35qOA5p+l6L6T5Ye65ZCO5omL5Yqo5YWz6Zet44CC')
        }

        $global:LASTEXITCODE = $Code
        return
    }

    if ($PauseOnExit) {
        Write-Host ''
        if ($script:BootstrapAdminHandoffStarted) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5omT5byA566h55CG5ZGY56qX5Y+j57un57ut5a6J6KOF44CC5b2T5YmN56qX5Y+j5bCG5ZyoIDMg56eS5ZCO6Ieq5Yqo5YWz6ZetLi4u')
            Start-Sleep -Seconds 3
            exit $Code
        }
        elseif ($script:BootstrapUserCancelled) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5Y+W5raI44CC5oyJ5Lu75oSP6ZSu5YWz6Zet56qX5Y+jLi4u')
        }
        else {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bey5a6M5oiQ44CC5oyJ5Lu75oSP6ZSu5YWz6Zet56qX5Y+jLi4u')
        }
        try {
            [void][System.Console]::ReadKey($true)
        }
        catch {
            try {
                & cmd.exe /d /c 'pause >nul'
            }
            catch {
                [void](Read-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJIEVudGVyIOWFs+mXreeql+WPow=='))
            }
        }
    }

    exit $Code
}

function Test-HttpSourceRoot {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot
    )

    return $SourceRoot -match '^https?://'
}

function Ensure-BootstrapDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Join-BootstrapSourcePath {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    if (Test-HttpSourceRoot -SourceRoot $SourceRoot) {
        $trimmedRoot = $SourceRoot.TrimEnd('/')
        $normalizedRelative = $RelativePath.Replace('\', '/')
        return '{0}/{1}' -f $trimmedRoot, $normalizedRelative
    }

    return Join-Path $SourceRoot $RelativePath
}

function Get-BootstrapReleaseAssetUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$AssetName
    )

    return 'https://github.com/{0}/releases/download/{1}/{2}' -f $Repo, $Tag, $AssetName
}

function Write-BootstrapDownloadProgress {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [int]$Percent,
        [Parameter(Mandatory)]
        [string]$Detail,
        [switch]$Completed
    )

    $safePercent = [Math]::Min(100, [Math]::Max(0, $Percent))
    $width = 20
    $filled = [int][Math]::Round(($safePercent / 100) * $width)
    $empty = $width - $filled
    $filledChar = [char]0x2588
    $emptyChar = [char]0x2591
    $bar = (([string]$filledChar) * $filled) + (([string]$emptyChar) * $empty)
    $line = ('[bootstrap] {0} [{1}] {2,3}% {3}' -f $Label, $bar, $safePercent, $Detail)
    Write-BootstrapProgressLine -Line $line -Completed:$Completed
}

function Invoke-BootstrapDownloadFile {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$OutFile
    )

    Ensure-BootstrapDirectory -Path (Split-Path -Parent $OutFile)
    $response = $null
    $inputStream = $null
    $outputStream = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.AllowAutoRedirect = $true
        $request.UserAgent = 'VibeCodingSetup/1.0'
        $response = $request.GetResponse()
        $totalBytes = [int64]$response.ContentLength
        $inputStream = $response.GetResponseStream()
        $outputStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $buffer = New-Object byte[] 1048576
        $downloadedBytes = [int64]0
        $lastProgressPercent = -1
        $detail = Split-Path -Leaf $OutFile
        $downloadLabel = ConvertFrom-BootstrapUtf8Base64String -Value '5LiL6L29'

        do {
            $readBytes = $inputStream.Read($buffer, 0, $buffer.Length)
            if ($readBytes -gt 0) {
                $outputStream.Write($buffer, 0, $readBytes)
                $downloadedBytes += $readBytes

                if ($totalBytes -gt 0) {
                    $progressPercent = [int](($downloadedBytes * 100) / $totalBytes)
                    if ($progressPercent -lt 100 -and $progressPercent -ge ($lastProgressPercent + 5)) {
                        Write-BootstrapDownloadProgress -Label $downloadLabel -Percent $progressPercent -Detail $detail
                        $lastProgressPercent = $progressPercent
                    }
                }
            }
        } while ($readBytes -gt 0)

        Write-BootstrapDownloadProgress -Label $downloadLabel -Percent 100 -Detail $detail -Completed
    }
    finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

function Copy-BootstrapDependency {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    $destinationDir = Split-Path -Parent $destinationPath
    Ensure-BootstrapDirectory -Path $destinationDir

    if ((-not $Refresh) -and (Test-Path -LiteralPath $destinationPath)) {
        return
    }

    $sourcePath = Join-BootstrapSourcePath -SourceRoot $SourceRoot -RelativePath $RelativePath
    Write-BootstrapMessage ((ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6I635Y+W6Ieq5Li+5L6d6LWW77yaezB9') -f $RelativePath)

    if (Test-HttpSourceRoot -SourceRoot $SourceRoot) {
        Invoke-BootstrapDownloadFile -Uri $sourcePath -OutFile $destinationPath
        return
    }

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw ((ConvertFrom-BootstrapUtf8Base64String -Value '5om+5LiN5Yiw6Ieq5Li+5L6d6LWW5rqQ5paH5Lu277yaezB9') -f $sourcePath)
    }

    $resolvedSourcePath = (Resolve-Path -LiteralPath $sourcePath).Path
    $resolvedDestinationPath = if (Test-Path -LiteralPath $destinationPath) {
        (Resolve-Path -LiteralPath $destinationPath).Path
    }
    else {
        [IO.Path]::GetFullPath($destinationPath)
    }

    if ($resolvedSourcePath -eq $resolvedDestinationPath) {
        Write-BootstrapMessage ((ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5Li+5L6d6LWW5bey5bCx57uq77yaezB9') -f $RelativePath)
        return
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

function Copy-BootstrapReleaseAsset {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [Parameter(Mandatory)]
        [string]$AssetName,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    $destinationDir = Split-Path -Parent $destinationPath
    Ensure-BootstrapDirectory -Path $destinationDir

    if ((-not $Refresh) -and (Test-Path -LiteralPath $destinationPath)) {
        Write-BootstrapMessage ((ConvertFrom-BootstrapUtf8Base64String -Value '5L2/55So5bey57yT5a2Y55qEIFJlbGVhc2Ug6LWE5Lqn77yaezB9') -f $RelativePath)
        return
    }

    $url = Get-BootstrapReleaseAssetUrl -Repo $Repo -Tag $Tag -AssetName $AssetName
    Write-BootstrapMessage ((ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6I635Y+WIFJlbGVhc2Ug6LWE5Lqn77yaezB9') -f $RelativePath)
    Invoke-BootstrapDownloadFile -Uri $url -OutFile $destinationPath
}

function Sync-BootstrapSkillBundleAsset {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    Copy-BootstrapReleaseAsset `
        -Repo $Repo `
        -Tag $Tag `
        -DestinationRoot $DestinationRoot `
        -RelativePath 'downloads/skills.zip' `
        -AssetName 'skills.zip' `
        -Refresh:$Refresh
}

function Sync-BootstrapDependencies {
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [string[]]$Dependencies,
        [switch]$Refresh
    )

    $shouldRefresh = $Refresh.IsPresent -or (Test-HttpSourceRoot -SourceRoot $SourceRoot)
    foreach ($relativePath in $Dependencies) {
        Copy-BootstrapDependency `
            -SourceRoot $SourceRoot `
            -DestinationRoot $DestinationRoot `
            -RelativePath $relativePath `
            -Refresh:$shouldRefresh
    }
}

$script:TuiFrameInitialized = $false
$script:TuiFrameLastLineCount = 0

function Start-TuiFrame {
    if ([Console]::IsOutputRedirected) {
        Clear-Host
        return
    }

    try {
        if (-not $script:TuiFrameInitialized) {
            Clear-Host
            $script:TuiFrameInitialized = $true
        }
        [Console]::CursorVisible = $false
        [Console]::SetCursorPosition(0, 0)
    }
    catch {
        Clear-Host
    }
}

function Complete-TuiFrame {
    if ([Console]::IsOutputRedirected) {
        return
    }

    try {
        $currentTop = [Console]::CursorTop
        $previousTop = [int]$script:TuiFrameLastLineCount
        if ($previousTop -gt $currentTop) {
            $width = [Math]::Max(1, [Console]::BufferWidth - 1)
            $blank = ' ' * $width
            for ($line = $currentTop; $line -lt $previousTop; $line++) {
                if ($line -ge [Console]::BufferHeight) {
                    break
                }
                [Console]::SetCursorPosition(0, $line)
                [Console]::Write($blank)
            }
        }
        $script:TuiFrameLastLineCount = $currentTop
        [Console]::SetCursorPosition(0, [Math]::Min($currentTop, [Console]::BufferHeight - 1))
        [Console]::CursorVisible = $true
    }
    catch {
    }
}

function Write-TuiHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [switch]$ShowIntro
    )

    Start-TuiFrame
    Write-Host ('+ {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'VmliZSBDb2RpbmcgU2V0dXA=')) -ForegroundColor Cyan
    Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '546w5Luj5YyW5o6n5Yi25Y+w5a6J6KOF5ZCR5a+8')) -ForegroundColor DarkGray
    if ($ShowIntro) {
        Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5qC45b+D5Yqf6IO977ya5LiA6ZSu5a6J6KOF57u05oqkIFZpYmUgQ29kaW5nIOeOr+Wigw==')) -ForegroundColor DarkGray
        Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5YW35L2T6IO95Yqb77ya5qOA5p+l5a6J6KOF5LiO5pu05paw5bqU55So44CB5a+85YWlIENDIFN3aXRjaOOAgemFjee9riBTa2lsbCDlpZfku7bjgIFNQ1Ag5LiOIENMSeOAgg==')) -ForegroundColor DarkGray
        Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5LuT5bqT5Zyw5Z2A77yaaHR0cHM6Ly9naXRodWIuY29tL2luZGllYXJrL3ZpYmUtY29kaW5nLXNldHVw')) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ('-' * 64) -ForegroundColor DarkGray
}

function Write-TuiSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [string]$Detail
    )

    Write-Host ''
    Write-Host ('[{0}]' -f $Title) -ForegroundColor Cyan
    Write-Host ('-' * 64) -ForegroundColor DarkGray
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        Write-Host $Detail -ForegroundColor DarkGray
        Write-Host ''
    }
}

function Write-TuiLoading {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Detail
    )

    Write-TuiHeader -Title $Title
    Write-Host $Message -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        Write-Host $Detail -ForegroundColor DarkGray
    }
}

function New-TuiOption {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string]$SwitchName,
        [bool]$Enabled = $false
    )

    return [pscustomobject]@{
        Key        = $Key
        Label      = $Label
        SwitchName = $SwitchName
        Enabled    = $Enabled
    }
}

function New-TuiOptionForSwitch {
    param(
        [Parameter(Mandatory)]
        [string]$SwitchName
    )

    switch ($SwitchName) {
        'DryRun' { return (New-TuiOption -Key 'dryrun' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD5qih5byP77yI5LiN55yf5q2j5a6J6KOF77yJ') -SwitchName 'DryRun' -Enabled $true) }
        'SkipCcSwitch' { return (New-TuiOption -Key 'skipcc' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIENDIFN3aXRjaCBQcm92aWRlciDlr7zlhaU=') -SwitchName 'SkipCcSwitch' -Enabled $true) }
        'NoReplaceOrphan' { return (New-TuiOption -Key 'noorphan' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5penIFNraWxsIOebruW9leS4jeabv+aNou+8jOWPqui3s+i/hw==') -SwitchName 'NoReplaceOrphan' -Enabled $true) }
        'ReplaceForeign' { return (New-TuiOption -Key 'replaceforeign' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '56ys5LiJ5pa55ZCM5ZCNIFNraWxsIOWFgeiuuOWkh+S7veabv+aNog==') -SwitchName 'ReplaceForeign' -Enabled $true) }
        'RenameForeign' { return (New-TuiOption -Key 'renameforeign' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '56ys5LiJ5pa55ZCM5ZCNIFNraWxsIOaUueWQjeS4uiAtaW5kaWVhcmsg5a+85YWl') -SwitchName 'RenameForeign' -Enabled $true) }
        'SkipSkillsManagerLaunch' { return (New-TuiOption -Key 'skipmanager' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWlIFNraWxsIOWQjuS4jeiHquWKqOWQr+WKqCBTa2lsbHMgTWFuYWdlcg==') -SwitchName 'SkipSkillsManagerLaunch' -Enabled $true) }
        'RefreshBootstrapDependencies' { return (New-TuiOption -Key 'refresh' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5Yi35paw6Ieq5Li+5L6d6LWW5ZKM6LWE5Lqn') -SwitchName 'RefreshBootstrapDependencies' -Enabled $true) }
        default { return (New-TuiOption -Key $SwitchName.ToLowerInvariant() -Label $SwitchName -SwitchName $SwitchName -Enabled $true) }
    }
}

function New-TuiModeOption {
    param(
        [Parameter(Mandatory)]
        [string]$Mode,
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string]$Detail
    )

    return [pscustomobject]@{
        Mode   = $Mode
        Label  = $Label
        Detail = $Detail
    }
}

function Show-TuiModeSelection {
    $modes = @(
        New-TuiModeOption `
            -Mode 'original' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6buY6K6k5a6J6KOF') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ6buY6K6k6YWN572u5a6J6KOF5bqU55So77yM5bm25a+85YWlIFNraWxsIOS4jiBDQyBTd2l0Y2jjgII=')
        New-TuiModeOption `
            -Mode 'workbench' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5qih5byP') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6L+b5YWl6Ieq5a6a5LmJ5bel5L2c5Y+w77ya5qOA5p+l54q25oCB44CB5a6J6KOF5oiW5pu05paw6L2v5Lu244CB6YCJ5oupIFNraWxsIC8gTUNQIC8gQ0xJ44CC')
        New-TuiModeOption `
            -Mode 'dryrun' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J5YWo5ryU57uD') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YeP5ryU57uD77yM5LiN5a+85YWlIENDIFN3aXRjaO+8jOS4jeabv+aNouaXpyBTa2lsbO+8jOS4jeWQr+WKqCBTa2lsbHMgTWFuYWdlcu+8jOW5tum7mOiupOmAieaLqeWFqOmDqCBTa2lsbOOAgg==')
    )

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup6L+Q6KGM5qih5byP') -ShowIntro
        for ($i = 0; $i -lt $modes.Count; $i++) {
            $mode = $modes[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $mode.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $mode.Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgUSDpgIDlh7o=') -ForegroundColor DarkGray

        Complete-TuiFrame

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($modes.Count - 1)) { $index++ } }
            'Enter' { return $modes[$index].Mode }
            'Q' { return $null }
        }
    }
}

function New-TuiWorkbenchAction {
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string]$Detail
    )

    return [pscustomobject]@{
        Action = $Action
        Label  = $Label
        Detail = $Detail
    }
}

function Get-TuiAppDecisionText {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Decision
    )

    return Get-BootstrapAppDecisionModeText -Decision $Decision
}

function Get-BootstrapAppDecisionModeText {
    param(
        [AllowNull()]
        [pscustomobject]$Decision,
        [switch]$Failed
    )

    if ($Failed) {
        return ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5aSx6LSl'
    }

    if ($null -eq $Decision) {
        return ConvertFrom-BootstrapUtf8Base64String -Value '6ZyA6KaB56Gu6K6k'
    }

    if ($Decision.Action -eq 'skip') {
        return ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H'
    }

    if ($Decision.Reason -eq 'outdated') {
        return ConvertFrom-BootstrapUtf8Base64String -Value '5pu05paw'
    }

    if ($Decision.Action -eq 'install') {
        return ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF'
    }

    return ConvertFrom-BootstrapUtf8Base64String -Value '6ZyA6KaB56Gu6K6k'
}

function Write-BootstrapAppPlan {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps,
        [Parameter(Mandatory)]
        [hashtable]$PrecheckByKey
    )

    $installCount = 0
    $updateCount = 0
    $skipCount = 0
    $failedCount = 0
    $appsToDisplay = New-Object System.Collections.Generic.List[object]

    foreach ($app in ($Apps | Sort-Object order)) {
        $precheck = $PrecheckByKey[[string]$app.key]
        $failed = ($null -ne $precheck -and $precheck.Status -eq 'failed')
        $decision = if ($null -ne $precheck) { $precheck.Decision } else { $null }
        $mode = Get-BootstrapAppDecisionModeText -Decision $decision -Failed:$failed

        if ($failed) {
            $failedCount++
        }
        elseif ($null -ne $decision -and $decision.Action -eq 'skip') {
            $skipCount++
        }
        elseif ($null -ne $decision -and $decision.Reason -eq 'outdated') {
            $updateCount++
            [void]$appsToDisplay.Add([pscustomobject]@{
                    App  = $app
                    Mode = $mode
                })
        }
        else {
            $installCount++
            [void]$appsToDisplay.Add([pscustomobject]@{
                    App  = $app
                    Mode = $mode
                })
        }
    }

    if ($appsToDisplay.Count -gt 0) {
        Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5YeG5aSH5a6J6KOF5oiW5pu05paw55qE5bqU55So5riF5Y2V77ya')
        foreach ($item in $appsToDisplay) {
            Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIHswfSAoezF9Ke+8mnsyfQ==') -f $item.App.name, $item.App.key, $item.Mode)
        }
    }

    Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bqU55So5omn6KGM6K6h5YiS77ya5a6J6KOFIHswfe+8jOabtOaWsCB7MX3vvIzot7Pov4cgezJ977yM5qOA5p+l5aSx6LSlIHszfQ==') -f $installCount, $updateCount, $skipCount, $failedCount)
}

function New-BootstrapAppPrecheckResult {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$App,
        [Parameter(Mandatory)]
        [pscustomobject]$Precheck
    )

    if ($Precheck.Status -eq 'failed') {
        return [pscustomobject]@{
            Name   = $App.name
            Key    = $App.key
            Status = 'failed'
            Source = $App.strategy
            Detail = ((ConvertFrom-BootstrapUtf8Base64String -Value '6aKE5qOA5p+l5byC5bi477yaezB9') -f $Precheck.Error)
        }
    }

    $decision = $Precheck.Decision
    if ($null -eq $decision -or $decision.Action -ne 'skip') {
        return $null
    }

    $skipDetail = if ($decision.Reason -eq 'present') {
        if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) {
            ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5rWL5Yiw5bey5a6J6KOF77yb5bey5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5'
        }
        else {
            (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5rWL5Yiw5bey5a6J6KOF77yIezB977yJ77yb5bey5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5') -f $decision.InstalledVersion
        }
    }
    else {
        '{0} >= {1}' -f $decision.InstalledVersion, $decision.DesiredVersion
    }

    return [pscustomobject]@{
        Name   = $App.name
        Key    = $App.key
        Status = 'ok'
        Source = 'precheck-skip'
        Detail = $skipDetail
    }
}

function Get-TuiAppStatusRows {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps
    )

    $rows = New-Object System.Collections.Generic.List[object]
    $decisionsByKey = @{}
    foreach ($precheck in @(Get-AppInstallDecisionBatch -Definitions $Apps)) {
        $decisionsByKey[[string]$precheck.Key] = $precheck
    }

    foreach ($app in ($Apps | Sort-Object order)) {
        try {
            $precheck = $decisionsByKey[[string]$app.key]
            if ($null -eq $precheck -or $precheck.Status -ne 'ok') {
                $errorDetail = if ($precheck -and -not [string]::IsNullOrWhiteSpace([string]$precheck.Error)) { [string]$precheck.Error } else { ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5aSx6LSl' }
                throw $errorDetail
            }

            $decision = $precheck.Decision
            $rows.Add([pscustomobject]@{
                    Key              = $app.key
                    Name             = $app.name
                    Decision         = $decision
                    Action           = $decision.Action
                    InstalledVersion = if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) { '-' } else { [string]$decision.InstalledVersion }
                    DesiredVersion   = if ([string]::IsNullOrWhiteSpace([string]$decision.DesiredVersion)) { '-' } else { [string]$decision.DesiredVersion }
                    ActionText       = Get-TuiAppDecisionText -Decision $decision
                    Error            = $null
                })
        }
        catch {
            $rows.Add([pscustomobject]@{
                    Key              = $app.key
                    Name             = $app.name
                    Decision         = $null
                    Action           = 'unknown'
                    InstalledVersion = '-'
                    DesiredVersion   = '-'
                    ActionText       = ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5aSx6LSl'
                    Error            = $_.Exception.Message
                })
        }
    }

    return $rows.ToArray()
}

function Show-TuiAppStatus {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps
    )

    $rows = @(Get-TuiAppStatusRows -Apps $Apps)
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6L2v5Lu254q25oCB')
        Write-Host ('{0,-24} {1,-20} {2,-14} {3}' -f `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5bqU55So'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN54mI5pys'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '55uu5qCH54mI5pys'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5bu66K6u5Yqo5L2c')) -ForegroundColor DarkGray
        foreach ($row in $rows) {
            $color = if ($row.Action -eq 'skip') { 'DarkGray' } elseif ($row.Action -eq 'unknown') { 'Yellow' } else { 'Cyan' }
            Write-Host ('{0,-24} {1,-20} {2,-14} {3}' -f $row.Name, $row.InstalledVersion, $row.DesiredVersion, $row.ActionText) -ForegroundColor $color
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5oiWIEIg6L+U5ZueICBRIOmAgOWHug==') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' { return 'back' }
            'B' { return 'back' }
            'Q' { return 'quit' }
        }
    }
}

function Show-TuiSoftwareActionSelection {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps
    )

    Write-TuiLoading `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6L2v5Lu254q25oCB5LiO5a6J6KOFIC8g5pu05paw') `
        -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo5qOA5p+l6L2v5Lu254q25oCB77yM6K+356iN5YCZLi4u')
    $rows = @(Get-TuiAppStatusRows -Apps $Apps)
    $suggestedRows = @($rows | Where-Object { $_.Action -eq 'install' })
    $suggestedKeys = @($suggestedRows | ForEach-Object { $_.Key })
    $selected = @{}
    foreach ($row in $rows) {
        $selected[$row.Key] = ($suggestedKeys -contains $row.Key)
    }

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6L2v5Lu254q25oCB5LiO5a6J6KOFIC8g5pu05paw')
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '6buY6K6k5bey6YCJ5Lit6ZyA6KaB5a6J6KOF5oiW5pu05paw55qE6aG555uu77yM5Y+v55So56m65qC85Y676Zmk5LiN5oOz5aSE55CG55qE6aG555uu44CC') -ForegroundColor DarkGray
        Write-Host ''
        Write-Host ('{0,-4} {1,-24} {2,-20} {3,-14} {4}' -f `
                '', `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5bqU55So'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN54mI5pys'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '55uu5qCH54mI5pys'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5bu66K6u5Yqo5L2c')) -ForegroundColor DarkGray
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $row = $rows[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $canSelect = ($row.Action -eq 'install')
            $mark = if ($canSelect -and $selected[$row.Key]) { 'x' } elseif ($canSelect) { ' ' } else { '-' }
            $color = if ($i -eq $index) { 'Cyan' } elseif (-not $canSelect) { 'DarkGray' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2,-24} {3,-20} {4,-14} {5}' -f $cursor, $mark, $row.Name, $row.InstalledVersion, $row.DesiredVersion, $row.ActionText) -ForegroundColor $color
        }

        Write-Host ''
        $count = @($suggestedKeys | Where-Object { $selected[$_] }).Count
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJ5oupIHswfS97MX0g5Liq5bu66K6u6aG5') -f $count, $suggestedKeys.Count) -ForegroundColor DarkGray
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDljrvpmaQgIEEg5YWo6YCJICBOIOa4heepuiAgRW50ZXIg5LiL5LiA5q2lICBCIOi/lOWbniAgUSDpgIDlh7o=') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($rows.Count - 1)) { $index++ } }
            'Spacebar' {
                if ($rows[$index].Action -eq 'install') {
                    $selected[$rows[$index].Key] = -not $selected[$rows[$index].Key]
                }
            }
            'A' {
                foreach ($keyName in $suggestedKeys) {
                    $selected[$keyName] = $true
                }
            }
            'N' {
                foreach ($keyName in $suggestedKeys) {
                    $selected[$keyName] = $false
                }
            }
            'B' { return $null }
            'Q' { return 'quit' }
            'Enter' {
                $selectedKeys = @($suggestedKeys | Where-Object { $selected[$_] })
                if ($selectedKeys.Count -eq 0) {
                    Write-Host ''
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5pys5qyh5pON5L2c5LiN5Lya5a6J6KOF5oiW5pu05paw6L2v5Lu244CC') -ForegroundColor Yellow
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
                    [void][Console]::ReadKey($true)
                    return $null
                }

                return [pscustomobject]@{
                    AppKeys = $selectedKeys
                    Label   = (ConvertFrom-BootstrapUtf8Base64String -Value '5bu66K6u5aSE55CGIHswfSDkuKrlupTnlKg=') -f $selectedKeys.Count
                }
            }
        }
    }
}

function Show-TuiAppSelection {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps
    )

    $selected = @{}
    foreach ($app in $Apps) {
        $selected[$app.key] = $true
    }

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup6KaB5a6J6KOF5oiW5qOA5p+l55qE5bqU55So')
        for ($i = 0; $i -lt $Apps.Count; $i++) {
            $app = $Apps[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $mark = if ($selected[$app.key]) { 'x' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2,-24} {3}' -f $cursor, $mark, $app.name, $app.key) -ForegroundColor $color
        }

        Write-Host ''
        $count = @($selected.Keys | Where-Object { $selected[$_] }).Count
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJ5oupIHswfS97MX0g5Liq5bqU55So') -f $count, $Apps.Count) -ForegroundColor DarkGray
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDpgInmi6kgIEEg5YWo6YCJICBOIOa4heepuiAgRW50ZXIg5LiL5LiA5q2lICBRIOmAgOWHug==') -ForegroundColor DarkGray

        Complete-TuiFrame

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($Apps.Count - 1)) { $index++ } }
            'Spacebar' { $selected[$Apps[$index].key] = -not $selected[$Apps[$index].key] }
            'A' { foreach ($app in $Apps) { $selected[$app.key] = $true } }
            'N' { foreach ($app in $Apps) { $selected[$app.key] = $false } }
            'Enter' {
                $keys = @($Apps | Where-Object { $selected[$_.key] } | ForEach-Object { $_.key })
                if ($keys.Count -gt 0) {
                    return $keys
                }
            }
            'Q' { return $null }
        }
    }
}

function Show-TuiOptionSelection {
    $options = @(
        New-TuiOption -Key 'dryrun' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD5qih5byP77yI5LiN55yf5q2j5a6J6KOF77yJ') -SwitchName 'DryRun' -Enabled $true
        New-TuiOption -Key 'skipcc' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIENDIFN3aXRjaCBQcm92aWRlciDlr7zlhaU=') -SwitchName 'SkipCcSwitch' -Enabled $true
        New-TuiOption -Key 'skipskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ==') -SwitchName 'SkipSkills'
        New-TuiOption -Key 'noorphan' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5penIFNraWxsIOebruW9leS4jeabv+aNou+8jOWPqui3s+i/hw==') -SwitchName 'NoReplaceOrphan' -Enabled $true
        New-TuiOption -Key 'replaceforeign' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '56ys5LiJ5pa55ZCM5ZCNIFNraWxsIOWFgeiuuOWkh+S7veabv+aNog==') -SwitchName 'ReplaceForeign'
        New-TuiOption -Key 'renameforeign' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '56ys5LiJ5pa55ZCM5ZCNIFNraWxsIOaUueWQjeS4uiAtaW5kaWVhcmsg5a+85YWl') -SwitchName 'RenameForeign'
        New-TuiOption -Key 'skipmanager' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWlIFNraWxsIOWQjuS4jeiHquWKqOWQr+WKqCBTa2lsbHMgTWFuYWdlcg==') -SwitchName 'SkipSkillsManagerLaunch' -Enabled $true
    )

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5aSN6YCJ6aG5')
        for ($i = 0; $i -lt $options.Count; $i++) {
            $option = $options[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $mark = if ($option.Enabled) { 'x' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2}' -f $cursor, $mark, $option.Label) -ForegroundColor $color
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDlpI3pgIkv5Y+W5raIICBFbnRlciDkuIvkuIDmraUgIEIg6L+U5ZueICBRIOmAgOWHug==') -ForegroundColor DarkGray

        Complete-TuiFrame

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($options.Count - 1)) { $index++ } }
            'Spacebar' {
                $options[$index].Enabled = -not $options[$index].Enabled
                if ($options[$index].Key -eq 'replaceforeign' -and $options[$index].Enabled) {
                    ($options | Where-Object { $_.Key -eq 'renameforeign' }).Enabled = $false
                }
                if ($options[$index].Key -eq 'renameforeign' -and $options[$index].Enabled) {
                    ($options | Where-Object { $_.Key -eq 'replaceforeign' }).Enabled = $false
                }
            }
            'Enter' { return $options }
            'B' { return $null }
            'Q' { return 'quit' }
        }
    }
}

function Show-TuiSkillProfileSelection {
    param(
        [object[]]$Profiles = @(),
        [int]$BundleSkillCount = 0,
        [int]$RegistrySkillCount = 0,
        [int]$InstalledSkillCount = 0,
        [int]$NewSkillCount = 0
    )

    function Format-TuiListPreview {
        param(
            [string[]]$Values = @(),
            [int]$MaxItems = 6
        )

        $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        if ($items.Count -eq 0) {
            return (ConvertFrom-BootstrapUtf8Base64String -Value '5peg')
        }

        $visible = @($items | Select-Object -First $MaxItems)
        $text = $visible -join ', '
        if ($items.Count -gt $MaxItems) {
            $text = '{0} ... {1}' -f $text, ((ConvertFrom-BootstrapUtf8Base64String -Value '562JIHswfSDkuKo=') -f $items.Count)
        }
        return $text
    }

    function Format-TuiSkillProfileSelectionPreview {
        param(
            [object[]]$Options = @(),
            [int]$MaxItems = 4
        )

        $selected = @(
            $Options |
            Where-Object { $_.Enabled } |
            Select-Object -First $MaxItems |
            ForEach-Object {
                if ($_.IsAllSkills) {
                    ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs'
                }
                elseif ($_.IsAllSuites) {
                    ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu2'
                }
                elseif ($_.IsSkipSkills) {
                    ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxs'
                }
                else {
                    [string]$_.ProfileName
                }
            }
        )
        if ($selected.Count -eq 0) {
            return ConvertFrom-BootstrapUtf8Base64String -Value '5peg'
        }

        $text = $selected -join ', '
        $selectedCount = @($Options | Where-Object { $_.Enabled }).Count
        if ($selectedCount -gt $MaxItems) {
            $text = '{0} ... {1}' -f $text, ((ConvertFrom-BootstrapUtf8Base64String -Value '562JIHswfSDkuKo=') -f $selectedCount)
        }
        return $text
    }

    function Write-TuiSkillProfileDetail {
        param(
            [Parameter(Mandatory)]
            [object]$Option
        )

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN6aG56K+m5oOF') -ForegroundColor DarkCyan
        if ($Option.IsSkipSkills) {
            Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5bCG6Lez6L+HIFNraWxsIOWvvOWFpe+8jOS4jeWuieijhSBNQ1AgLyBDTEnjgII=')) -ForegroundColor Gray
            return
        }

        $summary = if ([int]$Option.SuiteCount -gt 0) {
            (ConvertFrom-BootstrapUtf8Base64String -Value '5aWX5Lu2IHswfSDkuKrvvJtTa2lsbCB7MX3vvJtNQ1AgezJ977ybQ0xJIHszfQ==') -f $Option.SuiteCount, $Option.SkillCount, $Option.McpCount, $Option.CliCount
        }
        else {
            (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwgezB977ybTUNQIHsxfe+8m0NMSSB7Mn0=') -f $Option.SkillCount, $Option.McpCount, $Option.CliCount
        }
        Write-Host ('  {0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5pWw6YeP'), $summary) -ForegroundColor Gray
        Write-Host ('  {0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'TUNQ'), (Format-TuiListPreview -Values @($Option.Mcp))) -ForegroundColor Gray
        Write-Host ('  {0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0xJIOS+nei1lg=='), (Format-TuiListPreview -Values @($Option.Prereqs))) -ForegroundColor Gray
        if (-not [string]::IsNullOrWhiteSpace([string]$Option.Description)) {
            Write-Host ('  {0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6K+05piO'), $Option.Description) -ForegroundColor DarkGray
        }
    }

    function Get-TuiProfileSkillNames {
        param([Parameter(Mandatory)][object]$Profile)

        $expandedProperty = $Profile.PSObject.Properties['ExpandedSkills']
        if ($expandedProperty) {
            return @($expandedProperty.Value | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }

        return @($Profile.Skills | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $allSuiteSkills = @($Profiles | ForEach-Object { Get-TuiProfileSkillNames -Profile $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $allSuiteMcp = @($Profiles | ForEach-Object { $_.Mcp } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $allSuitePrereqs = @($Profiles | ForEach-Object { $_.Prereqs } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $allSkillCount = if ($RegistrySkillCount -gt 0) { $RegistrySkillCount } else { $BundleSkillCount }
    $allSkillsLabel = if ($allSkillCount -gt 0) {
        (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs77yIezB9IOS4qu+8m01DUCAw77ybQ0xJIDDvvIk=') -f $allSkillCount
    }
    else {
        ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs77yI6buY6K6k77yJ'
    }
    $allSuitesLabel = (ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu277yIezB9IOS4quWll+S7tu+8m1NraWxsIHsxfe+8m01DUCB7Mn3vvJtDTEkgezN977yJ') -f $Profiles.Count, $allSuiteSkills.Count, $allSuiteMcp.Count, $allSuitePrereqs.Count
    $options = New-Object System.Collections.Generic.List[object]
    $options.Add([pscustomobject]@{
            Key          = 'all'
            Label        = $allSkillsLabel
            ProfileName  = $null
            Enabled      = $true
            IsAllSkills  = $true
            IsAllSuites  = $false
            IsSkipSkills = $false
            SuiteCount   = 0
            SkillCount   = $allSkillCount
            McpCount     = 0
            CliCount     = 0
            Mcp          = @()
            Prereqs      = @()
            Description  = ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOFIHJlZ2lzdHJ5IOWFqOmDqCBTa2lsbO+8jOS4jeWuieijhSBNQ1AgLyBDTEnjgII='
        })
    $options.Add([pscustomobject]@{
            Key          = 'suites'
            Label        = $allSuitesLabel
            ProfileName  = $null
            Enabled      = $false
            IsAllSkills  = $false
            IsAllSuites  = $true
            IsSkipSkills = $false
            SuiteCount   = $Profiles.Count
            SkillCount   = $allSuiteSkills.Count
            McpCount     = $allSuiteMcp.Count
            CliCount     = $allSuitePrereqs.Count
            Mcp          = @($allSuiteMcp)
            Prereqs      = @($allSuitePrereqs)
            Description  = ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZSDlubbpm4bvvJrlronoo4XmiYDmnInlpZfku7blvJXnlKjnmoQgU2tpbGzjgIFNQ1Ag5ZKMIENMSSDliY3nva7kvp3otZY='
        })
    $options.Add([pscustomobject]@{
            Key          = 'skip'
            Label        = (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ==')
            ProfileName  = $null
            Enabled      = $false
            IsAllSkills  = $false
            IsAllSuites  = $false
            IsSkipSkills = $true
            SuiteCount   = 0
            SkillCount   = 0
            McpCount     = 0
            CliCount     = 0
            Mcp          = @()
            Prereqs      = @()
            Description  = ''
        })

    foreach ($profile in @($Profiles)) {
        $profileSkills = @(Get-TuiProfileSkillNames -Profile $profile)
        $profileMcp = @($profile.Mcp | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $profilePrereqs = @($profile.Prereqs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $detail = (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwgezB977ybTUNQIHsxfe+8m0NMSSB7Mn0=') -f $profileSkills.Count, $profileMcp.Count, $profilePrereqs.Count
        $label = if ([string]::IsNullOrWhiteSpace($profile.Description)) {
            (ConvertFrom-BootstrapUtf8Base64String -Value 'ezB9IC0gU2tpbGwgezF977ybTUNQIHsyfe+8m0NMSSB7M30=') -f $profile.Name, $profileSkills.Count, $profileMcp.Count, $profilePrereqs.Count
        }
        else {
            '{0} - {1}; {2}' -f $profile.Name, $profile.Description, $detail
        }
        $options.Add([pscustomobject]@{
                Key          = $profile.Name
                Label        = $label
                ProfileName  = $profile.Name
                Enabled      = $false
                IsAllSkills  = $false
                IsAllSuites  = $false
                IsSkipSkills = $false
                SuiteCount   = 0
                SkillCount   = $profileSkills.Count
                McpCount     = $profileMcp.Count
                CliCount     = $profilePrereqs.Count
                Mcp          = @($profileMcp)
                Prereqs      = @($profilePrereqs)
                Description  = $profile.Description
            })
    }

    $index = 0
    $pageSize = 12
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg5aSN6YCJ6aG5')
        if (-not $Profiles -or $Profiles.Count -eq 0) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6K+75Y+W5YiwIFByb2ZpbGXvvIzpu5jorqTlr7zlhaXlhajpg6ggU2tpbGzjgII=') -ForegroundColor DarkGray
            Write-Host ''
        }

        Write-Host ('{0}: {1}; {2}: {3}; {4}: {5}; {6}: {7}' -f `
            (ConvertFrom-BootstrapUtf8Base64String -Value 'QnVuZGxlIFNraWxs'), $BundleSkillCount, `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v6YCJIFNraWxs'), $RegistrySkillCount, `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5pys5py65bey5a6J6KOF'), $InstalledSkillCount, `
            (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v6IO95paw5aKe'), $NewSkillCount) -ForegroundColor DarkGray
        $selectedCount = @($options | Where-Object { $_.Enabled }).Count
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJIHswfSDkuKrvvJvlvZPliY0gezF9L3syfQ==') -f $selectedCount, ($index + 1), $options.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJ'), (Format-TuiSkillProfileSelectionPreview -Options $options)) -ForegroundColor DarkGray
        Write-Host ''

        $halfPage = [Math]::Floor($pageSize / 2)
        $start = [Math]::Max(0, $index - $halfPage)
        $end = [Math]::Min($options.Count - 1, $start + $pageSize - 1)
        if (($end - $start + 1) -lt $pageSize) {
            $start = [Math]::Max(0, $end - $pageSize + 1)
        }
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5pi+56S6IHswfS17MX0gLyB7Mn0=') -f ($start + 1), ($end + 1), $options.Count) -ForegroundColor DarkGray

        for ($i = $start; $i -le $end; $i++) {
            $option = $options[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $mark = if ($option.Enabled) { 'x' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2}' -f $cursor, $mark, $option.Label) -ForegroundColor $color
        }

        Write-TuiSkillProfileDetail -Option $options[$index]

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDlpI3pgIkv5Y+W5raIICBBIOWFqOmAiSAgTiDmuIXnqbogIEVudGVyIOS4i+S4gOatpSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray

        Complete-TuiFrame

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($options.Count - 1)) { $index++ } }
            'Spacebar' {
                $options[$index].Enabled = -not $options[$index].Enabled
                if ($options[$index].IsAllSkills -and $options[$index].Enabled) {
                    foreach ($option in $options | Where-Object { -not $_.IsAllSkills }) {
                        $option.Enabled = $false
                    }
                }
                elseif ($options[$index].IsAllSuites -and $options[$index].Enabled) {
                    foreach ($option in $options | Where-Object { -not $_.IsAllSuites }) {
                        $option.Enabled = $false
                    }
                }
                elseif ($options[$index].IsSkipSkills -and $options[$index].Enabled) {
                    foreach ($option in $options | Where-Object { -not $_.IsSkipSkills }) {
                        $option.Enabled = $false
                    }
                }
                elseif ((-not $options[$index].IsAllSkills) -and (-not $options[$index].IsAllSuites) -and $options[$index].Enabled) {
                    ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                    ($options | Where-Object { $_.IsAllSuites } | Select-Object -First 1).Enabled = $false
                    ($options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1).Enabled = $false
                }
            }
            'A' {
                ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                ($options | Where-Object { $_.IsAllSuites } | Select-Object -First 1).Enabled = $false
                ($options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1).Enabled = $false
                foreach ($option in $options | Where-Object { -not $_.IsAllSkills }) {
                    if ((-not $option.IsAllSuites) -and (-not $option.IsSkipSkills)) {
                        $option.Enabled = $true
                    }
                }
            }
            'N' {
                foreach ($option in $options) {
                    $option.Enabled = $false
                }
            }
            'Enter' {
                $allOption = $options | Where-Object { $_.IsAllSkills } | Select-Object -First 1
                $allSuitesOption = $options | Where-Object { $_.IsAllSuites } | Select-Object -First 1
                $skipOption = $options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1
                $selectedProfiles = @($options | Where-Object { $_.Enabled -and -not $_.IsAllSkills -and -not $_.IsAllSuites -and -not $_.IsSkipSkills } | ForEach-Object { $_.ProfileName })
                if ($skipOption.Enabled) {
                    return [pscustomobject]@{
                        SkipSkills    = $true
                        AllSkills     = $false
                        AllSuites     = $false
                        SkillProfiles = @()
                    }
                }
                if ($allSuitesOption.Enabled) {
                    return [pscustomobject]@{
                        SkipSkills    = $false
                        AllSkills     = $false
                        AllSuites     = $true
                        SkillProfiles = @()
                    }
                }
                if ($allOption.Enabled -or $selectedProfiles.Count -eq 0) {
                    if (-not $allOption.Enabled -and $selectedProfiles.Count -eq 0) {
                        Write-Host ''
                        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup5Lu75L2VIFByb2ZpbGXjgILor7fpgInkuK3lhajpg6ggU2tpbGzjgIHoh7PlsJHkuIDkuKogUHJvZmlsZe+8jOaIlumAieaLqei3s+i/hyBTa2lsbCDlr7zlhaXjgII=') -ForegroundColor Yellow
                        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
                        [void][Console]::ReadKey($true)
                        continue
                    }
                    return [pscustomobject]@{
                        SkipSkills    = $false
                        AllSkills     = $true
                        AllSuites     = $false
                        SkillProfiles = @()
                    }
                }

                return [pscustomobject]@{
                    SkipSkills    = $false
                    AllSkills     = $false
                    AllSuites     = $false
                    SkillProfiles = $selectedProfiles
                }
            }
            'B' { return $null }
            'Q' { return 'quit' }
        }
    }
}

function Show-TuiComponentSelection {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$TypeName,
        [object[]]$Entries = @()
    )

    function Format-TuiComponentPreview {
        param(
            [object[]]$Options = @(),
            [int]$MaxItems = 4
        )

        $selected = @($Options | Where-Object { $_.Enabled } | Select-Object -First $MaxItems | ForEach-Object { $_.Name })
        if ($selected.Count -eq 0) {
            return ConvertFrom-BootstrapUtf8Base64String -Value '5peg'
        }

        $text = $selected -join ', '
        $selectedCount = @($Options | Where-Object { $_.Enabled }).Count
        if ($selectedCount -gt $MaxItems) {
            $text = '{0} ... {1}' -f $text, ((ConvertFrom-BootstrapUtf8Base64String -Value '562JIHswfSDkuKo=') -f $selectedCount)
        }
        return $text
    }

    $options = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($Entries | Sort-Object Name)) {
        $detail = ''
        $status = ''
        if ($entry.PSObject.Properties['Status']) {
            $status = [string]$entry.Status
        }
        if ($entry.PSObject.Properties['Description']) {
            $detail = [string]$entry.Description
        }
        elseif ($entry.PSObject.Properties['Kind']) {
            $detail = [string]$entry.Kind
        }
        $options.Add([pscustomobject]@{
                Name    = [string]$entry.Name
                Status  = $status
                Detail  = $detail
                Enabled = $false
            })
    }

    if ($options.Count -eq 0) {
        Write-TuiHeader -Title $Title
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5rKh5pyJ5Y+v6YCJ5oup55qEIHswfeOAgg==') -f $TypeName) -ForegroundColor Yellow
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
        [void][Console]::ReadKey($true)
        return $null
    }

    $index = 0
    $pageSize = 12
    while ($true) {
        Write-TuiHeader -Title $Title
        $selectedCount = @($options | Where-Object { $_.Enabled }).Count
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJIHswfSDkuKrvvJvlvZPliY0gezF9L3syfQ==') -f $selectedCount, ($index + 1), $options.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJ'), (Format-TuiComponentPreview -Options $options)) -ForegroundColor DarkGray
        Write-Host ''

        $halfPage = [Math]::Floor($pageSize / 2)
        $start = [Math]::Max(0, $index - $halfPage)
        $end = [Math]::Min($options.Count - 1, $start + $pageSize - 1)
        if (($end - $start + 1) -lt $pageSize) {
            $start = [Math]::Max(0, $end - $pageSize + 1)
        }
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5pi+56S6IHswfS17MX0gLyB7Mn0=') -f ($start + 1), ($end + 1), $options.Count) -ForegroundColor DarkGray

        $hasStatus = @($options | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Status) }).Count -gt 0
        if ($hasStatus) {
            Write-Host ('  {0,-34} {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5ZCN56ew'), (ConvertFrom-BootstrapUtf8Base64String -Value '54q25oCB')) -ForegroundColor DarkGray
        }
        for ($i = $start; $i -le $end; $i++) {
            $option = $options[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $mark = if ($option.Enabled) { 'x' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            if ($hasStatus) {
                Write-Host ('{0} [{1}] {2,-34} {3}' -f $cursor, $mark, $option.Name, $option.Status) -ForegroundColor $color
            }
            else {
                Write-Host ('{0} [{1}] {2}' -f $cursor, $mark, $option.Name) -ForegroundColor $color
            }
        }

        Write-Host ''
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN6aG577yaezB9') -f $options[$index].Name) -ForegroundColor DarkCyan
        if (-not [string]::IsNullOrWhiteSpace($options[$index].Detail)) {
            Write-Host ('  {0}' -f $options[$index].Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDlpI3pgIkv5Y+W5raIICBBIOWFqOmAiSAgTiDmuIXnqbogIEVudGVyIOS4i+S4gOatpSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($options.Count - 1)) { $index++ } }
            'Spacebar' { $options[$index].Enabled = -not $options[$index].Enabled }
            'A' {
                foreach ($option in $options) {
                    $option.Enabled = $true
                }
            }
            'N' {
                foreach ($option in $options) {
                    $option.Enabled = $false
                }
            }
            'Enter' {
                $selected = @($options | Where-Object { $_.Enabled } | ForEach-Object { $_.Name })
                if ($selected.Count -eq 0) {
                    Write-Host ''
                    Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup5Lu75L2VIHswfeOAgg==') -f $TypeName) -ForegroundColor Yellow
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
                    [void][Console]::ReadKey($true)
                    continue
                }
                return $selected
            }
            'B' { return $null }
            'Q' { return 'quit' }
        }
    }
}

function Show-TuiSkillsManagerScenarioSelection {
    param(
        [string]$InitialMode = 'skip',
        [string]$InitialName
    )

    $options = @(
        [pscustomobject]@{
            Mode   = 'default'
            Label  = (ConvertFrom-BootstrapUtf8Base64String -Value '6buY6K6k5Zy65pmv77yI5b2T5YmN5ZCv55So77yJ')
            Detail = (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6buY6K6k5Zy65pmv')
        }
        [pscustomobject]@{
            Mode   = 'custom'
            Label  = (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5Zy65pmv')
            Detail = (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6Ieq5a6a5LmJ5Zy65pmv77yaezB9') -f ($(if ([string]::IsNullOrWhiteSpace($InitialName)) { ConvertFrom-BootstrapUtf8Base64String -Value 'SW5kaWVBcmsgU2tpbGxz' } else { $InitialName }))
        }
        [pscustomobject]@{
            Mode   = 'skip'
            Label  = (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H5Zy65pmv5rOo5YaM77yI5Y+q5aSN5Yi2IFNraWxsIOaWh+S7tu+8iQ==')
            Detail = (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxscyBNYW5hZ2VyIOWcuuaZr+azqOWGjA==')
        }
    )

    $index = 0
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($options[$i].Mode -eq $InitialMode) {
            $index = $i
            break
        }
    }

    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGxzIE1hbmFnZXIg5Zy65pmv')
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '6K+36YCJ5oup5a+85YWlIFNraWxsIOWQjuWmguS9leWGmeWFpSBTa2lsbHMgTWFuYWdlciDlnLrmma/vvJo=') -ForegroundColor DarkGray
        Write-Host ''
        for ($i = 0; $i -lt $options.Count; $i++) {
            $option = $options[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $option.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $option.Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($options.Count - 1)) { $index++ } }
            'B' { return $null }
            'Q' { return 'quit' }
            'Enter' {
                $mode = $options[$index].Mode
                $name = $InitialName
                if ($mode -eq 'custom') {
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = ConvertFrom-BootstrapUtf8Base64String -Value 'SW5kaWVBcmsgU2tpbGxz'
                    }
                    Write-Host ''
                    $answer = Read-Host ('{0} [{1}]' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5Zy65pmv5ZCN56ew'), $name)
                    if (-not [string]::IsNullOrWhiteSpace($answer)) {
                        $name = $answer.Trim()
                    }
                }

                return [pscustomobject]@{
                    Mode = $mode
                    Name = $name
                }
            }
        }
    }
}

function ConvertTo-TuiArgumentText {
    param(
        [Parameter(Mandatory)]
        [string[]]$Tokens
    )

    return ($Tokens | ForEach-Object {
            if ($_ -match '[\s"]') {
                '"{0}"' -f ($_ -replace '"', '\"')
            }
            else {
                $_
            }
        }) -join ' '
}

function Get-TuiBootstrapArgumentTokens {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedAppKeys,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Options,
        [string[]]$SkillProfiles = @(),
        [string[]]$SkillNames = @(),
        [string[]]$McpNames = @(),
        [string[]]$CliNames = @(),
        [string]$SkillsManagerScenarioMode,
        [string]$SkillsManagerScenarioName,
        [switch]$ShowDefaultCommand,
        [switch]$IncludeOnly
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    if ($ShowDefaultCommand) {
        return $tokens.ToArray()
    }

    $skipAppsOption = $Options | Where-Object { $_.SwitchName -eq 'SkipApps' -and $_.Enabled } | Select-Object -First 1
    if ($IncludeOnly -and -not $skipAppsOption -and $SelectedAppKeys.Count -gt 0) {
        $tokens.Add('-Only')
        $tokens.Add(($SelectedAppKeys -join ','))
    }
    foreach ($option in $Options | Where-Object { $_.Enabled }) {
        $tokens.Add(('-{0}' -f $option.SwitchName))
    }
    if ($SkillProfiles -and $SkillProfiles.Count -gt 0) {
        $tokens.Add('-SkillProfile')
        foreach ($profile in $SkillProfiles) {
            $tokens.Add($profile)
        }
    }
    if ($SkillNames -and @($SkillNames).Count -gt 0) {
        $tokens.Add('-SkillName')
        foreach ($name in $SkillNames) {
            $tokens.Add($name)
        }
    }
    if ($McpNames -and @($McpNames).Count -gt 0) {
        $tokens.Add('-McpName')
        foreach ($name in $McpNames) {
            $tokens.Add($name)
        }
    }
    if ($CliNames -and @($CliNames).Count -gt 0) {
        $tokens.Add('-CliName')
        foreach ($name in $CliNames) {
            $tokens.Add($name)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($SkillsManagerScenarioMode) -and $SkillsManagerScenarioMode -ne 'prompt') {
        $tokens.Add('-SkillsManagerScenarioMode')
        $tokens.Add($SkillsManagerScenarioMode)
    }
    if (-not [string]::IsNullOrWhiteSpace($SkillsManagerScenarioName)) {
        $tokens.Add('-SkillsManagerScenarioName')
        $tokens.Add($SkillsManagerScenarioName)
    }

    return $tokens.ToArray()
}

function Show-TuiReview {
    param(
        [AllowEmptyCollection()]
        [string[]]$SelectedAppKeys,
        [AllowEmptyCollection()]
        [object[]]$Options = @(),
        [string[]]$SkillProfiles = @(),
        [string[]]$SkillNames = @(),
        [string[]]$McpNames = @(),
        [string[]]$CliNames = @(),
        [string]$SkillsManagerScenarioMode,
        [string]$SkillsManagerScenarioName,
        [string]$ModeName,
        [switch]$UseDefaultInstall,
        [switch]$IncludeOnly
    )

    $tokens = Get-TuiBootstrapArgumentTokens -SelectedAppKeys $SelectedAppKeys -Options $Options -SkillProfiles $SkillProfiles -SkillNames $SkillNames -McpNames $McpNames -CliNames $CliNames -SkillsManagerScenarioMode $SkillsManagerScenarioMode -SkillsManagerScenarioName $SkillsManagerScenarioName -ShowDefaultCommand:$UseDefaultInstall -IncludeOnly:$IncludeOnly
    $commandText = '.\bootstrap.cmd'
    if ($tokens.Count -gt 0) {
        $commandText = '{0} {1}' -f $commandText, (ConvertTo-TuiArgumentText -Tokens $tokens)
    }

    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM56Gu6K6k')
        $dryRunOption = $Options | Where-Object { $_.SwitchName -eq 'DryRun' } | Select-Object -First 1
        $isDryRun = $false
        if ($dryRunOption) {
            $isDryRun = [bool]$dryRunOption.Enabled
        }
        $mode = if (-not [string]::IsNullOrWhiteSpace($ModeName)) { $ModeName } elseif ($isDryRun) { ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5byP5a6J6KOF' }
        $enabledOptions = @($Options | Where-Object { $_.Enabled -and $_.SwitchName -ne 'DryRun' } | ForEach-Object { $_.Label })
        $optionText = if ($enabledOptions.Count -gt 0) { $enabledOptions -join ', ' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5peg' }
        $skipSkillsOption = $Options | Where-Object { $_.SwitchName -eq 'SkipSkills' -and $_.Enabled } | Select-Object -First 1
        $skipAppsOption = $Options | Where-Object { $_.SwitchName -eq 'SkipApps' -and $_.Enabled } | Select-Object -First 1
        $allSkillsOption = $Options | Where-Object { $_.SwitchName -eq 'AllSkills' -and $_.Enabled } | Select-Object -First 1
        $allSuitesOption = $Options | Where-Object { $_.SwitchName -eq 'AllSuites' -and $_.Enabled } | Select-Object -First 1
        $appText = if ($skipAppsOption) {
            ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H6L2v5Lu25a6J6KOF'
        }
        elseif ($SelectedAppKeys -and $SelectedAppKeys.Count -gt 0) {
            $SelectedAppKeys -join ', '
        }
        else {
            ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup'
        }
        $skillText = if ($skipSkillsOption) {
            ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ=='
        }
        elseif ($allSkillsOption) {
            ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs'
        }
        elseif ($allSuitesOption) {
            ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu2'
        }
        elseif ($SkillProfiles -and $SkillProfiles.Count -gt 0) {
            $SkillProfiles -join ', '
        }
        elseif ((@($SkillNames).Count + @($McpNames).Count + @($CliNames).Count) -gt 0) {
            (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwgezB9IOS4qu+8m01DUCB7MX0g5Liq77ybQ0xJIHsyfSDkuKo=') -f @($SkillNames).Count, @($McpNames).Count, @($CliNames).Count
        }
        else {
            ConvertFrom-BootstrapUtf8Base64String -Value '5ZG95Luk5qih5byP6buY6K6k'
        }
        $scenarioText = switch ($SkillsManagerScenarioMode) {
            'default' { ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6buY6K6k5Zy65pmv' }
            'custom' { (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6Ieq5a6a5LmJ5Zy65pmv77yaezB9') -f $SkillsManagerScenarioName }
            'skip' { ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxscyBNYW5hZ2VyIOWcuuaZr+azqOWGjA==' }
            default { ConvertFrom-BootstrapUtf8Base64String -Value '5ZG95Luk5qih5byP6buY6K6k' }
        }

        Write-TuiSection `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup5pGY6KaB') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6L+Z6YeM5rGH5oC75pys5qyh5bCG5omn6KGM55qE6L2v5Lu244CBU2tpbGzjgIHlnLrmma/lkozpmYTliqDlj4LmlbDjgII=')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5qih5byP'), $mode) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5Lit5bqU55So'), $appText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg6YCJ5oup'), $skillText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGxzIE1hbmFnZXIg5Zy65pmv'), $scenarioText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6ZmE5Yqg5Y+C5pWw'), $optionText) -ForegroundColor Gray

        Write-TuiSection `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5ZG95Luk') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '56Gu6K6k5ZCO5bCG5omn6KGM5LiL6Z2i55qE5ZG95Luk77yb5Y+v5YWI5aSN5Yi25YaN6L+Q6KGM44CC')
        Write-Host $commandText -ForegroundColor Cyan
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5byA5aeL5omn6KGMICBDIOWkjeWItuWRveS7pCAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray

        Complete-TuiFrame

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' {
                return [pscustomobject]@{
                    Tokens  = $tokens
                    Options = $Options
                }
            }
            'C' {
                try {
                    Set-Clipboard -Value $commandText
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5ZG95Luk5bey5aSN5Yi25Yiw5Ymq6LS05p2/') -ForegroundColor Green
                }
                catch {
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5Ymq6LS05p2/5LiN5Y+v55So77yM5ZG95Luk5aaC5LiL77ya') -ForegroundColor Yellow
                    Write-Host $commandText
                }
                [void][Console]::ReadKey($true)
            }
            'B' { return $null }
            'Q' { return 'quit' }
        }
    }
}

function New-TuiBootstrapResult {
    param(
        [AllowNull()]
        [string[]]$Only,
        [AllowEmptyCollection()]
        [object[]]$Options = @(),
        [string[]]$SkillProfiles = @(),
        [string[]]$SkillNames = @(),
        [string[]]$McpNames = @(),
        [string[]]$CliNames = @(),
        [string]$SkillsManagerScenarioMode,
        [string]$SkillsManagerScenarioName,
        [switch]$UseDefaultInstall
    )

    $switches = @{}
    foreach ($option in $Options) {
        $switches[$option.SwitchName] = [bool]$option.Enabled
    }

    return [pscustomobject]@{
        Only                         = $Only
        UseDefaultInstall            = [bool]$UseDefaultInstall
        SkillProfile                 = @($SkillProfiles)
        SkillName                    = @($SkillNames)
        McpName                      = @($McpNames)
        CliName                      = @($CliNames)
        SkillsManagerScenarioMode    = $SkillsManagerScenarioMode
        SkillsManagerScenarioName    = $SkillsManagerScenarioName
        DryRun                       = [bool]$switches['DryRun']
        SkipCcSwitch                 = [bool]$switches['SkipCcSwitch']
        SkipApps                     = [bool]$switches['SkipApps']
        SkipSkills                   = [bool]$switches['SkipSkills']
        AllSkills                    = [bool]$switches['AllSkills']
        AllSuites                    = [bool]$switches['AllSuites']
        NoReplaceOrphan              = [bool]$switches['NoReplaceOrphan']
        ReplaceForeign               = [bool]$switches['ReplaceForeign']
        RenameForeign                = [bool]$switches['RenameForeign']
        SkipSkillsManagerLaunch      = [bool]$switches['SkipSkillsManagerLaunch']
        RefreshBootstrapDependencies = [bool]$switches['RefreshBootstrapDependencies']
    }
}

function Get-BootstrapTuiSkillProfiles {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    $skillBundlePath = Join-Path $DestinationRoot 'downloads\skills.zip'
    Sync-BootstrapSkillBundleAsset `
        -Repo $Repo `
        -Tag $Tag `
        -DestinationRoot $DestinationRoot `
        -Refresh:$Refresh

    try {
        return @(Get-SkillBundleProfiles -ZipPath $skillBundlePath)
    }
    catch {
        Write-BootstrapMessage $_.Exception.Message
        return @()
    }
}

function Get-BootstrapTuiSkillBundleSummary {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    $skillBundlePath = Join-Path $DestinationRoot 'downloads\skills.zip'
    Sync-BootstrapSkillBundleAsset `
        -Repo $Repo `
        -Tag $Tag `
        -DestinationRoot $DestinationRoot `
        -Refresh:$Refresh

    $componentStatus = Get-SkillBundleComponentStatus -ZipPath $skillBundlePath
    $profiles = @($componentStatus.Profiles)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $skillBundlePath).ProviderPath)
    try {
        $bundleSkills = @(
            $archive.Entries |
            Where-Object { $_.FullName -match '(^|/)SKILL\.md$' } |
            ForEach-Object {
                $parent = Split-Path -Parent ($_.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar))
                if (-not [string]::IsNullOrWhiteSpace($parent)) {
                    Split-Path -Leaf $parent
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
    }
    finally {
        $archive.Dispose()
    }

    $homeDir = Get-OriginalUserHomeDirectory
    $localSkillRoot = Join-Path $homeDir '.skills-manager\skills'
    $installedSkills = @()
    if (Test-Path -LiteralPath $localSkillRoot) {
        $installedSkills = @(
            Get-ChildItem -LiteralPath $localSkillRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
            ForEach-Object { $_.Name } |
            Sort-Object -Unique
        )
    }

    $installedSet = @{}
    foreach ($skillName in $installedSkills) {
        $installedSet[[string]$skillName.ToLowerInvariant()] = $true
    }
    $newSkills = @($bundleSkills | Where-Object { -not $installedSet.ContainsKey([string]$_.ToLowerInvariant()) })

    return [pscustomobject]@{
        Profiles        = $profiles
        BundleSkills    = $bundleSkills
        InstalledSkills = $installedSkills
        NewSkills       = $newSkills
        RegistrySkills  = @($componentStatus.RegistrySkills)
        SkillStatus     = @($componentStatus.Skills)
        McpStatus       = @($componentStatus.Mcp)
        PrereqStatus    = @($componentStatus.Prereqs)
        ZipPath         = $skillBundlePath
        LocalSkillRoot  = $localSkillRoot
    }
}

function Get-BootstrapTuiSkillOnlySummary {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    $skillBundlePath = Join-Path $DestinationRoot 'downloads\skills.zip'
    Sync-BootstrapSkillBundleAsset `
        -Repo $Repo `
        -Tag $Tag `
        -DestinationRoot $DestinationRoot `
        -Refresh:$Refresh

    $inventory = Get-SkillBundleInventory -ZipPath $skillBundlePath
    $homeDir = Get-OriginalUserHomeDirectory
    $localSkillRoot = Join-Path $homeDir '.skills-manager\skills'
    $installedSkills = @()
    if (Test-Path -LiteralPath $localSkillRoot) {
        $installedSkills = @(
            Get-ChildItem -LiteralPath $localSkillRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
            ForEach-Object { $_.Name } |
            Sort-Object -Unique
        )
    }

    $installedSet = @{}
    foreach ($skillName in $installedSkills) {
        $installedSet[[string]$skillName.ToLowerInvariant()] = $true
    }

    $bundleSkillSet = @{}
    foreach ($skillName in @($inventory.BundleSkills)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$skillName)) {
            $bundleSkillSet[[string]$skillName.ToLowerInvariant()] = $true
        }
    }
    $skillNames = @(
        @($inventory.BundleSkills) + @($inventory.RegistrySkills | ForEach-Object { $_.Name }) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
    $registrySkills = @(
        foreach ($skillName in $skillNames) {
            $key = [string]$skillName.ToLowerInvariant()
            [pscustomobject]@{
                Name    = $skillName
                Section = if ($bundleSkillSet.ContainsKey($key)) { 'bundle' } else { 'external' }
            }
        }
    )

    $skillStatus = @(
        for ($i = 0; $i -lt $registrySkills.Count; $i++) {
            $entry = $registrySkills[$i]
            $progressPercent = if ($registrySkills.Count -gt 0) { [int]((($i + 1) * 100) / $registrySkills.Count) } else { 100 }
            $detail = (ConvertFrom-BootstrapUtf8Base64String -Value 'ezB9L3sxfSDkuKogU2tpbGwg5bey5a6M5oiQ') -f ($i + 1), $registrySkills.Count
            $isComplete = (($i + 1) -ge $registrySkills.Count)
            $line = '  Skill {0,3}%  {1}' -f $progressPercent, $detail
            Write-BootstrapProgressLine -Line $line -Completed:$isComplete
            [pscustomobject]@{
                Name      = $entry.Name
                Kind      = $entry.Section
                Installed = $installedSet.ContainsKey([string]$entry.Name.ToLowerInvariant())
            }
        }
    )
    $newSkills = @($skillNames | Where-Object { -not $installedSet.ContainsKey([string]$_.ToLowerInvariant()) })

    return [pscustomobject]@{
        Profiles        = @($inventory.Profiles)
        BundleSkills    = @($inventory.BundleSkills)
        InstalledSkills = $installedSkills
        NewSkills       = $newSkills
        RegistrySkills  = $registrySkills
        SkillStatus     = $skillStatus
        McpStatus       = @()
        PrereqStatus    = @()
        ZipPath         = $skillBundlePath
        LocalSkillRoot  = $localSkillRoot
    }
}

function Show-TuiSkillStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    Write-TuiLoading `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+lIFNraWxsIOeKtuaAgQ==') `
        -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6K+75Y+WIFNraWxsIGJ1bmRsZSDlkozmnKzmnLogU2tpbGwg54q25oCB77yM6K+356iN5YCZLi4u') `
        -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+q6Kej5p6QIFNraWxsIOa4heWNleS4juacrOacuuWuieijheeKtuaAge+8jOS4jeajgOa1i+Wll+S7tuOAgU1DUCDmiJYgQ0xJ44CC')
    $summary = Get-BootstrapTuiSkillOnlySummary -Repo $Repo -Tag $Tag -DestinationRoot $DestinationRoot -Refresh $Refresh
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg54q25oCB')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'QnVuZGxlIFNraWxs'), $summary.BundleSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5pys5py65bey5a6J6KOF'), $summary.InstalledSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v6IO95paw5aKe'), $summary.NewSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v5pu05paw5YaF5a65'), (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWl5pe255Sx5LiJ5oCB5ZCM5q2l57un57ut5Yik5pat44CC')) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg5riF5Y2V') -ForegroundColor Yellow
        Write-Host ('{0,-36} {1,-12} {2}' -f `
            (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGw='), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '57G75Z6L'), `
            (ConvertFrom-BootstrapUtf8Base64String -Value '54q25oCB')) -ForegroundColor DarkGray
        foreach ($skill in $summary.SkillStatus | Sort-Object Name | Select-Object -First 24) {
            $statusText = if ($skill.Installed) { ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6J6KOF' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5a6J6KOF' }
            $color = if ($skill.Installed) { 'Gray' } else { 'Cyan' }
            Write-Host ('  {0,-34} {1,-12} {2}' -f $skill.Name, $skill.Kind, $statusText) -ForegroundColor $color
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5oiWIEIg6L+U5ZueICBRIOmAgOWHug==') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' { return $summary }
            'B' { return $summary }
            'Q' { return 'quit' }
        }
    }
}

function Show-TuiSuiteStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$Refresh
    )

    Write-TuiLoading `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu254q25oCB') `
        -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6K+75Y+W5aWX5Lu244CBTUNQIOWSjCBDTEkg54q25oCB77yM6K+356iN5YCZLi4u') `
        -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6K+75Y+W54q25oCB5Y+v6IO96ZyA6KaB5LiL6L295bm26Kej5p6QIHNraWxscy56aXDvvIzor7fnqI3lgJnjgII=')
    $summary = Get-BootstrapTuiSkillBundleSummary -Repo $Repo -Tag $Tag -DestinationRoot $DestinationRoot -Refresh $Refresh
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu254q25oCB')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZSDmlbDph48='), $summary.Profiles.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'QnVuZGxlIFNraWxs'), $summary.BundleSkills.Count) -ForegroundColor Gray
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value 'TUNQ77yaezB977yb5bey6YWN572u77yaezF9') -f $summary.McpStatus.Count, @($summary.McpStatus | Where-Object { $_.Configured }).Count) -ForegroundColor Gray
        Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q0xJ77yaezB977yb5bey5a6J6KOF77yaezF9') -f $summary.PrereqStatus.Count, @($summary.PrereqStatus | Where-Object { $_.Installed }).Count) -ForegroundColor Gray
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '6L+Z6YeM5bGV56S655qE5piv5aWX5Lu2IFByb2ZpbGXjgIFNQ1Ag6YWN572u5ZKMIENMSSDmo4DmtYvnirbmgIHjgII=') -ForegroundColor DarkGray
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5aWX5Lu25riF5Y2V') -ForegroundColor Yellow
        if ($summary.Profiles.Count -eq 0) {
            Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5Y+R546wIFByb2ZpbGXvvIzku43lj6/lronoo4Xlhajpg6ggU2tpbGzjgII=')) -ForegroundColor DarkGray
        }
        else {
            foreach ($profile in $summary.Profiles | Select-Object -First 12) {
                Write-Host ((ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIHswfe+8iFNraWxsIHsxfe+8m01DUCB7Mn3vvJtDTEkgezN977yJ') -f $profile.Name, @($profile.Skills).Count, @($profile.Mcp).Count, @($profile.Prereqs).Count) -ForegroundColor Gray
            }
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'TUNQIOeKtuaAge+8iOWJjSAxMiDkuKrvvIk=') -ForegroundColor Yellow
        foreach ($mcp in $summary.McpStatus | Select-Object -First 12) {
            $targetText = if (@($mcp.Targets).Count -gt 0) { @($mcp.Targets) -join ', ' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YWN572u' }
            Write-Host ('  - {0}: {1}' -f $mcp.Name, $targetText) -ForegroundColor Gray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0xJIOeKtuaAge+8iOWJjSAxMiDkuKrvvIk=') -ForegroundColor Yellow
        foreach ($cli in $summary.PrereqStatus | Select-Object -First 12) {
            $statusText = if ($cli.Installed) { ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6J6KOF' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5qOA5rWL5Yiw' }
            Write-Host ('  - {0}: {1}' -f $cli.Name, $statusText) -ForegroundColor Gray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5oiWIEIg6L+U5ZueICBRIOmAgOWHug==') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' { return $summary }
            'B' { return $summary }
            'Q' { return 'quit' }
        }
    }
}

function Get-TuiWorkbenchOptions {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$State
    )

    $options = New-Object System.Collections.Generic.List[object]
    foreach ($option in @($State.BaseOptions)) {
        $options.Add($option)
    }
    if ($State.SkipApps) {
        $options.Add((New-TuiOption -Key 'skipapps' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H6L2v5Lu25a6J6KOF') -SwitchName 'SkipApps' -Enabled $true))
    }
    if ($State.SkipSkills) {
        $options.Add((New-TuiOption -Key 'skipskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ==') -SwitchName 'SkipSkills' -Enabled $true))
    }
    elseif ($State.AllSkills) {
        $options.Add((New-TuiOption -Key 'allskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs') -SwitchName 'AllSkills' -Enabled $true))
    }
    elseif ($State.AllSuites) {
        $options.Add((New-TuiOption -Key 'allsuites' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu2') -SwitchName 'AllSuites' -Enabled $true))
    }

    return $options.ToArray()
}

function Get-TuiWorkbenchSummaryText {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$State
    )

    $softwareText = if ($State.SkipApps) {
        ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup6L2v5Lu2'
    }
    else {
        $State.AppLabel
    }
    $skillText = if ($State.SkipSkills) {
        ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oupIFNraWxs'
    }
    elseif ($State.AllSkills) {
        ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs'
    }
    elseif ($State.AllSuites) {
        ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu2'
    }
    elseif (@($State.SkillProfiles).Count -gt 0) {
        (ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZTogezB9') -f ($State.SkillProfiles -join ', ')
    }
    elseif ((@($State.SkillNames).Count + @($State.McpNames).Count + @($State.CliNames).Count) -gt 0) {
        (ConvertFrom-BootstrapUtf8Base64String -Value '5Y2V6aG577yaU2tpbGwgezB977ybTUNQIHsxfe+8m0NMSSB7Mn0=') -f @($State.SkillNames).Count, @($State.McpNames).Count, @($State.CliNames).Count
    }
    else {
        ConvertFrom-BootstrapUtf8Base64String -Value '5peg'
    }
    $scenarioText = if ($State.SkipSkills) {
        ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oupIFNraWxs'
    }
    else {
        switch ($State.SkillsManagerScenarioMode) {
            'default' { ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6buY6K6k5Zy65pmv' }
            'custom' { (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6Ieq5a6a5LmJ5Zy65pmv77yaezB9') -f $State.SkillsManagerScenarioName }
            'skip' { ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxscyBNYW5hZ2VyIOWcuuaZr+azqOWGjA==' }
            default { ConvertFrom-BootstrapUtf8Base64String -Value '5ZG95Luk5qih5byP6buY6K6k' }
        }
    }

    return [pscustomobject]@{
        Software = $softwareText
        Skill    = $skillText
        Scenario = $scenarioText
    }
}

function Show-TuiWorkbenchMenu {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$State
    )

    $hasRunnableSelection = -not ($State.SkipApps -and $State.SkipSkills)
    $actions = @(
        New-TuiWorkbenchAction -Action 'software' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsOi9r+S7tg==') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWI5qOA5p+l5pys5py654q25oCB77yM5YaN6YCJ5oup5pys5qyh6KaB5a6J6KOF5oiW5pu05paw55qE6L2v5Lu277yb6buY6K6k5YWo6YCJ5bu66K6u6aG577yM5Y+v55So56m65qC85Y676Zmk44CC')
        New-TuiWorkbenchAction -Action 'skill-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsOWll+S7tg==') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWI6K+75Y+W5aWX5Lu254q25oCB77yM5YaN6YCJ5oup5pys5qyh6KaB5a6J6KOF5oiW5pu05paw55qE5aWX5Lu277yb5pSv5oyB5YWo6YOoIFNraWxs44CB5omA5pyJ5aWX5Lu25oiW5aSa5LiqIFByb2ZpbGXjgII=')
        New-TuiWorkbenchAction -Action 'skill-component-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBTa2lsbA==') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWI6K+75Y+WIFNraWxsIOeKtuaAge+8jOWGjemAieaLqeacrOasoeimgeWuieijheaIluabtOaWsOeahCBTa2lsbO+8m+aUr+aMgSBidW5kbGVkIC8gZXh0ZXJuYWwgU2tpbGzjgII=')
        New-TuiWorkbenchAction -Action 'mcp-component-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBNQ1A=') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWI6K+75Y+WIE1DUCDnirbmgIHvvIzlho3pgInmi6nmnKzmrKHopoHlronoo4XmiJbmm7TmlrDnmoQgTUNQ77yb5Lya6Ieq5Yqo5aSE55CG5YW2IENMSSDliY3nva7kvp3otZbjgII=')
        New-TuiWorkbenchAction -Action 'cli-component-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBDTEk=') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWI6K+75Y+WIENMSSDnirbmgIHvvIzlho3pgInmi6nmnKzmrKHopoHlronoo4XmiJbmm7TmlrDnmoQgQ0xJIC8gcnVudGltZSDliY3nva7kvp3otZbjgII=')
    )
    if ($hasRunnableSelection) {
        $actions += New-TuiWorkbenchAction -Action 'review' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5byA5aeL5omn6KGM') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6L+b5YWl5pyA57uI56Gu6K6k6aG177yM56Gu6K6k5ZCO5byA5aeL5omn6KGM44CC')
    }
    $actions += @(
        New-TuiWorkbenchAction -Action 'back' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6L+U5Zue') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5Zue5Yiw6L+Q6KGM5qih5byP6YCJ5oup44CC')
    )

    $index = 0
    while ($true) {
        $summary = Get-TuiWorkbenchSummaryText -State $State
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5bel5L2c5Y+w')

        Write-TuiSection `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN6YCJ5oup') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6L+Z6YeM5pi+56S65bey6YCJ5oup55qE6L2v5Lu244CBU2tpbGwg5ZKM5Zy65pmv44CC')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6L2v5Lu2'), $summary.Software) -ForegroundColor DarkGray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGw='), $summary.Skill) -ForegroundColor DarkGray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Zy65pmv5rOo5YaM'), $summary.Scenario) -ForegroundColor DarkGray

        Write-TuiSection `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v5omn6KGM5Yqo5L2c') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup5LiL5LiA5q2l6KaB5qOA5p+l44CB6YCJ5oup5oiW5omn6KGM55qE5pON5L2c44CC')
        for ($i = 0; $i -lt $actions.Count; $i++) {
            $action = $actions[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $action.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $action.Detail) -ForegroundColor DarkGray
        }

        Write-TuiSection `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5pON5L2c5o+Q56S6') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5L2/55So5pa55ZCR6ZSu56e75Yqo77yMRW50ZXIg56Gu6K6k44CC')
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray
        Complete-TuiFrame
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($actions.Count - 1)) { $index++ } }
            'Enter' { return $actions[$index].Action }
            'B' { return 'back' }
            'Q' { return 'quit' }
        }
    }
}

function Invoke-BootstrapTuiWorkbench {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps,
        [object[]]$SkillProfiles = @(),
        [object[]]$InitialOptions = @(),
        [Parameter(Mandatory)]
        [string]$BootstrapAssetsRepo,
        [Parameter(Mandatory)]
        [string]$BootstrapAssetsTag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$RefreshSkillBundle,
        [string]$InitialSkillsManagerScenarioMode = 'skip',
        [string]$InitialSkillsManagerScenarioName
    )

    $availableSkillProfiles = @($SkillProfiles)
    $baseOptions = @($InitialOptions | Where-Object { $_.SwitchName -notin @('SkipApps', 'SkipSkills', 'AllSkills', 'AllSuites') })
    $state = [pscustomobject]@{
        AppKeys                   = @()
        AppLabel                  = ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup'
        SkipApps                  = $true
        SkipSkills                = $true
        AllSkills                 = $false
        AllSuites                 = $false
        SkillProfiles             = @()
        SkillNames                = @()
        McpNames                  = @()
        CliNames                  = @()
        BundleSkillCount          = 0
        RegistrySkillEntries      = @()
        SkillStatus               = @()
        RegistryMcpEntries        = @()
        RegistryPrereqEntries     = @()
        AvailableSkillProfiles    = @($availableSkillProfiles)
        SkillRegistryLoaded       = $false
        ComponentRegistryLoaded   = $false
        SkillsManagerScenarioMode = if ([string]::IsNullOrWhiteSpace($InitialSkillsManagerScenarioMode) -or $InitialSkillsManagerScenarioMode -eq 'prompt') { 'skip' } else { $InitialSkillsManagerScenarioMode }
        SkillsManagerScenarioName = $InitialSkillsManagerScenarioName
        BaseOptions               = $baseOptions
    }

    function Update-TuiSkillStateFromSummary {
        param(
            [Parameter(Mandatory)]
            [object]$Summary,
            [switch]$ComponentStatus
        )

        $state.AvailableSkillProfiles = @($Summary.Profiles)
        $state.BundleSkillCount = @($Summary.BundleSkills).Count
        $state.SkillStatus = @($Summary.SkillStatus)
        if ($state.SkillStatus.Count -gt 0) {
            $state.RegistrySkillEntries = @($state.SkillStatus | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Section = $_.Kind } })
        }
        else {
            $state.RegistrySkillEntries = @($Summary.RegistrySkills)
        }
        if ($ComponentStatus) {
            $state.RegistryMcpEntries = @($Summary.McpStatus)
            $state.RegistryPrereqEntries = @($Summary.PrereqStatus)
            $state.ComponentRegistryLoaded = $true
        }
        $state.SkillRegistryLoaded = $true
    }

    function Ensure-TuiSkillRegistry {
        if ($state.SkillRegistryLoaded) {
            return
        }

        Write-TuiLoading `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwgQnVuZGxlIOWHhuWkhw==') `
            -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6K+75Y+WIFNraWxsIGJ1bmRsZSDlkozmnKzmnLogU2tpbGwg54q25oCB77yM6K+356iN5YCZLi4u') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+q6Kej5p6QIFNraWxsIOa4heWNleS4juacrOacuuWuieijheeKtuaAge+8jOS4jeajgOa1i+Wll+S7tuOAgU1DUCDmiJYgQ0xJ44CC')
        $skillSummary = Get-BootstrapTuiSkillOnlySummary -Repo $BootstrapAssetsRepo -Tag $BootstrapAssetsTag -DestinationRoot $DestinationRoot -Refresh $RefreshSkillBundle
        Update-TuiSkillStateFromSummary -Summary $skillSummary
    }

    function Ensure-TuiComponentRegistry {
        if ($state.ComponentRegistryLoaded) {
            return
        }

        Write-TuiLoading `
            -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5aWX5Lu244CBTUNQgLyBDTEkg54q25oCB') `
            -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo6K+75Y+W5aWX5Lu244CBTUNQIOWSjCBDTEkg54q25oCB77yM6K+356iN5YCZLi4u') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6K+75Y+W54q25oCB5Y+v6IO96ZyA6KaB5LiL6L295bm26Kej5p6QIHNraWxscy56aXDvvJvmnKzova7oh6rlrprkuYnmqKHlvI/kvJrlpI3nlKjor6Xnu5PmnpzjgII=')
        $skillSummary = Get-BootstrapTuiSkillBundleSummary -Repo $BootstrapAssetsRepo -Tag $BootstrapAssetsTag -DestinationRoot $DestinationRoot -Refresh $RefreshSkillBundle
        Update-TuiSkillStateFromSummary -Summary $skillSummary -ComponentStatus
    }

    while ($true) {
        $action = Show-TuiWorkbenchMenu -State $state
        switch ($action) {
            'software' {
                $selection = Show-TuiSoftwareActionSelection -Apps $Apps
                if ($selection -eq 'quit') { return $null }
                if ($null -ne $selection) {
                    $state.AppKeys = @($selection.AppKeys)
                    $state.AppLabel = $selection.Label
                    $state.SkipApps = $false
                }
            }
            'skill-install' {
                Ensure-TuiSkillRegistry
                $skillSelection = Show-TuiSkillProfileSelection -Profiles @($state.AvailableSkillProfiles) -BundleSkillCount $state.BundleSkillCount -RegistrySkillCount (@($state.RegistrySkillEntries).Count) -InstalledSkillCount (@($state.SkillStatus | Where-Object { $_.Installed }).Count) -NewSkillCount (@($state.SkillStatus | Where-Object { -not $_.Installed }).Count)
                if ($skillSelection -eq 'quit') { return $null }
                if ($null -ne $skillSelection) {
                    if ($skillSelection.SkipSkills) {
                        $state.SkipSkills = $true
                        $state.AllSkills = $false
                        $state.AllSuites = $false
                        $state.SkillProfiles = @()
                        $state.SkillNames = @()
                        $state.McpNames = @()
                        $state.CliNames = @()
                        continue
                    }

                    $scenarioSelection = Show-TuiSkillsManagerScenarioSelection -InitialMode $state.SkillsManagerScenarioMode -InitialName $state.SkillsManagerScenarioName
                    if ($scenarioSelection -eq 'quit') { return $null }
                    if ($null -eq $scenarioSelection) { continue }

                    $state.SkipSkills = $false
                    $state.AllSkills = [bool]$skillSelection.AllSkills
                    $state.AllSuites = [bool]$skillSelection.AllSuites
                    $state.SkillProfiles = @($skillSelection.SkillProfiles)
                    $state.SkillNames = @()
                    $state.McpNames = @()
                    $state.CliNames = @()
                    $state.SkillsManagerScenarioMode = $scenarioSelection.Mode
                    $state.SkillsManagerScenarioName = $scenarioSelection.Name
                }
            }
            'skill-component-install' {
                Ensure-TuiSkillRegistry
                $skillEntries = @($state.SkillStatus | ForEach-Object {
                        $entry = $_
                        $statusText = if ($entry.Installed) { ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6J6KOF' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5a6J6KOF' }
                        [pscustomobject]@{ Name = $entry.Name; Status = $statusText; Description = [string]$entry.Kind }
                    })
                $selection = Show-TuiComponentSelection -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBTa2lsbA==') -TypeName 'Skill' -Entries $skillEntries
                if ($selection -eq 'quit') { return $null }
                if ($null -ne $selection) {
                    $scenarioSelection = Show-TuiSkillsManagerScenarioSelection -InitialMode $state.SkillsManagerScenarioMode -InitialName $state.SkillsManagerScenarioName
                    if ($scenarioSelection -eq 'quit') { return $null }
                    if ($null -eq $scenarioSelection) { continue }
                    $state.SkipApps = $true
                    $state.SkipSkills = $false
                    $state.AllSkills = $false
                    $state.AllSuites = $false
                    $state.SkillProfiles = @()
                    $state.SkillNames = @($selection)
                    $state.SkillsManagerScenarioMode = $scenarioSelection.Mode
                    $state.SkillsManagerScenarioName = $scenarioSelection.Name
                }
            }
            'mcp-component-install' {
                Ensure-TuiComponentRegistry
                $mcpEntries = @($state.RegistryMcpEntries | ForEach-Object {
                        $entry = $_
                        $statusText = if ($entry.Configured) {
                            $targetsText = if (@($entry.Targets).Count -gt 0) { @($entry.Targets) -join ', ' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YWN572u' }
                            '{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YWN572u'), $targetsText
                        }
                        else {
                            ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YWN572u'
                        }
                        [pscustomobject]@{ Name = $entry.Name; Status = $statusText; Description = $statusText }
                    })
                $selection = Show-TuiComponentSelection -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBNQ1A=') -TypeName 'MCP' -Entries $mcpEntries
                if ($selection -eq 'quit') { return $null }
                if ($null -ne $selection) {
                    $state.SkipApps = $true
                    $state.SkipSkills = $false
                    $state.AllSkills = $false
                    $state.AllSuites = $false
                    $state.SkillProfiles = @()
                    $state.McpNames = @($selection)
                    $state.SkillNames = @()
                    $state.CliNames = @()
                    $state.SkillsManagerScenarioMode = 'skip'
                    $state.SkillsManagerScenarioName = ''
                }
            }
            'cli-component-install' {
                Ensure-TuiComponentRegistry
                $cliEntries = @($state.RegistryPrereqEntries | ForEach-Object {
                        $entry = $_
                        $statusText = if ($entry.Installed) { ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6J6KOF' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5qOA5rWL5Yiw' }
                        [pscustomobject]@{ Name = $entry.Name; Status = $statusText; Description = ('{0}; {1}' -f $entry.Kind, $statusText) }
                    })
                $selection = Show-TuiComponentSelection -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFL+abtOaWsCBDTEk=') -TypeName 'CLI' -Entries $cliEntries
                if ($selection -eq 'quit') { return $null }
                if ($null -ne $selection) {
                    $state.SkipApps = $true
                    $state.SkipSkills = $false
                    $state.AllSkills = $false
                    $state.AllSuites = $false
                    $state.SkillProfiles = @()
                    $state.CliNames = @($selection)
                    $state.SkillNames = @()
                    $state.McpNames = @()
                    $state.SkillsManagerScenarioMode = 'skip'
                    $state.SkillsManagerScenarioName = ''
                }
            }
            'review' {
                if ($state.SkipApps -and $state.SkipSkills) {
                    Write-Host ''
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bCa5pyq6YCJ5oup5Lu75L2V5omn6KGM5Yqo5L2c44CC6K+35YWI6YCJ5oup6L2v5Lu25a6J6KOF5oiWIFNraWxsIOWuieijheOAgg==') -ForegroundColor Yellow
                    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
                    [void][Console]::ReadKey($true)
                    continue
                }

                $options = @(Get-TuiWorkbenchOptions -State $state)
                $review = Show-TuiReview `
                    -SelectedAppKeys @($state.AppKeys) `
                    -Options $options `
                    -SkillProfiles @($state.SkillProfiles) `
                    -SkillNames @($state.SkillNames) `
                    -McpNames @($state.McpNames) `
                    -CliNames @($state.CliNames) `
                    -SkillsManagerScenarioMode $state.SkillsManagerScenarioMode `
                    -SkillsManagerScenarioName $state.SkillsManagerScenarioName `
                    -ModeName (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5qih5byP') `
                    -IncludeOnly:(!$state.SkipApps)
                if ($review -eq 'quit') { return $null }
                if ($null -eq $review) { continue }

                return New-TuiBootstrapResult -Only @($state.AppKeys) -Options $review.Options -SkillProfiles @($state.SkillProfiles) -SkillNames @($state.SkillNames) -McpNames @($state.McpNames) -CliNames @($state.CliNames) -SkillsManagerScenarioMode $state.SkillsManagerScenarioMode -SkillsManagerScenarioName $state.SkillsManagerScenarioName
            }
            'back' {
                return 'back'
            }
            'quit' {
                return $null
            }
        }
    }
}

function Invoke-BootstrapTui {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps,
        [object[]]$SkillProfiles = @(),
        [object[]]$InitialOptions = @(),
        [string[]]$InitialSkillProfiles = @(),
        [string]$InitialSkillsManagerScenarioMode = 'prompt',
        [string]$InitialSkillsManagerScenarioName,
        [Parameter(Mandatory)]
        [string]$BootstrapAssetsRepo,
        [Parameter(Mandatory)]
        [string]$BootstrapAssetsTag,
        [Parameter(Mandatory)]
        [string]$DestinationRoot,
        [Parameter(Mandatory)]
        [bool]$RefreshSkillBundle
    )

    $allAppKeys = @($Apps | ForEach-Object { $_.key })
    $availableSkillProfiles = @($SkillProfiles)

    while ($true) {
        $selectedMode = Show-TuiModeSelection
        if ($null -eq $selectedMode) {
            return $null
        }

        if ($selectedMode -eq 'original') {
            return New-TuiBootstrapResult -Only $null -Options $InitialOptions -SkillProfiles $InitialSkillProfiles -SkillsManagerScenarioMode $InitialSkillsManagerScenarioMode -SkillsManagerScenarioName $InitialSkillsManagerScenarioName -UseDefaultInstall
        }

        if ($selectedMode -eq 'dryrun') {
            $options = @(
                New-TuiOption -Key 'dryrun' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD5qih5byP77yI5LiN55yf5q2j5a6J6KOF77yJ') -SwitchName 'DryRun' -Enabled $true
                New-TuiOption -Key 'skipcc' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIENDIFN3aXRjaCBQcm92aWRlciDlr7zlhaU=') -SwitchName 'SkipCcSwitch' -Enabled $true
                New-TuiOption -Key 'allskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5YWo6YOoIFNraWxs') -SwitchName 'AllSkills' -Enabled $true
                New-TuiOption -Key 'noorphan' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5penIFNraWxsIOebruW9leS4jeabv+aNou+8jOWPqui3s+i/hw==') -SwitchName 'NoReplaceOrphan' -Enabled $true
                New-TuiOption -Key 'skipmanager' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWlIFNraWxsIOWQjuS4jeiHquWKqOWQr+WKqCBTa2lsbHMgTWFuYWdlcg==') -SwitchName 'SkipSkillsManagerLaunch' -Enabled $true
            )
            $review = Show-TuiReview `
                -SelectedAppKeys $allAppKeys `
                -Options $options `
                -SkillsManagerScenarioMode 'skip' `
                -ModeName (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J5YWo5ryU57uD') `
                -IncludeOnly
            if ($review -eq 'quit') {
                return $null
            }
            if ($null -eq $review) {
                continue
            }

            return New-TuiBootstrapResult -Only $allAppKeys -Options $options -SkillsManagerScenarioMode 'skip'
        }

        if ($selectedMode -ne 'workbench') {
            continue
        }

        $workbenchResult = Invoke-BootstrapTuiWorkbench `
            -Apps $Apps `
            -SkillProfiles $availableSkillProfiles `
            -InitialOptions $InitialOptions `
            -BootstrapAssetsRepo $BootstrapAssetsRepo `
            -BootstrapAssetsTag $BootstrapAssetsTag `
            -DestinationRoot $DestinationRoot `
            -RefreshSkillBundle $RefreshSkillBundle `
            -InitialSkillsManagerScenarioMode $InitialSkillsManagerScenarioMode `
            -InitialSkillsManagerScenarioName $InitialSkillsManagerScenarioName
        if ($workbenchResult -eq 'back') {
            continue
        }

        return $workbenchResult
    }
}

function Set-BootstrapBoundSwitchParameter {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [bool]$Present
    )

    if ($Present) {
        $BoundParameters[$Name] = [System.Management.Automation.SwitchParameter]$true
    }
    else {
        [void]$BoundParameters.Remove($Name)
    }
}

function ConvertTo-BootstrapNonEmptyStringArray {
    param(
        [AllowNull()]
        [object]$Value
    )

    return @(
        $Value |
        ForEach-Object {
            if ($null -ne $_) {
                [string]$_
            }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Test-BootstrapShouldUseTui {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters,
        [switch]$TuiSwitch
    )

    if ($BoundParameters.ContainsKey('BootstrapTuiResolved')) {
        return $false
    }

    if ($TuiSwitch.IsPresent) {
        return $true
    }

    $ignoredParameters = @(
        'PauseOnExit',
        'KeepShellOpen',
        'UserHomeOverride',
        'BootstrapSourceRoot',
        'BootstrapAssetsRepo',
        'BootstrapAssetsTag',
        'RefreshBootstrapDependencies'
    )

    foreach ($name in $BoundParameters.Keys) {
        if ($name -eq 'Tui' -or ($ignoredParameters -contains $name)) {
            continue
        }

        return $false
    }

    return $true
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($BootstrapSourceRoot)) {
    $localDependenciesReady = (Test-Path -LiteralPath (Join-Path $root 'modules\common.psm1')) -and (Test-Path -LiteralPath (Join-Path $root 'manifest\apps.json'))
    if ($localDependenciesReady) {
        $BootstrapSourceRoot = $root
    }
    else {
        $BootstrapSourceRoot = 'https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'
    }
}

$bootstrapDependencies = @(
    'modules/common.psm1',
    'manifest/apps.json'
)

Write-BootstrapSection `
    -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5q2l6aqk5LiA77ya6I635Y+W5L6d6LWW') `
    -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5ZCM5q2l5ZCv5Yqo6ISa5pys44CB5qih5Z2X44CB5bqU55So5riF5Y2V5ZKM5pys5Zyw6LWE5Lqn44CC')
Sync-BootstrapDependencies `
    -SourceRoot $BootstrapSourceRoot `
    -DestinationRoot $root `
    -Dependencies $bootstrapDependencies `
    -Refresh:$RefreshBootstrapDependencies

Import-Module (Join-Path $root 'modules\common.psm1') -Force

$effectiveUserHome = Get-OriginalUserHomeDirectory
if (-not [string]::IsNullOrWhiteSpace($effectiveUserHome)) {
    $env:VIBE_CODING_USER_HOME = $effectiveUserHome
}

$manifestPath = Join-Path $root 'manifest\apps.json'
$manifest = Get-AppManifest -ManifestPath $manifestPath
$shouldUseTui = Test-BootstrapShouldUseTui -BoundParameters $PSBoundParameters -TuiSwitch:$Tui
$skillBundlePath = Join-Path $root 'downloads\skills.zip'

if ($shouldUseTui) {
    Set-BootstrapEnglishInputLayout
    $tuiInitialOptions = @(
        if ($DryRun) { New-TuiOptionForSwitch -SwitchName 'DryRun' }
        if ($SkipCcSwitch) { New-TuiOptionForSwitch -SwitchName 'SkipCcSwitch' }
        if ($SkipApps) { New-TuiOption -Key 'skipapps' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H6L2v5Lu25a6J6KOF') -SwitchName 'SkipApps' -Enabled $true }
        if ($SkipSkills) { New-TuiOption -Key 'skipskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ==') -SwitchName 'SkipSkills' -Enabled $true }
        if ($AllSkills) { New-TuiOption -Key 'allskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs') -SwitchName 'AllSkills' -Enabled $true }
        if ($AllSuites) { New-TuiOption -Key 'allsuites' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5omA5pyJ5aWX5Lu2') -SwitchName 'AllSuites' -Enabled $true }
        if ($NoReplaceOrphan) { New-TuiOptionForSwitch -SwitchName 'NoReplaceOrphan' }
        if ($ReplaceForeign) { New-TuiOptionForSwitch -SwitchName 'ReplaceForeign' }
        if ($RenameForeign) { New-TuiOptionForSwitch -SwitchName 'RenameForeign' }
        if ($SkipSkillsManagerLaunch) { New-TuiOptionForSwitch -SwitchName 'SkipSkillsManagerLaunch' }
        if ($RefreshBootstrapDependencies) { New-TuiOptionForSwitch -SwitchName 'RefreshBootstrapDependencies' }
    )
    $initialSkillProfiles = @(ConvertTo-BootstrapNonEmptyStringArray -Value $SkillProfile)
    $shouldRefreshSkillBundle = $RefreshBootstrapDependencies.IsPresent -or (Test-HttpSourceRoot -SourceRoot $BootstrapSourceRoot)
    $tuiResult = Invoke-BootstrapTui `
        -Apps $manifest.apps `
        -InitialOptions $tuiInitialOptions `
        -InitialSkillProfiles $initialSkillProfiles `
        -InitialSkillsManagerScenarioMode $SkillsManagerScenarioMode `
        -InitialSkillsManagerScenarioName $SkillsManagerScenarioName `
        -BootstrapAssetsRepo $BootstrapAssetsRepo `
        -BootstrapAssetsTag $BootstrapAssetsTag `
        -DestinationRoot $root `
        -RefreshSkillBundle $shouldRefreshSkillBundle
    if ($null -eq $tuiResult) {
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5Y+W5raI44CC')
        $script:BootstrapUserCancelled = $true
        Invoke-BootstrapExit -Code 0
    }

    $Only = $tuiResult.Only
    $SkillProfile = @(ConvertTo-BootstrapNonEmptyStringArray -Value $tuiResult.SkillProfile)
    $SkillName = @(ConvertTo-BootstrapNonEmptyStringArray -Value $tuiResult.SkillName)
    $McpName = @(ConvertTo-BootstrapNonEmptyStringArray -Value $tuiResult.McpName)
    $CliName = @(ConvertTo-BootstrapNonEmptyStringArray -Value $tuiResult.CliName)
    $SkillsManagerScenarioMode = if ([string]::IsNullOrWhiteSpace([string]$tuiResult.SkillsManagerScenarioMode)) { 'prompt' } else { [string]$tuiResult.SkillsManagerScenarioMode }
    $SkillsManagerScenarioName = [string]$tuiResult.SkillsManagerScenarioName
    $DryRun = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.DryRun)
    $SkipCcSwitch = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipCcSwitch)
    $SkipApps = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipApps)
    $SkipSkills = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipSkills)
    $AllSkills = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.AllSkills)
    $AllSuites = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.AllSuites)
    $NoReplaceOrphan = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.NoReplaceOrphan)
    $ReplaceForeign = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.ReplaceForeign)
    $RenameForeign = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.RenameForeign)
    $SkipSkillsManagerLaunch = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipSkillsManagerLaunch)
    $RefreshBootstrapDependencies = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.RefreshBootstrapDependencies)
    $Tui = [System.Management.Automation.SwitchParameter]$false

    [void]$PSBoundParameters.Remove('Tui')
    $PSBoundParameters['BootstrapTuiResolved'] = [System.Management.Automation.SwitchParameter]$true
    if ($null -eq $Only -or $Only.Count -eq 0) {
        [void]$PSBoundParameters.Remove('Only')
    }
    else {
        $PSBoundParameters['Only'] = $Only
    }
    if ($SkillProfile.Count -eq 0) {
        [void]$PSBoundParameters.Remove('SkillProfile')
    }
    else {
        $PSBoundParameters['SkillProfile'] = $SkillProfile
    }
    if ($SkillName.Count -eq 0) {
        [void]$PSBoundParameters.Remove('SkillName')
    }
    else {
        $PSBoundParameters['SkillName'] = $SkillName
    }
    if ($McpName.Count -eq 0) {
        [void]$PSBoundParameters.Remove('McpName')
    }
    else {
        $PSBoundParameters['McpName'] = $McpName
    }
    if ($CliName.Count -eq 0) {
        [void]$PSBoundParameters.Remove('CliName')
    }
    else {
        $PSBoundParameters['CliName'] = $CliName
    }
    if ([string]::IsNullOrWhiteSpace($SkillsManagerScenarioMode) -or $SkillsManagerScenarioMode -eq 'prompt') {
        [void]$PSBoundParameters.Remove('SkillsManagerScenarioMode')
    }
    else {
        $PSBoundParameters['SkillsManagerScenarioMode'] = $SkillsManagerScenarioMode
    }
    if ([string]::IsNullOrWhiteSpace($SkillsManagerScenarioName)) {
        [void]$PSBoundParameters.Remove('SkillsManagerScenarioName')
    }
    else {
        $PSBoundParameters['SkillsManagerScenarioName'] = $SkillsManagerScenarioName
    }
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'DryRun' -Present ([bool]$DryRun)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'SkipCcSwitch' -Present ([bool]$SkipCcSwitch)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'SkipApps' -Present ([bool]$SkipApps)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'SkipSkills' -Present ([bool]$SkipSkills)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'AllSkills' -Present ([bool]$AllSkills)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'AllSuites' -Present ([bool]$AllSuites)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'NoReplaceOrphan' -Present ([bool]$NoReplaceOrphan)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'ReplaceForeign' -Present ([bool]$ReplaceForeign)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'RenameForeign' -Present ([bool]$RenameForeign)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'SkipSkillsManagerLaunch' -Present ([bool]$SkipSkillsManagerLaunch)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'RefreshBootstrapDependencies' -Present ([bool]$RefreshBootstrapDependencies)
}

if (-not $DryRun -and -not (Test-IsAdministrator)) {
    if (-not $PSBoundParameters.ContainsKey('UserHomeOverride') -and -not [string]::IsNullOrWhiteSpace($effectiveUserHome)) {
        $PSBoundParameters['UserHomeOverride'] = $effectiveUserHome
    }

    $relaunchArgs = @(ConvertTo-ArgumentTokens -BoundParameters $PSBoundParameters)
    $argumentList = New-Object System.Collections.Generic.List[string]
    if ($PauseOnExit) {
        $argumentList.Add('-NoExit')
        if (-not $PSBoundParameters.ContainsKey('KeepShellOpen')) {
            $relaunchArgs += '-KeepShellOpen'
        }
    }

    foreach ($token in @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $PSCommandPath)
        )) {
        $argumentList.Add([string]$token)
    }

    foreach ($token in $relaunchArgs) {
        $argumentList.Add([string]$token)
    }

    Write-Host ''
    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '6ZyA6KaB566h55CG5ZGY5p2D6ZmQ77yM5q2j5Zyo6K+35rGCIFVBQyDmj5DmnYMuLi4=')
    Start-BootstrapElevatedShell -PowerShellArguments $argumentList.ToArray()
    $script:BootstrapAdminHandoffStarted = $true
    Invoke-BootstrapExit -Code 0
}

$selectedApps = @()
if (-not $SkipApps) {
    Write-BootstrapSection `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5q2l6aqk5LqM77ya5bqU55So5a6J6KOF') `
        -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5bm25a6J6KOFIC8g5pu05paw5pys5py65bqU55So44CC')
    $selectedApps = @(Get-SelectedApps -Apps $manifest.apps -Only $Only)
}

$appPrecheckByKey = @{}
if (-not $SkipApps -and $selectedApps.Count -gt 0) {
    foreach ($precheck in @(Get-AppInstallDecisionBatch -Definitions $selectedApps)) {
        $appPrecheckByKey[[string]$precheck.Key] = $precheck
    }
    Write-BootstrapAppPlan -Apps $selectedApps -PrecheckByKey $appPrecheckByKey
}

Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bel5L2c5Yy677yaezB9') -f $root)
Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5qih5byP77yaezB9') -f ($(if ($DryRun) { ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF' })))
if ($SkipApps) {
    Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF6K6h5YiS')
    Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIOi3s+i/h+i9r+S7tuWuieijhQ==')
}

$shouldRunCcSwitchConfig = (-not $SkipCcSwitch -and ($selectedApps | Where-Object { $_.key -eq 'cc-switch' }))
$results = New-Object System.Collections.Generic.List[object]

$appsToRun = New-Object System.Collections.Generic.List[object]
foreach ($app in ($selectedApps | Sort-Object order)) {
    $appPrecheck = $appPrecheckByKey[[string]$app.key]
    if ($null -ne $appPrecheck) {
        $precheckResult = New-BootstrapAppPrecheckResult -App $app -Precheck $appPrecheck
        if ($null -ne $precheckResult) {
            $results.Add($precheckResult)
            continue
        }
    }

    $appsToRun.Add($app)
}

if (-not $SkipApps -and $appsToRun.Count -eq 0) {
    Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value '5rKh5pyJ6ZyA6KaB5a6J6KOF5oiW5pu05paw55qE5bqU55So44CC')
}

$progressTotalSteps = 1 + $appsToRun.Count
if (-not $SkipSkills) {
    $progressTotalSteps++
}
if ($shouldRunCcSwitchConfig) {
    $progressTotalSteps++
}
$progressCompletedSteps = 0

try {
    $workspaceResult = Initialize-CodexWorkspaceDirectory -DryRun:$DryRun
    $results.Add($workspaceResult)
    $progressCompletedSteps++
}
catch {
    $results.Add([pscustomobject]@{
            Name   = (ConvertFrom-BootstrapUtf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
            Key    = 'codex-workspace'
            Status = 'failed'
            Source = 'filesystem'
            Detail = $_.Exception.Message
        })
    Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy66K6+572u5aSx6LSl77yaezB9') -f $_.Exception.Message)
    $progressCompletedSteps++
}

$appInstallIndex = 0
foreach ($app in $appsToRun) {
    $appInstallIndex++
    try {
        $appPrecheck = $appPrecheckByKey[[string]$app.key]
        $installDecision = if ($null -ne $appPrecheck) { $appPrecheck.Decision } else { $null }
        $appProgressStatus = if ($null -ne $installDecision -and $installDecision.Reason -eq 'outdated') {
            (ConvertFrom-BootstrapUtf8Base64String -Value '5YeG5aSH5pu05paw5bqU55So77yaezB9ICh7MX0vezJ9KQ==') -f $app.name, $appInstallIndex, $appsToRun.Count
        }
        elseif ($null -ne $installDecision -and $installDecision.Action -ne 'install') {
            (ConvertFrom-BootstrapUtf8Base64String -Value '5YeG5aSH5aSE55CG5bqU55So77yaezB9ICh7MX0vezJ9KQ==') -f $app.name, $appInstallIndex, $appsToRun.Count
        }
        else {
            (ConvertFrom-BootstrapUtf8Base64String -Value '5YeG5aSH5a6J6KOF5bqU55So77yaezB9ICh7MX0vezJ9KQ==') -f $app.name, $appInstallIndex, $appsToRun.Count
        }
        Write-BootstrapProgress -CompletedSteps $progressCompletedSteps -TotalSteps $progressTotalSteps -Status $appProgressStatus
        $result = Install-AppFromDefinition -Definition $app -WorkspaceRoot $root -InstallDecision $installDecision -DryRun:$DryRun
        $results.Add($result)
        $progressCompletedSteps++
        Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQ5bqU55So77yaezB977yb54q25oCBPXsxfQ==') -f $app.name, (ConvertTo-BootstrapDisplayStatus -Status $result.Status))
    }
    catch {
        $results.Add([pscustomobject]@{
                Name   = $app.name
                Key    = $app.key
                Status = 'failed'
                Source = $app.strategy
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'ezB9IOWuieijheWksei0pe+8mnsxfQ==') -f $app.name, $_.Exception.Message)
        $progressCompletedSteps++
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bqU55So5aSx6LSl77yaezB977yb54q25oCBPeWksei0pQ==') -f $app.name)
    }
}

if ($shouldRunCcSwitchConfig) {
    Write-BootstrapSection `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5q2l6aqk5LiJ77ya6YWN572u5a+85YWl') `
        -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWlIENDIFN3aXRjaCBQcm92aWRlciDnrYnpu5jorqTphY3nva7jgII=')
    try {
        $providerNameToCheck = $CcSwitchProviderName
        if ([string]::IsNullOrWhiteSpace($providerNameToCheck)) {
            $providerNameToCheck = $env:VIBE_CODING_PROVIDER_NAME
        }
        if ([string]::IsNullOrWhiteSpace($providerNameToCheck)) {
            $providerNameToCheck = 'IndieArk API 2'
        }

        $existingProvider = $null
        try {
            $existingProvider = Get-CcSwitchProviderByName -ProviderName $providerNameToCheck
        }
        catch {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIHByb3ZpZGVyIOmihOajgOafpeWksei0pe+8jOaUueS4uuS6pOS6kuW8j+i+k+WFpe+8mnswfQ==') -f $_.Exception.Message)
        }

        if ($existingProvider) {
            Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIOW3suWtmOWcqCBjb2RleCBwcm92aWRlciDigJx7MH3igJ3vvIzot7Pov4cgcHJvdmlkZXIg6L6T5YWl5ZKM5a+85YWl') -f $providerNameToCheck)
            $results.Add([pscustomobject]@{
                    Name   = (ConvertFrom-BootstrapUtf8Base64String -Value '6YWN572u5a+85YWl')
                    Key    = 'cc-switch-provider'
                    Status = 'ok'
                    Source = 'precheck-skip'
                    Detail = ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5om+5Yiw546w5pyJIHByb3ZpZGVy77yaezB9') -f $providerNameToCheck)
                })
        }
        else {
            $providerInfo = Read-CodexProviderInput `
                -PresetName $CcSwitchProviderName `
                -PresetBaseUrl $CcSwitchBaseUrl `
                -PresetModel $CcSwitchModel `
                -PresetApiKey $CcSwitchApiKey
            $ccSwitchInstallResult = @($results | Where-Object { $_.Key -eq 'cc-switch' } | Select-Object -Last 1)
            $ccSwitchInstalledThisRun = $false
            if ($ccSwitchInstallResult.Count -gt 0) {
                $ccSwitchInstalledThisRun = ($ccSwitchInstallResult[0].Status -eq 'ok' -and $ccSwitchInstallResult[0].Source -ne 'precheck-skip')
            }

            $ccResult = Import-CcSwitchCodexProvider `
                -ProviderInfo $providerInfo `
                -ForceWarmup:$ccSwitchInstalledThisRun `
                -DryRun:$DryRun
            $results.Add($ccResult)
            Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQIENDIFN3aXRjaCBQcm92aWRlciDlr7zlhaXvvJvnirbmgIE9ezB9') -f (ConvertTo-BootstrapDisplayStatus -Status $ccResult.Status))
        }
        $progressCompletedSteps++
    }
    catch {
        $results.Add([pscustomobject]@{
                Name   = (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIFByb3ZpZGVyIOWvvOWFpQ==')
                Key    = 'cc-switch-provider'
                Status = 'failed'
                Source = 'ccswitch-deeplink'
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIFByb3ZpZGVyIOWvvOWFpeWksei0pe+8mnswfQ==') -f $_.Exception.Message)
        $progressCompletedSteps++
        Write-Log -Level 'ERROR' -Message (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIFByb3ZpZGVyIOWvvOWFpeWksei0pe+8m+eKtuaAgT3lpLHotKU=')
    }
}

if (-not $SkipSkills) {
    Write-BootstrapSection `
        -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5q2l6aqk5Zub77ya5o+S5Lu25a6J6KOF') `
        -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOFIFNraWxs44CB5aWX5Lu244CBTUNQIOWSjCBDTEkg5YmN572u5L6d6LWW44CC')
    try {
        $shouldRefreshSkillBundle = $RefreshBootstrapDependencies.IsPresent -or (Test-HttpSourceRoot -SourceRoot $BootstrapSourceRoot)
        Sync-BootstrapSkillBundleAsset `
            -Repo $BootstrapAssetsRepo `
            -Tag $BootstrapAssetsTag `
            -DestinationRoot $root `
            -Refresh:$shouldRefreshSkillBundle
        $skillResult = Install-SkillBundle `
            -ZipPath $skillBundlePath `
            -SkillProfiles $SkillProfile `
            -SkillNames $SkillName `
            -McpNames $McpName `
            -PrereqNames $CliName `
            -AllSkills:$AllSkills `
            -AllSuites:$AllSuites `
            -NoReplaceOrphan:$NoReplaceOrphan `
            -ReplaceForeign:$ReplaceForeign `
            -RenameForeign:$RenameForeign `
            -SkipSkillsManagerLaunch:$SkipSkillsManagerLaunch `
            -SkillsManagerScenarioMode $SkillsManagerScenarioMode `
            -SkillsManagerScenarioName $SkillsManagerScenarioName `
            -DryRun:$DryRun
        $results.Add($skillResult)
        $progressCompletedSteps++
        Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQIFNraWxsIOWvvOWFpe+8m+eKtuaAgT17MH0=') -f (ConvertTo-BootstrapDisplayStatus -Status $skillResult.Status))
    }
    catch {
        $results.Add([pscustomobject]@{
                Name   = 'skills.zip'
                Key    = 'skills-bundle'
                Status = 'failed'
                Source = 'local-zip'
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'c2tpbGxzLnppcCDlr7zlhaXlpLHotKXvvJp7MH0=') -f $_.Exception.Message)
        $progressCompletedSteps++
    }
}

Write-BootstrapSection -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5oGt5Zac77ya5a6J6KOF5rWB56iL5a6M5oiQ')

Write-Host ''
Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5pGY6KaB')
$results |
Select-Object `
@{ Name = (ConvertFrom-BootstrapUtf8Base64String -Value '5ZCN56ew'); Expression = { $_.Name } },
@{ Name = (ConvertFrom-BootstrapUtf8Base64String -Value '54q25oCB'); Expression = { if ($_.Status -eq 'failed') { ConvertFrom-BootstrapUtf8Base64String -Value '5aSx6LSl' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5oiQ5Yqf' } } },
@{ Name = (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM6Lev5b6E'); Expression = { ConvertTo-DisplaySource -Source $_.Source } },
@{ Name = (ConvertFrom-BootstrapUtf8Base64String -Value '6K+m5oOF'); Expression = { $_.Detail } } |
Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Status -eq 'failed' })
if ($failed.Count -gt 0) {
    Invoke-BootstrapExit -Code 1
}

Invoke-BootstrapExit -Code 0
