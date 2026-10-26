$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$assertions = 0
function Assert-Equal($Actual, $Expected, [string]$Name) {
    if (($Actual -join ',') -cne ($Expected -join ',')) { throw "$Name expected [$Expected], got [$Actual]" }
    $script:assertions++
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Name) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Equal ($message -like $Pattern) $true $Name
}
function Import-TestFunctions([string]$Path, [string[]]$Names) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw $errors[0] }
    foreach ($node in $ast.EndBlock.Statements) {
        if ($node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $Names) {
            Set-Item -Path ('function:script:' + $node.Name) -Value ([scriptblock]::Create($node.Body.Extent.Text.TrimStart('{').TrimEnd('}')))
        }
    }
}
Import-TestFunctions (Join-Path $root 'modules/common.psm1') @(
    'Get-ObjectPropertyValue','ConvertFrom-Utf8Base64String','Get-NormalizedVersionString','Compare-VersionStrings',
    'Get-InstalledCommandVersion','Get-InstalledAppVersion','Get-FallbackReleaseAssetVersion','Get-DesiredAppVersion',
    'Get-AppInstallDecision','Test-InstallRecoveredAfterPrimaryFailure','Install-AppFromDefinition','Resolve-PrimaryInstallFailure'
)
Import-TestFunctions (Join-Path $root 'scripts/Update-BootstrapAssets.ps1') @('Get-PythonInstaller')
$definition = (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'manifest/apps.json') | ConvertFrom-Json).apps |
    Where-Object key -eq 'python' | Select-Object -First 1
Assert-Equal $definition.wingetId 'Python.Python.3.14' 'Python package branch'
Assert-Equal $definition.minimumVersion '3.14.10' 'Python security floor'
Assert-Equal $definition.fallback.releaseAsset 'python-3.14.10-amd64.exe' 'Python fallback package'

# Exercise detection and install decisions with isolated command outputs, without changing runtimes.
$pyOutput = 'Python 3.14.10'; $pythonOutput = 'Python 3.13.17'; $pyMissing = $false
$wingetVersion = '3.14.7'
$pyArguments = @()
function py {
    $script:pyArguments = @($args)
    if ($script:pyMissing) { throw 'No suitable Python runtime found' }
    $script:pyOutput
}
function python { $script:pythonOutput }
function Get-InstalledAppxVersion { param($DetectConfig) return $null }
function Get-InstalledRegistryVersion { param($DetectConfig) return $null }
function Get-WingetPackageLatestVersion { param($PackageId,$Source) return $script:wingetVersion }
function Reset-InstallDetectionState { }
function Write-Log { param($Message,$Level) }
function Write-Step { param($Message) }

$installed = Get-InstalledAppVersion -Definition $definition
Assert-Equal $installed.Version '3.14.10' 'selected runtime is detected'
Assert-Equal $pyArguments @('-3.14','-V') 'launcher targets the configured branch'
Assert-Equal (Get-AppInstallDecision -Definition $definition).Action 'skip' 'patched runtime is current despite stale winget'
foreach ($version in @('3.13.17','3.15.2','3.14.10rc1','unknown')) {
    $pyOutput = 'Python ' + $version; $pythonOutput = $pyOutput
    Assert-Equal (Get-InstalledAppVersion -Definition $definition).Found $false "reject unrelated or unstable runtime $version"
}
$pyMissing = $true; $pythonOutput = 'Python 3.14.10'
Assert-Equal (Get-InstalledAppVersion -Definition $definition).Version '3.14.10' 'python fallback detects selected branch'
$pythonOutput = 'Python 3.13.17'
Assert-Equal (Get-AppInstallDecision -Definition $definition).Reason 'missing' 'old branch does not satisfy migration'
$pyMissing = $false; $pyOutput = 'Python 3.14.9'
$decision = Get-AppInstallDecision -Definition $definition
Assert-Equal $decision.Reason 'outdated' 'unpatched runtime needs an update'
Assert-Equal $decision.DesiredVersion '3.14.10' 'stale winget cannot lower target version'
$missing = [pscustomobject]@{Reason='missing'}
Assert-Equal (Test-InstallRecoveredAfterPrimaryFailure -Definition $definition -InitialDecision $missing -Attempts 1 -DelayMilliseconds 0).Recovered $false 'post-check cannot accept an unpatched runtime'
$pyOutput = 'Python 3.14.10'
Assert-Equal (Test-InstallRecoveredAfterPrimaryFailure -Definition $definition -InitialDecision $missing -Attempts 1 -DelayMilliseconds 0).Recovered $true 'post-check accepts patched runtime'
$wingetVersion = $null
Assert-Equal (Get-DesiredAppVersion -Definition $definition).Version '3.14.10' 'unknown winget retains security floor'
$wingetVersion = '3.14.11'
Assert-Equal (Get-DesiredAppVersion -Definition $definition).Version '3.14.11' 'newer winget versions remain eligible'
$wingetVersion = '3.14.7'; $definition.fallback.releaseAsset = 'python-3.14.11-amd64.exe'
Assert-Equal (Get-DesiredAppVersion -Definition $definition).Version '3.14.11' 'newer mirror remains the target while winget lags'
Assert-Equal (Test-InstallRecoveredAfterPrimaryFailure -Definition $definition -InitialDecision $missing -Attempts 1 -DelayMilliseconds 0).Recovered $false 'post-check requires the newer mirror target'
$definition.fallback.releaseAsset = 'python-3.14.10-amd64.exe'

