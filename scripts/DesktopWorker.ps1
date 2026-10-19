[CmdletBinding()]
param([string]$StopPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$root = Split-Path -Parent $PSScriptRoot
$runId = ''
$secret = ''

$emitLine = {
    param([hashtable]$Event, [string]$EventRunId, [string]$EventSecret)
    function Protect-EventValue {
        param($Value, [string]$Field = '')
        # Protocol identifiers are controlled values, never credential-bearing strings.
        if ($Field -in @('type','runId','key','phase','status','Source','kind')) { return $Value }
        if ($Value -is [string]) {
            if (-not $EventSecret) { return $Value }
            $escaped = ConvertTo-Json -InputObject $EventSecret -Compress
            return $Value.Replace($EventSecret, '[redacted]').Replace([uri]::EscapeDataString($EventSecret), '[redacted]').Replace($escaped.Substring(1, $escaped.Length - 2), '[redacted]')
        }
        if ($Value -is [Collections.IDictionary]) {
            $safe = @{}
            foreach ($key in $Value.Keys) { $safe[$key] = Protect-EventValue -Value $Value[$key] -Field $key }
            return $safe
        }
        if ($Value -is [array]) { return ,@($Value | ForEach-Object { Protect-EventValue -Value $_ }) }
        if ($Value -is [pscustomobject]) {
            $safe = @{}
            foreach ($property in $Value.PSObject.Properties) { $safe[$property.Name] = Protect-EventValue -Value $property.Value -Field $property.Name }
            return $safe
        }
        return $Value
    }
    $Event['runId'] = $EventRunId
    $safe = Protect-EventValue -Value $Event
    [Console]::Out.WriteLine('@@INDIEARK@@' + (ConvertTo-Json -InputObject $safe -Depth 14 -Compress))
    [Console]::Out.Flush()
}
function Send-DesktopEvent {
    param([hashtable]$Event)
    & $emitLine $Event $runId $secret
}

function Get-DesktopBundlePath {
    param([bool]$Refresh)
    # Reuse the launcher's atomic downloader, without running its entry point.
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bootstrap.ps1'), [ref]$tokens, [ref]$errors)
    foreach ($node in $ast.EndBlock.Statements) {
        if ($node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Ensure-BootstrapDirectory','Invoke-BootstrapDownloadFile','ConvertFrom-BootstrapUtf8Base64String')) {
            . ([scriptblock]::Create($node.Extent.Text))
        }
    }
    function Write-BootstrapDownloadProgress {
        param($Label,$Percent,$Detail,[switch]$Completed)
        Send-DesktopEvent @{type='progress';label=$Label;percent=$Percent;detail=$Detail}
    }
    $path = Join-Path $root 'downloads/skills.zip'
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $env:LOCALAPPDATA 'IndieArk/Setup/cache/skills.zip' }
    if ($Refresh -or -not (Test-Path -LiteralPath $path)) {
        Send-DesktopEvent @{type='phase';phase='extensions';message='Downloading extension catalog'}
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-BootstrapDownloadFile -Uri 'https://github.com/indieark/vibe-coding-setup/releases/download/bootstrap-assets/skills.zip' -OutFile $path
    }
    return $path
}

