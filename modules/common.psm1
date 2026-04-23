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

function Ensure-CodexWorkspaceDirectory {
    param(
        [switch]$DryRun
    )

    $driveRoot = 'D:\'
    $workspaceRoot = 'D:\Vibe Coding'
    $chatPath = 'D:\Vibe Coding\Chat'

    if (-not (Test-Path -LiteralPath $driveRoot)) {
        throw 'Drive D: is not available'
    }

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
        '--disable-interactivity',
        '--silent'
    )

    if ($DryRun) {
        Write-Log -Message ('[DryRun] winget {0} {1}' -f $Action, $PackageId)
        return
    }

    Write-Log -Message ('Running winget {0}: {1}' -f $Action, $PackageId)
    & winget @args
    $exitCode = $LASTEXITCODE

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
        [string]$PackageId
    )

    if (-not (Test-WingetInstalled)) {
        return $false
    }

    $output = & winget list --id $PackageId --exact --accept-source-agreements --disable-interactivity 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return $output -match [regex]::Escape($PackageId)
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
            $args = @('/i', $PackagePath, '/qn', '/norestart')
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

    switch ($Definition.strategy) {
        'winget' {
            try {
                if (Test-WingetPackageInstalled -PackageId $Definition.wingetId) {
                    Invoke-WingetAction -Action 'upgrade' -PackageId $Definition.wingetId -DryRun:$DryRun
                    return [pscustomobject]@{
                        Name = $Definition.name
                        Key = $Definition.key
                        Status = 'ok'
                        Source = 'winget-upgrade'
                        Detail = $Definition.wingetId
                    }
                }

                Invoke-WingetAction -Action 'install' -PackageId $Definition.wingetId -DryRun:$DryRun
                return [pscustomobject]@{
                    Name = $Definition.name
                    Key = $Definition.key
                    Status = 'ok'
                    Source = 'winget-install'
                    Detail = $Definition.wingetId
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

    $baseUrl = Read-Host 'OpenAI-compatible base URL (for example https://api.example.com/v1)'
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        throw 'Base URL cannot be empty'
    }

    $model = Read-Host 'Default model name (default gpt-5.4)'
    if ([string]::IsNullOrWhiteSpace($model)) {
        $model = 'gpt-5.4'
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

    $configToml = @"
model_provider = "custom"
model = "$($ProviderInfo.Model)"

[model_providers]
[model_providers.custom]
name = "custom"
wire_api = "responses"
requires_openai_auth = true
base_url = "$($ProviderInfo.BaseUrl)"
"@

    $payload = @{
        auth = @{
            OPENAI_API_KEY = $ProviderInfo.ApiKey
        }
        config = $configToml
    } | ConvertTo-Json -Compress -Depth 6

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    $queryPairs = @(
        'resource=provider',
        'app=codex',
        ('name={0}' -f [uri]::EscapeDataString($ProviderInfo.Name)),
        'configFormat=json',
        ('config={0}' -f [uri]::EscapeDataString($encoded))
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

    return $skillFiles | ForEach-Object { $_.Directory.FullName } | Sort-Object -Unique
}

function Get-SkillDirectoriesFromZip {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entries = $archive.Entries |
            Where-Object { $_.FullName -match '(^|/|\\)SKILL\.md$' } |
            ForEach-Object { [IO.Path]::GetDirectoryName($_.FullName.Replace('/', '\')) } |
            Sort-Object -Unique

        if (-not $entries -or $entries.Count -eq 0) {
            throw "No SKILL.md files were found in: $ZipPath"
        }

        return $entries
    }
    finally {
        $archive.Dispose()
    }
}

function Get-OptionalSkillTargets {
    $targets = New-Object System.Collections.Generic.List[object]

    $targets.Add([pscustomobject]@{
            Name = 'codex'
            Path = Join-Path $HOME '.codex\skills'
            Enabled = $true
        })

    foreach ($target in @(
            @{ Name = 'claude_code'; Root = Join-Path $HOME '.claude'; Path = Join-Path $HOME '.claude\skills' },
            @{ Name = 'cursor'; Root = Join-Path $HOME '.cursor'; Path = Join-Path $HOME '.cursor\skills' },
            @{ Name = 'gemini_cli'; Root = Join-Path $HOME '.gemini'; Path = Join-Path $HOME '.gemini\skills' },
            @{ Name = 'github_copilot'; Root = Join-Path $HOME '.copilot'; Path = Join-Path $HOME '.copilot\skills' }
        )) {
        $targets.Add([pscustomobject]@{
                Name = $target.Name
                Path = $target.Path
                Enabled = (Test-Path -LiteralPath $target.Root)
            })
    }

    return $targets
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

    $centralRoot = Join-Path $HOME '.skills-manager\skills'
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-bundle-' + [guid]::NewGuid().ToString('N'))
    $targets = Get-OptionalSkillTargets

    try {
        if (-not $DryRun) {
            Ensure-Directory -Path $tempRoot
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempRoot -Force
        }

        if ($DryRun) {
            $skillDirs = Get-SkillDirectoriesFromZip -ZipPath $ZipPath
        }
        else {
            $skillDirs = Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot
        }

        Write-Log -Message ('Discovered {0} skill directories' -f $skillDirs.Count)

        foreach ($skillDir in $skillDirs) {
            $skillName = Split-Path -Leaf $skillDir
            $sourcePath = if ($DryRun) { $skillDir } else { $skillDir }
            Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath (Join-Path $centralRoot $skillName) -DryRun:$DryRun

            foreach ($target in $targets | Where-Object { $_.Enabled }) {
                Copy-SkillDirectory -SourcePath $sourcePath -DestinationPath (Join-Path $target.Path $skillName) -DryRun:$DryRun
            }
        }

        if (-not $DryRun) {
            $skillsManagerExe = Join-Path $env:LOCALAPPDATA 'skills-manager\skills-manager.exe'
            if (Test-Path -LiteralPath $skillsManagerExe) {
                Write-Log -Message 'Imported central skills; launching Skills Manager to encourage a rescan'
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