$wingetCalls = @(); $downloads = @(); $packages = @()
function Initialize-Directory { param($Path) }
function Invoke-WingetAction {
    param($Action,$PackageId,$Source,$Version,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real winget execution forbidden' }
    $script:wingetCalls += [pscustomobject]@{PackageId=$PackageId;Version=$Version}
}
function Get-GitHubReleaseAssetDownloadUrl {
    param($Repo,$Tag,$AssetName)
    return ('https://github.com/{0}/releases/download/{1}/{2}' -f $Repo,$Tag,$AssetName)
}
function Invoke-DownloadFile {
    param($Url,$DestinationPath,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real downloads forbidden' }
    $script:downloads += $Url
}
function Install-DownloadedPackage {
    param($PackagePath,$InstallerType,$SilentArgs,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real package installation forbidden' }
    $script:packages += $PackagePath
}
$decision = [pscustomobject]@{Action='install';Reason='missing';InstalledVersion=$null;DesiredVersion=$null}
foreach ($available in @('3.14.7','')) {
    $wingetVersion = $available
    $result = Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision -DryRun
    Assert-Equal $result.Source 'release-fallback' "unpatched or unknown winget uses fallback [$available]"
}
Assert-Equal $wingetCalls.Count 0 'unsafe winget is never invoked'
Assert-Equal $downloads[-1] 'https://github.com/indieark/vibe-coding-setup/releases/download/bootstrap-assets/python-3.14.10-amd64.exe' 'fallback downloads patched asset'
Assert-Equal (Split-Path -Leaf $packages[-1]) 'python-3.14.10-amd64.exe' 'fallback installs selected package'
$wingetVersion = '3.14.11'
$result = Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision -DryRun
Assert-Equal $result.Source 'winget' 'patched winget is used'
Assert-Equal $wingetCalls[-1].PackageId 'Python.Python.3.14' 'winget installs selected branch'
Assert-Equal $wingetCalls[-1].Version '3.14.11' 'winget pins the version that passed the floor'
$wingetVersion = '3.14.10'; $definition.fallback.releaseAsset = 'python-3.14.11-amd64.exe'
Assert-Equal (Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision -DryRun).Source 'release-fallback' 'newer mirror is used even after winget passes the security floor'
$wingetVersion = '3.14.11'; $definition.fallback.releaseAsset = 'python-3.14.10-amd64.exe'
& {
    # Even a successful winget exit is insufficient when the required runtime is still absent.
    function Invoke-WingetAction { param($Action,$PackageId,$Source,$Version,[switch]$DryRun) }
    function Resolve-PrimaryInstallFailure { param($Definition,$InitialDecision,$PrimarySource,$ErrorRecord,[switch]$DryRun) return $null }
    $script:pyOutput = 'Python 3.14.9'
    Assert-Throws { Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision } '*could not be confirmed*' 'successful winget cannot hide an unpatched runtime'
    $script:pyOutput = 'Python 3.14.11'
    Assert-Equal (Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision).Source 'winget' 'post-check confirms patched winget installation'
}
$definition.fallback.releaseAsset = 'python-3.14.9-amd64.exe'; $wingetVersion = '3.14.7'
Assert-Throws { Install-AppFromDefinition -Definition $definition -WorkspaceRoot $root -InstallDecision $decision -DryRun } '*does not meet the required version*' 'unpatched fallback is rejected'
$definition.fallback.releaseAsset = 'python-3.14.10-amd64.exe'

# Simulate source-only releases, missing files and server failures in the official listing.
$listing = '<a href="3.14.9/">old</a><a href="3.14.10/">current</a><a href="3.14.11/">new</a><a href="3.15.2/">other</a><a href="3.14.12rc1/">preview</a>'
$statuses = @{'3.14.11'=404;'3.14.10'=200}
$requests = @(); $transportFailure = $false
function Invoke-WebRequest {
    [CmdletBinding()]
    param($Uri,$Method,[switch]$UseBasicParsing,$TimeoutSec)
    $script:requests += [pscustomobject]@{Uri=$Uri;Method=$Method}
    if ($script:transportFailure) { throw 'Fixture connection failure' }
    if ($Uri -eq 'https://www.python.org/ftp/python/') { return [pscustomobject]@{Content=$script:listing} }
    if ($Method -ne 'Head') { throw 'Candidate checks must use HEAD' }
    if ($Uri -notmatch '/(?<version>3\.14\.\d+)/python-\k<version>-amd64\.exe$') { throw ('Unexpected candidate: ' + $Uri) }
    $status = $script:statuses[$Matches['version']]
    if ($null -eq $status) { throw ('Unexpected version: ' + $Matches['version']) }
    if ($status -ne 200) {
        $failure = [Exception]::new('Fixture HTTP ' + $status)
        $failure | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{StatusCode=$status})
        throw $failure
    }
    return [pscustomobject]@{StatusCode=200}
}
$asset = Get-PythonInstaller -Definition $definition
Assert-Equal $asset.Name 'python-3.14.10-amd64.exe' 'missing newer EXE is skipped'
Assert-Equal @($requests | Where-Object Method -eq Head).Count 2 'candidate file existence is checked'
$statuses['3.14.11'] = 410
Assert-Equal (Get-PythonInstaller -Definition $definition).Name 'python-3.14.10-amd64.exe' 'gone EXE is skipped'
$statuses['3.14.11'] = 200; $requests = @()
Assert-Equal (Get-PythonInstaller -Definition $definition).Name 'python-3.14.11-amd64.exe' 'highest published stable version wins'
Assert-Equal @($requests | Where-Object Method -eq Head).Count 1 'older files are not checked once a candidate exists'
foreach ($status in @(403,429,500)) {
    $statuses['3.14.11'] = $status; $requests = @()
    Assert-Throws { Get-PythonInstaller -Definition $definition } ('*Fixture HTTP ' + $status) "HTTP $status must not trigger a downgrade"
    Assert-Equal @($requests | Where-Object Method -eq Head).Count 1 "HTTP $status stops resolution"
}
$statuses['3.14.11'] = 404; $statuses['3.14.10'] = 404; $requests = @()
Assert-Throws { Get-PythonInstaller -Definition $definition } '*No published Python*' 'no eligible EXE is an error'
Assert-Equal @($requests | Where-Object Uri -like '*3.14.9*').Count 0 'never probes below the security floor'
$listing = '<a href="3.14.9/">old</a><a href="3.15.2/">other</a>'
Assert-Throws { Get-PythonInstaller -Definition $definition } '*No published Python*' 'wrong branch and older versions cannot satisfy refresh'
$transportFailure = $true
Assert-Throws { Get-PythonInstaller -Definition $definition } '*Fixture connection failure*' 'network failures retain their diagnostic error'
Write-Output "PASS: $assertions Python migration assertions; no installations, downloads or user configuration changes"
