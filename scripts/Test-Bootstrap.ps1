$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:TestRoot = Split-Path -Parent $PSScriptRoot
Set-Location $script:TestRoot
Import-Module .\modules\common.psm1 -Force -DisableNameChecking
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PWD 'bootstrap.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
foreach ($node in $ast.EndBlock.Statements) {
    if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) {
        . ([scriptblock]::Create($node.Extent.Text))
    }
}
function Assert-Equal($Actual, $Expected, [string]$Name) {
    if (($Actual -join ',') -cne ($Expected -join ',')) { throw "$Name expected [$Expected], got [$Actual]" }
    $script:Assertions++
}
$script:Assertions = 0
$script:ExistingProvider = $null
$script:InstallFailure = $false
function Get-AppInstallDecisionBatch { param($Definitions)
    $script:Calls.Apps = @($Definitions.key)
    foreach ($app in $Definitions) {
        [pscustomobject]@{Key=$app.key;Status='ok';Decision=[pscustomobject]@{Action='install';Reason='missing';InstalledVersion='';DesiredVersion=''}}
    }
}
function Install-AppFromDefinition { param($Definition, $WorkspaceRoot, $InstallDecision, [switch]$DryRun)
    if (-not $DryRun) { throw 'Real install forbidden' }
    [pscustomobject]@{Name=$Definition.name;Key=$Definition.key;Status=$(if ($script:InstallFailure) {'failed'} else {'ok'});Source='mock-install';Detail='dry-run'}
}
function Write-BootstrapAppPlan { param($Apps,$PrecheckByKey) }
function Write-Log { param($Message,$Level) }
function Write-BootstrapSection { param($Title,$Detail) $script:Calls.Title = $Title }
function Write-BootstrapProgress { param($CompletedSteps,$TotalSteps,$Status,[switch]$Completed) }
function Get-OriginalUserHomeDirectory { return $null }
function Set-BootstrapEnglishInputLayout { }
function Sync-BootstrapDependencies { param($SourceRoot,$DestinationRoot,$Dependencies,[switch]$Refresh) }
function Get-CcSwitchProviderByName { param($ProviderName) return $script:ExistingProvider }
function Import-CcSwitchCodexProvider { param($ProviderInfo,[switch]$ForceWarmup,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real provider import forbidden' }
    $script:Calls.Provider++
    [pscustomobject]@{Name='CC Switch';Key='cc-switch-provider';Status='ok';Source='mock-provider';Detail='dry-run'}
}
function Read-CodexProviderInput { param($PresetName,$PresetBaseUrl,$PresetModel,$PresetApiKey)
    [pscustomobject]@{Name='IndieArk API';BaseUrl='https://api.indieark.tech/v1';Model='gpt-6.1-sol';ApiKey='test-placeholder'}
}
function Sync-BootstrapSkillBundleAsset { param($Repo,$Tag,$DestinationRoot,[switch]$Refresh)
    $script:Calls.Bundle++
}
function Install-SkillBundle { param($ZipPath,$SkillProfiles,$SkillNames,$McpNames,$PrereqNames,[switch]$AllSkills,[switch]$AllSuites,[switch]$NoReplaceOrphan,[switch]$ReplaceForeign,[switch]$RenameForeign,[switch]$SkipSkillsManagerLaunch,$SkillsManagerScenarioMode,$SkillsManagerScenarioName,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real component import forbidden' }
    $script:Calls.Components++
    $script:Calls.SkillNames = @($SkillNames)
    $script:Calls.McpNames = @($McpNames)
    $script:Calls.CliNames = @($PrereqNames)
    [pscustomobject]@{Name='skills.zip';Key='skills-bundle';Status='ok';Source='mock-bundle';Detail='dry-run'}
}
function Show-TuiModeSelection { return $script:Mode }
function Show-TuiReview { param($SelectedAppKeys,$Options,$SkillsManagerScenarioMode,$ModeName,[switch]$IncludeOnly) return [pscustomobject]@{Options=$Options} }
function Show-TuiSkillsManagerScenarioSelection { param($InitialMode,$InitialName)
    $script:Calls.Scenarios++
    return [pscustomobject]@{Mode='skip';Name=''}
}
function Invoke-BootstrapExit { param([int]$Code)
    $script:Calls.ExitCode = $Code
    $script:Calls.Results = $results.ToArray()
    throw [OperationCanceledException]::new('test-complete')
}
$prefix = @'
$root = $script:TestRoot
$shouldUseTui = [bool]$Tui
$bootstrapDependencies = @()
'@
$start = $ast.Extent.Text.IndexOf('$effectiveUserHome = Get-OriginalUserHomeDirectory')
$body = [scriptblock]::Create($ast.ParamBlock.Extent.Text + "`n" + $prefix + "`n" + $ast.Extent.Text.Substring($start))
function Invoke-Case([string]$Name, [hashtable]$Arguments, [string[]]$Apps, [int]$Bundles = 0, [int]$ExpectedExit = 0) {
    $script:Calls = @{Apps=@();Bundle=0;Components=0;Scenarios=0;Provider=0;ExitCode=-1;Results=@();Title=''}
    $Arguments.DryRun = $true
    $Arguments.BootstrapSourceRoot = $script:TestRoot
    try { & $body @Arguments *>&1 | Out-Null }
    catch { if ($_.Exception.Message -ne 'test-complete') { throw } }
    Assert-Equal $script:Calls.ExitCode $ExpectedExit "$Name exit"
    Assert-Equal $script:Calls.Apps $Apps "$Name apps"
    Assert-Equal $script:Calls.Bundle $Bundles "$Name bundle download"
    Assert-Equal $script:Calls.Components $Bundles "$Name component import"
    Assert-Equal @($script:Calls.Results | Where-Object Key -eq 'codex-workspace').Count 0 "$Name workspace"
    Write-Output "PASS: $Name"
}
$defaults = @('git','nodejs','python','vscode','codex','chatgpt','cc-switch')
Invoke-Case 'command defaults' @{} $defaults
Invoke-Case 'explicit optional application' @{Only='skills-manager';SkipCcSwitch=$true} @('skills-manager')
Invoke-Case 'no apps' @{SkipApps=$true;SkipCcSwitch=$true} @()
Invoke-Case 'all skills opt-in' @{SkipApps=$true;AllSkills=$true} @() 1
Invoke-Case 'all suites opt-in' @{SkipApps=$true;AllSuites=$true} @() 1
foreach ($selector in @('SkillProfile','SkillName','McpName','CliName')) {
    $arguments = @{SkipApps=$true}; $arguments[$selector]='test-component'
    Invoke-Case "$selector opt-in" $arguments @() 1
}
Invoke-Case 'skip wins over explicit components' @{SkipApps=$true;AllSkills=$true;SkipSkills=$true} @()
$script:Mode = 'original'
Invoke-Case 'TUI default' @{Tui=$true} $defaults
Assert-Equal $script:Calls.Scenarios 0 'default does not ask Skills Manager scenario'
foreach ($selector in @('SkillName','McpName','CliName')) {
    $arguments = @{Tui=$true;SkipApps=$true}; $arguments[$selector]='test-component'
    Invoke-Case "TUI preserves $selector" $arguments @() 1
    Assert-Equal $script:Calls[$selector.Replace('Name','Names')] 'test-component' "TUI selected $selector"
}
$script:Mode = 'dryrun'
Invoke-Case 'TUI safe preview defaults' @{Tui=$true} $defaults
Assert-Equal $script:Calls.Scenarios 0 'safe preview does not ask scenario'
Invoke-Case 'resolved default after elevation' @{BootstrapTuiResolved=$true;SkipSkills=$true} $defaults
Invoke-Case 'resolved component after elevation' @{BootstrapTuiResolved=$true;SkillName='test-component';SkipApps=$true} @() 1

# Exercise real defaults and the real deep link without input or UI.
$module = Get-Module common
$provider = & $module {
    function Read-HostWithDefaultValue { param($Prompt,$DefaultValue) return $DefaultValue }
    function Write-CodexProviderInputSection { param($Title,$Detail) }
    function Write-CodexProviderInputLine { param($Label,$Value) }
    $names = @('VIBE_CODING_PROVIDER_NAME','VIBE_CODING_BASE_URL','VIBE_CODING_MODEL')
    $saved = @{}
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name); [Environment]::SetEnvironmentVariable($name,$null) }
    try { Read-CodexProviderInput -PresetApiKey 'test-placeholder' }
    finally { foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$saved[$name]) } }
}
Assert-Equal $provider.Name 'IndieArk API' 'provider default name'
Assert-Equal $provider.Model 'gpt-6.1-sol' 'provider default model'
Assert-Equal $provider.BaseUrl 'https://api.indieark.tech/v1' 'provider default endpoint'
$link = & $module { param($info) New-CcSwitchCodexDeepLink -ProviderInfo $info } $provider
Assert-Equal ([uri]::UnescapeDataString($link).Contains('endpoint=https://api.indieark.tech/v1')) $true 'deep link endpoint'
Assert-Equal ($link.Contains('model=gpt-6.1-sol')) $true 'deep link model'
$manifest = Get-AppManifest -ManifestPath .\manifest\apps.json
Assert-Equal @($manifest.apps | Where-Object key -eq 'codex-provider-sync').Count 0 'provider sync removed'
Assert-Equal @(Get-SelectedApps -Apps $manifest.apps -Only 'skills-manager').key 'skills-manager' 'optional application can be selected'
Assert-Equal @(Get-SelectedApps -Apps $manifest.apps -Only 'git,skills-manager').key @('git','skills-manager') 'mixed explicit selection'
$script:ExistingProvider = [pscustomobject]@{Id='existing';Name='IndieArk API'}
Invoke-Case 'existing provider preserved' @{Only='cc-switch'} @('cc-switch')
Assert-Equal $script:Calls.Provider 0 'existing provider is not imported implicitly'
foreach ($setting in @('CcSwitchBaseUrl','CcSwitchModel','CcSwitchApiKey')) {
    $arguments = @{Only='cc-switch'}; $arguments[$setting]='test-override'
    Invoke-Case "explicit $setting imports again" $arguments @('cc-switch')
    Assert-Equal $script:Calls.Provider 1 "$setting override is respected"
}
$script:ExistingProvider = $null
$script:InstallFailure = $true
Invoke-Case 'failure summary' @{Only='git';SkipCcSwitch=$true} @('git') 0 1
Assert-Equal $script:Calls.Title.Contains('failed') $false 'completion title is localized'
Assert-Equal $script:Calls.Title.StartsWith([char]0x606D) $false 'failure does not congratulate'
function Invoke-BootstrapExit { param([int]$Code)
    $script:Calls.ExitCode = $Code
    $script:Calls.Results = $results.ToArray()
}
Invoke-Case 'failure when keep-open exit helper returns' @{Only='git';SkipCcSwitch=$true;KeepShellOpen=$true} @('git') 0 1
$script:InstallFailure = $false
foreach ($only in @('git,unknown-app','codex-provider-sync')) {
    $rejected = $false
    try { Get-SelectedApps -Apps $manifest.apps -Only $only | Out-Null }
    catch { $rejected = $_.Exception.Message -like '*Unknown application key*' }
    Assert-Equal $rejected $true "unknown application rejected: $only"
}

# Evaluate the actual startup policy without fetching files.
$policyStart = $ast.Extent.Text.IndexOf('$bootstrapDependenciesRefresh =')
$policyEnd = $ast.Extent.Text.IndexOf('$shouldUseTui = Test-BootstrapShouldUseTui')
$policy = [scriptblock]::Create($ast.Extent.Text.Substring($policyStart, $policyEnd - $policyStart) + "`nreturn `$bootstrapDependenciesRefresh")
$root = $script:TestRoot
[switch]$RefreshBootstrapDependencies = $false
$BootstrapSourceRoot = $root
Assert-Equal (& $policy) $false 'complete local checkout does not self-update'
$BootstrapSourceRoot = 'https://raw.githubusercontent.com/indieark/vibe-coding-setup/main'
Assert-Equal (& $policy) $true 'remote bootstrap always refreshes dependencies'
Write-Output "PASS: $script:Assertions assertions, installation and provider side effects mocked"
