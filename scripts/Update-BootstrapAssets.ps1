[CmdletBinding()]
param(
    [string]$ManifestPath = 'manifest/apps.json',
    [string]$ReadmePath = 'README.md',
    [string]$Repo = $env:GITHUB_REPOSITORY,
    [string]$ReleaseTag = 'bootstrap-assets',
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$SourceGitHubToken = $env:SOURCE_GITHUB_TOKEN,
    [string]$Model00000Token = $env:MODEL_00000_TOKEN,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Repo)) {
    throw 'Repo is required. Pass -Repo owner/name or set GITHUB_REPOSITORY.'
}

if (-not $DryRun -and [string]::IsNullOrWhiteSpace($GitHubToken)) {
    throw 'GITHUB_TOKEN is required when not running with -DryRun.'
}

$repoParts = $Repo.Split('/')
if ($repoParts.Count -ne 2) {
    throw ('Repo must be in owner/name form: {0}' -f $Repo)
}

$owner = $repoParts[0]
$repoName = $repoParts[1]
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestFullPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath
}
else {
    Join-Path $workspaceRoot $ManifestPath
}
$readmeFullPath = if ([System.IO.Path]::IsPathRooted($ReadmePath)) {
    $ReadmePath
}
else {
    Join-Path $workspaceRoot $ReadmePath
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([Parameter(Mandatory=$true)][string]$Message)
    Write-Host ('[assets] {0}' -f $Message)
}

function Get-ApiHeaders {
    param([string]$Token = $GitHubToken)

    $headers = @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers.Authorization = ('Bearer {0}' -f $Token)
    }

    return $headers
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [ValidateSet('GET', 'POST', 'DELETE')]
        [string]$Method = 'GET',
        [object]$Body,
        [string]$Token = $GitHubToken
    )

    $params = @{
        Uri = $Uri
        Method = $Method
        Headers = Get-ApiHeaders -Token $Token
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
        $params.ContentType = 'application/json'
    }

    return Invoke-RestMethod @params
}

function Get-LatestGitHubRelease {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRepo,
        [string]$Token = $GitHubToken
    )
    return Invoke-GitHubApi -Uri ('https://api.github.com/repos/{0}/releases/latest' -f $SourceRepo) -Token $Token
}

