[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Only,
    [switch]$SkipCcSwitch,
    [switch]$SkipApps,
    [switch]$SkipSkills,
    [string[]]$SkillProfile,
    [switch]$AllSkills,
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

function Test-BootstrapProgressRendering {
    try {
        return ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected)
    }
    catch {
        return $false
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
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5omT5byA566h55CG5ZGY56qX5Y+j57un57ut5a6J6KOF44CC5oyJ5Lu75oSP6ZSu5YWz6Zet5b2T5YmN56qX5Y+jLi4u')
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
    $canRenderInPlace = Test-BootstrapProgressRendering

    if (-not $canRenderInPlace) {
        if ($Completed) {
            Write-Host $line
        }
        return
    }

    if ($Completed) {
        Write-Host ("`r{0}" -f $line)
    }
    else {
        Write-Host ("`r{0}" -f $line) -NoNewline
    }
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

function Write-TuiHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Clear-Host
    Write-Host ('+ {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'VmliZSBDb2RpbmcgU2V0dXA=')) -ForegroundColor Cyan
    Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '546w5Luj5YyW5o6n5Yi25Y+w5a6J6KOF5ZCR5a+8')) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ('-' * 64) -ForegroundColor DarkGray
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
        Key = $Key
        Label = $Label
        SwitchName = $SwitchName
        Enabled = $Enabled
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
        Mode = $Mode
        Label = $Label
        Detail = $Detail
    }
}

