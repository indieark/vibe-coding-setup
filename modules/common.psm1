Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host ('[{0}] [{1}] {2}' -f $timestamp, $Level, $Message)
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-ArgumentTokens {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $BoundParameters.GetEnumerator()) {
        $name = '-{0}' -f $entry.Key
        $value = $entry.Value

        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $tokens.Add($name)
            }
            continue
        }

        if ($value -is [System.Array]) {
            $tokens.Add($name)
            foreach ($item in $value) {
                $tokens.Add(('"{0}"' -f [string]$item))
            }
            continue
        }

        $tokens.Add($name)
        $tokens.Add(('"{0}"' -f [string]$value))
    }

    return $tokens.ToArray()
}

function ConvertTo-WindowsProcessArgument {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    return '"{0}"' -f ($Value -replace '"', '\"')
}

function Get-AppManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    return Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-SelectedApps {
    param(
        [Parameter(Mandatory)]
        [object[]]$Apps,
        [string[]]$Only
    )

    if (-not $Only -or $Only.Count -eq 0) {
        return $Apps
    }

    $lookup = @(
        $Only |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.ToLowerInvariant() }
    )
    $selected = @($Apps | Where-Object { $lookup -contains $_.key.ToLowerInvariant() })

    if ($selected.Count -eq 0) {
        throw ('No app keys matched: {0}' -f ($Only -join ', '))
    }

    return $selected
}

function Initialize-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-UserHomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:VIBE_CODING_USER_HOME)) {
        return $env:VIBE_CODING_USER_HOME
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }

    return $HOME
}

function Get-UserLocalAppDataDirectory {
    $homeDir = Get-UserHomeDirectory
    if (-not [string]::IsNullOrWhiteSpace($homeDir)) {
        $candidate = Join-Path $homeDir 'AppData\Local'
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        return $env:LOCALAPPDATA
    }

    if (-not [string]::IsNullOrWhiteSpace($homeDir)) {
        return Join-Path $homeDir 'AppData\Local'
    }

    return $null
}

function Initialize-CodexWorkspaceDirectory {
    param(
        [switch]$DryRun
    )

    $candidateDrives = @('D:\', 'C:\')
    $driveRoot = $candidateDrives | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $driveRoot) {
        throw 'Neither drive D: nor C: is available'
    }

    $workspaceRoot = Join-Path $driveRoot 'Vibe Coding'
    $chatPath = Join-Path $workspaceRoot 'Chat'

    if ($DryRun) {
        Write-Log -Message ('[DryRun] Create Codex workspace directory: {0}' -f $chatPath)
        return [pscustomobject]@{
            Name = 'Codex Workspace'
            Key = 'codex-workspace'
            Status = 'ok'
            Source = 'filesystem'
            Detail = $chatPath
        }
    }

    if (Test-Path -LiteralPath $chatPath -PathType Container) {
        Write-Log -Message ('Codex workspace directory already exists, skip creation: {0}' -f $chatPath)
    }
    else {
        Initialize-Directory -Path $workspaceRoot
        Initialize-Directory -Path $chatPath
        Write-Log -Message ('Created Codex workspace directory: {0}' -f $chatPath)
    }

    return [pscustomobject]@{
        Name = 'Codex Workspace'
        Key = 'codex-workspace'
        Status = 'ok'
        Source = 'filesystem'
        Detail = $chatPath
    }
}

function Resolve-WorkspacePath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    return Join-Path $WorkspaceRoot $RelativePath
}

function Get-GitHubLatestReleaseAsset {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,
        [Parameter(Mandatory)]
        [string]$AssetPattern
    )

    $uri = 'https://api.github.com/repos/{0}/releases/latest' -f $Repo
    $headers = @{
        'User-Agent' = 'VibeCodingSetup/1.0'
        'Accept' = 'application/vnd.github+json'
    }

    Write-Log -Message ('Querying GitHub latest release: {0}' -f $Repo)
    $release = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw ('Repo {0} did not expose an asset matching: {1}' -f $Repo, $AssetPattern)
    }

    return [pscustomobject]@{
        Repo = $Repo
        Version = $release.tag_name
        Name = $asset.name
        Url = $asset.browser_download_url
    }
}

function Get-GitHubLatestTagViaRedirect {
    param(
        [Parameter(Mandatory)]
        [string]$Repo
    )

    $url = 'https://github.com/{0}/releases/latest' -f $Repo
    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.Method = 'GET'
    $request.AllowAutoRedirect = $false
    $request.UserAgent = 'VibeCodingSetup/1.0'

    try {
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
        }
        else {
            throw
        }
    }

    try {
        $location = $response.Headers['Location']
        if ([string]::IsNullOrWhiteSpace($location)) {
            throw ('GitHub latest redirect did not provide a Location header: {0}' -f $Repo)
        }

        $match = [regex]::Match($location, '/tag/(?<tag>[^/]+)$')
        if (-not $match.Success) {
            throw ('Could not parse latest tag from redirect: {0}' -f $location)
        }

        return $match.Groups['tag'].Value
    }
    finally {
        $response.Close()
    }
}

function Invoke-DownloadFile {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message ('[DryRun] Download {0} -> {1}' -f $Url, $DestinationPath)
        return $DestinationPath
    }

    Initialize-Directory -Path (Split-Path -Parent $DestinationPath)
    Write-Log -Message ('Downloading {0}' -f $Url)
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath
    return $DestinationPath
}

function Get-GitHubReleaseAssetDownloadUrl {
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

function Test-WingetInstalled {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

function Get-AppendedTextLines {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [ref]$Offset,
        [ref]$PendingLine,
        [switch]$Flush
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $text) {
        return @()
    }

    $safeOffset = [Math]::Min([int]$Offset.Value, $text.Length)
    if ($safeOffset -ge $text.Length) {
        return @()
    }

    $delta = $text.Substring($safeOffset)
    $Offset.Value = $text.Length
    if ([string]::IsNullOrEmpty($delta) -and -not $Flush) {
        return @()
    }

    $combined = '{0}{1}' -f ([string]$PendingLine.Value), $delta
    $normalized = $combined -replace "`r`n", "`n" -replace "`r", "`n"
    $segments = @($normalized -split "`n", 0, 'SimpleMatch')
    $pending = ''

    if (-not $Flush -and $normalized.Length -gt 0 -and -not $normalized.EndsWith("`n")) {
        if ($segments.Count -gt 0) {
            $pending = [string]$segments[-1]
            if ($segments.Count -gt 1) {
                $segments = $segments[0..($segments.Count - 2)]
            }
            else {
                $segments = @()
            }
        }
    }

    $PendingLine.Value = $pending
    return @(
        $segments |
        ForEach-Object { $_.Trim() } |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and
            $_ -notmatch '^[\-/\\|]+$'
        }
    )
}

function Test-WingetNoApplicableUpgradeOutput {
    param(
        [string]$OutputText
    )

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return $false
    }

    foreach ($pattern in @(
            'No available upgrade found\.',
            'No newer package versions are available from the configured sources\.',
            'No installed package found matching input criteria\.'
        )) {
        if ($OutputText -match $pattern) {
            return $true
        }
    }

    return $false
}

function Write-WingetOutputLines {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines = @(),
        [Parameter(Mandatory)]
        [ref]$LastLine,
        [Parameter(Mandatory)]
        [ref]$LastProgressPercent,
        [Parameter(Mandatory)]
        [ref]$Emitted
    )

    foreach ($line in $Lines) {
        $normalizedLine = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($normalizedLine)) {
            continue
        }

        if ($normalizedLine -match '(?<percent>\d{1,3})%' -and $normalizedLine -notmatch '[A-Za-z]') {
            $progressPercent = [int]$Matches['percent']
            if ($progressPercent -eq [int]$LastProgressPercent.Value) {
                continue
            }

            Write-Log -Message ('winget progress: {0}%' -f $progressPercent)
            $LastProgressPercent.Value = $progressPercent
            $LastLine.Value = 'progress:{0}' -f $progressPercent
            $Emitted.Value = $true
            continue
        }

        if ($normalizedLine -match '^\d{1,3}%$' -or $normalizedLine -notmatch '[A-Za-z0-9]') {
            continue
        }

        if ($normalizedLine -match '^(Category|Pricing|Free Trial|Terms of Transaction|Seizure Warning|Store License Terms|Publisher|Publisher Url|Publisher Support Url|License|Privacy Url|Copyright|Agreements|Installer|Installer Type|Store Product Id|Offline Distribution Supported)\s*:') {
            continue
        }

        if ($normalizedLine -match 'Microsoft Store' -and $normalizedLine -notmatch '(?i)install|upgrade|found|available') {
            continue
        }

        if ($normalizedLine -match 'https?://') {
            continue
        }

        if ($normalizedLine -eq [string]$LastLine.Value) {
            continue
        }

        Write-Log -Message ('winget> {0}' -f $normalizedLine)
        $LastLine.Value = $normalizedLine
        $Emitted.Value = $true
    }
}

