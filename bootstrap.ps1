[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Only,
    [switch]$SkipCcSwitch,
    [switch]$SkipSkills,
    [string[]]$SkillProfile,
    [switch]$AllSkills,
    [switch]$NoReplaceOrphan,
    [switch]$ReplaceForeign,
    [switch]$RenameForeign,
    [switch]$SkipSkillsManagerLaunch,
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
}
'@
        }

        $englishLayout = [BootstrapKeyboardLayout]::LoadKeyboardLayout('00000409', 1)
        if ($englishLayout -ne [IntPtr]::Zero) {
            [void][BootstrapKeyboardLayout]::ActivateKeyboardLayout($englishLayout, 0)
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

    if ($KeepShellOpen) {
        Write-Host ''
        if ($script:BootstrapAdminHandoffStarted) {
            Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5omT5byA566h55CG5ZGY56qX5Y+j57un57ut5a6J6KOF44CC6L+Z5Liq56qX5Y+j5Y+v5Lul5YWz6Zet77yb6K+35Zyo566h55CG5ZGY56qX5Y+j5Lit5p+l55yL5ZCO57ut6L+b5bqm44CC')
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

function Invoke-BootstrapDownloadFile {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$OutFile
    )

    $previousProgressPreference = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    }
    finally {
        $ProgressPreference = $previousProgressPreference
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
            -Mode 'custom' `
            -Label (ConvertFrom-BootstrapUtf8Base64String -Value '6Ieq5a6a5LmJ6YCJ5oup') `
            -Detail (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5oup5bqU55So44CB5ryU57uDL+WuieijheOAgVNraWxsIOWSjCBDQyBTd2l0Y2gg5aSN6YCJ6aG544CC')
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
                elseif ((-not $options[$index].IsAllSkills) -and $options[$index].Enabled) {
                    ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                }
            }
            'A' {
                ($options | Where-Object { $_.IsAllSkills } | Select-Object -First 1).Enabled = $false
                foreach ($option in $options | Where-Object { -not $_.IsAllSkills }) {
                    $option.Enabled = $true
                }
            }
            'N' {
                foreach ($option in $options) {
                    $option.Enabled = $false
                }
            }
            'Enter' {
                $allOption = $options | Where-Object { $_.IsAllSkills } | Select-Object -First 1
                $selectedProfiles = @($options | Where-Object { $_.Enabled -and -not $_.IsAllSkills } | ForEach-Object { $_.ProfileName })
                if ($allOption.Enabled -or $selectedProfiles.Count -eq 0) {
                    return [pscustomobject]@{
                        AllSkills = $true
                        SkillProfiles = @()
                    }
                }

                return [pscustomobject]@{
                    AllSkills = $false
                    SkillProfiles = $selectedProfiles
                }
            }
            'B' { return $null }
            'Q' { return 'quit' }
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
        [string[]]$SelectedAppKeys,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Options,
        [string[]]$SkillProfiles = @(),
        [switch]$ShowDefaultCommand,
        [switch]$IncludeOnly
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    if ($ShowDefaultCommand) {
        return $tokens.ToArray()
    }

    if ($IncludeOnly) {
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

    return $tokens.ToArray()
}

function Show-TuiReview {
    param(
        [Parameter(Mandatory)]
        [string[]]$SelectedAppKeys,
        [AllowEmptyCollection()]
        [object[]]$Options = @(),
        [string[]]$SkillProfiles = @(),
        [string]$ModeName,
        [switch]$UseDefaultInstall,
        [switch]$IncludeOnly
    )

    $tokens = Get-TuiBootstrapArgumentTokens -SelectedAppKeys $SelectedAppKeys -Options $Options -SkillProfiles $SkillProfiles -ShowDefaultCommand:$UseDefaultInstall -IncludeOnly:$IncludeOnly
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
        $allSkillsOption = $Options | Where-Object { $_.SwitchName -eq 'AllSkills' -and $_.Enabled } | Select-Object -First 1
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

        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '5omn6KGM5qih5byP'), $mode) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5Lit5bqU55So'), ($SelectedAppKeys -join ', ')) -ForegroundColor Gray
        Write-Host ('{0}: {1}' -f (ConvertFrom-BootstrapUtf8Base64String -Value 'U2tpbGwg6YCJ5oup'), $skillText) -ForegroundColor Gray
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
        DryRun = [bool]$switches['DryRun']
        SkipCcSwitch = [bool]$switches['SkipCcSwitch']
        SkipSkills = [bool]$switches['SkipSkills']
        AllSkills = [bool]$switches['AllSkills']
        NoReplaceOrphan = [bool]$switches['NoReplaceOrphan']
        ReplaceForeign = [bool]$switches['ReplaceForeign']
        RenameForeign = [bool]$switches['RenameForeign']
        SkipSkillsManagerLaunch = [bool]$switches['SkipSkillsManagerLaunch']
        RefreshBootstrapDependencies = [bool]$switches['RefreshBootstrapDependencies']
    }
}