function Get-ReleaseByTag {
    param([Parameter(Mandatory=$true)][string]$Tag)

    $uri = 'https://api.github.com/repos/{0}/{1}/releases/tags/{2}' -f $owner, $repoName, [uri]::EscapeDataString($Tag)
    try {
        return Invoke-GitHubApi -Uri $uri
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        if ($statusCode -ne 404) {
            throw
        }

        Write-Step ('Release {0} does not exist; it will be created.' -f $Tag)
        if ($DryRun) {
            return [pscustomobject]@{
                id = $null
                upload_url = 'https://uploads.github.com/repos/{owner}/{repo}/releases/{id}/assets{?name,label}'
                assets = @()
            }
        }

        return Invoke-GitHubApi `
            -Uri ('https://api.github.com/repos/{0}/{1}/releases' -f $owner, $repoName) `
            -Method POST `
            -Body @{
                tag_name = $Tag
                name = $Tag
                body = 'Bootstrap installer assets used by the Windows setup script.'
                draft = $false
                prerelease = $false
            }
    }
}

function Add-FlattenedItems {
    param(
        [Parameter(Mandatory=$true)][System.Collections.IList]$List,
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [System.Array]) {
        foreach ($entry in $Value) {
            Add-FlattenedItems -List $List -Value $entry
        }
        return
    }

    [void]$List.Add($Value)
}

function Get-ReleaseAssets {
    param([Parameter(Mandatory=$true)]$Release)

    if (-not $Release.id) {
        return @()
    }

    $allAssets = [System.Collections.ArrayList]::new()
    $page = 1
    while ($true) {
        $uri = 'https://api.github.com/repos/{0}/{1}/releases/{2}/assets?per_page=100&page={3}' -f $owner, $repoName, $Release.id, $page
        $pageAssets = [System.Collections.ArrayList]::new()
        Add-FlattenedItems -List $pageAssets -Value (Invoke-GitHubApi -Uri $uri)
        foreach ($asset in $pageAssets) {
            [void]$allAssets.Add($asset)
        }

        if ($pageAssets.Count -lt 100) {
            break
        }

        $page++
    }

    foreach ($asset in $allAssets) {
        $asset
    }
}

function Find-AssetByRegex {
    param(
        [Parameter(Mandatory=$true)][object[]]$Assets,
        [Parameter(Mandatory=$true)][string]$Pattern
    )

    $flatAssets = [System.Collections.ArrayList]::new()
    Add-FlattenedItems -List $flatAssets -Value $Assets
    return @($flatAssets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1)
}

function Save-UrlToFile {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$Path,
        [hashtable]$Headers
    )

    Write-Step ('Downloading {0}' -f $Uri)
    $params = @{
        Uri = $Uri
        OutFile = $Path
    }

    if ($null -ne $Headers -and $Headers.Count -gt 0) {
        $params.Headers = $Headers
    }

    Invoke-WebRequest @params
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-SameReleaseAsset {
    param(
        [Parameter(Mandatory=$true)][object]$SourceAsset,
        [Parameter(Mandatory=$true)][object]$TargetAsset,
        [Parameter(Mandatory=$true)][string]$SourceDownloadUrl,
        [Parameter(Mandatory=$true)][string]$TargetDownloadUrl,
        [Parameter(Mandatory=$true)][string]$TempDir
    )

    if ($SourceAsset.PSObject.Properties.Name -contains 'digest' -and $TargetAsset.PSObject.Properties.Name -contains 'digest') {
        if (-not [string]::IsNullOrWhiteSpace($SourceAsset.digest) -and -not [string]::IsNullOrWhiteSpace($TargetAsset.digest)) {
            return $SourceAsset.digest -eq $TargetAsset.digest
        }
    }

    if ($SourceAsset.PSObject.Properties.Name -contains 'size' -and $TargetAsset.PSObject.Properties.Name -contains 'size') {
        if ([int64]$SourceAsset.size -ne [int64]$TargetAsset.size) {
            return $false
        }
    }

    $sourcePath = Join-Path $TempDir ('source-{0}' -f $SourceAsset.name)
    $targetPath = Join-Path $TempDir ('target-{0}' -f $TargetAsset.name)
    Save-UrlToFile -Uri $SourceDownloadUrl -Path $sourcePath
    Save-UrlToFile -Uri $TargetDownloadUrl -Path $targetPath
    return (Get-FileSha256 -Path $sourcePath) -eq (Get-FileSha256 -Path $targetPath)
}

function Upload-ReleaseAsset {
    param(
        [Parameter(Mandatory=$true)]$Release,
        [Parameter(Mandatory=$true)][string]$AssetPath,
        [Parameter(Mandatory=$true)][string]$AssetName
    )

    if ($DryRun) {
        Write-Step ('Dry run: would upload {0}' -f $AssetName)
        return
    }

    $uploadBase = ($Release.upload_url -replace '\{\?name,label\}$', '')
    $uploadUri = '{0}?name={1}' -f $uploadBase, [uri]::EscapeDataString($AssetName)
    Write-Step ('Uploading {0}' -f $AssetName)

    Invoke-RestMethod `
        -Uri $uploadUri `
        -Method POST `
        -Headers (Get-ApiHeaders) `
        -ContentType 'application/octet-stream' `
        -InFile $AssetPath | Out-Null
}

function Remove-ReleaseAsset {
    param([Parameter(Mandatory=$true)]$Asset)

    if ($DryRun) {
        Write-Step ('Dry run: would delete {0}' -f $Asset.name)
        return
    }

    Write-Step ('Deleting old asset {0}' -f $Asset.name)
    Invoke-GitHubApi -Uri $Asset.url -Method DELETE | Out-Null
}

function Get-NodeInstaller {
    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
    $release = @($index | Where-Object { $_.files -contains 'win-x64-msi' } | Select-Object -First 1)
    if ($release.Count -eq 0) {
        throw 'Could not resolve latest Node.js win-x64 MSI release.'
    }

    $version = $release[0].version
    $assetName = 'node-{0}-x64.msi' -f $version
    return [pscustomobject]@{
        Name = $assetName
        DownloadUrl = 'https://nodejs.org/dist/{0}/{1}' -f $version, $assetName
    }
}

function Get-Python313Installer {
    $listing = Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/' -UseBasicParsing
    $versions = @(
        [regex]::Matches($listing.Content, 'href="(?<version>3\.13\.\d+)/"') |
            ForEach-Object { $_.Groups['version'].Value } |
            Sort-Object { [version]$_ } -Descending
    )

    if ($versions.Count -eq 0) {
        throw 'Could not resolve latest Python 3.13 release.'
    }

    $version = $versions[0]
    $assetName = 'python-{0}-amd64.exe' -f $version
    return [pscustomobject]@{
        Name = $assetName
        DownloadUrl = 'https://www.python.org/ftp/python/{0}/{1}' -f $version, $assetName
    }
}

function Get-VSCodeInstaller {
    $versions = Invoke-RestMethod -Uri 'https://update.code.visualstudio.com/api/releases/stable'
    $version = @($versions | Select-Object -First 1)[0]
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw 'Could not resolve latest Visual Studio Code stable release.'
    }

    return [pscustomobject]@{
        Name = 'VSCodeUserSetup-x64-{0}.exe' -f $version
        DownloadUrl = 'https://update.code.visualstudio.com/{0}/win32-x64-user/stable' -f $version
    }
}