function Invoke-WingetAction {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('install', 'upgrade')]
        [string]$Action,
        [Parameter(Mandatory)]
        [string]$PackageId,
        [string]$Source,
        [switch]$DryRun
    )

    if (-not (Test-WingetInstalled)) {
        throw 'winget is not available'
    }

    $args = @(
        $Action,
        '--id', $PackageId,
        '--exact',
        '--silent',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $args += @('--source', $Source)
    }

    if ($DryRun) {
        Write-Log -Message ('[DryRun] winget {0} {1}' -f $Action, $PackageId)
        return
    }

    Write-Log -Message ('Running winget {0}: {1}' -f $Action, $PackageId)
    if ($Source -eq 'msstore') {
        Write-Log -Message ('winget {0} for Store package {1} may pause without progress output while Microsoft Store resolves the request' -f $Action, $PackageId)
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('winget-' + [guid]::NewGuid().ToString('N'))
    Initialize-Directory -Path $tempRoot
    $stdoutPath = Join-Path $tempRoot 'stdout.log'
    $stderrPath = Join-Path $tempRoot 'stderr.log'
    $stdoutOffset = 0
    $stderrOffset = 0
    $stdoutPending = ''
    $stderrPending = ''
    $lastHeartbeat = Get-Date
    $lastWingetLine = $null
    $lastWingetProgressPercent = -1

    try {
        $process = Start-Process -FilePath 'winget.exe' -ArgumentList $args -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

        do {
            $sawOutput = $false
            foreach ($entry in @(
                    @{ Path = $stdoutPath; Offset = ([ref]$stdoutOffset); Pending = ([ref]$stdoutPending) },
                    @{ Path = $stderrPath; Offset = ([ref]$stderrOffset); Pending = ([ref]$stderrPending) }
                )) {
                $lines = @(Get-AppendedTextLines -Path $entry.Path -Offset $entry.Offset -PendingLine $entry.Pending)
                Write-WingetOutputLines -Lines $lines -LastLine ([ref]$lastWingetLine) -LastProgressPercent ([ref]$lastWingetProgressPercent) -Emitted ([ref]$sawOutput)
            }

            if ($sawOutput) {
                $lastHeartbeat = Get-Date
            }
            elseif (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 15) {
                Write-Log -Message ('winget {0} for {1} is still running...' -f $Action, $PackageId)
                $lastHeartbeat = Get-Date
            }

            if (-not $process.HasExited) {
                Start-Sleep -Milliseconds 500
                $process.Refresh()
            }
        } while (-not $process.HasExited)

        foreach ($entry in @(
                @{ Path = $stdoutPath; Offset = ([ref]$stdoutOffset); Pending = ([ref]$stdoutPending) },
                @{ Path = $stderrPath; Offset = ([ref]$stderrOffset); Pending = ([ref]$stderrPending) }
            )) {
            $lines = @(Get-AppendedTextLines -Path $entry.Path -Offset $entry.Offset -PendingLine $entry.Pending -Flush)
            $emittedFinal = $false
            Write-WingetOutputLines -Lines $lines -LastLine ([ref]$lastWingetLine) -LastProgressPercent ([ref]$lastWingetProgressPercent) -Emitted ([ref]$emittedFinal)
        }

        $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
        $stderrText = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
        $combinedOutput = @($stdoutText, $stderrText) -join "`n"
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($exitCode -ne 0) {
        if (Test-WingetNoApplicableUpgradeOutput -OutputText $combinedOutput) {
            Write-Log -Message ('winget {0} reported no applicable update for {1}; treating as current' -f $Action, $PackageId)
            return
        }

        if ($Action -eq 'upgrade') {
            Write-Log -Level 'WARN' -Message ('winget upgrade {0} returned {1}; continuing' -f $PackageId, $exitCode)
            return
        }
        $exitText = if ($null -eq $exitCode) { 'unknown' } else { [string]$exitCode }
        throw ('winget {0} {1} failed, exit={2}' -f $Action, $PackageId, $exitText)
    }

    Reset-InstallDetectionState
    Write-Log -Message ('winget {0} completed: {1}' -f $Action, $PackageId)
}

function Test-WingetPackageInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,
        [string]$Source
    )

    if (-not (Test-WingetInstalled)) {
        return $false
    }

    $args = @('list', '--id', $PackageId, '--exact', '--accept-source-agreements', '--disable-interactivity')
    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $args += @('--source', $Source)
    }

    $output = & winget @args 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return $output -match [regex]::Escape($PackageId)
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$Object,
        [Parameter(Mandatory)]
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function Update-CurrentProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $currentPath = $env:Path

    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($pathValue in @($machinePath, $userPath, $currentPath)) {
        foreach ($segment in @($pathValue -split ';')) {
            $trimmed = [string]$segment
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }

            if ($segments -notcontains $trimmed) {
                $segments.Add($trimmed)
            }
        }
    }

    $env:Path = ($segments -join ';')
}

function Reset-InstallDetectionState {
    if (Get-Variable -Name UninstallRegistryEntries -Scope Script -ErrorAction SilentlyContinue) {
        Remove-Variable -Name UninstallRegistryEntries -Scope Script -Force
    }

    Update-CurrentProcessPath
}

function Get-NormalizedVersionString {
    param(
        [string]$VersionText
    )

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return $null
    }

    $match = [regex]::Match($VersionText.Trim(), '(?i)v?(?<version>\d+(?:\.\d+)+)')
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups['version'].Value
}

function Compare-VersionStrings {
    param(
        [string]$LeftVersion,
        [string]$RightVersion
    )

    $left = Get-NormalizedVersionString -VersionText $LeftVersion
    $right = Get-NormalizedVersionString -VersionText $RightVersion
    if ([string]::IsNullOrWhiteSpace($left) -or [string]::IsNullOrWhiteSpace($right)) {
        return $null
    }

    $leftParts = $left.Split('.') | ForEach-Object { [int]$_ }
    $rightParts = $right.Split('.') | ForEach-Object { [int]$_ }
    $length = [Math]::Max($leftParts.Count, $rightParts.Count)

    for ($index = 0; $index -lt $length; $index++) {
        $leftValue = if ($index -lt $leftParts.Count) { $leftParts[$index] } else { 0 }
        $rightValue = if ($index -lt $rightParts.Count) { $rightParts[$index] } else { 0 }

        if ($leftValue -lt $rightValue) {
            return -1
        }

        if ($leftValue -gt $rightValue) {
            return 1
        }
    }

    return 0
}

function Get-UninstallRegistryEntries {
    param(
        [switch]$Refresh
    )

    if ($Refresh -and (Get-Variable -Name UninstallRegistryEntries -Scope Script -ErrorAction SilentlyContinue)) {
        Remove-Variable -Name UninstallRegistryEntries -Scope Script -Force
    }

    if (Get-Variable -Name UninstallRegistryEntries -Scope Script -ErrorAction SilentlyContinue) {
        return $script:UninstallRegistryEntries
    }

    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $entries = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    }

    $script:UninstallRegistryEntries = @(
        $entries |
        Where-Object {
            $displayNameProperty = $_.PSObject.Properties['DisplayName']
            $null -ne $displayNameProperty -and -not [string]::IsNullOrWhiteSpace([string]$displayNameProperty.Value)
        }
    )
    return $script:UninstallRegistryEntries
}

function Select-BestVersionRecord {
    param(
        [Parameter(Mandatory)]
        [object[]]$Records,
        [Parameter(Mandatory)]
        [scriptblock]$VersionSelector
    )

    $selected = $null
    foreach ($record in $Records) {
        if ($null -eq $selected) {
            $selected = $record
            continue
        }

        $candidateVersion = & $VersionSelector $record
        $selectedVersion = & $VersionSelector $selected
        $comparison = Compare-VersionStrings -LeftVersion $candidateVersion -RightVersion $selectedVersion
        if ($comparison -gt 0) {
            $selected = $record
        }
    }

    return $selected
}

function Get-InstalledRegistryVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$DetectConfig
    )

    $displayName = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'registryDisplayName')
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        return $null
    }

    $matchMode = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'registryMatch' -Default 'contains')
    $entries = Get-UninstallRegistryEntries
    $matched = switch ($matchMode) {
        'exact' { @($entries | Where-Object { [string](Get-ObjectPropertyValue -Object $_ -Name 'DisplayName') -eq $displayName }) }
        'regex' { @($entries | Where-Object { [string](Get-ObjectPropertyValue -Object $_ -Name 'DisplayName') -match $displayName }) }
        default { @($entries | Where-Object { [string](Get-ObjectPropertyValue -Object $_ -Name 'DisplayName') -like ('*{0}*' -f $displayName) }) }
    }
    $matched = @($matched)

    if ($matched.Count -eq 0) {
        return [pscustomobject]@{
            Found = $false
            Version = $null
            Source = 'registry'
            Detail = $displayName
        }
    }

    $selected = Select-BestVersionRecord -Records $matched -VersionSelector { param($entry) $entry.DisplayVersion }
    return [pscustomobject]@{
        Found = $true
        Version = $selected.DisplayVersion
        Source = 'registry'
        Detail = $selected.DisplayName
    }
}

function Get-InstalledAppxVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$DetectConfig
    )

    $appxName = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'appxName')
    if ([string]::IsNullOrWhiteSpace($appxName)) {
        return $null
    }

    $packages = @(Get-AppxPackage -Name $appxName -ErrorAction SilentlyContinue)
    if ($packages.Count -eq 0) {
        return [pscustomobject]@{
            Found = $false
            Version = $null
            Source = 'appx'
            Detail = $appxName
        }
    }

    $selected = $packages | Sort-Object Version -Descending | Select-Object -First 1
    return [pscustomobject]@{
        Found = $true
        Version = $selected.Version.ToString()
        Source = 'appx'
        Detail = $selected.Name
    }
}

function Get-InstalledCommandVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$DetectConfig
    )

    $primaryCommandName = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'command')
    if ([string]::IsNullOrWhiteSpace($primaryCommandName)) {
        return $null
    }

    $commandSpecs = New-Object System.Collections.Generic.List[object]
    $commandSpecs.Add([pscustomobject]@{
            command = $primaryCommandName
            args = @((Get-ObjectPropertyValue -Object $DetectConfig -Name 'args' -Default @()))
            regex = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'regex')
        })

    foreach ($fallbackSpec in @((Get-ObjectPropertyValue -Object $DetectConfig -Name 'fallbackCommands' -Default @()))) {
        $commandSpecs.Add($fallbackSpec)
    }

    $lastFailure = $null
    foreach ($commandSpec in $commandSpecs) {
        $commandName = [string](Get-ObjectPropertyValue -Object $commandSpec -Name 'command')
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
            $lastFailure = [pscustomobject]@{
                Found = $false
                Version = $null
                Source = 'command'
                Detail = $commandName
            }
            continue
        }

        $arguments = @((Get-ObjectPropertyValue -Object $commandSpec -Name 'args' -Default @()))
        $pattern = [string](Get-ObjectPropertyValue -Object $commandSpec -Name 'regex')
        try {
            $outputLines = @(& $commandName @arguments 2>&1)
        }
        catch {
            $lastFailure = [pscustomobject]@{
                Found = $false
                Version = $null
                Source = 'command'
                Detail = '{0} invocation failed: {1}' -f $commandName, $_.Exception.Message
            }
            continue
        }

        $outputText = ($outputLines | Out-String)
        $version = $null
        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            $match = [regex]::Match($outputText, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
            if ($match.Success -and $match.Groups['version'].Success) {
                $version = $match.Groups['version'].Value
            }
        }

        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = Get-NormalizedVersionString -VersionText $outputText
        }

        return [pscustomobject]@{
            Found = $true
            Version = $version
            Source = 'command'
            Detail = $commandName
        }
    }

    if ($null -ne $lastFailure) {
        return $lastFailure
    }

    return [pscustomobject]@{
        Found = $false
        Version = $null
        Source = 'command'
        Detail = $primaryCommandName
    }
}

