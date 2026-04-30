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
    [switch]$RefreshBootstrapDependencies
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
        if ($Code -eq 0) {
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
        Write-Host (ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF5bey5a6M5oiQ44CC5oyJ5Lu75oSP6ZSu5YWz6Zet56qX5Y+jLi4u')
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
        Invoke-WebRequest -Uri $sourcePath -OutFile $destinationPath
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
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
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
    Start-Process -FilePath (Get-CurrentPowerShellExecutable) -Verb RunAs -ArgumentList $argumentList.ToArray() | Out-Null
    Invoke-BootstrapExit -Code 0
}

$manifestPath = Join-Path $root 'manifest\apps.json'
$manifest = Get-AppManifest -ManifestPath $manifestPath
$selectedApps = Get-SelectedApps -Apps $manifest.apps -Only $Only

if (-not $SkipSkills) {
    $shouldRefreshSkillBundle = $RefreshBootstrapDependencies.IsPresent -or (Test-HttpSourceRoot -SourceRoot $BootstrapSourceRoot)
    Copy-BootstrapReleaseAsset `
        -Repo $BootstrapAssetsRepo `
        -Tag $BootstrapAssetsTag `
        -DestinationRoot $root `
        -RelativePath 'downloads/skills.zip' `
        -AssetName 'skills.zip' `
        -Refresh:$shouldRefreshSkillBundle
}

Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5bel5L2c5Yy677yaezB9') -f $root)
Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '5qih5byP77yaezB9') -f ($(if ($DryRun) { ConvertFrom-BootstrapUtf8Base64String -Value '5ryU57uD' } else { ConvertFrom-BootstrapUtf8Base64String -Value '5a6J6KOF' })))
Write-Log -Message ((ConvertFrom-BootstrapUtf8Base64String -Value '6YCJ5Lit55qE5bqU55So77yaezB9') -f (($selectedApps | ForEach-Object { $_.name }) -join ', '))

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

try {
    $workspaceResult = Initialize-CodexWorkspaceDirectory -DryRun:$DryRun
    $results.Add($workspaceResult)
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
}

foreach ($app in ($selectedApps | Sort-Object order)) {
    try {
        $result = Install-AppFromDefinition -Definition $app -WorkspaceRoot $root -DryRun:$DryRun
        $results.Add($result)
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
    }
}

if (-not $SkipSkills) {
    try {
        $skillResult = Install-SkillBundle `
            -ZipPath (Join-Path $root 'downloads\skills.zip') `
            -SkillProfiles $SkillProfile `
            -AllSkills:$AllSkills `
            -NoReplaceOrphan:$NoReplaceOrphan `
            -ReplaceForeign:$ReplaceForeign `
            -RenameForeign:$RenameForeign `
            -SkipSkillsManagerLaunch:$SkipSkillsManagerLaunch `
            -DryRun:$DryRun
        $results.Add($skillResult)
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
    }
}

if (-not $SkipCcSwitch -and $providerInfo -and ($selectedApps | Where-Object { $_.key -eq 'cc-switch' })) {
    try {
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
    }
}

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