function Get-GitHubInstaller {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRepo,
        [Parameter(Mandatory=$true)][string]$AssetPattern,
        [string]$OutputName,
        [string]$Token = $GitHubToken,
        [switch]$AuthenticatedDownload
    )

    $release = Get-LatestGitHubRelease -SourceRepo $SourceRepo -Token $Token
    $asset = @(Find-AssetByRegex -Assets @($release.assets) -Pattern $AssetPattern)
    if ($asset.Count -eq 0) {
        throw ('Could not find asset matching {0} in {1}@{2}.' -f $AssetPattern, $SourceRepo, $release.tag_name)
    }

    $sourceAsset = $asset | Select-Object -First 1
    $downloadUrl = $sourceAsset.browser_download_url
    $downloadHeaders = $null
    if ($AuthenticatedDownload) {
        $downloadUrl = $sourceAsset.url
        $downloadHeaders = Get-ApiHeaders -Token $Token
        $downloadHeaders.Accept = 'application/octet-stream'
    }

    return [pscustomobject]@{
        Name = if ([string]::IsNullOrWhiteSpace($OutputName)) { $sourceAsset.name } else { $OutputName }
        DownloadUrl = $downloadUrl
        DownloadHeaders = $downloadHeaders
        SourceAsset = $sourceAsset
    }
}

function Set-ManifestAssetName {
    param(
        [Parameter(Mandatory=$true)]$Manifest,
        [Parameter(Mandatory=$true)][string]$Key,
        [Parameter(Mandatory=$true)][string]$PropertyPath,
        [Parameter(Mandatory=$true)][string]$AssetName
    )

    $app = @($Manifest.apps | Where-Object { $_.key -eq $Key } | Select-Object -First 1)
    if ($app.Count -eq 0) {
        throw ('Manifest app not found: {0}' -f $Key)
    }

    switch ($PropertyPath) {
        'fallback.releaseAsset' {
            if ($app[0].fallback.releaseAsset -ne $AssetName) {
                Write-Step ('Manifest {0}: {1} -> {2}' -f $Key, $app[0].fallback.releaseAsset, $AssetName)
                $app[0].fallback.releaseAsset = $AssetName
                return $true
            }
        }
        'assetName' {
            if ($app[0].assetName -ne $AssetName) {
                Write-Step ('Manifest {0}: {1} -> {2}' -f $Key, $app[0].assetName, $AssetName)
                $app[0].assetName = $AssetName
                return $true
            }
        }
        default {
            throw ('Unsupported manifest property path: {0}' -f $PropertyPath)
        }
    }

    return $false
}