function Get-InstalledAppVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    $detectConfig = Get-ObjectPropertyValue -Object $Definition -Name 'detect'
    if ($null -eq $detectConfig) {
        return [pscustomobject]@{
            Found = $false
            Version = $null
            Source = 'none'
            Detail = 'No detection rule'
        }
    }

    $lastResult = $null
    foreach ($resolver in @(
            { param($config) Get-InstalledCommandVersion -DetectConfig $config },
            { param($config) Get-InstalledAppxVersion -DetectConfig $config },
            { param($config) Get-InstalledRegistryVersion -DetectConfig $config }
        )) {
        $result = & $resolver $detectConfig
        if ($null -eq $result) {
            continue
        }

        $lastResult = $result
        if ($result.Found) {
            return $result
        }
    }

    if ($null -ne $lastResult) {
        return $lastResult
    }

    return [pscustomobject]@{
        Found = $false
        Version = $null
        Source = 'none'
        Detail = 'No detection rule'
    }
}

function Get-WingetPackageLatestVersion {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,
        [string]$Source
    )

    if (-not (Test-WingetInstalled)) {
        return $null
    }

    $cacheKey = if ([string]::IsNullOrWhiteSpace($Source)) { $PackageId } else { '{0}@{1}' -f $PackageId, $Source }
    if (-not (Get-Variable -Name WingetShowCache -Scope Script -ErrorAction SilentlyContinue)) {
        $script:WingetShowCache = @{}
    }

    if ($script:WingetShowCache.ContainsKey($cacheKey)) {
        return $script:WingetShowCache[$cacheKey]
    }

    $args = @('show', '--id', $PackageId, '--exact', '--accept-source-agreements')
    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $args += @('--source', $Source)
    }

    $output = (& winget @args 2>$null | Out-String)
    if ($LASTEXITCODE -ne 0) {
        $script:WingetShowCache[$cacheKey] = $null
        return $null
    }

    $version = $null
    $topLevelMatch = [regex]::Match($output, '(?m)^(?:Version|版本):\s*(?<version>.+?)\s*$')
    if ($topLevelMatch.Success) {
        $candidate = $topLevelMatch.Groups['version'].Value.Trim()
        if ($candidate -notin @('Unknown', '未知')) {
            $version = $candidate
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $descriptionMatch = [regex]::Match($output, '(?m)^\s+(?:Version|版本):\s*v?(?<version>\d+(?:\.\d+)+)\s*$')
        if ($descriptionMatch.Success) {
            $version = $descriptionMatch.Groups['version'].Value
        }
    }

    $script:WingetShowCache[$cacheKey] = $version
    return $version
}

function Get-FallbackReleaseAssetVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    $fallback = Get-ObjectPropertyValue -Object $Definition -Name 'fallback'
    if ($null -eq $fallback) {
        return $null
    }

    $releaseAsset = [string](Get-ObjectPropertyValue -Object $fallback -Name 'releaseAsset')
    if ([string]::IsNullOrWhiteSpace($releaseAsset)) {
        return $null
    }

    return Get-NormalizedVersionString -VersionText $releaseAsset
}

function Get-DesiredAppVersion {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    $explicitTarget = Get-ObjectPropertyValue -Object $Definition -Name 'targetVersion'
    if (-not [string]::IsNullOrWhiteSpace([string]$explicitTarget)) {
        return [pscustomobject]@{
            Found = $true
            Version = [string]$explicitTarget
            Source = 'manifest'
        }
    }

    switch ($Definition.strategy) {
        'winget' {
            $wingetSource = [string](Get-ObjectPropertyValue -Object $Definition -Name 'wingetSource')
            $version = Get-WingetPackageLatestVersion -PackageId $Definition.wingetId -Source $wingetSource
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return [pscustomobject]@{
                    Found = $true
                    Version = $version
                    Source = 'winget-show'
                }
            }

            $fallbackVersion = Get-FallbackReleaseAssetVersion -Definition $Definition
            if (-not [string]::IsNullOrWhiteSpace($fallbackVersion)) {
                return [pscustomobject]@{
                    Found = $true
                    Version = $fallbackVersion
                    Source = 'fallback-release-asset'
                }
            }
        }
        'github-latest-tag' {
            $tag = Get-GitHubLatestTagViaRedirect -Repo $Definition.repo
            if (-not [string]::IsNullOrWhiteSpace($tag)) {
                return [pscustomobject]@{
                    Found = $true
                    Version = $tag.TrimStart('v')
                    Source = 'github-latest-tag'
                }
            }
        }
        'release-asset' {
            $assetName = [string](Get-ObjectPropertyValue -Object $Definition -Name 'assetName')
            $version = Get-NormalizedVersionString -VersionText $assetName
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return [pscustomobject]@{
                    Found = $true
                    Version = $version
                    Source = 'release-asset-name'
                }
            }
        }
    }

    return [pscustomobject]@{
        Found = $false
        Version = $null
        Source = 'unknown'
    }
}

function Get-AppInstallDecision {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    $installed = Get-InstalledAppVersion -Definition $Definition
    $desired = Get-DesiredAppVersion -Definition $Definition
    $installIfMissingOnly = [bool](Get-ObjectPropertyValue -Object $Definition -Name 'installIfMissingOnly' -Default $false)

    if (-not $installed.Found) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'missing'
            InstalledVersion = $null
            DesiredVersion = $desired.Version
            Detail = 'Not installed'
        }
    }

    if ($installIfMissingOnly) {
        return [pscustomobject]@{
            Action = 'skip'
            Reason = 'present'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = 'Installed app detected and installIfMissingOnly is enabled'
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$installed.Version)) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'unknown-installed-version'
            InstalledVersion = $null
            DesiredVersion = $desired.Version
            Detail = 'Installed version could not be determined'
        }
    }

    if (-not $desired.Found -or [string]::IsNullOrWhiteSpace([string]$desired.Version)) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'unknown-target-version'
            InstalledVersion = $installed.Version
            DesiredVersion = $null
            Detail = 'Installed version detected, but target version is not comparable'
        }
    }

    $comparison = Compare-VersionStrings -LeftVersion $installed.Version -RightVersion $desired.Version
    if ($null -eq $comparison) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'non-comparable'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = 'Installed and target versions are not comparable'
        }
    }

    if ($comparison -ge 0) {
        return [pscustomobject]@{
            Action = 'skip'
            Reason = 'current'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = 'Installed version is current'
        }
    }

    return [pscustomobject]@{
        Action = 'install'
        Reason = 'outdated'
        InstalledVersion = $installed.Version
        DesiredVersion = $desired.Version
        Detail = 'Installed version is older than target'
    }
}

function Test-InstallRecoveredAfterPrimaryFailure {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition,
        [Parameter(Mandatory)]
        [pscustomobject]$InitialDecision,
        [int]$Attempts = 6,
        [int]$DelayMilliseconds = 1500
    )

    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        Reset-InstallDetectionState
        $installed = Get-InstalledAppVersion -Definition $Definition
        if ($installed.Found) {
            if ($InitialDecision.Reason -eq 'missing') {
                return [pscustomobject]@{
                    Recovered = $true
                    InstalledVersion = $installed.Version
                    Detail = 'App became detectable after primary installer returned an error'
                }
            }

            $postDecision = Get-AppInstallDecision -Definition $Definition
            if ($postDecision.Action -eq 'skip') {
                return [pscustomobject]@{
                    Recovered = $true
                    InstalledVersion = $postDecision.InstalledVersion
                    Detail = $postDecision.Detail
                }
            }
        }

        if ($attempt -lt ($Attempts - 1)) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    return [pscustomobject]@{
        Recovered = $false
        InstalledVersion = $null
        Detail = 'App was still not verifiably installed after recheck'
    }
}

function Resolve-PrimaryInstallFailure {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition,
        [Parameter(Mandatory)]
        [pscustomobject]$InitialDecision,
        [Parameter(Mandatory)]
        [string]$PrimarySource,
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [switch]$DryRun
    )

    Write-Log -Level 'WARN' -Message ('{0} path raised an error for {1}: {2}' -f $PrimarySource, $Definition.name, $ErrorRecord.Exception.Message)
    if (-not $DryRun) {
        $recovered = Test-InstallRecoveredAfterPrimaryFailure -Definition $Definition -InitialDecision $InitialDecision
        if ($recovered.Recovered) {
            Write-Log -Level 'WARN' -Message ('{0} appears installed after post-failure recheck; skipping fallback for {1}' -f $Definition.name, $PrimarySource)
            return [pscustomobject]@{
                Name = $Definition.name
                Key = $Definition.key
                Status = 'ok'
                Source = '{0}-postcheck' -f $PrimarySource
                Detail = if ([string]::IsNullOrWhiteSpace([string]$recovered.InstalledVersion)) { $recovered.Detail } else { '{0} ({1})' -f $recovered.Detail, $recovered.InstalledVersion }
            }
        }
    }

    Write-Log -Level 'WARN' -Message ('{0} path failed, falling back to release or local package: {1}' -f $PrimarySource, $Definition.name)
    return $null
}