function Invoke-BootstrapTui {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps,
        [object[]]$SkillProfiles = @(),
        [object[]]$InitialOptions = @(),
        [string[]]$InitialSkillProfiles = @()
    )

    $allAppKeys = @($Apps | ForEach-Object { $_.key })

    while ($true) {
        $selectedMode = Show-TuiModeSelection
        if ($null -eq $selectedMode) {
            return $null
        }

        if ($selectedMode -eq 'original') {
            return New-TuiBootstrapResult -Only $null -Options $InitialOptions -SkillProfiles $InitialSkillProfiles -UseDefaultInstall
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
                -ModeName (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J5YWo5ryU57uD') `
                -IncludeOnly
            if ($review -eq 'quit') {
                return $null
            }
            if ($null -eq $review) {
                continue
            }

            return New-TuiBootstrapResult -Only $allAppKeys -Options $options
        }

        $selectedAppKeys = Show-TuiAppSelection -Apps $Apps
        if ($null -eq $selectedAppKeys) {
            return $null
        }

        $options = Show-TuiOptionSelection
        if ($options -eq 'quit') {
            return $null
        }
        if ($null -eq $options) {
            continue
        }

        $skipSkillsSelected = [bool]($options | Where-Object { $_.SwitchName -eq 'SkipSkills' -and $_.Enabled } | Select-Object -First 1)
        $selectedSkillProfiles = @()
        if (-not $skipSkillsSelected) {
            $skillSelection = Show-TuiSkillProfileSelection -Profiles $SkillProfiles
            if ($skillSelection -eq 'quit') {
                return $null
            }
            if ($null -eq $skillSelection) {
                continue
            }

            if ($skillSelection.AllSkills) {
                $options = @($options) + (New-TuiOption -Key 'allskills' -Label (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5YWo6YOoIFNraWxs') -SwitchName 'AllSkills' -Enabled $true)
            }
            else {
                $selectedSkillProfiles = @($skillSelection.SkillProfiles)
            }
        }

        $review = Show-TuiReview -SelectedAppKeys $selectedAppKeys -Options $options -SkillProfiles $selectedSkillProfiles -IncludeOnly
        if ($review -eq 'quit') {
            return $null
        }
        if ($null -eq $review) {
            continue
        }

        return New-TuiBootstrapResult -Only $selectedAppKeys -Options $review.Options -SkillProfiles $selectedSkillProfiles
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

$tuiSkillProfiles = @()
if ($shouldUseTui -and -not $SkipSkills) {
    $shouldRefreshSkillBundle = $RefreshBootstrapDependencies.IsPresent -or (Test-HttpSourceRoot -SourceRoot $BootstrapSourceRoot)
    Sync-BootstrapSkillBundleAsset `
        -Repo $BootstrapAssetsRepo `
        -Tag $BootstrapAssetsTag `
        -DestinationRoot $root `
        -Refresh:$shouldRefreshSkillBundle

    try {
        $tuiSkillProfiles = @(Get-SkillBundleProfiles -ZipPath $skillBundlePath)
    }
    catch {
        Write-BootstrapMessage $_.Exception.Message
    }
}

if ($shouldUseTui) {
    Set-BootstrapEnglishInputLayout
    $tuiInitialOptions = @(
        if ($DryRun) { [pscustomobject]@{ SwitchName = 'DryRun'; Enabled = $true } }
        if ($SkipCcSwitch) { [pscustomobject]@{ SwitchName = 'SkipCcSwitch'; Enabled = $true } }
        if ($SkipSkills) { [pscustomobject]@{ SwitchName = 'SkipSkills'; Enabled = $true } }
        if ($AllSkills) { [pscustomobject]@{ SwitchName = 'AllSkills'; Enabled = $true } }
        if ($NoReplaceOrphan) { [pscustomobject]@{ SwitchName = 'NoReplaceOrphan'; Enabled = $true } }
        if ($ReplaceForeign) { [pscustomobject]@{ SwitchName = 'ReplaceForeign'; Enabled = $true } }
        if ($RenameForeign) { [pscustomobject]@{ SwitchName = 'RenameForeign'; Enabled = $true } }
        if ($SkipSkillsManagerLaunch) { [pscustomobject]@{ SwitchName = 'SkipSkillsManagerLaunch'; Enabled = $true } }
        if ($RefreshBootstrapDependencies) { [pscustomobject]@{ SwitchName = 'RefreshBootstrapDependencies'; Enabled = $true } }
    )
    $initialSkillProfiles = @(ConvertTo-BootstrapNonEmptyStringArray -Value $SkillProfile)
    $tuiResult = Invoke-BootstrapTui -Apps $manifest.apps -SkillProfiles $tuiSkillProfiles -InitialOptions $tuiInitialOptions -InitialSkillProfiles $initialSkillProfiles
    if ($null -eq $tuiResult) {
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5bey5Y+W5raI44CC')
        Invoke-BootstrapExit -Code 0
    }

    $Only = $tuiResult.Only
    $SkillProfile = @(ConvertTo-BootstrapNonEmptyStringArray -Value $tuiResult.SkillProfile)
    $DryRun = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.DryRun)
    $SkipCcSwitch = [System.Management.Automation.SwitchParameter]([bool]$tuiResult.SkipCcSwitch)
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
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'DryRun' -Present ([bool]$DryRun)
    Set-BootstrapBoundSwitchParameter -BoundParameters $PSBoundParameters -Name 'SkipCcSwitch' -Present ([bool]$SkipCcSwitch)
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

$selectedApps = @(Get-SelectedApps -Apps $manifest.apps -Only $Only)

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
foreach ($app in ($selectedApps | Sort-Object order)) {
    Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value 'ICAtIHswfSAoezF9KQ==') -f $app.name, $app.key)
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