function Show-TuiModeSelection {
    $modes = @(
        New-TuiModeOption `
            -Mode 'original' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6buY6K6k5a6J6KOF77yI5Y6f5p2l5qih5byP77yJ') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5YWo6YOo5bqU55So77yM5bm25oyJ5Y6f6ISa5pys5rWB56iL5a+85YWlIFNraWxsIOS4jiBDQyBTd2l0Y2jjgII=')
        New-TuiModeOption `
            -Mode 'workbench' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value 'VFVJIOaooeW8jw==') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6L+b5YWl5bel5L2c5Y+w77ya5qOA5p+l54q25oCB44CB5a6J6KOF5oiW5pu05paw6L2v5Lu244CB6YCJ5oupIFNraWxs44CC')
        New-TuiModeOption `
            -Mode 'dryrun' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J5YWo5ryU57uD') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YeP5ryU57uD77yM5LiN5a+85YWlIENDIFN3aXRjaO+8jOS4jeabv+aNouaXpyBTa2lsbO+8jOS4jeWQr+WKqCBTa2lsbHMgTWFuYWdlcu+8jOW5tum7mOiupOmAieaLqeWFqOmDqCBTa2lsbOOAgg==')
    )

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup6L+Q6KGM5qih5byP')
        for ($i = 0; $i -lt $modes.Count; $i++) {
            $mode = $modes[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $mode.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $mode.Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgUSDpgIDlh7o=') -ForegroundColor DarkGray

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
        Label = $Label
        Detail = $Detail
    }
}

function Get-TuiAppDecisionText {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Decision
    )

    if ($Decision.Action -eq 'skip') {
        if ($Decision.Reason -eq 'current') {
            return ConvertFrom-BootstrapUtf8Base64String -Value '5bey5piv5pyA5paw'
        }

        return ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H'
    }

    switch ($Decision.Reason) {
        'missing' { return (ConvertFrom-BootstrapUtf8Base64String -Value '57y65aSx') }
        'outdated' { return (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v5pu05paw') }
        default { return (ConvertFrom-BootstrapUtf8Base64String -Value '6ZyA56Gu6K6k') }
    }
}

function Get-TuiAppStatusRows {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps
    )

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($app in ($Apps | Sort-Object order)) {
        try {
            $decision = Get-AppInstallDecision -Definition $app
            $rows.Add([pscustomobject]@{
                    Key = $app.key
                    Name = $app.name
                    Decision = $decision
                    Action = $decision.Action
                    InstalledVersion = if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) { '-' } else { [string]$decision.InstalledVersion }
                    DesiredVersion = if ([string]::IsNullOrWhiteSpace([string]$decision.DesiredVersion)) { '-' } else { [string]$decision.DesiredVersion }
                    ActionText = Get-TuiAppDecisionText -Decision $decision
                    Error = $null
                })
        }
        catch {
            $rows.Add([pscustomobject]@{
                    Key = $app.key
                    Name = $app.name
                    Decision = $null
                    Action = 'unknown'
                    InstalledVersion = '-'
                    DesiredVersion = '-'
                    ActionText = ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l5aSx6LSl'
                    Error = $_.Exception.Message
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

    $rows = @(Get-TuiAppStatusRows -Apps $Apps)
    $suggestedKeys = @($rows | Where-Object { $_.Action -ne 'skip' } | ForEach-Object { $_.Key })
    $allAppKeys = @($Apps | ForEach-Object { $_.key })
    $actions = @(
        New-TuiWorkbenchAction -Action 'suggested' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bu66K6u6aG5') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF57y65aSx5oiW5Y+v5pu05paw55qE6L2v5Lu244CC')
        New-TuiWorkbenchAction -Action 'all' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5YWo6YOo5bqU55So') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJIG1hbmlmZXN0IOWFqOmHj+W6lOeUqOaJp+ihjOWuieijhSAvIOabtOaWsOOAgg==')
        New-TuiWorkbenchAction -Action 'manual' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5omL5Yqo6YCJ5oup5bqU55So') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5LuO5bqU55So5riF5Y2V5Lit6YCJ5oup5pys5qyh5a6J6KOFIC8g5pu05paw6IyD5Zu044CC')
    )

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOFIC8g5pu05paw6L2v5Lu2')
        for ($i = 0; $i -lt $actions.Count; $i++) {
            $action = $actions[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $action.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $action.Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' { if ($index -gt 0) { $index-- } }
            'DownArrow' { if ($index -lt ($actions.Count - 1)) { $index++ } }
            'B' { return $null }
            'Q' { return 'quit' }
            'Enter' {
                switch ($actions[$index].Action) {
                    'suggested' {
                        if ($suggestedKeys.Count -eq 0) {
                            Write-Host ''
                            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5b2T5YmN5rKh5pyJ6ZyA6KaB5a6J6KOF5oiW5pu05paw55qE6L2v5Lu244CC') -ForegroundColor Yellow
                            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ5Lu75oSP6ZSu6L+U5ZueLi4u') -ForegroundColor DarkGray
                            [void][Console]::ReadKey($true)
                            continue
                        }

                        return [pscustomobject]@{
                            AppKeys = $suggestedKeys
                            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '5bu66K6u6aG5IHswfSDkuKrlupTnlKg=') -f $suggestedKeys.Count
                        }
                    }
                    'all' {
                        return [pscustomobject]@{
                            AppKeys = $allAppKeys
                            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIHswfSDkuKrlupTnlKg=') -f $allAppKeys.Count
                        }
                    }
                    'manual' {
                        $selected = Show-TuiAppSelection -Apps $Apps
                        if ($null -eq $selected) {
                            return 'quit'
                        }

                        return [pscustomobject]@{
                            AppKeys = $selected
                            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '5bey6YCJIHswfSDkuKrlupTnlKg=') -f $selected.Count
                        }
                    }
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
        [object[]]$Profiles = @()
    )

    $options = New-Object System.Collections.Generic.List[object]
    $options.Add([pscustomobject]@{
            Key = 'all'
            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '5YWo6YOoIFNraWxs77yI6buY6K6k77yJ')
            ProfileName = $null
            Enabled = $true
            IsAllSkills = $true
            IsSkipSkills = $false
        })
    $options.Add([pscustomobject]@{
            Key = 'skip'
            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+HIFNraWxsIOWvvOWFpQ==')
            ProfileName = $null
            Enabled = $false
            IsAllSkills = $false
            IsSkipSkills = $true
        })

    foreach ($profile in @($Profiles)) {
        $label = if ([string]::IsNullOrWhiteSpace($profile.Description)) {
            $profile.Name
        }
        else {
            '{0} - {1}' -f $profile.Name, $profile.Description
        }
        $options.Add([pscustomobject]@{
                Key = $profile.Name
                Label = $label
                ProfileName = $profile.Name
                Enabled = $false
                IsAllSkills = $false
                IsSkipSkills = $false
            })
    }

    $index = 0
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg5aSN6YCJ6aG5')
        if (-not $Profiles -or $Profiles.Count -eq 0) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6K+75Y+W5YiwIFByb2ZpbGXvvIzpu5jorqTlr7zlhaXlhajpg6ggU2tpbGzjgII=') -ForegroundColor DarkGray
            Write-Host ''
        }

        for ($i = 0; $i -lt $options.Count; $i++) {
            $option = $options[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $mark = if ($option.Enabled) { 'x' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} [{1}] {2}' -f $cursor, $mark, $option.Label) -ForegroundColor $color
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIOepuuagvCDlpI3pgIkv5Y+W5raIICBBIOWFqOmAiSAgTiDmuIXnqbogIEVudGVyIOS4i+S4gOatpSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray

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
                elseif ($options[$index].IsSkipSkills -and $options[$index].Enabled) {
                    foreach ($option in $options | Where-Object { -not $_.IsSkipSkills }) {
                        $option.Enabled = $false
                    }
                }
                elseif ((-not $options[$index].IsAllSkills) -and $options[$index].Enabled) {
                    ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                    ($options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1).Enabled = $false
                }
            }
            'A' {
                ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                ($options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1).Enabled = $false
                foreach ($option in $options | Where-Object { -not $_.IsAllSkills }) {
                    if (-not $option.IsSkipSkills) {
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
                $skipOption = $options | Where-Object { $_.IsSkipSkills } | Select-Object -First 1
                $selectedProfiles = @($options | Where-Object { $_.Enabled -and -not $_.IsAllSkills } | ForEach-Object { $_.ProfileName })
                if ($skipOption.Enabled) {
                    return [pscustomobject]@{
                        SkipSkills = $true
                        AllSkills = $false
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
                        SkipSkills = $false
                        AllSkills = $true
                        SkillProfiles = @()
                    }
                }

                return [pscustomobject]@{
                    SkipSkills = $false
                    AllSkills = $false
                    SkillProfiles = $selectedProfiles
                }
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
            Mode = 'default'
            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '6buY6K6k5Zy65pmv77yI5b2T5YmN5ZCv55So77yJ')
            Detail = (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6buY6K6k5Zy65pmv')
        }
        [pscustomobject]@{
            Mode = 'custom'
            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ5Zy65pmv')
            Detail = (ConvertFrom-BootstrapUtf8Base64String -Value '5YaZ5YWl6Ieq5a6a5LmJ5Zy65pmv77yaezB9') -f ($(if ([string]::IsNullOrWhiteSpace($InitialName)) { ConvertFrom-BootstrapUtf8Base64String -Value 'SW5kaWVBcmsgU2tpbGxz' } else { $InitialName }))
        }
        [pscustomobject]@{
            Mode = 'skip'
            Label = (ConvertFrom-BootstrapUtf8Base64String -Value '6Lez6L+H5Zy65pmv5rOo5YaM77yI5Y+q5aSN5Yi2IFNraWxsIOaWh+S7tu+8iQ==')
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
        [string]$SkillsManagerScenarioMode,
        [string]$SkillsManagerScenarioName,
        [string]$ModeName,
        [switch]$UseDefaultInstall,
        [switch]$IncludeOnly
    )

    $tokens = Get-TuiBootstrapArgumentTokens -SelectedAppKeys $SelectedAppKeys -Options $Options -SkillProfiles $SkillProfiles -SkillsManagerScenarioMode $SkillsManagerScenarioMode -SkillsManagerScenarioName $SkillsManagerScenarioName -ShowDefaultCommand:$UseDefaultInstall -IncludeOnly:$IncludeOnly
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
        elseif ($SkillProfiles -and $SkillProfiles.Count -gt 0) {
            $SkillProfiles -join ', '
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

        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5qih5byP'), $mode) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5Lit5bqU55So'), $appText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg6YCJ5oup'), $skillText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGxzIE1hbmFnZXIg5Zy65pmv'), $scenarioText) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6ZmE5Yqg5Y+C5pWw'), $optionText) -ForegroundColor Gray
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bCG5omn6KGM5ZG95Luk') -ForegroundColor DarkGray
        Write-Host $commandText -ForegroundColor Cyan
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5byA5aeL5omn6KGMICBDIOWkjeWItuWRveS7pCAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter' {
                return [pscustomobject]@{
                    Tokens = $tokens
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
        [string]$SkillsManagerScenarioMode,
        [string]$SkillsManagerScenarioName,
        [switch]$UseDefaultInstall
    )

    $switches = @{}
    foreach ($option in $Options) {
        $switches[$option.SwitchName] = [bool]$option.Enabled
    }

    return [pscustomobject]@{
        Only = $Only
        UseDefaultInstall = [bool]$UseDefaultInstall
        SkillProfile = @($SkillProfiles)
        SkillsManagerScenarioMode = $SkillsManagerScenarioMode
        SkillsManagerScenarioName = $SkillsManagerScenarioName
        DryRun = [bool]$switches['DryRun']
        SkipCcSwitch = [bool]$switches['SkipCcSwitch']
        SkipApps = [bool]$switches['SkipApps']
        SkipSkills = [bool]$switches['SkipSkills']
        AllSkills = [bool]$switches['AllSkills']
        NoReplaceOrphan = [bool]$switches['NoReplaceOrphan']
        ReplaceForeign = [bool]$switches['ReplaceForeign']
        RenameForeign = [bool]$switches['RenameForeign']
        SkipSkillsManagerLaunch = [bool]$switches['SkipSkillsManagerLaunch']
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

    $profiles = @(Get-SkillBundleProfiles -ZipPath $skillBundlePath)
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
        $installedSet[$skillName] = $true
    }
    $newSkills = @($bundleSkills | Where-Object { -not $installedSet.ContainsKey($_) })

    return [pscustomobject]@{
        Profiles = $profiles
        BundleSkills = $bundleSkills
        InstalledSkills = $installedSkills
        NewSkills = $newSkills
        ZipPath = $skillBundlePath
        LocalSkillRoot = $localSkillRoot
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

    $summary = Get-BootstrapTuiSkillBundleSummary -Repo $Repo -Tag $Tag -DestinationRoot $DestinationRoot -Refresh $Refresh
    while ($true) {
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg54q25oCB')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'QnVuZGxlIFNraWxs'), $summary.BundleSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5pys5py65bey5a6J6KOF'), $summary.InstalledSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v6IO95paw5aKe'), $summary.NewSkills.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZSDmlbDph48='), $summary.Profiles.Count) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Y+v5pu05paw5YaF5a65'), (ConvertFrom-BootstrapUtf8Base64String -Value '5a+85YWl5pe255Sx5LiJ5oCB5ZCM5q2l57un57ut5Yik5pat44CC')) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZSDmuIXljZU=') -ForegroundColor Yellow
        if ($summary.Profiles.Count -eq 0) {
            Write-Host ('  {0}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5pyq5Y+R546wIFByb2ZpbGXvvIzku43lj6/lronoo4Xlhajpg6ggU2tpbGzjgII=')) -ForegroundColor DarkGray
        }
        else {
            foreach ($profile in $summary.Profiles | Select-Object -First 12) {
                Write-Host ('  - {0}' -f $profile.Name) -ForegroundColor Gray
            }
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value 'RW50ZXIg5oiWIEIg6L+U5ZueICBRIOmAgOWHug==') -ForegroundColor DarkGray
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
    elseif ($State.SkillProfiles.Count -gt 0) {
        (ConvertFrom-BootstrapUtf8Base64String -Value 'UHJvZmlsZTogezB9') -f ($State.SkillProfiles -join ', ')
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
        Skill = $skillText
        Scenario = $scenarioText
    }
}

function Show-TuiWorkbenchMenu {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$State
    )

    $actions = @(
        New-TuiWorkbenchAction -Action 'software-status' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+l6L2v5Lu254q25oCB') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5p+l55yL5bey5a6J6KOF54mI5pys44CB55uu5qCH54mI5pys5ZKM5bu66K6u5Yqo5L2c44CC')
        New-TuiWorkbenchAction -Action 'software-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOFIC8g5pu05paw6L2v5Lu2') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup5bu66K6u6aG544CB5YWo6YOo5bqU55So5oiW5omL5Yqo5oyR6YCJ5bqU55So44CC')
        New-TuiWorkbenchAction -Action 'skill-status' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5qOA5p+lIFNraWxsIOeKtuaAgQ==') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5oyJ6ZyA6K+75Y+WIGJ1bmRsZe+8jOafpeeciyBQcm9maWxl44CB5bey5a6J6KOF5ZKM5Y+v6IO95paw5aKe5YaF5a6544CC')
        New-TuiWorkbenchAction -Action 'skill-install' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOFIFNraWxs') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup5YWo6YOoIFNraWxsIOaIluS4gOS4qiAvIOWkmuS4qiBQcm9maWxl44CC')
        New-TuiWorkbenchAction -Action 'review' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5pGY6KaB') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '56Gu6K6k5b2T5YmN6YCJ5oup5bm25byA5aeL5omn6KGM44CC')
        New-TuiWorkbenchAction -Action 'back' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6L+U5Zue') -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '5Zue5Yiw6L+Q6KGM5qih5byP6YCJ5oup44CC')
    )

    $index = 0
    while ($true) {
        $summary = Get-TuiWorkbenchSummaryText -State $State
        Write-TuiHeader -Title (ConvertFrom-BootstrapUtf8Base64String -Value 'VFVJIOW3peS9nOWPsA==')
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6L2v5Lu2'), $summary.Software) -ForegroundColor DarkGray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGw='), $summary.Skill) -ForegroundColor DarkGray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5Zy65pmv5rOo5YaM'), $summary.Scenario) -ForegroundColor DarkGray
        Write-Host ''
        for ($i = 0; $i -lt $actions.Count; $i++) {
            $action = $actions[$i]
            $cursor = if ($i -eq $index) { '>' } else { ' ' }
            $color = if ($i -eq $index) { 'Cyan' } else { 'Gray' }
            Write-Host ('{0} {1}' -f $cursor, $action.Label) -ForegroundColor $color
            Write-Host ('  {0}' -f $action.Detail) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '4oaRL+KGkyDnp7vliqggIEVudGVyIOmAieaLqSAgQiDov5Tlm54gIFEg6YCA5Ye6') -ForegroundColor DarkGray
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
    $skillProfilesLoaded = $availableSkillProfiles.Count -gt 0
    $baseOptions = @($InitialOptions | Where-Object { $_.SwitchName -notin @('SkipApps', 'SkipSkills', 'AllSkills') })
    $state = [pscustomobject]@{
        AppKeys = @()
        AppLabel = ConvertFrom-BootstrapUtf8Base64String -Value '5pyq6YCJ5oup'
        SkipApps = $true
        SkipSkills = $true
        AllSkills = $false
        SkillProfiles = @()
        SkillsManagerScenarioMode = if ([string]::IsNullOrWhiteSpace($InitialSkillsManagerScenarioMode) -or $InitialSkillsManagerScenarioMode -eq 'prompt') { 'skip' } else { $InitialSkillsManagerScenarioMode }
        SkillsManagerScenarioName = $InitialSkillsManagerScenarioName
        BaseOptions = $baseOptions
    }

    while ($true) {
        $action = Show-TuiWorkbenchMenu -State $state
        switch ($action) {
            'software-status' {
                $statusResult = Show-TuiAppStatus -Apps $Apps
                if ($statusResult -eq 'quit') { return $null }
            }
            'software-install' {
                $selection = Show-TuiSoftwareActionSelection -Apps $Apps
                if ($selection -eq 'quit') { return $null }
                if ($null -ne $selection) {
                    $state.AppKeys = @($selection.AppKeys)
                    $state.AppLabel = $selection.Label
                    $state.SkipApps = $false
                }
            }
            'skill-status' {
                $skillStatus = Show-TuiSkillStatus -Repo $BootstrapAssetsRepo -Tag $BootstrapAssetsTag -DestinationRoot $DestinationRoot -Refresh $RefreshSkillBundle
                if ($skillStatus -eq 'quit') { return $null }
                if ($skillStatus -and $skillStatus.Profiles) {
                    $availableSkillProfiles = @($skillStatus.Profiles)
                    $skillProfilesLoaded = $true
                }
            }
            'skill-install' {
                if (-not $skillProfilesLoaded) {
                    $availableSkillProfiles = @(Get-BootstrapTuiSkillProfiles `
                            -Repo $BootstrapAssetsRepo `
                            -Tag $BootstrapAssetsTag `
                            -DestinationRoot $DestinationRoot `
                            -Refresh $RefreshSkillBundle)
                    $skillProfilesLoaded = $true
                }

                $skillSelection = Show-TuiSkillProfileSelection -Profiles $availableSkillProfiles
                if ($skillSelection -eq 'quit') { return $null }
                if ($null -ne $skillSelection) {
                    if ($skillSelection.SkipSkills) {
                        $state.SkipSkills = $true
                        $state.AllSkills = $false
                        $state.SkillProfiles = @()
                        continue
                    }

                    $scenarioSelection = Show-TuiSkillsManagerScenarioSelection -InitialMode $state.SkillsManagerScenarioMode -InitialName $state.SkillsManagerScenarioName
                    if ($scenarioSelection -eq 'quit') { return $null }
                    if ($null -eq $scenarioSelection) { continue }

                    $state.SkipSkills = $false
                    $state.AllSkills = [bool]$skillSelection.AllSkills
                    $state.SkillProfiles = @($skillSelection.SkillProfiles)
                    $state.SkillsManagerScenarioMode = $scenarioSelection.Mode
                    $state.SkillsManagerScenarioName = $scenarioSelection.Name
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
                    -SkillsManagerScenarioMode $state.SkillsManagerScenarioMode `
                    -SkillsManagerScenarioName $state.SkillsManagerScenarioName `
                    -ModeName (ConvertFrom-BootstrapUtf8Base64String -Value 'VFVJIOaooeW8jw==') `
                    -IncludeOnly:(!$state.SkipApps)
                if ($review -eq 'quit') { return $null }
                if ($null -eq $review) { continue }

                return New-TuiBootstrapResult -Only @($state.AppKeys) -Options $review.Options -SkillProfiles @($state.SkillProfiles) -SkillsManagerScenarioMode $state.SkillsManagerScenarioMode -SkillsManagerScenarioName $state.SkillsManagerScenarioName
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
    $SkillsManagerScenarioMode = if ([string]::IsNullOrWhiteSpace([string]$tuiResult.SkillsManagerScenarioMode)) { 'prompt' } else { [string]$tuiResult.SkillsManagerScenarioMode }
    $SkillsManagerScenarioName = [string]$tuiResult.SkillsManagerScenarioName
    $DryRun = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.DryRun)
    $SkipCcSwitch = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipCcSwitch)
    $SkipApps = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipApps)
    $SkipSkills = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipSkills)
    $AllSkills = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.AllSkills)
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

    Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '6ZyA6KaB566h55CG5ZGY5p2D6ZmQ77yM5q2j5Zyo6K+35rGCIFVBQyDmj5DmnYMuLi4=')
    Start-BootstrapElevatedShell -PowerShellArguments $argumentList.ToArray()
    $script:BootstrapAdminHandoffStarted = $true
    Invoke-BootstrapExit -Code 0
}

