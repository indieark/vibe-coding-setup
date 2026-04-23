[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Only,
    [switch]$SkipCcSwitch,
    [switch]$SkipSkills,
    [switch]$PauseOnExit,
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

    if ($PauseOnExit) {
        Write-Host ''
        Write-Host 'Installation finished. Press any key to close this window...'
        try {
            [void][System.Console]::ReadKey($true)
        }
        catch {
            try {
                & cmd.exe /d /c 'pause >nul'
            }
            catch {
                [void](Read-Host 'Press Enter to close this window')
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
    Write-BootstrapMessage ('Fetching dependency: {0}' -f $RelativePath)

    if (Test-HttpSourceRoot -SourceRoot $SourceRoot) {
        Invoke-WebRequest -Uri $sourcePath -OutFile $destinationPath
        return
    }

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw ('Bootstrap dependency not found at source path: {0}' -f $sourcePath)
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
        Write-BootstrapMessage ('Using cached release asset: {0}' -f $RelativePath)
        return
    }

    $url = Get-BootstrapReleaseAssetUrl -Repo $Repo -Tag $Tag -AssetName $AssetName
    Write-BootstrapMessage ('Fetching release asset: {0}' -f $RelativePath)
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

    $relaunchArgs = ConvertTo-ArgumentTokens -BoundParameters $PSBoundParameters
    $argumentList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath)
    ) + $relaunchArgs

    Write-Host 'Administrator privileges are required. Requesting UAC elevation...'
    Start-Process -FilePath (Get-CurrentPowerShellExecutable) -Verb RunAs -ArgumentList $argumentList | Out-Null
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

Write-Log -Message ('Workspace: {0}' -f $root)
Write-Log -Message ('Mode: {0}' -f ($(if ($DryRun) { 'DryRun' } else { 'Install' })))
Write-Log -Message ('Selected apps: {0}' -f (($selectedApps | ForEach-Object { $_.name }) -join ', '))

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
        Write-Log -Level 'WARN' -Message ('CC Switch provider precheck failed, fallback to interactive prompt: {0}' -f $_.Exception.Message)
    }

    if ($existingProvider) {
        Write-Log -Message ('CC Switch already has codex provider "{0}", skip provider prompts and import' -f $providerNameToCheck)
        $providerPrecheckResult = [pscustomobject]@{
            Name = 'CC Switch Provider Import'
            Key = 'cc-switch-provider'
            Status = 'ok'
            Source = 'precheck-skip'
            Detail = ('Existing provider found: {0}' -f $providerNameToCheck)
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
    $workspaceResult = Ensure-CodexWorkspaceDirectory -DryRun:$DryRun
    $results.Add($workspaceResult)
}
catch {
    $results.Add([pscustomobject]@{
            Name = 'Codex Workspace'
            Key = 'codex-workspace'
            Status = 'failed'
            Source = 'filesystem'
            Detail = $_.Exception.Message
        })
    Write-Log -Level 'ERROR' -Message ('Codex workspace setup failed: {0}' -f $_.Exception.Message)
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
        Write-Log -Level 'ERROR' -Message ('{0} install failed: {1}' -f $app.name, $_.Exception.Message)
    }
}

if (-not $SkipSkills) {
    try {
        $skillResult = Install-SkillBundle `
            -ZipPath (Join-Path $root 'downloads\skills.zip') `
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
        Write-Log -Level 'ERROR' -Message ('skills.zip import failed: {0}' -f $_.Exception.Message)
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
                Name = 'CC Switch Provider Import'
                Key = 'cc-switch-provider'
                Status = 'failed'
                Source = 'ccswitch-deeplink'
                Detail = $_.Exception.Message
            })
        Write-Log -Level 'ERROR' -Message ('CC Switch provider import failed: {0}' -f $_.Exception.Message)
    }
}

Write-Host ''
Write-Host '==== Summary ===='
$results | Select-Object Name, Status, Source, Detail | Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Status -eq 'failed' })
if ($failed.Count -gt 0) {
    Invoke-BootstrapExit -Code 1
}

Invoke-BootstrapExit -Code 0