function Set-ReadmeAssetName {
    param(
        [Parameter(Mandatory=$true)][ref]$ReadmeText,
        [Parameter(Mandatory=$true)][string]$AssetPattern,
        [Parameter(Mandatory=$true)][string]$AssetName
    )

    if ($null -eq $ReadmeText.Value) {
        return $false
    }

    $pattern = $AssetPattern.TrimStart('^').TrimEnd('$')
    $matches = [regex]::Matches([string]$ReadmeText.Value, $pattern)
    $oldNames = @(
        $matches |
            ForEach-Object { $_.Value } |
            Where-Object { $_ -ne $AssetName } |
            Sort-Object -Unique
    )

    if ($oldNames.Count -eq 0) {
        return $false
    }

    foreach ($oldName in $oldNames) {
        Write-Step ('README asset: {0} -> {1}' -f $oldName, $AssetName)
    }

    $ReadmeText.Value = [regex]::Replace([string]$ReadmeText.Value, $pattern, $AssetName)
    return $true
}

$managedAssets = @(
    @{
        Key = 'git'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^Git-[0-9][0-9A-Za-z.\-]*-64-bit\.exe$'
        Resolve = { Get-GitHubInstaller -SourceRepo 'git-for-windows/git' -AssetPattern '^Git-[0-9][0-9A-Za-z.\-]*-64-bit\.exe$' }
    },
    @{
        Key = 'nodejs'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^node-v[0-9][0-9A-Za-z.\-]*-x64\.msi$'
        Resolve = { Get-NodeInstaller }
    },
    @{
        Key = 'python'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^python-3\.13\.\d+-amd64\.exe$'
        Resolve = { Get-Python313Installer }
    },
    @{
        Key = 'vscode'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^VSCodeUserSetup-x64-[0-9][0-9A-Za-z.\-]*\.exe$'
        Resolve = { Get-VSCodeInstaller }
    },
    @{
        Key = 'chatgpt'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^ChatGPT_x64\.msi$'
        CompareContentOnSameName = $true
        Resolve = { Get-GitHubInstaller -SourceRepo 'tw93/Pake' -AssetPattern '^ChatGPT_x64\.msi$' }
    },
    @{
        Key = 'cc-switch'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^CC-Switch-v?[0-9][0-9A-Za-z.\-]*-Windows\.msi$'
        Resolve = { Get-GitHubInstaller -SourceRepo 'farion1231/cc-switch' -AssetPattern '^CC-Switch-v?[0-9][0-9A-Za-z.\-]*-Windows\.msi$' }
    },
    @{
        Key = 'codex-provider-sync'
        ManifestPath = 'assetName'
        ExistingAssetPattern = '^Codex\.Provider\.Sync_[0-9][0-9A-Za-z.\-]*_x64-setup\.exe$'
        Resolve = { Get-GitHubInstaller -SourceRepo 'indieark/codex-provider-sync' -AssetPattern '^Codex\.Provider\.Sync_[0-9][0-9A-Za-z.\-]*_x64-setup\.exe$' -Token $SourceGitHubToken -AuthenticatedDownload }
    },
    @{
        Key = 'skills-bundle'
        ManifestPath = $null
        ExistingAssetPattern = '^skills\.zip$'
        CompareContentOnSameName = $true
        Resolve = {
            $modelToken = if ([string]::IsNullOrWhiteSpace($Model00000Token)) { $SourceGitHubToken } else { $Model00000Token }
            if ([string]::IsNullOrWhiteSpace($modelToken)) {
                throw 'MODEL_00000_TOKEN or SOURCE_GITHUB_TOKEN is required to mirror indieark/00000-model skills bundle.'
            }

            Get-GitHubInstaller `
                -SourceRepo 'indieark/00000-model' `
                -AssetPattern '^(?:bundle|skills)_[0-9][0-9A-Za-z.\-]*\.zip$' `
                -OutputName 'skills.zip' `
                -Token $modelToken `
                -AuthenticatedDownload
        }
    },
    @{
        Key = 'skills-manager'
        ManifestPath = 'fallback.releaseAsset'
        ExistingAssetPattern = '^skills-manager_[0-9][0-9A-Za-z.\-]*_x64_en-US\.msi$'
        Resolve = { Get-GitHubInstaller -SourceRepo 'xingkongliang/skills-manager' -AssetPattern '^skills-manager_[0-9][0-9A-Za-z.\-]*_x64_en-US\.msi$' }
    }
)

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestFullPath | ConvertFrom-Json
$readmeText = if (Test-Path -LiteralPath $readmeFullPath) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $readmeFullPath
}
else {
    $null
}
$release = Get-ReleaseByTag -Tag $ReleaseTag
$assets = @(Get-ReleaseAssets -Release $release)
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('bootstrap-assets-{0}' -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$manifestChanged = $false
$readmeChanged = $false
$updatedCount = 0

try {
    foreach ($item in $managedAssets) {
        Write-Step ('Checking {0}' -f $item['Key'])
        $desired = & $item['Resolve']
        $desiredName = $desired.Name
        $existingAssetPattern = [string]$item['ExistingAssetPattern']
        $existing = @($assets | Where-Object { $_.name -eq $desiredName } | Select-Object -First 1)
        $matchingOld = @($assets | Where-Object { $_.name -match $existingAssetPattern -and $_.name -ne $desiredName })
        $needsUpload = $existing.Count -eq 0

        $compareContentOnSameName = ($item.ContainsKey('CompareContentOnSameName') -and $item['CompareContentOnSameName'])
        if (-not $needsUpload -and $compareContentOnSameName -and ($desired.PSObject.Properties.Name -contains 'SourceAsset')) {
            $sameAsset = Test-SameReleaseAsset `
                -SourceAsset $desired.SourceAsset `
                -TargetAsset $existing[0] `
                -SourceDownloadUrl ([string]$desired.DownloadUrl) `
                -TargetDownloadUrl ([string]$existing[0].browser_download_url) `
                -TempDir $tempDir
            if (-not $sameAsset) {
                Write-Step ('Existing {0} has same name but different content.' -f $desiredName)
                Remove-ReleaseAsset -Asset $existing[0]
                $assets = @($assets | Where-Object { $_.id -ne $existing[0].id })
                $existing = @()
                $needsUpload = $true
            }
        }

        if ($needsUpload) {
            $downloadPath = Join-Path $tempDir $desiredName
            $downloadHeaders = if ($desired.PSObject.Properties.Name -contains 'DownloadHeaders') { $desired.DownloadHeaders } else { $null }
            Save-UrlToFile -Uri $desired.DownloadUrl -Path $downloadPath -Headers $downloadHeaders
            Upload-ReleaseAsset -Release $release -AssetPath $downloadPath -AssetName $desiredName
            $updatedCount++
        }
        else {
            Write-Step ('Release asset is current: {0}' -f $desiredName)
        }

        if ($needsUpload -or $existing.Count -gt 0) {
            foreach ($oldAsset in $matchingOld) {
                Remove-ReleaseAsset -Asset $oldAsset
            }
        }

        if ($item.ContainsKey('ManifestPath') -and -not [string]::IsNullOrWhiteSpace([string]$item['ManifestPath'])) {
            $manifestChanged = (Set-ManifestAssetName -Manifest $manifest -Key $item['Key'] -PropertyPath $item['ManifestPath'] -AssetName $desiredName) -or $manifestChanged
        }
        $readmeChanged = (Set-ReadmeAssetName -ReadmeText ([ref]$readmeText) -AssetPattern $existingAssetPattern -AssetName $desiredName) -or $readmeChanged
    }
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($manifestChanged) {
    if ($DryRun) {
        Write-Step 'Dry run: manifest would be updated.'
    }
    else {
        $json = $manifest | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($manifestFullPath, ($json + [Environment]::NewLine), $utf8NoBom)
        Write-Step ('Updated manifest: {0}' -f $manifestFullPath)
    }
}

if ($readmeChanged) {
    if ($DryRun) {
        Write-Step 'Dry run: README would be updated.'
    }
    else {
        [System.IO.File]::WriteAllText($readmeFullPath, $readmeText, $utf8NoBom)
        Write-Step ('Updated README: {0}' -f $readmeFullPath)
    }
}

Write-Step ('Finished. Uploaded or replaced assets: {0}; manifest changed: {1}; README changed: {2}' -f $updatedCount, $manifestChanged, $readmeChanged)