function Install-DownloadedPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath,
        [Parameter(Mandatory)]
        [string]$InstallerType,
        [string[]]$SilentArgs = @(),
        [switch]$DryRun
    )

    if ($InstallerType -ne 'uri' -and -not (Test-Path -LiteralPath $PackagePath) -and -not $DryRun) {
        throw "Package not found: $PackagePath"
    }

    switch ($InstallerType) {
        'msi' {
            $args = @('/i', $PackagePath, '/qn', '/norestart') + $SilentArgs
            $argumentLine = (($args | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' ')
            if ($DryRun) {
                Write-Log -Message ('[DryRun] msiexec.exe {0}' -f $argumentLine)
                return
            }

            Write-Log -Message ('Installing MSI: {0}' -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentLine -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw ('MSI install failed, exit={0}' -f $proc.ExitCode)
            }

            Reset-InstallDetectionState
        }
        'exe' {
            $argumentLine = (($SilentArgs | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' ')
            if ($DryRun) {
                Write-Log -Message ('[DryRun] {0} {1}' -f $PackagePath, $argumentLine)
                return
            }

            Write-Log -Message ('Installing EXE: {0}' -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath $PackagePath -ArgumentList $argumentLine -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw ('EXE install failed, exit={0}' -f $proc.ExitCode)
            }

            Reset-InstallDetectionState
        }
        'msix' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] Add-AppxPackage {0}' -f $PackagePath)
                return
            }

            Write-Log -Message ('Installing MSIX: {0}' -f (Split-Path -Leaf $PackagePath))
            Add-AppxPackage -Path $PackagePath
            Reset-InstallDetectionState
        }
        'uri' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] Start-Process {0}' -f $PackagePath)
                return
            }

            Write-Log -Message ('Opening installer URI: {0}' -f $PackagePath)
            Start-Process -FilePath $PackagePath | Out-Null
        }
        default {
            throw ('Unsupported installerType: {0}' -f $InstallerType)
        }
    }
}

