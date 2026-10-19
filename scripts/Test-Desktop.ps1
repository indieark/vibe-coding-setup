[CmdletBinding()]
param([switch]$SkipBinary)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$scratch = Join-Path $root ('.local\desktop-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $scratch 'scripts'),(Join-Path $scratch 'modules'),(Join-Path $scratch 'manifest') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'scripts\DesktopWorker.ps1') -Destination (Join-Path $scratch 'scripts\DesktopWorker.ps1')
Copy-Item -LiteralPath (Join-Path $root 'manifest\apps.json') -Destination (Join-Path $scratch 'manifest\apps.json')
Copy-Item -LiteralPath (Join-Path $root 'bootstrap.ps1') -Destination (Join-Path $scratch 'bootstrap.ps1')
New-Item -ItemType Directory -Path (Join-Path $scratch 'downloads') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $scratch 'downloads/skills.zip'),'fixture: inventory is mocked')
# The native host materializes scripts into a new run directory. Never download assets in its fixture.
[IO.File]::AppendAllText((Join-Path $scratch 'bootstrap.ps1'), "`r`nfunction Invoke-BootstrapDownloadFile { param(`$Uri,`$OutFile); New-Item -ItemType Directory -Path (Split-Path -Parent `$OutFile) -Force | Out-Null; [IO.File]::WriteAllText(`$OutFile,'fixture') }`r`n")
$common = [IO.File]::ReadAllText((Join-Path $root 'modules\common.psm1'))
$mocks = @'
function Get-AppInstallDecisionBatch {
    param($Definitions)
    foreach ($item in $Definitions) {
        [pscustomobject]@{Key=$item.key;Status='ok';Error=$null;Decision=[pscustomobject]@{Action='install';Reason='missing';InstalledVersion='';DesiredVersion=''}}
    }
}
function Install-AppFromDefinition {
    param($Definition,$WorkspaceRoot,$InstallDecision,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real installations forbidden in tests' }
    if ($Definition.key -eq 'git') { throw 'Simulated Git download failure' }
    [pscustomobject]@{Name=$Definition.name;Key=$Definition.key;Status='ok';Source='test';Detail='dry-run'}
}
function Import-CcSwitchCodexProvider {
    param($ProviderInfo,[switch]$ForceWarmup,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real provider import forbidden in tests' }
    throw ('Simulated failure: ' + $ProviderInfo.ApiKey + ' / ' + [uri]::EscapeDataString($ProviderInfo.ApiKey))
}
function Get-SkillBundleInventory {
    param($ZipPath)
    [pscustomobject]@{
        Profiles=@([pscustomobject]@{Name='web';Description='Web tools';Skills=@('design-group');ExpandedSkills=@('design','detail');Mcp=@('browser');Prereqs=@('node')})
        BundleSkills=@('design','detail');RegistrySkills=@()
        Mcp=@([pscustomobject]@{Name='browser';Transport='stdio';Requires=@('node')})
        Prereqs=@([pscustomobject]@{Name='node';Kind='npm'})
    }
}
function Get-SkillBundleComponentStatus {
    param($ZipPath)
    [pscustomobject]@{Skills=@([pscustomobject]@{Name='design';Installed=$false;UpdateAvailable=$false});Mcp=@([pscustomobject]@{Name='browser';Configured=$true;Targets=@('Codex')});Prereqs=@([pscustomobject]@{Name='node';Installed=$true})}
}
function Install-SkillBundle {
    param($ZipPath,$SkillNames,$McpNames,$PrereqNames,[switch]$NoReplaceOrphan,[switch]$SkipSkillsManagerLaunch,$SkillsManagerScenarioMode,[switch]$DryRun)
    if (-not $DryRun) { throw 'Real extension installs forbidden in tests' }
    if (-not $NoReplaceOrphan -or -not $SkipSkillsManagerLaunch -or $SkillsManagerScenarioMode -ne 'skip') { throw 'Unsafe GUI extension policy' }
    if ('detail' -in $SkillNames) { Write-Log -Level WARN -Message 'Kept an existing fixture skill' }
    [pscustomobject]@{Name='Extensions';Key='skills-bundle';Status='ok';Source='test';Detail=(@{Skills=@($SkillNames);Mcp=@($McpNames);Cli=@($PrereqNames)} | ConvertTo-Json -Compress)}
}
Export-ModuleMember -Function Get-AppInstallDecisionBatch,Install-AppFromDefinition,Import-CcSwitchCodexProvider,Get-SkillBundleInventory,Get-SkillBundleComponentStatus,Install-SkillBundle
'@
[IO.File]::WriteAllText((Join-Path $scratch 'modules\common.psm1'),$common + "`r`n" + $mocks,[Text.UTF8Encoding]::new($false))
$assertions = 0
function Assert-True([bool]$Value,[string]$Message) { if (-not $Value) {throw $Message}; $script:assertions++ }
function Run-Worker([hashtable]$Plan,[string]$StopPath='') {
    $Plan.runId = 'test-run'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = 'powershell.exe'
    $process.StartInfo.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $scratch 'scripts\DesktopWorker.ps1') + '"'
    if ($StopPath) { $process.StartInfo.Arguments += ' -StopPath "' + $StopPath + '"' }
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardInput = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $inputBytes = [Text.Encoding]::UTF8.GetBytes(($Plan | ConvertTo-Json -Depth 10 -Compress))
    $process.StandardInput.BaseStream.Write($inputBytes,0,$inputBytes.Length)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(15000)) {$process.Kill();throw 'Worker timed out'}
    $process.WaitForExit()
    $raw = $stdout.Result
    $events = @($raw -split "`r?`n" | Where-Object { $_.StartsWith('@@INDIEARK@@') } | ForEach-Object {$_.Substring(12) | ConvertFrom-Json})
    [pscustomobject]@{ExitCode=$process.ExitCode;Raw=$raw;Events=$events;Error=$stderr.Result}
}
$describe = Run-Worker @{mode='describe'}
Assert-True ($describe.ExitCode -eq 0) ('Describe should succeed. Worker stdout: ' + $describe.Raw + '; stderr: ' + $describe.Error)
$catalog = $describe.Events | Where-Object type -eq 'catalog'
Assert-True ($catalog.apps.Count -eq 8) 'Catalog reads the real manifest'
Assert-True ($catalog.provider.Model -eq 'gpt-6.1-sol') 'Catalog reuses provider defaults'
$previousInputEncoding = [Console]::InputEncoding
try {
    [Console]::InputEncoding = [Text.UTF8Encoding]::new($true)
    $bomDescribe = Run-Worker @{mode='describe'}
}
finally { [Console]::InputEncoding = $previousInputEncoding }
Assert-True ($bomDescribe.ExitCode -eq 0) 'Worker input remains valid when the parent console uses UTF-8 with BOM'
if (-not $catalog.isAdmin) {
    $denied = Run-Worker @{mode='install';appKeys=@('nodejs');dryRun=$false;configureProvider=$false;provider=@{}}
    Assert-True ($denied.ExitCode -eq 1 -and @($denied.Events | Where-Object type -eq 'app-start').Count -eq 0) 'Unelevated real installations are rejected before execution'
}
$run = Run-Worker @{mode='install';appKeys=@('git','nodejs');dryRun=$true;configureProvider=$false;provider=@{}}
Assert-True ($run.ExitCode -eq 1) 'Failed app produces failure exit code'
$results = @($run.Events | Where-Object type -eq 'app-result')
Assert-True ($results.Count -eq 2) 'Failure does not skip later selected apps'
Assert-True ($results[0].result.Status -eq 'failed' -and $results[1].result.Status -eq 'ok') 'Per-app outcomes are preserved'
$invalid = Run-Worker @{mode='install';appKeys=@('git','not-an-app');dryRun=$true;configureProvider=$false;provider=@{}}
Assert-True ($invalid.ExitCode -eq 1) 'Invalid selection is rejected'
Assert-True (@($invalid.Events | Where-Object type -eq 'app-start').Count -eq 0) 'Invalid plan never reaches installation'
$secret = 'test-private"key/with?encoding'
$secure = Run-Worker @{mode='install';appKeys=@('nodejs');dryRun=$true;configureProvider=$true;provider=@{name='Test';baseUrl='https://api.indieark.tech/v1';model='test';apiKey=$secret}}
Assert-True (-not $secure.Raw.Contains($secret)) 'Raw key is redacted'
Assert-True (-not $secure.Raw.Contains([uri]::EscapeDataString($secret))) 'URL-encoded key is redacted'
Assert-True ($secure.Raw.Contains('[redacted]')) 'Secret-bearing errors are safely diagnosable'
$decodedDetail = ($secure.Events | Where-Object { $_.type -eq 'app-result' -and $_.key -eq 'cc-switch-provider' }).result.Detail
Assert-True (-not $decodedDetail.Contains($secret)) 'Decoded error does not contain a JSON-escaped key'
$stopPath = Join-Path $scratch 'stop'
[IO.File]::WriteAllText($stopPath,'stop')
$stopped = Run-Worker @{mode='install';appKeys=@('nodejs');dryRun=$true;configureProvider=$false;provider=@{}} $stopPath
Assert-True (@($stopped.Events | Where-Object type -eq 'app-start').Count -eq 0) 'Stop prevents subsequent app launches'
Assert-True (($stopped.Events | Where-Object type -eq 'done').cancelled) 'Stopped operation is not reported as success'
$extensionCatalog = Run-Worker @{mode='extensions';dryRun=$true;refreshBundle=$false}
Assert-True ($extensionCatalog.ExitCode -eq 0) 'Extension catalog runs in the hidden worker'
$extensionItems = @(($extensionCatalog.Events | Where-Object type -eq 'extensions-catalog').items)
Assert-True ($extensionItems.Count -eq 5) 'All four extension kinds are exposed'
Assert-True (($extensionItems | Where-Object id -eq 'mcp:browser').targets[0] -eq 'Codex') 'MCP catalog preserves actual configuration targets'
$mixed = Run-Worker @{mode='install-components';dryRun=$true;refreshBundle=$false;componentIds=@('profile:web','skill:design','cli:node')}
Assert-True ($mixed.ExitCode -eq 0) 'GUI supports mixed profiles and explicit component selections'
$selection = ($mixed.Events | Where-Object type -eq 'app-result').result.Detail | ConvertFrom-Json
Assert-True ($selection.Skills.Count -eq 2 -and 'design' -in $selection.Skills -and 'detail' -in $selection.Skills) 'Profile skill groups expand to real members and deduplicate direct choices'
Assert-True ($selection.Mcp.Count -eq 1 -and $selection.Mcp[0] -eq 'browser') 'Explicit selections do not discard profile MCP members'
Assert-True ($selection.Cli.Count -eq 1 -and $selection.Cli[0] -eq 'node') 'Profile and direct CLI dependencies are merged'
Assert-True (($mixed.Events | Where-Object type -eq 'app-result').result.Status -eq 'warning') 'Core warnings remain visible instead of reporting unconditional success'
$cliOnly = Run-Worker @{mode='install-components';dryRun=$true;refreshBundle=$false;componentIds=@('cli:node')}
$cliSelection = ($cliOnly.Events | Where-Object type -eq 'app-result').result.Detail | ConvertFrom-Json
Assert-True ($cliOnly.ExitCode -eq 0 -and $cliSelection.Skills.Count -eq 0 -and $cliSelection.Mcp.Count -eq 0) 'CLI-only selection never installs skills or MCP implicitly'
foreach ($ids in @(@(),@('profile:web','skill:unknown'))) {
    $invalidExtensions = Run-Worker @{mode='install-components';dryRun=$true;refreshBundle=$false;componentIds=$ids}
    Assert-True ($invalidExtensions.ExitCode -eq 1 -and @($invalidExtensions.Events | Where-Object type -eq 'app-start').Count -eq 0) 'Empty or unknown extension selections are rejected before installation'
}
$stoppedExtensions = Run-Worker @{mode='install-components';dryRun=$true;refreshBundle=$false;componentIds=@('cli:node')} $stopPath
Assert-True (($stoppedExtensions.Events | Where-Object type -eq 'done').cancelled -and @($stoppedExtensions.Events | Where-Object type -eq 'app-start').Count -eq 0) 'Stop prevents the selected extension transaction from starting'
$routeResults = & {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bootstrap.ps1'),[ref]$tokens,[ref]$errors)
    foreach ($node in $ast.EndBlock.Statements) {
        if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { . ([scriptblock]::Create($node.Extent.Text)) }
    }
    function Start-BootstrapDesktop {
        param($Root,$SourceRoot,$UserHome,[switch]$CheckOnly,[switch]$DryRunOnly)
        [pscustomobject]@{Mode='gui';DryRunOnly=[bool]$DryRunOnly}
    }
    $prefix = '$shouldUseTui = Test-BootstrapShouldUseTui -BoundParameters $PSBoundParameters -TuiSwitch:$Tui'
    $start = $ast.Extent.Text.IndexOf('$effectiveUserHome = Get-OriginalUserHomeDirectory')
    $body = [scriptblock]::Create($ast.ParamBlock.Extent.Text + "`n" + $prefix + "`n" + $ast.Extent.Text.Substring($start))
    Import-Module (Join-Path $root 'modules\common.psm1') -Force -DisableNameChecking
    & $body -PauseOnExit
    & $body -Gui -DryRun
}
Assert-True ($routeResults.Count -eq 2 -and $routeResults[0].Mode -eq 'gui') 'No-operation launcher defaults to GUI before terminal menus'
Assert-True $routeResults[1].DryRunOnly 'Explicit GUI dry-run forwards the enforced safety flag'
if (-not $SkipBinary) {
    foreach ($launcher in @('bootstrap.cmd','vibe-coding-setup.cmd')) {
        $output = & (Join-Path $root $launcher) -GuiCheck | Out-String
        Assert-True ($LASTEXITCODE -eq 0 -and $output.Contains('IndieArkSetup.exe')) ($launcher + ' resolves to the local GUI')
    }
    $safeOutput = & (Join-Path $root 'bootstrap.cmd') -GuiCheck -DryRun | Out-String
    $safeMetadata = ($safeOutput -split "`r?`n" | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json
    Assert-True ($safeMetadata.DryRunOnly -and -not $safeMetadata.RequiresElevation) 'Safe GUI routing never requests installation privileges'
    $exe = Join-Path $root 'desktop\bin\IndieArkSetup.exe'
    $report = Join-Path $scratch 'binary-smoke.json'
    $process = Start-Process -FilePath $exe -ArgumentList @('--smoke-test',('"' + $report + '"')) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Binary smoke test timed out' }
    Assert-True (Test-Path -LiteralPath $report) 'Packaged worker produces a smoke report'
    $events = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    Assert-True (@($events | Where-Object { $_.type -eq 'done' -and $_.success }).Count -eq 1) 'Packaged real worker completes a safe dry-run'
    $overrideReport = Join-Path $scratch 'source-override-smoke.json'
    $override = Start-Process -FilePath $exe -ArgumentList @('--source-root',('"' + $scratch + '"'),'--dry-run-only','--smoke-test',('"' + $overrideReport + '"')) -WindowStyle Hidden -PassThru
    if (-not $override.WaitForExit(30000)) { $override.Kill(); throw 'Source override smoke test timed out' }
    $overrideEvents = Get-Content -LiteralPath $overrideReport -Raw | ConvertFrom-Json
    Assert-True (@($overrideEvents | Where-Object { $_.type -eq 'app-result' -and $_.result.Source -eq 'test' }).Count -eq 1) 'Launcher-provided module overrides embedded resources'
    Assert-True (($overrideEvents | Where-Object type -eq 'done').dryRun) 'Desktop safe-mode policy overrides a real-install request'
    $componentReport = Join-Path $scratch 'native-components.json'
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = Join-Path $scratch 'native-appdata'
        $componentProcess = Start-Process -FilePath $exe -ArgumentList @('--source-root',('"' + $scratch + '"'),'--dry-run-only','--smoke-components','--smoke-test',('"' + $componentReport + '"')) -WindowStyle Hidden -PassThru
    }
    finally { $env:LOCALAPPDATA = $previousLocalAppData }
    if (-not $componentProcess.WaitForExit(30000)) { $componentProcess.Kill(); throw 'Native extension smoke test timed out' }
    $componentEvents = Get-Content -LiteralPath $componentReport -Raw | ConvertFrom-Json
    Assert-True (@($componentEvents | Where-Object type -eq 'extensions-catalog').Count -eq 1) 'Native host forwards the extension catalog without a terminal'
    $componentDone = @($componentEvents | Where-Object type -eq 'done' | Select-Object -Last 1)[0]
    Assert-True ($componentDone.success -and $componentDone.dryRun -and $componentDone.results[0].Key -eq 'skills-bundle') 'Native host serializes component selection and enforces safe-mode policy'
}
Write-Output ("PASS: $assertions desktop integration assertions; no software installed, no GUI opened")
