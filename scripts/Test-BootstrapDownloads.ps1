$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'modules/common.psm1') -Force -DisableNameChecking
$module = Get-Module common
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'bootstrap.ps1'), [ref]$tokens, [ref]$errors)
foreach ($node in $ast.EndBlock.Statements) {
    if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) { . ([scriptblock]::Create($node.Extent.Text)) }
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('vibe-bootstrap-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$ready = Join-Path $scratch 'port.txt'
$server = Start-Job -ArgumentList $ready,$repoRoot -ScriptBlock {
    param($Ready,$RepoRoot)
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $listener.Start()
    [IO.File]::WriteAllText($Ready, [string]$listener.LocalEndpoint.Port)
    try {
        while ($true) {
            if (-not $listener.Pending()) { Start-Sleep -Milliseconds 25; continue }
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream(); $stream.ReadTimeout = 5000
                $reader = [IO.StreamReader]::new($stream)
                $requestLine = $reader.ReadLine()
                if (-not $requestLine) { continue }
                $route = ($requestLine -split ' ')[1]
                while ($reader.ReadLine()) { }
                $status = '200 OK'
                $content = [Text.Encoding]::UTF8.GetBytes('new-download')
                if ($route -in @('/bootstrap.ps1','/modules/common.psm1','/manifest/apps.json')) {
                    $content = [IO.File]::ReadAllBytes((Join-Path $RepoRoot $route.TrimStart('/')))
                }
                elseif ($route -eq '/broken') { $content = [Text.Encoding]::UTF8.GetBytes('short') }
                elseif ($route -ne '/ok') { $status = '404 Not Found' }
                $length = $content.Length
                if ($route -eq '/broken') { $length += 100 }
                $headers = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Length: $length`r`nContent-Type: application/octet-stream`r`nConnection: close`r`n`r`n")
                $stream.Write($headers,0,$headers.Length)
                $stream.Write($content,0,$content.Length)
                $stream.Flush()
            }
            finally { $client.Close() }
        }
    }
    finally { $listener.Stop() }
}
$assertions = 0
function Assert-True([bool]$Value,[string]$Name) {
    if (-not $Value) { throw $Name }
    $script:assertions++
}
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path -LiteralPath $ready)) {
        if ([DateTime]::UtcNow -ge $deadline -or $server.State -eq 'Failed') { throw 'Loopback server did not start' }
        Start-Sleep -Milliseconds 50
    }
    $url = 'http://127.0.0.1:' + [IO.File]::ReadAllText($ready)
    foreach ($kind in @('bootstrap','installer')) {
        $target = Join-Path $scratch ($kind + '.bin')
        $download = if ($kind -eq 'bootstrap') {
            { param($Source,$Target) Invoke-BootstrapDownloadFile -Uri $Source -OutFile $Target }
        } else {
            { param($Source,$Target) & $module { param($Source,$Target) Invoke-DownloadFile -Url $Source -DestinationPath $Target } $Source $Target | Out-Null }
        }
        [IO.File]::WriteAllText($target,'old-download')
        & $download ($url + '/ok') $target
        Assert-True ([IO.File]::ReadAllText($target) -eq 'new-download') "$kind successful replacement"
        foreach ($route in @('/broken','/missing')) {
            $rejected = $false
            try { & $download ($url + $route) $target } catch { $rejected = $true }
            Assert-True $rejected "$kind rejects $route"
            Assert-True ([IO.File]::ReadAllText($target) -eq 'new-download') "$kind preserves cache on $route"
        }
        $newTarget = Join-Path $scratch ($kind + '-absent.bin')
        $rejected = $false
        try { & $download ($url + '/broken') $newTarget } catch { $rejected = $true }
        Assert-True $rejected "$kind rejects initial truncated download"
        Assert-True (-not (Test-Path -LiteralPath $newTarget)) "$kind does not publish truncated file"
        Assert-True (@(Get-ChildItem -LiteralPath $scratch -Filter '*.download').Count -eq 0) "$kind removes pending files"
    }

    # A fresh source checkout gets the public GUI without requiring a compiler.
    $localDesktopRoutes = & {
        $BootstrapAssetsRepo = 'indieark/vibe-coding-setup'
        $BootstrapAssetsTag = 'bootstrap-assets'
        $reuseOnly = $false
        function Copy-BootstrapReleaseAsset {
            param($Repo,$Tag,$DestinationRoot,$RelativePath,$AssetName,$Refresh)
            if ($reuseOnly) { throw 'Local GUI should reuse the existing executable' }
            if ($AssetName -ne 'IndieArkSetup-0.2.3.exe') { throw 'Unexpected desktop asset' }
            $path = Join-Path $DestinationRoot $RelativePath
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
            [IO.File]::WriteAllBytes($path, [byte[]]@(77,90,0,0))
        }
        $localRoot = Join-Path $scratch 'fresh-source'
        Start-BootstrapDesktop -Root $localRoot -SourceRoot $repoRoot -UserHome $scratch -CheckOnly -DryRunOnly | ConvertFrom-Json
        $reuseOnly = $true
        Start-BootstrapDesktop -Root $localRoot -SourceRoot $repoRoot -UserHome $scratch -CheckOnly -DryRunOnly | ConvertFrom-Json
        $reuseOnly = $false
        $renamedRoot = Join-Path $scratch 'renamed-entry'
        [void](New-Item -ItemType Directory -Path $renamedRoot)
        $renamedEntry = Join-Path $renamedRoot 'vibe-bootstrap.ps1'
        Copy-Item -LiteralPath (Join-Path $repoRoot 'bootstrap.ps1') -Destination $renamedEntry
        Start-BootstrapDesktop -Root $renamedRoot -SourceRoot $repoRoot -UserHome $scratch -EntryPath $renamedEntry -CheckOnly -DryRunOnly | ConvertFrom-Json
        $canonicalEntry = Join-Path $renamedRoot 'bootstrap.ps1'
        Assert-True (Test-Path -LiteralPath $canonicalEntry) 'renamed legacy entry provides the desktop source contract'
        Assert-True ((Get-FileHash -LiteralPath $canonicalEntry).Hash -eq (Get-FileHash -LiteralPath $renamedEntry).Hash) 'canonical entry preserves the running legacy script bytes'
    }
    Assert-True ($localDesktopRoutes.Count -eq 3 -and $localDesktopRoutes[0].Mode -eq 'gui') 'fresh source checkout downloads the public GUI'
    Assert-True ($localDesktopRoutes[1].Mode -eq 'gui' -and $localDesktopRoutes[1].DryRunOnly) 'local GUI is reused without elevation or a window'

    # Execute the actual launcher command in a child with an isolated TEMP.
    $launcherLine = Get-Content -LiteralPath (Join-Path $repoRoot 'vibe-coding-setup.cmd') | Where-Object { $_ -match '-Command "' }
    if ($launcherLine -notmatch '-Command "(.*)"$') { throw 'Launcher command not found' }
    $template = $Matches[1].Replace('%BOOTSTRAP_ASSETS_REPO%','indieark/vibe-coding-setup').Replace('%BOOTSTRAP_ASSETS_TAG%','bootstrap-assets').Replace('%*','-DryRun -SkipApps -SkipCcSwitch -KeepShellOpen')
    $runRoot = Join-Path $scratch 'vibe-coding-setup'
    New-Item -ItemType Directory -Path (Join-Path $runRoot 'modules'),(Join-Path $runRoot 'manifest') -Force | Out-Null
    $cachedModule = Join-Path $runRoot 'modules/common.psm1'
    $cachedManifest = Join-Path $runRoot 'manifest/apps.json'
    [IO.File]::WriteAllText($cachedModule, [IO.File]::ReadAllText((Join-Path $repoRoot 'modules/common.psm1')).Replace('gpt-6.1-sol','old-model'))
    [IO.File]::WriteAllText($cachedManifest,'{"apps":[]}')
    $savedTemp = $env:TEMP
    try {
        $env:TEMP = $scratch
        foreach ($mode in @('success','failure')) {
            $source = if ($mode -eq 'success') {$url} else {$url + '/missing'}
            $runner = Join-Path $scratch ($mode + '.ps1')
            $command = $template.Replace('%BOOTSTRAP_ROOT%',$source)
            [IO.File]::WriteAllText($runner,$command,[Text.UTF8Encoding]::new($false))
            $entry = Join-Path $runRoot 'bootstrap.ps1'
            $marker = Join-Path $scratch 'stale-script-executed.txt'
            if ($mode -eq 'failure') { [IO.File]::WriteAllText($entry,"[IO.File]::WriteAllText('$marker','stale')") }
            $process = [Diagnostics.Process]::new()
            $process.StartInfo.FileName = 'powershell.exe'
            $process.StartInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $runner + '"'
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            [void]$process.Start()
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Launcher test timed out' }
            $process.WaitForExit()
            if ($mode -eq 'success') {
                Assert-True ($process.ExitCode -eq 0) ('launcher successful dry-run; exit=' + $process.ExitCode + '; stderr=' + $stderr.Result)
                Assert-True ((Get-FileHash $cachedModule).Hash -eq (Get-FileHash (Join-Path $repoRoot 'modules/common.psm1')).Hash) 'launcher replaces old compatible module'
                Assert-True ((Get-FileHash $cachedManifest).Hash -eq (Get-FileHash (Join-Path $repoRoot 'manifest/apps.json')).Hash) 'launcher replaces cached manifest'
            } else {
                Assert-True ($process.ExitCode -ne 0) 'launcher fails on HTTP error'
                Assert-True (-not (Test-Path -LiteralPath $marker)) 'launcher never executes stale script on failure'
            }
            Assert-True (@(Get-ChildItem -LiteralPath $runRoot -Filter '*.download').Count -eq 0) 'launcher cleans pending script'
        }
    }
    finally { $env:TEMP = $savedTemp }
    Write-Output "PASS: $assertions assertions with loopback HTTP and real launcher child processes"
}
finally {
    Stop-Job $server
    Remove-Job $server
    # Delete only this run's verified temporary directory.
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\vibe-bootstrap-test-'
    if (-not $resolvedScratch.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected scratch path' }
    Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
}