function Get-DesktopExtensionItems {
    param($Inventory, $Status)
    foreach ($profile in @($Inventory.Profiles)) {
        $profileSkills = if ($profile.PSObject.Properties['ExpandedSkills']) { @($profile.ExpandedSkills) } else { @($profile.Skills) }
        [pscustomobject]@{id=('profile:' + $profile.Name);kind='profile';name=$profile.Name;description=$profile.Description;skills=@($profileSkills);mcp=@($profile.Mcp);requires=@($profile.Prereqs);installed=$null;updateAvailable=$false;targets=@()}
    }
    $names = @(@($Inventory.BundleSkills) + @($Inventory.RegistrySkills | ForEach-Object Name) | Sort-Object -Unique)
    foreach ($name in $names) {
        $entry = @($Inventory.RegistrySkills | Where-Object Name -eq $name | Select-Object -First 1)
        $state = @($Status.Skills | Where-Object Name -eq $name | Select-Object -First 1)
        $requires = if ($entry.Count) { @($entry[0].Requires) } else { @() }
        if ($entry.Count -and $entry[0].Section -eq 'external' -and $entry[0].Repo) { $requires += 'git' }
        $members = @()
        if ($Inventory.PSObject.Properties['SkillSources']) {
            $members = @($Inventory.SkillSources | Where-Object { $_.Meta -and $_.Meta.PSObject.Properties['registry_entry_name'] -and $_.Meta.registry_entry_name -eq $name } | ForEach-Object Name | Sort-Object -Unique)
        }
        if ($members.Count -gt 0 -and $name -in @($Inventory.BundleSkills)) { $members = @(@($name) + $members | Sort-Object -Unique) }
        if ($members.Count -gt 0) {
            $memberStates = @($Status.Skills | Where-Object { $_.Name -in $members })
            $state = @(if ($memberStates.Count -eq $members.Count) {
                [pscustomobject]@{Installed=(@($memberStates | Where-Object { -not $_.Installed }).Count -eq 0);UpdateAvailable=(@($memberStates | Where-Object UpdateAvailable).Count -gt 0)}
            })
        }
        [pscustomobject]@{id=('skill:' + $name);kind='skill';name=$name;description=$(if ($entry.Count) {$entry[0].Description} else {''});skills=$members;mcp=@();requires=@($requires | Sort-Object -Unique);installed=$(if ($state.Count) {[bool]$state[0].Installed} else {$null});updateAvailable=($state.Count -gt 0 -and $state[0].UpdateAvailable);targets=@()}
    }
    foreach ($entry in @($Inventory.Mcp)) {
        $state = @($Status.Mcp | Where-Object Name -eq $entry.Name | Select-Object -First 1)
        [pscustomobject]@{id=('mcp:' + $entry.Name);kind='mcp';name=$entry.Name;description=('MCP / ' + $entry.Transport);skills=@();mcp=@();requires=@($entry.Requires);installed=$(if ($state.Count) {[bool]$state[0].Configured} else {$null});updateAvailable=$false;targets=@(if ($state.Count) {$state[0].Targets})}
    }
    foreach ($entry in @($Inventory.Prereqs)) {
        $state = @($Status.Prereqs | Where-Object Name -eq $entry.Name | Select-Object -First 1)
        [pscustomobject]@{id=('cli:' + $entry.Name);kind='cli';name=$entry.Name;description=$entry.Kind;skills=@();mcp=@();requires=@();installed=$(if ($state.Count) {[bool]$state[0].Installed} else {$null});updateAvailable=$false;targets=@()}
    }
}


function Get-DesktopValue {
    param($Object,[string]$Name,$Default=$null)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}