function Install-AppFromDefinition {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition,
        [Parameter(Mandatory)]
        [string]$WorkspaceRoot,
        [switch]$DryRun
    )

    $downloadsRoot = Join-Path $WorkspaceRoot 'downloads'
    Initialize-Directory -Path $downloadsRoot
    $decision = Get-AppInstallDecision -Definition $Definition

    switch ($decision.Reason) {
        'missing' {
            Write-Log -Message ('Precheck {0}: not installed, will install' -f $Definition.name)
        }
        'outdated' {
            Write-Log -Message ('Precheck {0}: installed {1}, target {2}, will update' -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
        'current' {
            Write-Log -Message ('Precheck {0}: installed {1}, target {2}, skip' -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
        'present' {
            if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) {
                Write-Log -Message ('Precheck {0}: detected as installed, installIfMissingOnly enabled, skip' -f $Definition.name)
            }
            else {
                Write-Log -Message ('Precheck {0}: installed {1}, installIfMissingOnly enabled, skip' -f $Definition.name, $decision.InstalledVersion)
            }
        }
        'unknown-target-version' {
            Write-Log -Message ('Precheck {0}: installed {1}, target version unavailable, will let source reconcile' -f $Definition.name, $decision.InstalledVersion)
        }
        'unknown-installed-version' {
            Write-Log -Message ('Precheck {0}: app exists but installed version is unknown, will reinstall or update' -f $Definition.name)
        }
        'non-comparable' {
            Write-Log -Message ('Precheck {0}: installed {1}, target {2}, versions not comparable, will reinstall or update' -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
    }

    if ($decision.Action -eq 'skip') {
        $skipDetail = if ($decision.Reason -eq 'present') {
            if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) {
                'Detected as installed; installIfMissingOnly enabled'
            }
            else {
                'Detected as installed ({0}); installIfMissingOnly enabled' -f $decision.InstalledVersion
            }
        }
        else {
            '{0} >= {1}' -f $decision.InstalledVersion, $decision.DesiredVersion
        }

        return [pscustomobject]@{
            Name = $Definition.name
            Key = $Definition.key
            Status = 'ok'
            Source = 'precheck-skip'
            Detail = $skipDetail
        }
    }

    switch ($Definition.strategy) {
        'winget' {
            try {
                $wingetSource = [string](Get-ObjectPropertyValue -Object $Definition -Name 'wingetSource')
                Invoke-WingetAction -Action 'install' -PackageId $Definition.wingetId -Source $wingetSource -DryRun:$DryRun
                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'winget'
                    Detail = if (-not [string]::IsNullOrWhiteSpace($wingetSource)) { '{0} ({1})' -f $Definition.wingetId, $wingetSource } else { $Definition.wingetId }
                }
            }
            catch {
                $recoveredResult = Resolve-PrimaryInstallFailure -Definition $Definition -InitialDecision $decision -PrimarySource 'winget' -ErrorRecord $_ -DryRun:$DryRun
                if ($null -ne $recoveredResult) {
                    return $recoveredResult
                }
            }
        }
        'github-release' {
            try {
                $asset = Get-GitHubLatestReleaseAsset -Repo $Definition.repo -AssetPattern $Definition.assetPattern
                $destination = Join-Path $downloadsRoot $asset.Name
                Invoke-DownloadFile -Url $asset.Url -DestinationPath $destination -DryRun:$DryRun | Out-Null
                Install-DownloadedPackage `
                    -PackagePath $destination `
                    -InstallerType $Definition.fallback.installerType `
                    -SilentArgs $Definition.fallback.silentArgs `
                    -DryRun:$DryRun

                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'github-release'
                    Detail = '{0} ({1})' -f $asset.Repo, $asset.Version
                }
            }
            catch {
                $recoveredResult = Resolve-PrimaryInstallFailure -Definition $Definition -InitialDecision $decision -PrimarySource 'github-release' -ErrorRecord $_ -DryRun:$DryRun
                if ($null -ne $recoveredResult) {
                    return $recoveredResult
                }
            }
        }
        'release-asset' {
            try {
                $assetName = $Definition.assetName
                $url = Get-GitHubReleaseAssetDownloadUrl -Repo $Definition.repo -Tag $Definition.tag -AssetName $assetName
                $destination = Join-Path $downloadsRoot $assetName
                Invoke-DownloadFile -Url $url -DestinationPath $destination -DryRun:$DryRun | Out-Null
                Install-DownloadedPackage `
                    -PackagePath $destination `
                    -InstallerType $Definition.installerType `
                    -SilentArgs $Definition.silentArgs `
                    -DryRun:$DryRun

                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'release-asset'
                    Detail = '{0}@{1}/{2}' -f $Definition.repo, $Definition.tag, $assetName
                }
            }
            catch {
                $recoveredResult = Resolve-PrimaryInstallFailure -Definition $Definition -InitialDecision $decision -PrimarySource 'release-asset' -ErrorRecord $_ -DryRun:$DryRun
                if ($null -ne $recoveredResult) {
                    return $recoveredResult
                }
            }
        }
        'direct-url' {
            try {
                $fileName = Split-Path -Leaf ([uri]$Definition.url).AbsolutePath
                $destination = Join-Path $downloadsRoot $fileName
                Invoke-DownloadFile -Url $Definition.url -DestinationPath $destination -DryRun:$DryRun | Out-Null
                Install-DownloadedPackage `
                    -PackagePath $destination `
                    -InstallerType $Definition.fallback.installerType `
                    -SilentArgs $Definition.fallback.silentArgs `
                    -DryRun:$DryRun

                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'direct-url'
                    Detail = $Definition.url
                }
            }
            catch {
                $recoveredResult = Resolve-PrimaryInstallFailure -Definition $Definition -InitialDecision $decision -PrimarySource 'direct-url' -ErrorRecord $_ -DryRun:$DryRun
                if ($null -ne $recoveredResult) {
                    return $recoveredResult
                }
            }
        }
        'github-latest-tag' {
            try {
                Write-Log -Message ('Resolving latest GitHub tag via redirect: {0}' -f $Definition.repo)
                $tag = Get-GitHubLatestTagViaRedirect -Repo $Definition.repo
                $version = $tag.TrimStart('v')
                $assetName = $Definition.assetTemplate.Replace('{tag}', $tag).Replace('{version}', $version)
                $url = 'https://github.com/{0}/releases/download/{1}/{2}' -f $Definition.repo, $tag, $assetName
                $destination = Join-Path $downloadsRoot $assetName

                Invoke-DownloadFile -Url $url -DestinationPath $destination -DryRun:$DryRun | Out-Null
                Install-DownloadedPackage `
                    -PackagePath $destination `
                    -InstallerType $Definition.fallback.installerType `
                    -SilentArgs $Definition.fallback.silentArgs `
                    -DryRun:$DryRun

                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'github-latest-tag'
                    Detail = '{0} ({1})' -f $Definition.repo, $tag
                }
            }
            catch {
                $recoveredResult = Resolve-PrimaryInstallFailure -Definition $Definition -InitialDecision $decision -PrimarySource 'github-latest-tag' -ErrorRecord $_ -DryRun:$DryRun
                if ($null -ne $recoveredResult) {
                    return $recoveredResult
                }
            }
        }
        default {
            throw ('Unsupported strategy: {0}' -f $Definition.strategy)
        }
    }

    if (-not $Definition.fallback) {
        throw ('{0} has no usable fallback' -f $Definition.name)
    }

    $fallbackWingetId = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'wingetId')
    if (-not [string]::IsNullOrWhiteSpace($fallbackWingetId)) {
        try {
            $fallbackWingetSource = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'wingetSource')
            Invoke-WingetAction -Action 'install' -PackageId $fallbackWingetId -Source $fallbackWingetSource -DryRun:$DryRun

            return [pscustomobject]@{
                Name = $Definition.name
                Key = $Definition.key
                Status = 'ok'
                Source = 'winget-fallback'
                Detail = if (-not [string]::IsNullOrWhiteSpace($fallbackWingetSource)) { '{0} ({1})' -f $fallbackWingetId, $fallbackWingetSource } else { $fallbackWingetId }
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('winget fallback failed: {0}' -f $_.Exception.Message)
        }
    }

    $fallbackReleaseAsset = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'releaseAsset')
    if (-not [string]::IsNullOrWhiteSpace($fallbackReleaseAsset)) {
        try {
            $releaseRepo = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'releaseRepo')
            $releaseTag = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'releaseTag')
            $assetName = $fallbackReleaseAsset
            $url = Get-GitHubReleaseAssetDownloadUrl -Repo $releaseRepo -Tag $releaseTag -AssetName $assetName
            $destination = Join-Path $downloadsRoot $assetName

            Invoke-DownloadFile -Url $url -DestinationPath $destination -DryRun:$DryRun | Out-Null
            Install-DownloadedPackage `
                -PackagePath $destination `
                -InstallerType ([string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'installerType')) `
                -SilentArgs @((Get-ObjectPropertyValue -Object $Definition.fallback -Name 'silentArgs' -Default @())) `
                -DryRun:$DryRun

            return [pscustomobject]@{
                Name = $Definition.name
                Key = $Definition.key
                Status = 'ok'
                Source = 'release-fallback'
                Detail = '{0}@{1}/{2}' -f $releaseRepo, $releaseTag, $assetName
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Release fallback failed: {0}' -f $_.Exception.Message)
        }
    }

    $fallbackUris = @((Get-ObjectPropertyValue -Object $Definition.fallback -Name 'uriCandidates' -Default @()))
    if ($fallbackUris.Count -gt 0) {
        foreach ($fallbackUri in $fallbackUris) {
            try {
                Install-DownloadedPackage `
                    -PackagePath ([string]$fallbackUri) `
                    -InstallerType 'uri' `
                    -DryRun:$DryRun

                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'uri-fallback'
                    Detail = [string]$fallbackUri
                }
            }
            catch {
                Write-Log -Level 'WARN' -Message ('URI fallback failed: {0}' -f $_.Exception.Message)
            }
        }
    }

    throw ('{0} has no usable fallback package after online sources failed' -f $Definition.name)
}

function ConvertFrom-SecureStringPlainText {
    param(
        [Parameter(Mandatory)]
        [Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-HostWithDefaultValue {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [string]$DefaultValue
    )

    $suffix = ''
    if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
        $suffix = ' [{0}]' -f $DefaultValue
    }

    $value = Read-Host ('{0}{1}' -f $Prompt, $suffix)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value.Trim()
}

function Get-CcSwitchDatabasePath {
    $homeDir = Get-UserHomeDirectory
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        return $null
    }

    return Join-Path $homeDir '.cc-switch\cc-switch.db'
}

function Initialize-WinSqliteInterop {
    if ('WinSqliteInterop' -as [type]) {
        return
    }

    $sqliteInteropCode = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinSqliteInterop
{
    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_open_v2(byte[] filename, out IntPtr db, int flags, IntPtr zvfs);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_close(IntPtr db);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_errmsg(IntPtr db);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int numBytes, out IntPtr stmt, IntPtr pzTail);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_step(IntPtr stmt);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int sqlite3_finalize(IntPtr stmt);

    [DllImport("winsqlite3", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr sqlite3_column_text(IntPtr stmt, int iCol);

    public static string PtrToStringUtf8(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero)
        {
            return null;
        }

        int length = 0;
        while (Marshal.ReadByte(ptr, length) != 0)
        {
            length++;
        }

        var bytes = new byte[length];
        Marshal.Copy(ptr, bytes, 0, length);
        return Encoding.UTF8.GetString(bytes);
    }
}
'@

    Add-Type -TypeDefinition $sqliteInteropCode
}

function Get-CcSwitchProviderByName {
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,
        [string]$AppType = 'codex'
    )

    $dbPath = Get-CcSwitchDatabasePath
    if ([string]::IsNullOrWhiteSpace($dbPath) -or -not (Test-Path -LiteralPath $dbPath)) {
        return $null
    }

    Initialize-WinSqliteInterop

    $sqliteOpenReadOnly = 0x00000001
    $sqliteRow = 100
    $db = [IntPtr]::Zero
    $stmt = [IntPtr]::Zero

    try {
        $openPathBytes = [System.Text.Encoding]::UTF8.GetBytes($dbPath + [char]0)
        $openResult = [WinSqliteInterop]::sqlite3_open_v2($openPathBytes, [ref]$db, $sqliteOpenReadOnly, [IntPtr]::Zero)
        if ($openResult -ne 0) {
            $openError = [WinSqliteInterop]::PtrToStringUtf8([WinSqliteInterop]::sqlite3_errmsg($db))
            throw ('Failed to open CC Switch database: {0}' -f $openError)
        }

        $escapedProviderName = $ProviderName.Replace("'", "''")
        $escapedAppType = $AppType.Replace("'", "''")
        $sql = @"
select id, name
from providers
where app_type = '$escapedAppType'
  and name = '$escapedProviderName'
limit 1;
"@

        $sqlBytes = [System.Text.Encoding]::UTF8.GetBytes($sql + [char]0)
        $prepareResult = [WinSqliteInterop]::sqlite3_prepare_v2($db, $sqlBytes, -1, [ref]$stmt, [IntPtr]::Zero)
        if ($prepareResult -ne 0) {
            $prepareError = [WinSqliteInterop]::PtrToStringUtf8([WinSqliteInterop]::sqlite3_errmsg($db))
            throw ('Failed to query CC Switch database: {0}' -f $prepareError)
        }

        $stepResult = [WinSqliteInterop]::sqlite3_step($stmt)
        if ($stepResult -ne $sqliteRow) {
            return $null
        }

        return [pscustomobject]@{
            Id = [WinSqliteInterop]::PtrToStringUtf8([WinSqliteInterop]::sqlite3_column_text($stmt, 0))
            Name = [WinSqliteInterop]::PtrToStringUtf8([WinSqliteInterop]::sqlite3_column_text($stmt, 1))
        }
    }
    finally {
        if ($stmt -ne [IntPtr]::Zero) {
            [void][WinSqliteInterop]::sqlite3_finalize($stmt)
        }

        if ($db -ne [IntPtr]::Zero) {
            [void][WinSqliteInterop]::sqlite3_close($db)
        }
    }
}

function Read-CodexProviderInput {
    param(
        [string]$PresetName,
        [string]$PresetBaseUrl,
        [string]$PresetModel,
        [string]$PresetApiKey
    )

    $name = $PresetName
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $env:VIBE_CODING_PROVIDER_NAME
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = 'IndieArk API 2'
    }

    $baseUrl = $PresetBaseUrl
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        $baseUrl = $env:VIBE_CODING_BASE_URL
    }
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        $baseUrl = 'https://api2.indieark.tech/v1'
    }

    $model = $PresetModel
    if ([string]::IsNullOrWhiteSpace($model)) {
        $model = $env:VIBE_CODING_MODEL
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        $model = 'gpt-5.5'
    }

    $name = Read-HostWithDefaultValue -Prompt 'CC Switch provider name' -DefaultValue $name
    $baseUrl = Read-HostWithDefaultValue -Prompt 'API base URL' -DefaultValue $baseUrl
    $model = Read-HostWithDefaultValue -Prompt 'Model name' -DefaultValue $model

    $apiKey = $PresetApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $secureApiKey = Read-Host 'SK (leave blank to use default sk-, input hidden)' -AsSecureString
        $apiKey = ConvertFrom-SecureStringPlainText -SecureString $secureApiKey
    }

    return [pscustomobject]@{
        Name = $name.Trim()
        BaseUrl = $baseUrl.Trim()
        Model = $model.Trim()
        ApiKey = if ([string]::IsNullOrWhiteSpace($apiKey)) { 'sk-' } else { $apiKey.Trim() }
    }
}

function New-CcSwitchCodexDeepLink {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProviderInfo
    )

    $queryPairs = @(
        'resource=provider',
        'app=codex',
        ('name={0}' -f [uri]::EscapeDataString($ProviderInfo.Name)),
        ('endpoint={0}' -f [uri]::EscapeDataString($ProviderInfo.BaseUrl)),
        ('apiKey={0}' -f [uri]::EscapeDataString($ProviderInfo.ApiKey)),
        ('model={0}' -f [uri]::EscapeDataString($ProviderInfo.Model)),
        'enabled=true'
    )

    return 'ccswitch://v1/import?{0}' -f ($queryPairs -join '&')
}

function Test-CcSwitchProtocolRegistered {
    return (Test-Path 'Registry::HKEY_CLASSES_ROOT\ccswitch')
}

function Get-InstalledCcSwitchExecutable {
    $entry = Get-UninstallRegistryEntries -Refresh | Where-Object {
        [string](Get-ObjectPropertyValue -Object $_ -Name 'DisplayName') -eq 'CC Switch'
    } | Select-Object -First 1

    if (-not $entry) {
        return $null
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $installLocation = [string](Get-ObjectPropertyValue -Object $entry -Name 'InstallLocation')
    if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
        $candidates.Add((Join-Path $installLocation 'cc-switch.exe'))
        $candidates.Add((Join-Path $installLocation 'CC Switch.exe'))
    }

    $displayIcon = [string](Get-ObjectPropertyValue -Object $entry -Name 'DisplayIcon')
    if (-not [string]::IsNullOrWhiteSpace($displayIcon)) {
        $candidates.Add($displayIcon.Trim('"'))
    }

    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Wait-CcSwitchProtocolRegistration {
    param(
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-CcSwitchProtocolRegistered) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    return (Test-CcSwitchProtocolRegistered)
}

function Import-CcSwitchCodexProvider {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProviderInfo,
        [switch]$ForceWarmup,
        [switch]$DryRun
    )

    $link = New-CcSwitchCodexDeepLink -ProviderInfo $ProviderInfo

    if ($DryRun) {
        if ($ForceWarmup) {
            Write-Log -Message '[DryRun] Would warm up CC Switch once before provider import because it was installed or updated in this run'
        }

        Write-Log -Message ('[DryRun] Would import provider via ccswitch:// deep link: {0} -> {1}' -f $ProviderInfo.Name, $ProviderInfo.BaseUrl)
        return [pscustomobject]@{
            Name = 'CC Switch Provider Import'
            Key = 'cc-switch-provider'
            Status = 'ok'
            Source = 'ccswitch-deeplink'
            Detail = $ProviderInfo.Name
        }
    }

    $protocolRegistered = Test-CcSwitchProtocolRegistered
    $ccSwitchExe = $null
    if ($ForceWarmup -or -not $protocolRegistered) {
        $ccSwitchExe = Get-InstalledCcSwitchExecutable
        if ($ccSwitchExe) {
            $warmupReason = if ($ForceWarmup) { 'fresh install or update detected' } else { 'protocol not registered yet' }
            Write-Log -Message ('Launching CC Switch before provider import ({0}): {1}' -f $warmupReason, $ccSwitchExe)
            Start-Process -FilePath $ccSwitchExe | Out-Null
            Start-Sleep -Seconds 5

            if (-not (Wait-CcSwitchProtocolRegistration -TimeoutSeconds 25)) {
                throw 'ccswitch:// protocol is not registered after launching CC Switch. Retry once manually if Windows is still finalizing app registration.'
            }

            Start-Sleep -Seconds 3
        }
        else {
            throw 'ccswitch:// protocol is not registered and CC Switch executable was not found. Launch CC Switch once, then retry.'
        }
    }

    Write-Log -Message ('Importing CC Switch provider via official deep link: {0}' -f $ProviderInfo.Name)
    if (-not $ccSwitchExe) {
        $ccSwitchExe = Get-InstalledCcSwitchExecutable
    }

    if ($ccSwitchExe) {
        Start-Process -FilePath $ccSwitchExe -ArgumentList $link | Out-Null
    }
    else {
        Start-Process -FilePath $link | Out-Null
    }

    return [pscustomobject]@{
        Name = 'CC Switch Provider Import'
        Key = 'cc-switch-provider'
        Status = 'ok'
        Source = 'ccswitch-deeplink'
        Detail = $ProviderInfo.Name
    }
}

function Remove-DirectoryContentsSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Copy-SkillDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Log -Message ('[DryRun] Copy skill {0} -> {1}' -f $SourcePath, $DestinationPath)
        return
    }

    Initialize-Directory -Path (Split-Path -Parent $DestinationPath)
    Remove-DirectoryContentsSafe -Path $DestinationPath
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Recurse -Force
}

function Get-DirectoryFileSignature {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $files = @(Get-ChildItem -LiteralPath $resolvedPath -File -Recurse | Sort-Object FullName)
    $entries = foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($resolvedPath.Length).TrimStart('\')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        '{0}|{1}' -f $relativePath.Replace('\', '/'), $hash
    }

    return ($entries -join "`n")
}

function Test-SkillDirectoryInSync {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $false
    }

    $sourceSignature = Get-DirectoryFileSignature -Path $SourcePath
    $destinationSignature = Get-DirectoryFileSignature -Path $DestinationPath
    return $sourceSignature -eq $destinationSignature
}

function Get-SkillDirectoriesFromExtractedRoot {
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $skillFiles = Get-ChildItem -LiteralPath $RootPath -Filter 'SKILL.md' -File -Recurse
    if (-not $skillFiles) {
        throw "No SKILL.md files were found in: $RootPath"
    }

    return @($skillFiles | ForEach-Object { $_.Directory.FullName } | Sort-Object -Unique)
}

function Get-SkillDirectoriesFromZip {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = @(
            $archive.Entries |
            Where-Object { $_.FullName -match '(^|/|\\)SKILL\.md$' } |
            ForEach-Object { [IO.Path]::GetDirectoryName($_.FullName.Replace('/', '\')) } |
            Sort-Object -Unique
        )

        if (-not $entries -or $entries.Count -eq 0) {
            throw "No SKILL.md files were found in: $ZipPath"
        }

        return @($entries)
    }
    finally {
        $archive.Dispose()
    }
}

function Test-InteractiveConsole {
    return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)
}

function ConvertFrom-Utf8Base64String {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Split-SelectionTokens {
    param(
        [string[]]$Values
    )

    return @(
        $Values |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Replace([char]0xFF0C, ',') -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function ConvertFrom-ProfileScalar {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $trimmed = $Value.Trim()
    if (($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'"))) {
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }

    return $trimmed
}

function ConvertFrom-ProfileInlineList {
    param(
        [string]$Value
    )

    $trimmed = (ConvertFrom-ProfileScalar -Value $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -eq '[]') {
        return @()
    }

    if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
        $trimmed = $trimmed.Substring(1, $trimmed.Length - 2)
    }

    return @(
        $trimmed.Replace([char]0xFF0C, ',') -split ',' |
        ForEach-Object { ConvertFrom-ProfileScalar -Value $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Expand-BundleRegistryArchive {
    param(
        [Parameter(Mandatory)]
        [string]$ExtractedBundleRoot,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $archivePath = Join-Path $ExtractedBundleRoot 'registry.tar.gz'
    if (-not (Test-Path -LiteralPath $archivePath)) {
        return $null
    }

    Initialize-Directory -Path $DestinationPath
    $tar = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tar) {
        Write-Log -Level 'WARN' -Message 'tar is not available; skip profile registry extraction'
        return $null
    }

    & $tar.Source -xzf $archivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level 'WARN' -Message ('Failed to extract registry.tar.gz, exit={0}; skip profile menu' -f $LASTEXITCODE)
        return $null
    }

    return $DestinationPath
}

function Read-SkillProfilesFromRegistry {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot
    )

    $profilesPath = Join-Path $RegistryRoot 'profiles.yaml'
    if (-not (Test-Path -LiteralPath $profilesPath)) {
        return @()
    }

    $profiles = @()
    $current = $null
    $currentList = $null

    foreach ($rawLine in (Get-Content -Encoding UTF8 -LiteralPath $profilesPath)) {
        $line = $rawLine.TrimEnd()
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^-\s+name\s*:\s*(.+)$') {
            if ($null -ne $current) {
                $profiles += [pscustomobject]$current
            }

            $current = [ordered]@{
                Name = ConvertFrom-ProfileScalar -Value $Matches[1]
                Description = ''
                Tags = @()
                Mcp = @()
                Skills = @()
            }
            $currentList = $null
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if ($trimmed -match '^description\s*:\s*(.*)$') {
            $current.Description = ConvertFrom-ProfileScalar -Value $Matches[1]
            $currentList = $null
            continue
        }

        if ($trimmed -match '^tags\s*:\s*(.*)$') {
            $current.Tags = @(ConvertFrom-ProfileInlineList -Value $Matches[1])
            $currentList = $null
            continue
        }

        if ($trimmed -match '^(mcp|skills)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            $currentList = if ($key -eq 'mcp') { 'Mcp' } else { 'Skills' }
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $current[$currentList] = @(ConvertFrom-ProfileInlineList -Value $value)
                $currentList = $null
            }
            continue
        }

        if ($currentList -and $trimmed -match '^-\s+(.+)$') {
            $current[$currentList] = @($current[$currentList]) + (ConvertFrom-ProfileScalar -Value $Matches[1])
        }
    }

    if ($null -ne $current) {
        $profiles += [pscustomobject]$current
    }

    return @($profiles)
}

function Read-RegistryRequiresMap {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $requiresByName = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $requiresByName
    }

    $currentName = $null
    foreach ($rawLine in (Get-Content -Encoding UTF8 -LiteralPath $Path)) {
        $trimmed = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^-\s+name\s*:\s*(.+)$') {
            $currentName = ConvertFrom-ProfileScalar -Value $Matches[1]
            $requiresByName[$currentName.ToLowerInvariant()] = @()
            continue
        }

        if ($currentName -and $trimmed -match '^requires\s*:\s*(.*)$') {
            $requiresByName[$currentName.ToLowerInvariant()] = @(ConvertFrom-ProfileInlineList -Value $Matches[1])
        }
    }

    return $requiresByName
}

function Get-ProfilePrereqNames {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [string[]]$SkillNames,
        [string[]]$McpNames
    )

    $skillsRequires = Read-RegistryRequiresMap -Path (Join-Path $RegistryRoot 'skills.yaml')
    $mcpRequires = Read-RegistryRequiresMap -Path (Join-Path $RegistryRoot 'mcp.yaml')
    $prereqs = @()

    foreach ($skillName in @($SkillNames)) {
        $key = $skillName.ToLowerInvariant()
        if ($skillsRequires.ContainsKey($key)) {
            $prereqs += @($skillsRequires[$key])
        }
    }

    foreach ($mcpName in @($McpNames)) {
        $key = $mcpName.ToLowerInvariant()
        if ($mcpRequires.ContainsKey($key)) {
            $prereqs += @($mcpRequires[$key])
        }
    }

    return @($prereqs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Select-SkillDirectoriesForProfiles {
    param(
        [Parameter(Mandatory)]
        [string[]]$SkillDirectories,
        [object[]]$Profiles,
        [string[]]$RequestedProfiles,
        [string]$RegistryRoot,
        [switch]$AllSkills
    )

    if ($AllSkills -or -not $Profiles -or $Profiles.Count -eq 0) {
        return @($SkillDirectories)
    }

    $tokens = @(Split-SelectionTokens -Values $RequestedProfiles)
    if ($tokens.Count -eq 0 -and -not (Test-InteractiveConsole)) {
        Write-Log -Message 'No interactive console detected; install all skills from bundle'
        return @($SkillDirectories)
    }

    if ($tokens.Count -eq 0) {
        Write-Host ''
        Write-Host (ConvertFrom-Utf8Base64String -Value '6K+36YCJ5oup6KaB5a6J6KOF55qEIEluZGllQXJrIFByb2ZpbGXvvIjlj6/ovpPlhaXluo/lj7cv5ZCN56ew77yM5aSa5Liq55So6YCX5Y+35YiG6ZqU77yb55u05o6l5Zue6L2m5a6J6KOF5YWo6YOoIHNraWxs77yJ77ya')
        Write-Host (ConvertFrom-Utf8Base64String -Value 'ICAwLiDlhajpg6ggc2tpbGzvvIjlhbzlrrnml6fpgLvovpHvvIk=')
        for ($index = 0; $index -lt $Profiles.Count; $index++) {
            $profile = $Profiles[$index]
            Write-Host ('  {0}. {1} - {2}' -f ($index + 1), $profile.Name, $profile.Description)
        }

        $answer = Read-Host 'Profile'
        $tokens = @(Split-SelectionTokens -Values @($answer))
        if ($tokens.Count -eq 0 -or $tokens -contains '0') {
            return @($SkillDirectories)
        }
    }

    $selectedProfiles = New-Object System.Collections.Generic.List[object]
    foreach ($token in $tokens) {
        $matched = $null
        [int]$numeric = 0
        if ([int]::TryParse($token, [ref]$numeric) -and $numeric -ge 1 -and $numeric -le $Profiles.Count) {
            $matched = $Profiles[$numeric - 1]
        }
        else {
            $matched = $Profiles | Where-Object { $_.Name -eq $token -or $_.Name.ToLowerInvariant() -eq $token.ToLowerInvariant() } | Select-Object -First 1
        }

        if (-not $matched) {
            throw ('Unknown skill profile: {0}' -f $token)
        }

        $selectedProfiles.Add($matched)
    }

    $wantedSkills = @($selectedProfiles | ForEach-Object { $_.Skills } | Sort-Object -Unique)
    $wantedMcp = @($selectedProfiles | ForEach-Object { $_.Mcp } | Sort-Object -Unique)
    $wantedPrereqs = @()
    if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) {
        $wantedPrereqs = @(Get-ProfilePrereqNames -RegistryRoot $RegistryRoot -SkillNames $wantedSkills -McpNames $wantedMcp)
    }

    if ($wantedSkills.Count -eq 0) {
        Write-Log -Level 'WARN' -Message 'Selected profiles do not reference any skills; install all skills from bundle'
        return @($SkillDirectories)
    }

    $skillByName = @{}
    $skillDirsByRegistryEntry = @{}
    foreach ($skillDir in $SkillDirectories) {
        $skillName = Split-Path -Leaf $skillDir
        $skillByName[$skillName.ToLowerInvariant()] = $skillDir

        $metaPath = Join-Path $skillDir '.skill-meta.json'
        if (Test-Path -LiteralPath $metaPath) {
            try {
                $meta = Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
                $entryName = [string](Get-ObjectPropertyValue -Object $meta -Name 'registry_entry_name')
                if (-not [string]::IsNullOrWhiteSpace($entryName)) {
                    $entryKey = $entryName.ToLowerInvariant()
                    if (-not $skillDirsByRegistryEntry.ContainsKey($entryKey)) {
                        $skillDirsByRegistryEntry[$entryKey] = New-Object System.Collections.Generic.List[string]
                    }
                    $skillDirsByRegistryEntry[$entryKey].Add($skillDir)
                }
            }
            catch {
                Write-Log -Level 'WARN' -Message ('Invalid .skill-meta.json while resolving profile entry for {0}: {1}' -f $skillName, $_.Exception.Message)
            }
        }
    }

    $selectedSkillDirs = New-Object System.Collections.Generic.List[string]
    $selectedSkillDirKeys = @{}
    $missingSkills = New-Object System.Collections.Generic.List[string]
    foreach ($skillName in $wantedSkills) {
        $key = $skillName.ToLowerInvariant()
        if ($skillByName.ContainsKey($key)) {
            $skillDir = $skillByName[$key]
            if (-not $selectedSkillDirKeys.ContainsKey($skillDir)) {
                $selectedSkillDirs.Add($skillDir)
                $selectedSkillDirKeys[$skillDir] = $true
            }
        }
        elseif ($skillDirsByRegistryEntry.ContainsKey($key)) {
            foreach ($skillDir in $skillDirsByRegistryEntry[$key]) {
                if (-not $selectedSkillDirKeys.ContainsKey($skillDir)) {
                    $selectedSkillDirs.Add($skillDir)
                    $selectedSkillDirKeys[$skillDir] = $true
                }
            }
        }
        else {
            $missingSkills.Add($skillName)
        }
    }

    if ($missingSkills.Count -gt 0) {
        Write-Log -Level 'WARN' -Message ('Profiles reference skills not found in bundle: {0}' -f ($missingSkills -join ', '))
    }

    $selectedProfileNames = @($selectedProfiles | ForEach-Object { $_.Name }) -join ', '
    $mcpDetail = if ($wantedMcp.Count -gt 0) { $wantedMcp -join ', ' } else { '(none)' }
    $prereqDetail = if ($wantedPrereqs.Count -gt 0) { $wantedPrereqs -join ', ' } else { '(none)' }
    Write-Log -Message ('Selected profiles: {0}' -f $selectedProfileNames)
    Write-Log -Message ('Selected skills: {0}/{1}' -f $selectedSkillDirs.Count, $SkillDirectories.Count)
    Write-Log -Message ('Selected MCP: {0}' -f $mcpDetail)
    Write-Log -Message ('Resolved prereqs: {0}' -f $prereqDetail)

    return @($selectedSkillDirs)
}

function Get-OptionalSkillTargets {
    $homeDir = Get-UserHomeDirectory
    $targets = New-Object System.Collections.Generic.List[object]

    $targets.Add([pscustomobject]@{
            Name = 'codex'
            Path = Join-Path $homeDir '.codex\skills'
            Enabled = $true
        })

    foreach ($target in @(
            @{ Name = 'claude_code'; Root = Join-Path $homeDir '.claude'; Path = Join-Path $homeDir '.claude\skills' },
            @{ Name = 'cursor'; Root = Join-Path $homeDir '.cursor'; Path = Join-Path $homeDir '.cursor\skills' },
            @{ Name = 'antigravity'; Root = Join-Path $homeDir '.gemini\antigravity'; Path = Join-Path $homeDir '.gemini\antigravity\global_skills' },
            @{ Name = 'gemini_cli'; Root = Join-Path $homeDir '.gemini'; Path = Join-Path $homeDir '.gemini\skills' },
            @{ Name = 'github_copilot'; Root = Join-Path $homeDir '.copilot'; Path = Join-Path $homeDir '.copilot\skills' }
        )) {
        $targets.Add([pscustomobject]@{
                Name = $target.Name
                Path = $target.Path
                Enabled = (Test-Path -LiteralPath $target.Root)
            })
    }

    return $targets
}

function Get-PythonLauncher {
    foreach ($candidate in @('python', 'py')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    return $null
}

function Get-InstalledSkillsManagerExecutable {
    $userLocalAppData = Get-UserLocalAppDataDirectory
    $userInstallCandidate = $null
    if (-not [string]::IsNullOrWhiteSpace($userLocalAppData)) {
        $userInstallCandidate = Join-Path $userLocalAppData 'skills-manager\skills-manager.exe'
    }

    $candidates = @(
        $userInstallCandidate,
        (Join-Path $env:ProgramFiles 'skills-manager\skills-manager.exe')
    )

    if ($env:ProgramFiles -and $env:ProgramFiles -ne ${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} 'skills-manager\skills-manager.exe'
    }

    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Initialize-SkillsManagerDatabase {
    param(
        [Parameter(Mandatory)]
        [string]$DbPath,
        [string]$SkillsManagerExe,
        [int]$TimeoutSeconds = 20,
        [switch]$DryRun
    )

    if (Test-Path -LiteralPath $DbPath) {
        return [pscustomobject]@{
            Available = $true
            LaunchedSkillsManager = $false
        }
    }

    if ($DryRun -or [string]::IsNullOrWhiteSpace($SkillsManagerExe)) {
        return [pscustomobject]@{
            Available = $false
            LaunchedSkillsManager = $false
        }
    }

    Write-Log -Message ('skills-manager DB not found yet; launching Skills Manager to initialize it: {0}' -f $SkillsManagerExe)
    Start-Process -FilePath $SkillsManagerExe | Out-Null

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $DbPath) {
            return [pscustomobject]@{
                Available = $true
                LaunchedSkillsManager = $true
            }
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    return [pscustomobject]@{
        Available = (Test-Path -LiteralPath $DbPath)
        LaunchedSkillsManager = $true
    }
}

function Read-SkillMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath,
        [Parameter(Mandatory)]
        [string]$SkillName,
        [Parameter(Mandatory)]
        [string]$CentralPath
    )

    $metaPath = Join-Path $SkillPath '.skill-meta.json'
    $meta = $null
    if (Test-Path -LiteralPath $metaPath) {
        try {
            $meta = Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Invalid .skill-meta.json for {0}; fall back to local source: {1}' -f $SkillName, $_.Exception.Message)
        }
    }

    $sourceType = if ($null -ne $meta) { [string](Get-ObjectPropertyValue -Object $meta -Name 'source_type') } else { 'local' }
    if ($sourceType -notin @('git', 'local')) {
        $sourceType = 'local'
    }

    $sourceRef = if ($null -ne $meta) { [string](Get-ObjectPropertyValue -Object $meta -Name 'source_ref') } else { $CentralPath }
    if ([string]::IsNullOrWhiteSpace($sourceRef)) {
        $sourceRef = $CentralPath
        $sourceType = 'local'
    }

    $sourceSubpath = if ($null -ne $meta) { Get-ObjectPropertyValue -Object $meta -Name 'source_subpath' } else { $null }
    $sourceBranch = if ($null -ne $meta) { Get-ObjectPropertyValue -Object $meta -Name 'source_branch' } else { $null }
    $sourceRevision = if ($null -ne $meta) { Get-ObjectPropertyValue -Object $meta -Name 'source_revision' } else { $null }
    $registryEntryName = if ($null -ne $meta) { Get-ObjectPropertyValue -Object $meta -Name 'registry_entry_name' } else { $null }
    if ([string]::IsNullOrWhiteSpace($registryEntryName)) {
        $registryEntryName = $SkillName
    }

    return [pscustomobject]@{
        Name = $SkillName
        Description = ''
        SourceType = $sourceType
        SourceRef = $sourceRef
        SourceSubpath = $sourceSubpath
        SourceBranch = $sourceBranch
        SourceRevision = $sourceRevision
        RegistryEntryName = $registryEntryName
        CentralPath = $CentralPath
    }
}

function Sync-SkillsManagerRegistry {
    param(
        [Parameter(Mandatory)]
        [object[]]$ImportedSkills,
        [switch]$DryRun
    )

    if ($ImportedSkills.Count -eq 0) {
        return
    }

    if ($DryRun) {
        foreach ($skill in $ImportedSkills) {
            Write-Log -Message ('[DryRun] Register skill in skills-manager DB: {0}' -f $skill.Name)
        }
        return
    }

    Update-CurrentProcessPath
    $python = Get-PythonLauncher
    if (-not $python) {
        Write-Log -Level 'WARN' -Message 'Python is not available yet; skip skills-manager DB sync for this run'
        return
    }

    $homeDir = Get-UserHomeDirectory
    $dbPath = Join-Path $homeDir '.skills-manager\skills-manager.db'
    $skillsManagerExe = Get-InstalledSkillsManagerExecutable
    $dbState = Initialize-SkillsManagerDatabase -DbPath $dbPath -SkillsManagerExe $skillsManagerExe -DryRun:$DryRun
    if (-not $dbState.Available) {
        Write-Log -Level 'WARN' -Message ('skills-manager DB not found, skip registry sync: {0}' -f $dbPath)
        return [pscustomobject]@{
            Synchronized = $false
            LaunchedSkillsManager = $dbState.LaunchedSkillsManager
        }
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-registry-' + [guid]::NewGuid().ToString('N'))
    Initialize-Directory -Path $tempRoot

    $payloadPath = Join-Path $tempRoot 'skills.json'
    $scriptPath = Join-Path $tempRoot 'sync_skills_manager_registry.py'
    $payloadJson = @{ skills = $ImportedSkills } | ConvertTo-Json -Depth 8
    $scriptContent = @'
import json
import os
import sqlite3
import sys
import time
import uuid

payload_path = sys.argv[1]
db_path = sys.argv[2]

with open(payload_path, 'r', encoding='utf-8') as fh:
    payload = json.load(fh)

conn = sqlite3.connect(db_path)
cur = conn.cursor()
now = int(time.time() * 1000)

active = cur.execute("SELECT scenario_id FROM active_scenario WHERE key='current'").fetchone()
if active:
    scenario_id = active[0]
else:
    first = cur.execute("SELECT id FROM scenarios ORDER BY created_at ASC LIMIT 1").fetchone()
    if not first:
        raise RuntimeError('No scenario found in skills-manager.db')
    scenario_id = first[0]

for skill in payload['skills']:
    source_type = skill.get('SourceType') or 'local'
    if source_type not in ('git', 'local'):
        source_type = 'local'

    source_ref = skill.get('SourceRef') or skill['CentralPath']
    source_subpath = skill.get('SourceSubpath')
    source_branch = skill.get('SourceBranch')
    source_revision = skill.get('SourceRevision')

    existing = cur.execute(
        "SELECT id FROM skills WHERE central_path=? OR name=? LIMIT 1",
        (skill['CentralPath'], skill['Name'])
    ).fetchone()
    skill_id = existing[0] if existing else str(uuid.uuid4())

    if existing:
        cur.execute(
            '''
            UPDATE skills
            SET name=?, description=?, source_type=?, source_ref=?, source_ref_resolved=NULL,
                source_subpath=?, source_branch=?, source_revision=?, remote_revision=NULL,
                central_path=?, enabled=1, updated_at=?, status='ok', update_status='unknown',
                last_checked_at=NULL, last_check_error=NULL
            WHERE id=?
            ''',
            (
                skill['Name'],
                skill.get('Description') or '',
                source_type,
                source_ref,
                source_subpath,
                source_branch,
                source_revision,
                skill['CentralPath'],
                now,
                skill_id,
            )
        )
    else:
        cur.execute(
            '''
            INSERT INTO skills (
                id, name, description, source_type, source_ref, source_ref_resolved,
                source_subpath, source_branch, source_revision, remote_revision,
                central_path, content_hash, enabled, created_at, updated_at,
                status, update_status, last_checked_at, last_check_error
            ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, NULL, ?, NULL, 1, ?, ?, 'ok', 'unknown', NULL, NULL)
            ''',
            (
                skill_id,
                skill['Name'],
                skill.get('Description') or '',
                source_type,
                source_ref,
                source_subpath,
                source_branch,
                source_revision,
                skill['CentralPath'],
                now,
                now,
            )
        )

    cur.execute(
        "INSERT OR REPLACE INTO scenario_skills (scenario_id, skill_id, added_at) VALUES (?, ?, ?)",
        (scenario_id, skill_id, now)
    )

    cur.execute("DELETE FROM scenario_skill_tools WHERE scenario_id=? AND skill_id=?", (scenario_id, skill_id))
    cur.execute("DELETE FROM skill_targets WHERE skill_id=?", (skill_id,))

    for target in skill.get('Targets', []):
        cur.execute(
            "INSERT INTO scenario_skill_tools (scenario_id, skill_id, tool, enabled, updated_at) VALUES (?, ?, ?, 1, ?)",
            (scenario_id, skill_id, target['Tool'], now)
        )
        cur.execute(
            '''
            INSERT INTO skill_targets (id, skill_id, tool, target_path, mode, status, synced_at, last_error)
            VALUES (?, ?, ?, ?, 'copy', 'ok', ?, NULL)
            ''',
            (str(uuid.uuid4()), skill_id, target['Tool'], target['Path'], now)
        )

conn.commit()
conn.close()
'@

    [System.IO.File]::WriteAllText($payloadPath, $payloadJson, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($scriptPath, $scriptContent, [System.Text.UTF8Encoding]::new($false))

    try {
        & $python $scriptPath $payloadPath $dbPath
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Level 'WARN' -Message ('skills-manager registry sync failed, exit={0}' -f $LASTEXITCODE)
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    return [pscustomobject]@{
        Synchronized = $true
        LaunchedSkillsManager = $dbState.LaunchedSkillsManager
    }
}

function Install-SkillBundle {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,
        [string[]]$SkillProfiles,
        [switch]$AllSkills,
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw "Skill bundle not found: $ZipPath"
    }

    $homeDir = Get-UserHomeDirectory
    $centralRoot = Join-Path $homeDir '.skills-manager\skills'
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-bundle-' + [guid]::NewGuid().ToString('N'))
    $targets = Get-OptionalSkillTargets
    $importedSkills = New-Object System.Collections.Generic.List[object]
    $copiedSkillCount = 0

    try {
        Write-Log -Message ('Skill source-of-truth root: {0}' -f $centralRoot)
        Initialize-Directory -Path $tempRoot
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempRoot -Force
        $allSkillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
        $registryRoot = Expand-BundleRegistryArchive -ExtractedBundleRoot $tempRoot -DestinationPath (Join-Path $tempRoot 'registry')
        $profiles = if ($registryRoot) { @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot) } else { @() }
        $skillDirs = @(Select-SkillDirectoriesForProfiles -SkillDirectories $allSkillDirs -Profiles $profiles -RequestedProfiles $SkillProfiles -RegistryRoot $registryRoot -AllSkills:$AllSkills)

        Write-Log -Message ('Discovered {0} skill directories; selected {1}' -f $allSkillDirs.Count, $skillDirs.Count)

        foreach ($skillDir in $skillDirs) {
            $skillName = Split-Path -Leaf $skillDir
            $sourcePath = $skillDir
            $centralPath = Join-Path $centralRoot $skillName
            $skillTargets = New-Object System.Collections.Generic.List[object]
            $centralNeedsImport = (-not (Test-SkillDirectoryInSync -SourcePath $sourcePath -DestinationPath $centralPath))
            $targetsNeedingSync = New-Object System.Collections.Generic.List[string]

            foreach ($target in $targets | Where-Object { $_.Enabled }) {
                $targetPath = Join-Path $target.Path $skillName
                $skillTargets.Add([pscustomobject]@{
                        Tool = $target.Name
                        Path = $targetPath
                    })

                if (-not (Test-SkillDirectoryInSync -SourcePath $sourcePath -DestinationPath $targetPath)) {
                    $targetsNeedingSync.Add($targetPath)
                }
            }

            $skillMetadata = Read-SkillMetadata -SkillPath $sourcePath -SkillName $skillName -CentralPath $centralPath
            $skillMetadata | Add-Member -MemberType NoteProperty -Name 'Targets' -Value $skillTargets -Force
            $importedSkills.Add($skillMetadata)

            if ((-not $centralNeedsImport) -and $targetsNeedingSync.Count -eq 0) {
                Write-Log -Message ('Skill already synchronized, skip: {0}' -f $skillName)
                continue
            }

            $copiedSkillCount++

            if ($centralNeedsImport) {
                Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath $centralPath -DryRun:$DryRun
            }

            foreach ($target in $targets | Where-Object { $_.Enabled }) {
                $targetPath = Join-Path $target.Path $skillName
                if ($targetsNeedingSync -contains $targetPath) {
                    $copySourcePath = if (Test-Path -LiteralPath $centralPath) { $centralPath } else { $sourcePath }
                    if (Test-SkillDirectoryInSync -SourcePath $copySourcePath -DestinationPath $targetPath) {
                        Write-Log -Message ('Target already synchronized after central import, skip duplicate copy: {0}' -f $targetPath)
                        continue
                    }

                    Copy-SkillDirectory -SourcePath $copySourcePath -DestinationPath $targetPath -DryRun:$DryRun
                }
            }

        }

        $registrySyncResult = $null
        if ($importedSkills.Count -gt 0) {
            $registrySyncResult = Sync-SkillsManagerRegistry -ImportedSkills $importedSkills -DryRun:$DryRun
        }

        if (-not $DryRun -and $importedSkills.Count -gt 0) {
            $skillsManagerExe = Get-InstalledSkillsManagerExecutable
            $alreadyLaunchedForDbInit = ($null -ne $registrySyncResult -and $registrySyncResult.LaunchedSkillsManager)
            if ($skillsManagerExe -and -not $alreadyLaunchedForDbInit) {
                Write-Log -Message 'Imported skills and synced skills-manager DB; launching Skills Manager'
                Start-Process -FilePath $skillsManagerExe | Out-Null
            }
        }

        return [pscustomobject]@{
            Name = 'skills.zip'
            Key = 'skills-bundle'
            Status = 'ok'
            Source = 'local-zip'
            Detail = if ($copiedSkillCount -eq 0) { 'All skills already synchronized' } else { '{0} skills imported' -f $copiedSkillCount }
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

Export-ModuleMember -Function @(
    'Write-Log',
    'Test-IsAdministrator',
    'ConvertTo-ArgumentTokens',
    'Get-AppManifest',
    'Get-SelectedApps',
    'Initialize-CodexWorkspaceDirectory',
    'Install-AppFromDefinition',
    'Get-CcSwitchProviderByName',
    'Read-CodexProviderInput',
    'Import-CcSwitchCodexProvider',
    'Install-SkillBundle'
)