$selectedApps = @()
if (-not $SkipApps) {
    $selectedApps = @(Get-SelectedApps -Apps $manifest.apps -Only $Only)
}

if (-not $SkipSkills) {
    $shouldRefreshSkillBundle = $RefreshBootstrapDependencies.IsPresent -or (Test-HttpSourceRoot -SourceRoot $BootstrapSourceRoot)
    Sync-BootstrapSkillBundleAsset `
        -Repo $BootstrapAssetsRepo `
        -Tag $BootstrapAssetsTag `
        -DestinationRoot $root `
        -Refresh:$shouldRefreshSkillBundle
}

Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bel5L2c5Yy677yaezB9') -f $root)
Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5qih5byP77yaezB9') -f ($(if ($DryRun) { ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF' })))
Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5Lit55qE5a6J6KOF5bqU55So5riF5Y2V77ya')
if ($SkipApps) {
    Write-Log -Message (ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIOi3s+i/h+i9r+S7tuWuieijhQ==')
}
else {
    foreach ($app in ($selectedApps | Sort-Object order)) {
        Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIHswfSAoezF9KQ==') -f $app.name, $app.key)
    }
}

$providerInfo = $null
$providerPrecheckResult = $null
if (-not $SkipCcSwitch -and ($selectedApps | Where-Object { $_.key -eq 'cc-switch' })) {
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
        $providerPrecheckResult = [pscustomobject]@{
            Name = 'CC Switch Provider Import'
            Key = 'cc-switch-provider'
            Status = 'ok'
            Source = 'precheck-skip'
            Detail = ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5om+5Yiw546w5pyJIHByb3ZpZGVy77yaezB9') -f $providerNameToCheck)
        }
    }
    else {
        $providerInfo = Read-CodexProviderInput `
            -PresetName $CcSwitchProviderName `
            -PresetBaseUrl $CcSwitchBaseUrl `
            -PresetModel $CcSwitchModel `
            -PresetApiKey $CcSwitchApiKey
    }
}