function Get-DesktopProviderState {
    param([string]$Name)
    try { $existing = Get-CcSwitchProviderByName -ProviderName $Name; return @{status=$(if ($existing) {'exists'} else {'missing'});name=$Name} }
    catch { return @{status='unknown';name=$Name;message='Unable to read CC Switch configuration. Retry or choose explicit import.'} }
}
function Resolve-DesktopComponents {
    param([string[]]$Ids)
    $zipPath = Get-DesktopBundlePath -Refresh:$false
    $inventory = Get-SkillBundleInventory -ZipPath $zipPath
    $emptyStatus = [pscustomobject]@{Skills=@();Mcp=@();Prereqs=@()}
    $items = @(Get-DesktopExtensionItems -Inventory $inventory -Status $emptyStatus)
    foreach ($id in $Ids) { if ($id -notin @($items | ForEach-Object id)) { throw ('Unknown extension component: ' + $id) } }
    $chosen = @($items | Where-Object { $_.id -in $Ids })
    $skills = @($chosen | Where-Object kind -eq 'skill' | ForEach-Object { if ($_.skills.Count) { $_.skills } else { $_.name } })
    $mcps = @($chosen | Where-Object kind -eq 'mcp' | ForEach-Object name)
    $prereqs = @($chosen | Where-Object kind -eq 'cli' | ForEach-Object name)
    foreach ($profile in @($chosen | Where-Object kind -eq 'profile')) { $skills += @($profile.skills); $mcps += @($profile.mcp) }
    $prereqs += @($chosen | ForEach-Object requires)
    if (($skills.Count + $mcps.Count + $prereqs.Count) -eq 0) { throw 'Select at least one installable extension component.' }
    return @{ZipPath=$zipPath;SkillNames=@($skills | Sort-Object -Unique);McpNames=@($mcps | Sort-Object -Unique);PrereqNames=@($prereqs | Sort-Object -Unique)}
}
try {
    $inputReader = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.UTF8Encoding]::new($false), $true)
    try { $plan = $inputReader.ReadToEnd() | ConvertFrom-Json } finally { $inputReader.Dispose() }
    $runId = [string]$plan.runId
    $mode = [string]$plan.mode
    if ($mode -notin @('describe','provider-check','check','install','extensions','install-components','execute')) { throw 'Unsupported operation.' }
    Import-Module (Join-Path $root 'modules/common.psm1') -Force -DisableNameChecking
    $manifest = Get-AppManifest -ManifestPath (Join-Path $root 'manifest/apps.json')
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($mode -eq 'describe') { Send-DesktopEvent @{type='catalog';protocolVersion=2;apps=@($manifest.apps);provider=Get-CodexProviderDefaults;isAdmin=$isAdmin}; exit 0 }
    if ($mode -eq 'provider-check') {
        $name = [string](Get-DesktopValue $plan.provider 'name' '')
        if ([string]::IsNullOrWhiteSpace($name)) { throw 'Provider name is required.' }
        Send-DesktopEvent @{type='catalog';providerState=(Get-DesktopProviderState $name)}; exit 0
    }
    $secret = [string](Get-DesktopValue (Get-DesktopValue $plan 'provider') 'apiKey' '')
    $warnings = [Collections.Generic.List[string]]::new()
    $componentRows = @{}
    $eventSink = {
        param($Event)
        if ($Event.type -eq 'log' -and $Event.level -in @('WARN','ERROR')) { $warnings.Add([string]$Event.message) }
        if ($Event.type -eq 'component-result') { $componentRows[[string]$Event.key] = $Event.result }
        & $emitLine $Event $runId $secret
    }.GetNewClosure()
    Set-InstallerEventSink -Sink $eventSink -StopPath $StopPath
    if ($mode -eq 'extensions') {
        Send-DesktopEvent @{type='phase';phase='extensions'}
        $zipPath = Get-DesktopBundlePath -Refresh:([bool](Get-DesktopValue $plan 'refreshBundle' $false))
        $inventory = Get-SkillBundleInventory -ZipPath $zipPath
        $status = Get-SkillBundleComponentStatus -ZipPath $zipPath
        $items = @(Get-DesktopExtensionItems -Inventory $inventory -Status $status)
        if (-not $items.Count) { throw 'The bundle contains no readable extension components. Update the catalog and retry.' }
        Send-DesktopEvent @{type='extensions-catalog';items=$items;checkedAt=[DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')}
        Send-DesktopEvent @{type='done';success=$true;cancelled=$false;checkedOnly=$true;results=@()}; exit 0
    }
    $dryRun = [bool]$plan.dryRun
    $keys = @(Get-DesktopValue $plan 'appKeys' @() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ids = @(Get-DesktopValue $plan 'componentIds' @() | Sort-Object -Unique)
    $configureProvider = [bool](Get-DesktopValue $plan 'configureProvider' $false)
    if ($mode -eq 'install-components') { $keys=@(); $configureProvider=$false; if (-not $ids.Count) { throw 'Select at least one extension component.' } }
    if ($mode -eq 'check' -and -not $keys.Count) { throw 'Select at least one application to check.' }
    if (($keys.Count + $ids.Count) -eq 0 -and -not $configureProvider) { throw 'Select applications, extensions, or provider configuration.' }
    if ($mode -ne 'check' -and -not $dryRun -and -not $isAdmin) { throw 'Administrator privileges are required. Reopen through the launcher.' }
    # Validate every part of a combined plan before any installation or configuration write.
    $apps = @(if ($keys.Count) { Get-SelectedApps -Apps $manifest.apps -Only $keys | Sort-Object order })
    $options = Get-DesktopValue $plan 'options'
    foreach ($flag in @('replacementConfirmed','launchSkillsManager')) {
        if ((Get-DesktopValue $options $flag $false) -isnot [bool]) { throw ('Invalid boolean import option: ' + $flag) }
    }
    $orphanPolicy = [string](Get-DesktopValue $options 'orphanPolicy' 'preserve')
    $foreignPolicy = [string](Get-DesktopValue $options 'foreignPolicy' 'preserve')
    $scenarioMode = [string](Get-DesktopValue $options 'scenarioMode' 'skip')
    $scenarioName = [string](Get-DesktopValue $options 'scenarioName' '')
    if ($orphanPolicy -notin @('preserve','backup') -or $foreignPolicy -notin @('preserve','replace','rename') -or $scenarioMode -notin @('skip','default','custom')) { throw 'Invalid extension import policy.' }
    if ($ids.Count -and $scenarioMode -eq 'custom' -and [string]::IsNullOrWhiteSpace($scenarioName)) { throw 'Enter a custom Skills Manager scenario name.' }
    if ($ids.Count -and -not $dryRun -and ($orphanPolicy -eq 'backup' -or $foreignPolicy -eq 'replace') -and -not [bool](Get-DesktopValue $options 'replacementConfirmed' $false)) { throw 'Confirm the backup and replacement policy before installation.' }
    $selection = if ($ids.Count) { Resolve-DesktopComponents $ids } else { $null }
    $provider = $null; $reuseProvider = $false
    if ($configureProvider -and $mode -ne 'check') {
        $name = [string](Get-DesktopValue $plan.provider 'name' '')
        if ([string]::IsNullOrWhiteSpace($name)) { throw 'Provider name is required.' }
        $providerMode = [string](Get-DesktopValue $options 'providerMode' 'reuse')
        if ($providerMode -notin @('reuse','import')) { throw 'Invalid provider import mode.' }
        $providerState = Get-DesktopProviderState $name
        $reuseProvider = $providerMode -eq 'reuse' -and $providerState.status -eq 'exists'
        if (-not $reuseProvider) {
            $endpoint = $null
            if (-not [uri]::TryCreate([string]$plan.provider.baseUrl,[UriKind]::Absolute,[ref]$endpoint) -or $endpoint.Scheme -notin @('https','http') -or $endpoint.UserInfo) { throw 'Enter a valid API endpoint without embedded credentials.' }
            if ([string]::IsNullOrWhiteSpace($plan.provider.model)) { throw 'Model is required.' }
            if (-not $dryRun -and [string]::IsNullOrWhiteSpace($secret)) { throw 'Enter an API Key or reuse an existing provider.' }
            $provider = [pscustomobject]@{Name=$name;BaseUrl=$endpoint.AbsoluteUri.TrimEnd('/');Model=[string]$plan.provider.model;ApiKey=$(if ($secret) {$secret} else {'sk-'})}
        }
    }
    $decisionsByKey = @{}
    if ($apps.Count) {
        Send-DesktopEvent @{type='phase';phase='check'}
        foreach ($decision in @(Get-AppInstallDecisionBatch -Definitions $apps)) {
            $decisionsByKey[[string]$decision.Key]=$decision
            Send-DesktopEvent @{type='checked';key=$decision.Key;status=$decision.Status;decision=$decision.Decision;error=$decision.Error}
        }
    }
    if ($mode -eq 'check') { Send-DesktopEvent @{type='done';success=$true;cancelled=$false;checkedOnly=$true;results=@()}; exit 0 }
    $results = [Collections.Generic.List[object]]::new()
    foreach ($app in $apps) {
        if ($StopPath -and (Test-Path -LiteralPath $StopPath)) { break }
        Send-DesktopEvent @{type='phase';phase='install'}
        Send-DesktopEvent @{type='app-start';key=$app.key;name=$app.name}
        try {
            $precheck = $decisionsByKey[[string]$app.key]
            if ($precheck.Status -ne 'ok') { throw $precheck.Error }
            $result = Install-AppFromDefinition -Definition $app -WorkspaceRoot $root -InstallDecision $precheck.Decision -DryRun:$dryRun
        } catch { $result = [pscustomobject]@{Name=$app.name;Key=$app.key;Status='failed';Source=$app.strategy;Detail=$_.Exception.Message} }
        $result | Add-Member -MemberType NoteProperty -Name Preview -Value $dryRun -Force
        $results.Add($result); Send-DesktopEvent @{type='app-result';key=$app.key;result=$result}
    }
    if ($configureProvider -and -not ($StopPath -and (Test-Path -LiteralPath $StopPath))) {
        Send-DesktopEvent @{type='phase';phase='provider'}
        try {
            if ($reuseProvider) { $result = [pscustomobject]@{Name='CC Switch Provider';Key='cc-switch-provider';Status='skipped';Source='precheck-skip';Detail='Existing provider preserved; no import required'} }
            else {
                $ccInstall = @($results | Where-Object Key -eq 'cc-switch' | Select-Object -Last 1)
                if ($ccInstall.Count -and $ccInstall[0].Status -eq 'failed') { throw 'CC Switch installation failed. Fix it before importing the provider.' }
                $warmup = $ccInstall.Count -gt 0 -and $ccInstall[0].Source -ne 'precheck-skip'
                $result = Import-CcSwitchCodexProvider -ProviderInfo $provider -ForceWarmup:$warmup -DryRun:$dryRun
                $result.Detail = if ($dryRun) {'Provider import previewed'} else {'Import opened; confirm in CC Switch'}
                $result | Add-Member -MemberType NoteProperty -Name NeedsConfirmation -Value (-not $dryRun) -Force
            }
        } catch { $result = [pscustomobject]@{Name='CC Switch Provider';Key='cc-switch-provider';Status='failed';Source='ccswitch-deeplink';Detail=$_.Exception.Message} }
        $result | Add-Member -MemberType NoteProperty -Name Preview -Value $dryRun -Force
        $results.Add($result); Send-DesktopEvent @{type='app-result';key='cc-switch-provider';result=$result}
    }
    if ($selection -and -not ($StopPath -and (Test-Path -LiteralPath $StopPath))) {
        Send-DesktopEvent @{type='phase';phase='components'}
        Send-DesktopEvent @{type='app-start';key='skills-bundle';name='Extension components'}
        try {
            $warnings.Clear()
            $result = Install-SkillBundle @selection -NoReplaceOrphan:($orphanPolicy -eq 'preserve') -ReplaceForeign:($foreignPolicy -eq 'replace') -RenameForeign:($foreignPolicy -eq 'rename') -SkipSkillsManagerLaunch:(-not [bool](Get-DesktopValue $options 'launchSkillsManager' $false)) -SkillsManagerScenarioMode $scenarioMode -SkillsManagerScenarioName $scenarioName -DryRun:$dryRun
            if ($warnings.Count) { $result | Add-Member -MemberType NoteProperty -Name Warnings -Value $warnings.ToArray() -Force; if ($result.Status -eq 'ok') { $result.Status='warning' } }
            if (@($componentRows.Values | Where-Object { $_.Status -eq 'failed' }).Count) { $result.Status='failed' }
        } catch { $result = [pscustomobject]@{Name='Extension components';Key='skills-bundle';Status='failed';Source='local-zip';Detail=$_.Exception.Message} }
        $result | Add-Member -MemberType NoteProperty -Name Preview -Value $dryRun -Force
        $results.Add($result); Send-DesktopEvent @{type='app-result';key='skills-bundle';result=$result}
    }
    $cancelled = [bool]($StopPath -and (Test-Path -LiteralPath $StopPath))
    $failed = @($results | Where-Object Status -eq 'failed')
    Send-DesktopEvent @{type='done';success=($failed.Count -eq 0 -and -not $cancelled);cancelled=$cancelled;results=$results.ToArray();dryRun=$dryRun}
    if ($failed.Count) { exit 1 }; exit 0
} catch { Send-DesktopEvent @{type='fatal';message=$_.Exception.Message}; exit 1 }
