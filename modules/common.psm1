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

function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-UserHomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }

    return $HOME
}

function Ensure-CodexWorkspaceDirectory {
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

    Ensure-Directory -Path $workspaceRoot
    Ensure-Directory -Path $chatPath
    Write-Log -Message ('Created Codex workspace directory: {0}' -f $chatPath)

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

    Ensure-Directory -Path (Split-Path -Parent $DestinationPath)
    Write-Log -Message ('Downloading {0}' -f $Url)
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath
    return $DestinationPath
}

function Invoke-ProcessWithProgress {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory)]
        [string]$Activity,
        [Parameter(Mandatory)]
        [string]$Status
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden
    $tick = 0

    try {
        while (-not $process.HasExited) {
            $percent = (($tick % 20) + 1) * 5
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
            Start-Sleep -Milliseconds 750
            $tick++
        }
    }
    finally {
        Write-Progress -Activity $Activity -Completed
    }

    return $process.ExitCode
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
    $exitCode = Invoke-ProcessWithProgress `
        -FilePath 'winget' `
        -ArgumentList $args `
        -Activity ('winget {0}' -f $Action) `
        -Status $PackageId

    if ($exitCode -ne 0) {
        if ($Action -eq 'upgrade') {
            Write-Log -Level 'WARN' -Message ('winget upgrade {0} returned {1}; continuing' -f $PackageId, $exitCode)
            return
        }
        throw ('winget {0} {1} failed, exit={2}' -f $Action, $PackageId, $exitCode)
    }
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

    $commandName = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'command')
    if ([string]::IsNullOrWhiteSpace($commandName)) {
        return $null
    }

    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Found = $false
            Version = $null
            Source = 'command'
            Detail = $commandName
        }
    }

    $arguments = @((Get-ObjectPropertyValue -Object $DetectConfig -Name 'args' -Default @()))
    $pattern = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'regex')
    $outputLines = @(& $commandName @arguments 2>&1)
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
    $topLevelMatch = [regex]::Match($output, '(?m)^Version:\s*(?<version>.+?)\s*$')
    if ($topLevelMatch.Success) {
        $candidate = $topLevelMatch.Groups['version'].Value.Trim()
        if ($candidate -ne 'Unknown') {
            $version = $candidate
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $descriptionMatch = [regex]::Match($output, '(?m)^\s+Version:\s*v?(?<version>\d+(?:\.\d+)+)\s*$')
        if ($descriptionMatch.Success) {
            $version = $descriptionMatch.Groups['version'].Value
        }
    }

    $script:WingetShowCache[$cacheKey] = $version
    return $version
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

    if (-not $installed.Found) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'missing'
            InstalledVersion = $null
            DesiredVersion = $desired.Version
            Detail = 'Not installed'
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

function Install-DownloadedPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath,
        [Parameter(Mandatory)]
        [string]$InstallerType,
        [string[]]$SilentArgs = @(),
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $PackagePath) -and -not $DryRun) {
        throw "Package not found: $PackagePath"
    }

    switch ($InstallerType) {
        'msi' {
            $args = @('/i', $PackagePath, '/qn', '/norestart') + $SilentArgs
            if ($DryRun) {
                Write-Log -Message ('[DryRun] msiexec.exe {0}' -f ($args -join ' '))
                return
            }

            Write-Log -Message ('Installing MSI: {0}' -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $args -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw ('MSI install failed, exit={0}' -f $proc.ExitCode)
            }
        }
        'exe' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] {0} {1}' -f $PackagePath, ($SilentArgs -join ' '))
                return
            }

            Write-Log -Message ('Installing EXE: {0}' -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath $PackagePath -ArgumentList $SilentArgs -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw ('EXE install failed, exit={0}' -f $proc.ExitCode)
            }
        }
        'msix' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] Add-AppxPackage {0}' -f $PackagePath)
                return
            }

            Write-Log -Message ('Installing MSIX: {0}' -f (Split-Path -Leaf $PackagePath))
            Add-AppxPackage -Path $PackagePath
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
    Ensure-Directory -Path $downloadsRoot
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
        return [pscustomobject]@{
            Name = $Definition.name
            Key = $Definition.key
            Status = 'ok'
            Source = 'precheck-skip'
            Detail = '{0} >= {1}' -f $decision.InstalledVersion, $decision.DesiredVersion
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
                Write-Log -Level 'WARN' -Message ('winget path failed, falling back to release or local package: {0}' -f $Definition.name)
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
                Write-Log -Level 'WARN' -Message ('GitHub release path failed, falling back to release or local package: {0}' -f $Definition.name)
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
                Write-Log -Level 'WARN' -Message ('Release asset path failed, falling back to release or local package: {0}' -f $Definition.name)
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
                Write-Log -Level 'WARN' -Message ('Direct URL path failed, falling back to release or local package: {0}' -f $Definition.name)
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
                Write-Log -Level 'WARN' -Message ('GitHub latest-tag path failed, falling back to release or local package: {0}' -f $Definition.name)
            }
        }
        default {
            throw ('Unsupported strategy: {0}' -f $Definition.strategy)
        }
    }

    if (-not $Definition.fallback) {
        throw ('{0} has no usable fallback' -f $Definition.name)
    }

    if ($Definition.fallback.releaseAsset) {
        try {
            $releaseRepo = $Definition.fallback.releaseRepo
            $releaseTag = $Definition.fallback.releaseTag
            $assetName = $Definition.fallback.releaseAsset
            $url = Get-GitHubReleaseAssetDownloadUrl -Repo $releaseRepo -Tag $releaseTag -AssetName $assetName
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
                Source = 'release-fallback'
                Detail = '{0}@{1}/{2}' -f $releaseRepo, $releaseTag, $assetName
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Release fallback failed: {0}' -f $_.Exception.Message)
        }
    }

    if ($Definition.fallback.localFile) {
        $localPackage = Resolve-WorkspacePath -WorkspaceRoot $WorkspaceRoot -RelativePath $Definition.fallback.localFile
        Install-DownloadedPackage `
            -PackagePath $localPackage `
            -InstallerType $Definition.fallback.installerType `
            -SilentArgs $Definition.fallback.silentArgs `
            -DryRun:$DryRun

        return [pscustomobject]@{
            Name = $Definition.name
            Key = $Definition.key
            Status = 'ok'
            Source = 'local-fallback'
            Detail = $Definition.fallback.localFile
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

function Read-CodexProviderInput {
    $name = Read-Host 'Provider name shown in CC Switch (default Team Relay)'
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = 'Team Relay'
    }

    $baseUrl = Read-Host 'OpenAI-compatible base URL (default https://api.indieark.tech/v1)'
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        $baseUrl = 'https://api.indieark.tech/v1'
    }

    $model = Read-Host 'Default model name (default gpt5.4)'
    if ([string]::IsNullOrWhiteSpace($model)) {
        $model = 'gpt5.4'
    }

    $secureApiKey = Read-Host 'API key (input hidden)' -AsSecureString
    $apiKey = ConvertFrom-SecureStringPlainText -SecureString $secureApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'API key cannot be empty'
    }

    return [pscustomobject]@{
        Name = $name
        BaseUrl = $baseUrl.Trim()
        Model = $model.Trim()
        ApiKey = $apiKey
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

function Import-CcSwitchCodexProvider {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$ProviderInfo,
        [switch]$DryRun
    )

    $link = New-CcSwitchCodexDeepLink -ProviderInfo $ProviderInfo

    if ($DryRun) {
        Write-Log -Message ('[DryRun] Would import provider via ccswitch:// deep link: {0} -> {1}' -f $ProviderInfo.Name, $ProviderInfo.BaseUrl)
        return [pscustomobject]@{
            Name = 'CC Switch Provider Import'
            Key = 'cc-switch-provider'
            Status = 'ok'
            Source = 'ccswitch-deeplink'
            Detail = $ProviderInfo.Name
        }
    }

    if (-not (Test-CcSwitchProtocolRegistered)) {
        throw 'ccswitch:// protocol is not registered. Launch CC Switch once, then retry.'
    }

    Write-Log -Message ('Importing CC Switch provider via official deep link: {0}' -f $ProviderInfo.Name)
    Start-Process -FilePath $link | Out-Null

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

    Ensure-Directory -Path (Split-Path -Parent $DestinationPath)
    Remove-DirectoryContentsSafe -Path $DestinationPath
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Recurse -Force
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
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'skills-manager\skills-manager.exe'),
        (Join-Path $env:ProgramFiles 'skills-manager\skills-manager.exe')
    )

    if ($env:ProgramFiles -and $env:ProgramFiles -ne ${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} 'skills-manager\skills-manager.exe'
    }

    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
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

    $python = Get-PythonLauncher
    if (-not $python) {
        throw 'Python is required to register imported skills in skills-manager.db'
    }

    $homeDir = Get-UserHomeDirectory
    $dbPath = Join-Path $homeDir '.skills-manager\skills-manager.db'
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-registry-' + [guid]::NewGuid().ToString('N'))
    Ensure-Directory -Path $tempRoot

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
    existing = cur.execute(
        "SELECT id FROM skills WHERE central_path=? OR name=? LIMIT 1",
        (skill['CentralPath'], skill['Name'])
    ).fetchone()
    skill_id = existing[0] if existing else str(uuid.uuid4())

    if existing:
        cur.execute(
            '''
            UPDATE skills
            SET name=?, description=?, source_type='local', source_ref=?, source_ref_resolved=NULL,
                source_subpath=?, source_branch=NULL, source_revision=NULL, remote_revision=NULL,
                central_path=?, enabled=1, updated_at=?, status='ok', update_status='unknown',
                last_checked_at=NULL, last_check_error=NULL
            WHERE id=?
            ''',
            (
                skill['Name'],
                skill.get('Description') or '',
                skill.get('SourceRef') or skill['CentralPath'],
                skill.get('SourceSubpath'),
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
            ) VALUES (?, ?, ?, 'local', ?, NULL, ?, NULL, NULL, NULL, ?, NULL, 1, ?, ?, 'ok', 'unknown', NULL, NULL)
            ''',
            (
                skill_id,
                skill['Name'],
                skill.get('Description') or '',
                skill.get('SourceRef') or skill['CentralPath'],
                skill.get('SourceSubpath'),
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
            throw ('skills-manager registry sync failed, exit={0}' -f $LASTEXITCODE)
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Install-SkillBundle {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,
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

    try {
        if (-not $DryRun) {
            Ensure-Directory -Path $tempRoot
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempRoot -Force
        }

        if ($DryRun) {
            $skillDirs = @(Get-SkillDirectoriesFromZip -ZipPath $ZipPath)
        }
        else {
            $skillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
        }

        Write-Log -Message ('Discovered {0} skill directories' -f $skillDirs.Count)

        foreach ($skillDir in $skillDirs) {
            $skillName = Split-Path -Leaf $skillDir
            $sourcePath = if ($DryRun) { $skillDir } else { $skillDir }
            $centralPath = Join-Path $centralRoot $skillName
            Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath $centralPath -DryRun:$DryRun

            $skillTargets = New-Object System.Collections.Generic.List[object]

            foreach ($target in $targets | Where-Object { $_.Enabled }) {
                $targetPath = Join-Path $target.Path $skillName
                Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath $targetPath -DryRun:$DryRun
                $skillTargets.Add([pscustomobject]@{
                        Tool = $target.Name
                        Path = $targetPath
                    })
            }

            $importedSkills.Add([pscustomobject]@{
                    Name = $skillName
                    Description = ''
                    SourceRef = $centralPath
                    SourceSubpath = $null
                    CentralPath = $centralPath
                    Targets = $skillTargets
                })
        }

        Sync-SkillsManagerRegistry -ImportedSkills $importedSkills -DryRun:$DryRun

        if (-not $DryRun) {
            $skillsManagerExe = Get-InstalledSkillsManagerExecutable
            if ($skillsManagerExe) {
                Write-Log -Message 'Imported skills and synced skills-manager DB; launching Skills Manager'
                Start-Process -FilePath $skillsManagerExe | Out-Null
            }
        }

        return [pscustomobject]@{
            Name = 'skills.zip'
            Key = 'skills-bundle'
            Status = 'ok'
            Source = 'local-zip'
            Detail = '{0} skills imported' -f $skillDirs.Count
        }
    }
    finally {
        if (-not $DryRun -and (Test-Path -LiteralPath $tempRoot)) {
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
    'Ensure-CodexWorkspaceDirectory',
    'Install-AppFromDefinition',
    'Read-CodexProviderInput',
    'Import-CcSwitchCodexProvider',
    'Install-SkillBundle'
)