$results = New-Object System.Collections.Generic.List[object]
if ($providerPrecheckResult) {
    $results.Add($providerPrecheckResult)
}

$progressTotalSteps = 1 + $selectedApps.Count
if (-not $SkipSkills) {
    $progressTotalSteps++
}
if (-not $SkipCcSwitch -and $providerInfo -and ($selectedApps | Where-Object { $_.key -eq 'cc-switch' })) {
    $progressTotalSteps++
}
$progressCompletedSteps = 0

try {
    $workspaceProgressStatus = ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo5YeG5aSHIENvZGV4IOW3peS9nOWMug=='
    Write-BootstrapProgress -CompletedSteps $progressCompletedSteps -TotalSteps $progressTotalSteps -Status $workspaceProgressStatus
    $workspaceResult = Initialize-CodexWorkspaceDirectory -DryRun:$DryRun
    $results.Add($workspaceResult)
    $progressCompletedSteps++
}
catch {
    $results.Add([pscustomobject]@{
            Name = (ConvertFrom-BootstrapUtf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
            Key = 'codex-workspace'
            Status = 'failed'
            Source = 'filesystem'
            Detail = $_.Exception.Message
        })
    Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy66K6+572u5aSx6LSl77yaezB9') -f $_.Exception.Message)
    $progressCompletedSteps++
}

$appInstallIndex = 0
foreach ($app in ($selectedApps | Sort-Object order)) {
    $appInstallIndex++
    try {
        $appProgressStatus = (ConvertFrom-BootstrapUtf8Base64String -Value '5YeG5aSH5a6J6KOF5bqU55So77yaezB9ICh7MX0vezJ9KQ==') -f $app.name, $appInstallIndex, $selectedApps.Count
        Write-BootstrapProgress -CompletedSteps $progressCompletedSteps -TotalSteps $progressTotalSteps -Status $appProgressStatus
        $result = Install-AppFromDefinition -Definition $app -WorkspaceRoot $root -DryRun:$DryRun
        $results.Add($result)
        $progressCompletedSteps++
        Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQ5bqU55So77yaezB977yb54q25oCBPXsxfQ==') -f $app.name, (ConvertTo-BootstrapDisplayStatus -Status $result.Status))
    }
    catch {
        $results.Add([pscustomobject]@{
                Name = $app.name
                Key = $app.key
                Status = 'failed'
                Source = $app.strategy
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'ezB9IOWuieijheWksei0pe+8mnsxfQ==') -f $app.name, $_.Exception.Message)
        $progressCompletedSteps++
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bqU55So5aSx6LSl77yaezB977yb54q25oCBPeWksei0pQ==') -f $app.name)
    }
}

if (-not $SkipSkills) {
    try {
        $skillProgressStatus = ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo5a+85YWlIFNraWxs'
        Write-BootstrapProgress -CompletedSteps $progressCompletedSteps -TotalSteps $progressTotalSteps -Status $skillProgressStatus
        $skillResult = Install-SkillBundle `
            -ZipPath $skillBundlePath `
            -SkillProfiles $SkillProfile `
            -AllSkills:$AllSkills `
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
                Name = 'skills.zip'
                Key = 'skills-bundle'
                Status = 'failed'
                Source = 'local-zip'
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'c2tpbGxzLnppcCDlr7zlhaXlpLHotKXvvJp7MH0=') -f $_.Exception.Message)
        $progressCompletedSteps++
    }
}

if (-not $SkipCcSwitch -and $providerInfo -and ($selectedApps | Where-Object { $_.key -eq 'cc-switch' })) {
    try {
        $ccSwitchProgressStatus = ConvertFrom-BootstrapUtf8Base64String -Value '5q2j5Zyo5a+85YWlIENDIFN3aXRjaCBQcm92aWRlcg=='
        Write-BootstrapProgress -CompletedSteps $progressCompletedSteps -TotalSteps $progressTotalSteps -Status $ccSwitchProgressStatus
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
        $progressCompletedSteps++
        Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQIENDIFN3aXRjaCBQcm92aWRlciDlr7zlhaXvvJvnirbmgIE9ezB9') -f (ConvertTo-BootstrapDisplayStatus -Status $ccResult.Status))
    }
    catch {
        $results.Add([pscustomobject]@{
                Name = (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIFByb3ZpZGVyIOWvvOWFpQ==')
                Key = 'cc-switch-provider'
                Status = 'failed'
                Source = 'ccswitch-deeplink'
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIHByb3ZpZGVyIOWvvOWFpeWksei0pe+8mnswfQ==') -f $_.Exception.Message)
        $progressCompletedSteps++
        Write-Log -Level 'ERROR' -Message (ConvertFrom-BootstrapUtf8Base64String -Value 'Q0MgU3dpdGNoIFByb3ZpZGVyIOWvvOWFpeWksei0pe+8m+eKtuaAgT3lpLHotKU=')
    }
}

Write-BootstrapProgress -CompletedSteps $progressTotalSteps -TotalSteps $progressTotalSteps -Status (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5a6M5oiQ5a6J6KOF5rWB56iL') -Completed

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
