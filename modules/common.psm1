Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:OperationProgressLineActive = $false
$script:OperationProgressLastLineLength = 0

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if ($script:OperationProgressLineActive) {
        Write-Host ''
        $script:OperationProgressLineActive = $false
        $script:OperationProgressLastLineLength = 0
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $levelText = switch ($Level) {
        'INFO' { ConvertFrom-Utf8Base64String -Value '5L+h5oGv' }
        'WARN' { ConvertFrom-Utf8Base64String -Value '6K2m5ZGK' }
        'ERROR' { ConvertFrom-Utf8Base64String -Value '6ZSZ6K+v' }
        default { $Level }
    }
    Write-Host ('[{0}] [{1}] {2}' -f $timestamp, $levelText, $Message)
}

function Test-ConsoleProgressRendering {
    try {
        return ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected)
    }
    catch {
        return $false
    }
}

function Write-OperationProgress {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [Nullable[int]]$Percent,
        [string]$Detail,
        [switch]$Completed
    )

    $barWidth = 20
    $canRenderInPlace = Test-ConsoleProgressRendering
    if ($Completed) {
        $percentValue = 100
    }
    elseif ($null -ne $Percent) {
        $percentValue = [Math]::Min(100, [Math]::Max(0, [int]$Percent))
    }
    else {
        $percentValue = 0
    }

    $suffix = if ([string]::IsNullOrWhiteSpace($Detail)) { '' } else { '  {0}' -f $Detail }
    function Format-OperationProgressLine {
        param([string]$Text)

        if (-not $canRenderInPlace) {
            return $Text
        }

        $clearLength = [Math]::Max(0, $script:OperationProgressLastLineLength - $Text.Length)
        $script:OperationProgressLastLineLength = $Text.Length
        if ($clearLength -gt 0) {
            return $Text + (' ' * $clearLength)
        }

        return $Text
    }

    if ($null -eq $Percent -and -not $Completed) {
        if (-not $canRenderInPlace) {
            return
        }

        $line = Format-OperationProgressLine -Text ('  {0} {1}{2}' -f $Label, (ConvertFrom-Utf8Base64String -Value '6L+Q6KGM5Lit'), $suffix)
        Write-Host ("`r{0}" -f $line) -ForegroundColor Cyan -NoNewline
        $script:OperationProgressLineActive = $true
        return
    }

    $filled = if ($null -ne $Percent -or $Completed) {
        [Math]::Min($barWidth, [Math]::Max(0, [int][Math]::Round(($percentValue / 100) * $barWidth)))
    }
    else {
        0
    }
    $empty = $barWidth - $filled
    $filledChar = [char]0x2588
    $emptyChar = [char]0x2591
    $bar = (([string]$filledChar) * $filled) + (([string]$emptyChar) * $empty)
    $percentText = if ($null -ne $Percent -or $Completed) { '{0,3}%' -f $percentValue } else { ConvertFrom-Utf8Base64String -Value '6L+Q6KGM5Lit' }

    $line = Format-OperationProgressLine -Text ('  {0} {1} {2}{3}' -f $Label, $bar, $percentText, $suffix)
    if (-not $canRenderInPlace) {
        if ($Completed) {
            Write-Host $line -ForegroundColor Cyan
        }
        return
    }

    if ($Completed) {
        Write-Host ("`r{0}" -f $line) -ForegroundColor Cyan
        $script:OperationProgressLineActive = $false
        $script:OperationProgressLastLineLength = 0
    }
    else {
        Write-Host ("`r{0}" -f $line) -ForegroundColor Cyan -NoNewline
        $script:OperationProgressLineActive = $true
    }
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
            $items = @(
                $value |
                ForEach-Object {
                    if ($null -ne $_) {
                        [string]$_
                    }
                } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
            if ($items.Count -eq 0) {
                continue
            }

            $tokens.Add($name)
            $tokens.Add(('"{0}"' -f ($items -join ',')))
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
        throw ((ConvertFrom-Utf8Base64String -Value '5om+5LiN5Yiw5a6J6KOF5riF5Y2V77yaezB9') -f $ManifestPath)
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
        ForEach-Object { Split-DelimitedSelectionText -Value $_ } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.ToLowerInvariant() }
    )
    $selected = @($Apps | Where-Object { $lookup -contains $_.key.ToLowerInvariant() })

    if ($selected.Count -eq 0) {
        throw ((ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5Yy56YWN5Yiw5bqU55SoIGtlee+8mnswfQ==') -f ($Only -join ', '))
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

function Get-UserRoamingAppDataDirectory {
    $homeDir = Get-UserHomeDirectory
    if (-not [string]::IsNullOrWhiteSpace($homeDir)) {
        return (Join-Path $homeDir 'AppData\Roaming')
    }

    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        return $env:APPDATA
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
        throw (ConvertFrom-Utf8Base64String -Value '5pyq5om+5YiwIEQ6IOaIliBDOiDnm5g=')
    }

    $workspaceRoot = Join-Path $driveRoot 'Vibe Coding'
    $chatPath = Join-Path $workspaceRoot 'Chat'

    if ($DryRun) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5Yib5bu6IENvZGV4IOW3peS9nOWMuuebruW9le+8mnswfQ==') -f $chatPath)
        return [pscustomobject]@{
            Name   = (ConvertFrom-Utf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
            Key    = 'codex-workspace'
            Status = 'ok'
            Source = 'filesystem'
            Detail = $chatPath
        }
    }

    if (Test-Path -LiteralPath $chatPath -PathType Container) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy655uu5b2V5bey5a2Y5Zyo77yM6Lez6L+H5Yib5bu677yaezB9') -f $chatPath)
    }
    else {
        Initialize-Directory -Path $workspaceRoot
        Initialize-Directory -Path $chatPath
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bey5Yib5bu6IENvZGV4IOW3peS9nOWMuuebruW9le+8mnswfQ==') -f $chatPath)
    }

    return [pscustomobject]@{
        Name   = (ConvertFrom-Utf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
        Key    = 'codex-workspace'
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
        'Accept'     = 'application/vnd.github+json'
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5p+l6K+iIEdpdEh1YiDmnIDmlrAgUmVsZWFzZe+8mnswfQ==') -f $Repo)
    $release = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw ((ConvertFrom-Utf8Base64String -Value '5LuT5bqTIHswfSDmsqHmnInmj5DkvpvljLnphY3otYTkuqfvvJp7MX0=') -f $Repo, $AssetPattern)
    }

    return [pscustomobject]@{
        Repo    = $Repo
        Version = $release.tag_name
        Name    = $asset.name
        Url     = $asset.browser_download_url
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
            throw ((ConvertFrom-Utf8Base64String -Value 'R2l0SHViIGxhdGVzdCDot7PovazmsqHmnInov5Tlm54gTG9jYXRpb24gaGVhZGVy77yaezB9') -f $Repo)
        }

        $match = [regex]::Match($location, '/tag/(?<tag>[^/]+)$')
        if (-not $match.Success) {
            throw ((ConvertFrom-Utf8Base64String -Value '5peg5rOV5LuO6Lez6L2s5Zyw5Z2A6Kej5p6QIGxhdGVzdCB0YWfvvJp7MH0=') -f $location)
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
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5LiL6L29IHswfSAtPiB7MX0=') -f $Url, $DestinationPath)
        return $DestinationPath
    }

    Initialize-Directory -Path (Split-Path -Parent $DestinationPath)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5LiL6L29IHswfQ==') -f $Url)
    $response = $null
    $inputStream = $null
    $outputStream = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.AllowAutoRedirect = $true
        $request.UserAgent = 'VibeCodingSetup/1.0'
        $response = $request.GetResponse()
        $totalBytes = [int64]$response.ContentLength
        $inputStream = $response.GetResponseStream()
        $outputStream = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $buffer = New-Object byte[] 1048576
        $readBytes = 0
        $downloadedBytes = [int64]0
        $lastProgressPercent = -1

        do {
            $readBytes = $inputStream.Read($buffer, 0, $buffer.Length)
            if ($readBytes -gt 0) {
                $outputStream.Write($buffer, 0, $readBytes)
                $downloadedBytes += $readBytes

                if ($totalBytes -gt 0) {
                    $progressPercent = [int](($downloadedBytes * 100) / $totalBytes)
                    if ($progressPercent -ge 100 -or $progressPercent -ge ($lastProgressPercent + 5)) {
                        Write-OperationProgress -Label (ConvertFrom-Utf8Base64String -Value '5LiL6L29') -Percent $progressPercent -Detail (Split-Path -Leaf $DestinationPath)
                        $lastProgressPercent = $progressPercent
                    }
                }
            }
        } while ($readBytes -gt 0)

        Write-OperationProgress -Label (ConvertFrom-Utf8Base64String -Value '5LiL6L29') -Percent 100 -Detail (Split-Path -Leaf $DestinationPath) -Completed
    }
    finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
    }
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

function ConvertTo-WingetByteCount {
    param(
        [Parameter(Mandatory)]
        [string]$Value,
        [Parameter(Mandatory)]
        [string]$Unit
    )

    $number = 0.0
    if (-not [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return 0
    }

    switch -Regex ($Unit.ToUpperInvariant()) {
        '^B$' { return [int64]$number }
        '^KB$' { return [int64]($number * 1KB) }
        '^MB$' { return [int64]($number * 1MB) }
        '^GB$' { return [int64]($number * 1GB) }
        default { return [int64]$number }
    }
}

function Get-WingetProgressInfo {
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($Line -match '(?<percent>\d{1,3})%' -and $Line -notmatch '[A-Za-z]') {
        return [pscustomobject]@{
            Percent = [int]$Matches['percent']
            Detail  = $null
        }
    }

    if ($Line -match '(?<done>\d+(?:\.\d+)?)\s*(?<doneUnit>B|KB|MB|GB)\s*/\s*(?<total>\d+(?:\.\d+)?)\s*(?<totalUnit>B|KB|MB|GB)') {
        $doneBytes = ConvertTo-WingetByteCount -Value $Matches['done'] -Unit $Matches['doneUnit']
        $totalBytes = ConvertTo-WingetByteCount -Value $Matches['total'] -Unit $Matches['totalUnit']
        if ($totalBytes -gt 0) {
            return [pscustomobject]@{
                Percent = [Math]::Min(100, [Math]::Max(0, [int](($doneBytes * 100) / $totalBytes)))
                Detail  = ('{0} {1} / {2}' -f (ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5LiL6L29'), ('{0} {1}' -f $Matches['done'], $Matches['doneUnit']), ('{0} {1}' -f $Matches['total'], $Matches['totalUnit']))
            }
        }
    }

    return $null
}

function ConvertTo-WingetChineseMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($Line -match 'Found an existing package already installed\. Trying to upgrade') {
        return ConvertFrom-Utf8Base64String -Value '5bey5qOA5rWL5Yiw5bey5a6J6KOF54mI5pys77yM5bCG5bCd6K+V5pu05paw'
    }

    if ($Line -match '^Found (?<found>.+)$') {
        $foundText = $Matches['found'] -replace '\s+\[[^\]]+\]\s+Version\s+', ' ' -replace '\s+Version\s+', ' '
        return (ConvertFrom-Utf8Base64String -Value '5bey5om+5Yiw5YyF77yaezB9') -f $foundText.Trim()
    }

    if ($Line -match 'Successfully verified installer hash') {
        return ConvertFrom-Utf8Base64String -Value '5bey6aqM6K+B5a6J6KOF5YyF5ZOI5biM'
    }

    if ($Line -match 'Starting package install') {
        return ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5ZCv5Yqo5a6J6KOF56iL5bqP'
    }

    if ($Line -match 'Installing|Starting|Downloading') {
        return ConvertFrom-Utf8Base64String -Value '5a6J6KOF56iL5bqP6L+Q6KGM5Lit'
    }

    if ($Line -match 'Successfully installed|Installation successful') {
        return ConvertFrom-Utf8Base64String -Value '5a6J6KOF5a6M5oiQ'
    }

    return $null
}

function Test-WingetNoiseLine {
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )

    if ($Line -match '^\d{1,3}%$' -or $Line -notmatch '[A-Za-z0-9]') {
        return $true
    }

    if ($Line -match '^(Category|Pricing|Free Trial|Terms of Transaction|Seizure Warning|Store License Terms|Publisher|Publisher Url|Publisher Support Url|License|Privacy Url|Copyright|Agreements|Installer|Installer Type|Store Product Id|Offline Distribution Supported)\s*:') {
        return $true
    }

    if ($Line -match 'This application is licensed to you by its owner') {
        return $true
    }

    if ($Line -match 'Microsoft is not responsible for') {
        return $true
    }

    if ($Line -match 'Microsoft Store' -and $Line -notmatch '(?i)install|upgrade|found|available') {
        return $true
    }

    if ($Line -match 'https?://') {
        return $true
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
        [ref]$Emitted,
        [string]$Action,
        [string]$PackageId
    )

    foreach ($line in $Lines) {
        $normalizedLine = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($normalizedLine)) {
            continue
        }

        $progress = Get-WingetProgressInfo -Line $normalizedLine
        if ($null -ne $progress) {
            $progressPercent = [int]$progress.Percent
            $progressDetail = [string]$progress.Detail
            $progressKey = 'progress:{0}:{1}' -f $progressPercent, $progressDetail
            if ($progressKey -eq [string]$LastLine.Value -and $progressPercent -eq [int]$LastProgressPercent.Value) {
                continue
            }

            Write-OperationProgress -Label 'winget' -Percent $progressPercent -Detail $progressDetail
            $LastProgressPercent.Value = $progressPercent
            $LastLine.Value = $progressKey
            $Emitted.Value = $true
            continue
        }

        if (Test-WingetNoiseLine -Line $normalizedLine) {
            $Emitted.Value = $true
            continue
        }

        $message = ConvertTo-WingetChineseMessage -Line $normalizedLine
        if ([string]::IsNullOrWhiteSpace($message)) {
            if ($normalizedLine -match '(?i)error|failed|failure|denied|not found|cannot|requires') {
                $message = (ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IOmUmeivr++8mnswfQ==') -f $normalizedLine
            }
            else {
                $Emitted.Value = $true
                continue
            }
        }

        if ($message -eq [string]$LastLine.Value) {
            continue
        }

        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V077yaezB9') -f $message)
        $LastLine.Value = $message
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
        throw (ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IOS4jeWPr+eUqA==')
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
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10gd2luZ2V0IHswfSB7MX0=') -f $Action, $PackageId)
        return
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5omn6KGMIHdpbmdldCB7MH3vvJp7MX0=') -f $Action, $PackageId)
    if ($Source -eq 'msstore') {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo6YCa6L+HIHdpbmdldCB7MH0gTWljcm9zb2Z0IFN0b3JlIOWMhSB7MX3vvIxTdG9yZSDop6PmnpDmnJ/pl7Tlj6/og73mmoLml7bmsqHmnInov5vluqbovpPlh7o=') -f $Action, $PackageId)
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
    $sawSuccessfulInstallOutput = $false
    $successSeenAt = $null
    $exitCode = $null

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
                if (($Action -eq 'install') -and (-not $sawSuccessfulInstallOutput) -and @($lines | Where-Object { $_ -match 'Successfully installed|Installation successful' }).Count -gt 0) {
                    $sawSuccessfulInstallOutput = $true
                    $successSeenAt = Get-Date
                }
                Write-WingetOutputLines -Lines $lines -LastLine ([ref]$lastWingetLine) -LastProgressPercent ([ref]$lastWingetProgressPercent) -Emitted ([ref]$sawOutput) -Action $Action -PackageId $PackageId
            }

            if ($sawOutput) {
                $lastHeartbeat = Get-Date
            }
            elseif (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 15) {
                Write-OperationProgress -Label 'winget' -Percent $null -Detail ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHswfSB7MX0g5LuN5Zyo6L+Q6KGMLi4u') -f $Action, $PackageId)
                $lastHeartbeat = Get-Date
            }

            if ($sawSuccessfulInstallOutput -and $null -ne $successSeenAt -and (-not $process.HasExited) -and ((Get-Date) - $successSeenAt).TotalSeconds -ge 20) {
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IOW3suaKpeWRiuWujOaIkOS9hui/m+eoi+acqumAgOWHuu+8jOato+WcqOaUtuWwvu+8mnswfQ==') -f $PackageId)
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                $exitCode = 0
                break
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
            Write-WingetOutputLines -Lines $lines -LastLine ([ref]$lastWingetLine) -LastProgressPercent ([ref]$lastWingetProgressPercent) -Emitted ([ref]$emittedFinal) -Action $Action -PackageId $PackageId
        }

        $stdoutText = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
        $stderrText = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
        $combinedOutput = @($stdoutText, $stderrText) -join "`n"
        if ($null -eq $exitCode) {
            $process.WaitForExit()
            $exitCode = $process.ExitCode
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($exitCode -ne 0) {
        if (Test-WingetNoApplicableUpgradeOutput -OutputText $combinedOutput) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHswfSDmiqXlkYogezF9IOayoeacieWPr+eUqOabtOaWsO+8jOaMieW3suaYr+acgOaWsOWkhOeQhg==') -f $Action, $PackageId)
            return
        }

        if ($Action -eq 'upgrade') {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHVwZ3JhZGUgezB9IOi/lOWbniB7MX3vvIznu6fnu63lkI7nu63mtYHnqIs=') -f $PackageId, $exitCode)
            return
        }
        $exitText = if ($null -eq $exitCode) { 'unknown' } else { [string]$exitCode }
        throw ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHswfSB7MX0g5aSx6LSl77yM6YCA5Ye656CBPXsyfQ==') -f $Action, $PackageId, $exitText)
    }

    Reset-InstallDetectionState
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHswfSDlt7LlrozmiJDvvJp7MX0=') -f $Action, $PackageId)
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
            Found   = $false
            Version = $null
            Source  = 'registry'
            Detail  = $displayName
        }
    }

    $selected = Select-BestVersionRecord -Records $matched -VersionSelector { param($entry) $entry.DisplayVersion }
    return [pscustomobject]@{
        Found   = $true
        Version = $selected.DisplayVersion
        Source  = 'registry'
        Detail  = $selected.DisplayName
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
            Found   = $false
            Version = $null
            Source  = 'appx'
            Detail  = $appxName
        }
    }

    $selected = $packages | Sort-Object Version -Descending | Select-Object -First 1
    return [pscustomobject]@{
        Found   = $true
        Version = $selected.Version.ToString()
        Source  = 'appx'
        Detail  = $selected.Name
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
            args    = @((Get-ObjectPropertyValue -Object $DetectConfig -Name 'args' -Default @()))
            regex   = [string](Get-ObjectPropertyValue -Object $DetectConfig -Name 'regex')
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
                Found   = $false
                Version = $null
                Source  = 'command'
                Detail  = $commandName
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
                Found   = $false
                Version = $null
                Source  = 'command'
                Detail  = (ConvertFrom-Utf8Base64String -Value 'ezB9IOiwg+eUqOWksei0pe+8mnsxfQ==') -f $commandName, $_.Exception.Message
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
            Found   = $true
            Version = $version
            Source  = 'command'
            Detail  = $commandName
        }
    }

    if ($null -ne $lastFailure) {
        return $lastFailure
    }

    return [pscustomobject]@{
        Found   = $false
        Version = $null
        Source  = 'command'
        Detail  = $primaryCommandName
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
            Found   = $false
            Version = $null
            Source  = 'none'
            Detail  = (ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5qOA5rWL6KeE5YiZ')
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
        Found   = $false
        Version = $null
        Source  = 'none'
        Detail  = (ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5qOA5rWL6KeE5YiZ')
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
            Found   = $true
            Version = [string]$explicitTarget
            Source  = 'manifest'
        }
    }

    switch ($Definition.strategy) {
        'winget' {
            $wingetSource = [string](Get-ObjectPropertyValue -Object $Definition -Name 'wingetSource')
            $version = Get-WingetPackageLatestVersion -PackageId $Definition.wingetId -Source $wingetSource
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return [pscustomobject]@{
                    Found   = $true
                    Version = $version
                    Source  = 'winget-show'
                }
            }

            $fallbackVersion = Get-FallbackReleaseAssetVersion -Definition $Definition
            if (-not [string]::IsNullOrWhiteSpace($fallbackVersion)) {
                return [pscustomobject]@{
                    Found   = $true
                    Version = $fallbackVersion
                    Source  = 'fallback-release-asset'
                }
            }
        }
        'github-latest-tag' {
            $tag = Get-GitHubLatestTagViaRedirect -Repo $Definition.repo
            if (-not [string]::IsNullOrWhiteSpace($tag)) {
                return [pscustomobject]@{
                    Found   = $true
                    Version = $tag.TrimStart('v')
                    Source  = 'github-latest-tag'
                }
            }
        }
        'release-asset' {
            $assetName = [string](Get-ObjectPropertyValue -Object $Definition -Name 'assetName')
            $version = Get-NormalizedVersionString -VersionText $assetName
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                return [pscustomobject]@{
                    Found   = $true
                    Version = $version
                    Source  = 'release-asset-name'
                }
            }
        }
    }

    return [pscustomobject]@{
        Found   = $false
        Version = $null
        Source  = 'unknown'
    }
}

function Get-AppInstallDecision {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition
    )

    $installed = Get-InstalledAppVersion -Definition $Definition
    $installIfMissingOnly = [bool](Get-ObjectPropertyValue -Object $Definition -Name 'installIfMissingOnly' -Default $false)

    if (-not $installed.Found) {
        return [pscustomobject]@{
            Action           = 'install'
            Reason           = 'missing'
            InstalledVersion = $null
            DesiredVersion   = $null
            Detail           = (ConvertFrom-Utf8Base64String -Value '5pyq5a6J6KOF')
        }
    }

    if ($installIfMissingOnly) {
        return [pscustomobject]@{
            Action           = 'skip'
            Reason           = 'present'
            InstalledVersion = $installed.Version
            DesiredVersion   = $null
            Detail           = (ConvertFrom-Utf8Base64String -Value '5bey5qOA5rWL5Yiw5bqU55So77yM5LiU5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5')
        }
    }

    $desired = Get-DesiredAppVersion -Definition $Definition

    if ([string]::IsNullOrWhiteSpace([string]$installed.Version)) {
        return [pscustomobject]@{
            Action           = 'install'
            Reason           = 'unknown-installed-version'
            InstalledVersion = $null
            DesiredVersion   = $desired.Version
            Detail           = (ConvertFrom-Utf8Base64String -Value '5peg5rOV56Gu5a6a5bey5a6J6KOF54mI5pys')
        }
    }

    if (-not $desired.Found -or [string]::IsNullOrWhiteSpace([string]$desired.Version)) {
        return [pscustomobject]@{
            Action           = 'install'
            Reason           = 'unknown-target-version'
            InstalledVersion = $installed.Version
            DesiredVersion   = $null
            Detail           = (ConvertFrom-Utf8Base64String -Value '5bey5qOA5rWL5Yiw5a6J6KOF54mI5pys77yM5L2G55uu5qCH54mI5pys5LiN5Y+v5q+U6L6D')
        }
    }

    $comparison = Compare-VersionStrings -LeftVersion $installed.Version -RightVersion $desired.Version
    if ($null -eq $comparison) {
        return [pscustomobject]@{
            Action           = 'install'
            Reason           = 'non-comparable'
            InstalledVersion = $installed.Version
            DesiredVersion   = $desired.Version
            Detail           = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5ZKM55uu5qCH54mI5pys5LiN5Y+v5q+U6L6D')
        }
    }

    if ($comparison -ge 0) {
        return [pscustomobject]@{
            Action           = 'skip'
            Reason           = 'current'
            InstalledVersion = $installed.Version
            DesiredVersion   = $desired.Version
            Detail           = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5Li65pyA5paw')
        }
    }

    return [pscustomobject]@{
        Action           = 'install'
        Reason           = 'outdated'
        InstalledVersion = $installed.Version
        DesiredVersion   = $desired.Version
        Detail           = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5L2O5LqO55uu5qCH54mI5pys')
    }
}

function Get-AppInstallDecisionBatch {
    param(
        [Parameter(Mandatory)]
        [object[]]$Definitions
    )

    $apps = @($Definitions | Where-Object { $null -ne $_ })
    if ($apps.Count -eq 0) {
        return @()
    }

    $modulePath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($modulePath) -and $MyInvocation.MyCommand.Module) {
        $modulePath = $MyInvocation.MyCommand.Module.Path
    }
    if ([string]::IsNullOrWhiteSpace($modulePath) -or -not (Test-Path -LiteralPath $modulePath)) {
        return @(
            $apps |
            ForEach-Object {
                $decision = Get-AppInstallDecision -Definition $_
                [pscustomobject]@{
                    Key      = $_.key
                    Name     = $_.name
                    Order    = [int]$_.order
                    Status   = 'ok'
                    Decision = $decision
                    Error    = $null
                }
            }
        )
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5bm26KGM5qOA5p+l5bqU55So5a6J6KOF54q25oCB77yaezB9IOS4qg==') -f $apps.Count)
    $jobs = New-Object System.Collections.Generic.List[object]
    foreach ($app in $apps) {
        $definitionJson = $app | ConvertTo-Json -Depth 16 -Compress
        $job = Start-Job -Name ('vcs-precheck-{0}' -f $app.key) -ScriptBlock {
            param(
                [Parameter(Mandatory)]
                [string]$ModulePath,
                [Parameter(Mandatory)]
                [string]$DefinitionJson
            )

            $ProgressPreference = 'SilentlyContinue'
            Import-Module $ModulePath -Force
            $definition = $DefinitionJson | ConvertFrom-Json
            try {
                $decision = Get-AppInstallDecision -Definition $definition
                [pscustomobject]@{
                    Key      = $definition.key
                    Name     = $definition.name
                    Order    = [int]$definition.order
                    Status   = 'ok'
                    Decision = $decision
                    Error    = $null
                }
            }
            catch {
                [pscustomobject]@{
                    Key      = $definition.key
                    Name     = $definition.name
                    Order    = [int]$definition.order
                    Status   = 'failed'
                    Decision = $null
                    Error    = $_.Exception.Message
                }
            }
        } -ArgumentList $modulePath, $definitionJson
        $jobs.Add($job)
    }

    try {
        $reportedCompleted = 0
        while ($true) {
            $completedCount = @($jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }).Count
            if ($completedCount -gt $reportedCompleted) {
                $progressPercent = if ($jobs.Count -gt 0) { [int](($completedCount * 100) / $jobs.Count) } else { 100 }
                $progressDetail = (ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKrlupTnlKjlt7LlrozmiJA=') -f $completedCount, $jobs.Count
                Write-OperationProgress -Label (ConvertFrom-Utf8Base64String -Value '5qOA5p+l') -Percent $progressPercent -Detail $progressDetail -Completed:($completedCount -ge $jobs.Count)
                $reportedCompleted = $completedCount
            }
            if ($completedCount -ge $jobs.Count) {
                break
            }
            $runningJobs = @($jobs | Where-Object { $_.State -eq 'Running' })
            if ($runningJobs.Count -gt 0) {
                Wait-Job -Job $runningJobs -Any -Timeout 1 | Out-Null
            }
            else {
                Start-Sleep -Milliseconds 200
            }
        }
        $results = @(
            foreach ($job in $jobs) {
                Receive-Job -Job $job
            }
        )
    }
    finally {
        foreach ($job in $jobs) {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }

    $failedCount = @($results | Where-Object { $_.Status -eq 'failed' }).Count
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+l5a6M5oiQ77yaezB9IOS4quaIkOWKn++8jHsxfSDkuKrlpLHotKU=') -f ($results.Count - $failedCount), $failedCount)
    return @($results | Sort-Object Order)
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
                    Recovered        = $true
                    InstalledVersion = $installed.Version
                    Detail           = (ConvertFrom-Utf8Base64String -Value '5Li75a6J6KOF5Zmo6L+U5Zue6ZSZ6K+v5ZCO77yM5bqU55So5bey5Y+v5qOA5rWL')
                }
            }

            $postDecision = Get-AppInstallDecision -Definition $Definition
            if ($postDecision.Action -eq 'skip') {
                return [pscustomobject]@{
                    Recovered        = $true
                    InstalledVersion = $postDecision.InstalledVersion
                    Detail           = $postDecision.Detail
                }
            }
        }

        if ($attempt -lt ($Attempts - 1)) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    return [pscustomobject]@{
        Recovered        = $false
        InstalledVersion = $null
        Detail           = (ConvertFrom-Utf8Base64String -Value '5aSN5p+l5ZCO5LuN5peg5rOV56Gu6K6k5bqU55So5bey5a6J6KOF')
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

    Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'ezB9IOi3r+W+hOWkhOeQhiB7MX0g5pe25Ye66ZSZ77yaezJ9') -f $PrimarySource, $Definition.name, $ErrorRecord.Exception.Message)
    if (-not $DryRun) {
        $recovered = Test-InstallRecoveredAfterPrimaryFailure -Definition $Definition -InitialDecision $InitialDecision
        if ($recovered.Recovered) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'ezB9IOWcqOWksei0peWQjuWkjeafpeaXtueci+i1t+adpeW3suWuieijhe+8jOi3s+i/hyB7MX0gZmFsbGJhY2s=') -f $Definition.name, $PrimarySource)
            return [pscustomobject]@{
                Name   = $Definition.name
                Key    = $Definition.key
                Status = 'ok'
                Source = '{0}-postcheck' -f $PrimarySource
                Detail = if ([string]::IsNullOrWhiteSpace([string]$recovered.InstalledVersion)) { $recovered.Detail } else { '{0} ({1})' -f $recovered.Detail, $recovered.InstalledVersion }
            }
        }
    }

    Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5Li76Lev5b6E5aSx6LSl77yM5pS555SoIHJlbGVhc2Ug5oiW5pys5Zyw5a6J6KOF5YyF77yaezB9IC8gezF9') -f $PrimarySource, $Definition.name)
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
        throw ((ConvertFrom-Utf8Base64String -Value '5a6J6KOF5YyF5LiN5a2Y5Zyo77yaezB9') -f $PackagePath)
    }

    function Wait-InstallerProcessWithProgress {
        param(
            [Parameter(Mandatory)]
            [System.Diagnostics.Process]$Process,
            [Parameter(Mandatory)]
            [string]$Label,
            [Parameter(Mandatory)]
            [string]$PackageName
        )

        $startedAt = Get-Date
        do {
            if (-not $Process.HasExited) {
                $elapsedSeconds = [int]((Get-Date) - $startedAt).TotalSeconds
                Write-OperationProgress -Label $Label -Percent $null -Detail ('{0}{1}{2}s' -f $PackageName, (ConvertFrom-Utf8Base64String -Value '77yM5bey55SoIA=='), $elapsedSeconds)
                Start-Sleep -Seconds 5
                $Process.Refresh()
            }
        } while (-not $Process.HasExited)

        $Process.WaitForExit()
        Write-OperationProgress -Label $Label -Percent 100 -Detail $PackageName -Completed
    }

    switch ($InstallerType) {
        'msi' {
            $args = @('/i', $PackagePath, '/qn', '/norestart') + $SilentArgs
            $argumentLine = (($args | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' ')
            if ($DryRun) {
                Write-Log -Message ('[DryRun] msiexec.exe {0}' -f $argumentLine)
                return
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5a6J6KOFIE1TSe+8mnswfQ==') -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentLine -PassThru
            Wait-InstallerProcessWithProgress -Process $proc -Label 'MSI' -PackageName (Split-Path -Leaf $PackagePath)
            if ($proc.ExitCode -ne 0) {
                throw ((ConvertFrom-Utf8Base64String -Value 'TVNJIOWuieijheWksei0pe+8jOmAgOWHuueggT17MH0=') -f $proc.ExitCode)
            }

            Reset-InstallDetectionState
        }
        'exe' {
            $argumentLine = (($SilentArgs | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' ')
            if ($DryRun) {
                Write-Log -Message ('[DryRun] {0} {1}' -f $PackagePath, $argumentLine)
                return
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5a6J6KOFIEVYRe+8mnswfQ==') -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath $PackagePath -ArgumentList $argumentLine -PassThru
            Wait-InstallerProcessWithProgress -Process $proc -Label 'EXE' -PackageName (Split-Path -Leaf $PackagePath)
            if ($proc.ExitCode -ne 0) {
                throw ((ConvertFrom-Utf8Base64String -Value 'RVhFIOWuieijheWksei0pe+8jOmAgOWHuueggT17MH0=') -f $proc.ExitCode)
            }

            Reset-InstallDetectionState
        }
        'msix' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] Add-AppxPackage {0}' -f $PackagePath)
                return
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5a6J6KOFIE1TSVjvvJp7MH0=') -f (Split-Path -Leaf $PackagePath))
            Add-AppxPackage -Path $PackagePath
            Reset-InstallDetectionState
        }
        'uri' {
            if ($DryRun) {
                Write-Log -Message ('[DryRun] Start-Process {0}' -f $PackagePath)
                return
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5omT5byA5a6J6KOFIFVSSe+8mnswfQ==') -f $PackagePath)
            Start-Process -FilePath $PackagePath | Out-Null
        }
        default {
            throw ((ConvertFrom-Utf8Base64String -Value '5LiN5pSv5oyB55qEIGluc3RhbGxlclR5cGXvvJp7MH0=') -f $InstallerType)
        }
    }
}

function Install-AppFromDefinition {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Definition,
        [Parameter(Mandatory)]
        [string]$WorkspaceRoot,
        [pscustomobject]$InstallDecision,
        [switch]$DryRun
    )

    $downloadsRoot = Join-Path $WorkspaceRoot 'downloads'
    Initialize-Directory -Path $downloadsRoot
    $decision = if ($null -ne $InstallDecision) { $InstallDecision } else { Get-AppInstallDecision -Definition $Definition }

    switch ($decision.Reason) {
        'missing' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muacquWuieijhe+8jOWwhuaJp+ihjOWuieijhQ==') -f $Definition.name)
        }
        'outdated' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW3suWuieijhSB7MX3vvIznm67moIcgezJ977yM5bCG5pu05paw') -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
        'current' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW3suWuieijhSB7MX3vvIznm67moIcgezJ977yM6Lez6L+H') -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
        'present' {
            if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) {
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muajgOa1i+WIsOW3suWuieijhe+8jOS4lOWQr+eUqCBpbnN0YWxsSWZNaXNzaW5nT25see+8jOi3s+i/hw==') -f $Definition.name)
            }
            else {
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW3suWuieijhSB7MX3vvIzkuJTlkK/nlKggaW5zdGFsbElmTWlzc2luZ09ubHnvvIzot7Pov4c=') -f $Definition.name, $decision.InstalledVersion)
            }
        }
        'unknown-target-version' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW3suWuieijhSB7MX3vvIznm67moIfniYjmnKzkuI3lj6/nlKjvvIzkuqTnu5nlronoo4XmnaXmupDlpITnkIY=') -f $Definition.name, $decision.InstalledVersion)
        }
        'unknown-installed-version' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW6lOeUqOWtmOWcqOS9huW3suWuieijheeJiOacrOacquefpe+8jOWwhumHjeaWsOWuieijheaIluabtOaWsA==') -f $Definition.name)
        }
        'non-comparable' {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6aKE5qOA5p+lIHswfe+8muW3suWuieijhSB7MX3vvIznm67moIcgezJ977yM54mI5pys5LiN5Y+v5q+U6L6D77yM5bCG6YeN5paw5a6J6KOF5oiW5pu05paw') -f $Definition.name, $decision.InstalledVersion, $decision.DesiredVersion)
        }
    }

    if ($decision.Action -eq 'skip') {
        $skipDetail = if ($decision.Reason -eq 'present') {
            if ([string]::IsNullOrWhiteSpace([string]$decision.InstalledVersion)) {
                ConvertFrom-Utf8Base64String -Value '5qOA5rWL5Yiw5bey5a6J6KOF77yb5bey5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5'
            }
            else {
                (ConvertFrom-Utf8Base64String -Value '5qOA5rWL5Yiw5bey5a6J6KOF77yIezB977yJ77yb5bey5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5') -f $decision.InstalledVersion
            }
        }
        else {
            '{0} >= {1}' -f $decision.InstalledVersion, $decision.DesiredVersion
        }

        return [pscustomobject]@{
            Name   = $Definition.name
            Key    = $Definition.key
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
                    Name   = $Definition.name
                    Key    = $Definition.key
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
                    Name   = $Definition.name
                    Key    = $Definition.key
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
                    Name   = $Definition.name
                    Key    = $Definition.key
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
                    Name   = $Definition.name
                    Key    = $Definition.key
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
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo6YCa6L+H6Lez6L2s6Kej5p6QIEdpdEh1YiDmnIDmlrAgdGFn77yaezB9') -f $Definition.repo)
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
                    Name   = $Definition.name
                    Key    = $Definition.key
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
            throw ((ConvertFrom-Utf8Base64String -Value '5LiN5pSv5oyB55qE5a6J6KOF562W55Wl77yaezB9') -f $Definition.strategy)
        }
    }

    if (-not $Definition.fallback) {
        throw ((ConvertFrom-Utf8Base64String -Value 'ezB9IOayoeacieWPr+eUqCBmYWxsYmFjaw==') -f $Definition.name)
    }

    $fallbackWingetId = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'wingetId')
    if (-not [string]::IsNullOrWhiteSpace($fallbackWingetId)) {
        try {
            $fallbackWingetSource = [string](Get-ObjectPropertyValue -Object $Definition.fallback -Name 'wingetSource')
            Invoke-WingetAction -Action 'install' -PackageId $fallbackWingetId -Source $fallbackWingetSource -DryRun:$DryRun

            return [pscustomobject]@{
                Name   = $Definition.name
                Key    = $Definition.key
                Status = 'ok'
                Source = 'winget-fallback'
                Detail = if (-not [string]::IsNullOrWhiteSpace($fallbackWingetSource)) { '{0} ({1})' -f $fallbackWingetId, $fallbackWingetSource } else { $fallbackWingetId }
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IGZhbGxiYWNrIOWksei0pe+8mnswfQ==') -f $_.Exception.Message)
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
                Name   = $Definition.name
                Key    = $Definition.key
                Status = 'ok'
                Source = 'release-fallback'
                Detail = '{0}@{1}/{2}' -f $releaseRepo, $releaseTag, $assetName
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'UmVsZWFzZSBmYWxsYmFjayDlpLHotKXvvJp7MH0=') -f $_.Exception.Message)
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
                    Name   = $Definition.name
                    Key    = $Definition.key
                    Status = 'ok'
                    Source = 'uri-fallback'
                    Detail = [string]$fallbackUri
                }
            }
            catch {
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'VVJJIGZhbGxiYWNrIOWksei0pe+8mnswfQ==') -f $_.Exception.Message)
            }
        }
    }

    throw ((ConvertFrom-Utf8Base64String -Value 'ezB9IOWcqOe6v+adpea6kOWksei0peWQjuayoeacieWPr+eUqCBmYWxsYmFjayDlronoo4XljIU=') -f $Definition.name)
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

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        $effectivePrompt = $Prompt
        if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $effectivePrompt = '{0} [{1}]' -f $Prompt, $DefaultValue
        }

        $value = Read-Host $effectivePrompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }

        return $value.Trim()
    }

    return Read-HostWithInlineDefaultValue -Label $Prompt -DefaultValue $DefaultValue
}

function Write-ConsoleInputTail {
    param(
        [Parameter(Mandatory)]
        [int]$Left,
        [Parameter(Mandatory)]
        [int]$Top,
        [string]$Value,
        [string]$Placeholder,
        [int]$ClearLength
    )

    [Console]::SetCursorPosition($Left, $Top)
    $tailWidth = [Math]::Max(0, [Console]::BufferWidth - $Left - 1)
    if ($tailWidth -gt 0) {
        Write-Host (' ' * $tailWidth) -NoNewline
        [Console]::SetCursorPosition($Left, $Top)
    }

    if ([string]::IsNullOrEmpty($Value) -and -not [string]::IsNullOrWhiteSpace($Placeholder)) {
        Write-Host $Placeholder -ForegroundColor DarkGray -NoNewline
        [Console]::SetCursorPosition($Left, $Top)
        return $Placeholder.Length
    }

    if (-not [string]::IsNullOrEmpty($Value)) {
        Write-Host $Value -NoNewline
        return $Value.Length
    }

    return 0
}

function Read-HostWithInlineDefaultValue {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [string]$DefaultValue
    )

    try {
        Write-Host ('{0} : ' -f $Label) -NoNewline
        $inputLeft = [Console]::CursorLeft
        $inputTop = [Console]::CursorTop
        $placeholder = if ([string]::IsNullOrWhiteSpace($DefaultValue)) { '' } else { $DefaultValue }
        $buffer = New-Object System.Text.StringBuilder
        $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value '' -Placeholder $placeholder -ClearLength 0

        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Enter) {
                Write-Host ''
                if ($buffer.Length -eq 0) {
                    return $DefaultValue
                }

                return $buffer.ToString().Trim()
            }

            if (($key.Modifiers -band [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::C) {
                throw 'Interrupted by user.'
            }

            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($buffer.Length -gt 0) {
                    $buffer.Length = $buffer.Length - 1
                    $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value $buffer.ToString() -Placeholder $placeholder -ClearLength $renderLength
                }
                continue
            }

            if ($key.KeyChar -ne [char]0 -and -not [char]::IsControl($key.KeyChar)) {
                [void]$buffer.Append($key.KeyChar)
                $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value $buffer.ToString() -Placeholder $placeholder -ClearLength $renderLength
            }
        }
    }
    catch {
        if ($_.Exception.Message -eq 'Interrupted by user.') {
            throw
        }

        $value = Read-Host ('{0} [{1}]' -f $Label, $DefaultValue)
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }

        return $value.Trim()
    }
}

function Read-HostHiddenValue {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [string]$Placeholder
    )

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        $secureValue = Read-Host ('{0} ({1})' -f $Label, $Placeholder) -AsSecureString
        return ConvertFrom-SecureStringPlainText -SecureString $secureValue
    }

    try {
        Write-Host ('{0} : ' -f $Label) -NoNewline
        $inputLeft = [Console]::CursorLeft
        $inputTop = [Console]::CursorTop
        $buffer = New-Object System.Text.StringBuilder
        $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value '' -Placeholder $Placeholder -ClearLength 0

        while ($true) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Enter) {
                Write-Host ''
                return $buffer.ToString()
            }

            if (($key.Modifiers -band [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::C) {
                throw 'Interrupted by user.'
            }

            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($buffer.Length -gt 0) {
                    $buffer.Length = $buffer.Length - 1
                    $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value ('*' * $buffer.Length) -Placeholder $Placeholder -ClearLength $renderLength
                }
                continue
            }

            if ($key.KeyChar -ne [char]0 -and -not [char]::IsControl($key.KeyChar)) {
                [void]$buffer.Append($key.KeyChar)
                $renderLength = Write-ConsoleInputTail -Left $inputLeft -Top $inputTop -Value ('*' * $buffer.Length) -Placeholder $Placeholder -ClearLength $renderLength
            }
        }
    }
    catch {
        if ($_.Exception.Message -eq 'Interrupted by user.') {
            throw
        }

        $secureValue = Read-Host ('{0} ({1})' -f $Label, $Placeholder) -AsSecureString
        return ConvertFrom-SecureStringPlainText -SecureString $secureValue
    }
}

function Write-CodexProviderInputSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [string]$Detail
    )

    Write-Host ''
    Write-Host ('== {0} ==' -f $Title) -ForegroundColor Cyan
    Write-Host ('-' * 64) -ForegroundColor DarkGray
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        Write-Host ('  {0}' -f $Detail) -ForegroundColor DarkGray
        Write-Host ''
    }
}

function Write-CodexProviderInputLine {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string]$Value
    )

    Write-Host ('  {0}: {1}' -f $Label, $Value) -ForegroundColor DarkGray
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
            throw ((ConvertFrom-Utf8Base64String -Value '5omT5byAIENDIFN3aXRjaCDmlbDmja7lupPlpLHotKXvvJp7MH0=') -f $openError)
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
            throw ((ConvertFrom-Utf8Base64String -Value '5p+l6K+iIENDIFN3aXRjaCDmlbDmja7lupPlpLHotKXvvJp7MH0=') -f $prepareError)
        }

        $stepResult = [WinSqliteInterop]::sqlite3_step($stmt)
        if ($stepResult -ne $sqliteRow) {
            return $null
        }

        return [pscustomobject]@{
            Id   = [WinSqliteInterop]::PtrToStringUtf8([WinSqliteInterop]::sqlite3_column_text($stmt, 0))
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

    Write-CodexProviderInputSection `
        -Title (ConvertFrom-Utf8Base64String -Value '6L6T5YWl5Yy6') `
        -Detail (ConvertFrom-Utf8Base64String -Value '5Y+z5L6n54Gw6Imy5paH5a2X5piv5b2T5YmN6buY6K6k5YC877yb55u05o6l5Zue6L2m5L+d55WZ77yM6L6T5YWl5paw5YC85Lya6KaG55uW44CCQVBJIEtleSDovpPlhaXml7bpmpDol4/vvIznlZnnqbrkvJrlhpnlhaXljaDkvY3lgLwgc2st44CC')
    $name = Read-HostWithDefaultValue -Prompt (ConvertFrom-Utf8Base64String -Value 'UHJvdmlkZXIg5ZCN56ew') -DefaultValue $name
    $baseUrl = Read-HostWithDefaultValue -Prompt (ConvertFrom-Utf8Base64String -Value 'QVBJIOWcsOWdgCAvIEJhc2UgVVJM') -DefaultValue $baseUrl
    $model = Read-HostWithDefaultValue -Prompt (ConvertFrom-Utf8Base64String -Value '5qih5Z6L5ZCN56ew') -DefaultValue $model

    $apiKey = $PresetApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = Read-HostHiddenValue -Label 'API Key' -Placeholder (ConvertFrom-Utf8Base64String -Value '6L6T5YWl5pe26ZqQ6JeP77yM5Zue6L2m5Y+v5L2/55So5Y2g5L2N5YC8IHNrLQ==')
    }
    else {
        Write-CodexProviderInputLine -Label 'API Key' -Value (ConvertFrom-Utf8Base64String -Value '5bey5LuO5ZG95Luk5Y+C5pWw6K+75Y+W77yM5YaF5a656ZqQ6JeP44CC')
    }

    $finalApiKey = if ([string]::IsNullOrWhiteSpace($apiKey)) { 'sk-' } else { $apiKey.Trim() }
    $apiKeyStatus = if ($finalApiKey -eq 'sk-') {
        ConvertFrom-Utf8Base64String -Value '5pyq5aGr5YaZ77yM5bCG5L2/55So5Y2g5L2N6buY6K6k5YC8'
    }
    else {
        ConvertFrom-Utf8Base64String -Value '5bey5aGr5YaZ'
    }

    Write-CodexProviderInputSection `
        -Title (ConvertFrom-Utf8Base64String -Value '6YWN572u5pGY6KaB') `
        -Detail (ConvertFrom-Utf8Base64String -Value '6L+Z6YeM56Gu6K6k5pyA57uI5bCG5YaZ5YWlIENDIFN3aXRjaCBkZWVwIGxpbmsg55qE6YWN572u77ybQVBJIEtleSDlj6rmmL7npLrnirbmgIHjgII=')
    Write-CodexProviderInputLine -Label 'Provider' -Value $name.Trim()
    Write-CodexProviderInputLine -Label 'Base URL' -Value $baseUrl.Trim()
    Write-CodexProviderInputLine -Label 'Model' -Value $model.Trim()
    Write-CodexProviderInputLine -Label 'API Key' -Value $apiKeyStatus

    return [pscustomobject]@{
        Name    = $name.Trim()
        BaseUrl = $baseUrl.Trim()
        Model   = $model.Trim()
        ApiKey  = $finalApiKey
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
            Write-Log -Message (ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5pys5qyh5Yia5a6J6KOF5oiW5pu05paw5LqGIENDIFN3aXRjaO+8jOWvvOWFpSBwcm92aWRlciDliY3kvJrlhYjlkK/liqjkuIDmrKHlupTnlKjlrozmiJDms6jlhow=')
        }

        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5bCG6YCa6L+HIGNjc3dpdGNoOi8vIGRlZXAgbGluayDlr7zlhaUgcHJvdmlkZXLvvJp7MH0gLT4gezF9') -f $ProviderInfo.Name, $ProviderInfo.BaseUrl)
        return [pscustomobject]@{
            Name   = (ConvertFrom-Utf8Base64String -Value '6YWN572u5a+85YWl')
            Key    = 'cc-switch-provider'
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
            $warmupReason = if ($ForceWarmup) { ConvertFrom-Utf8Base64String -Value '5Yia5a6J6KOF5oiW5pu05paw' } else { ConvertFrom-Utf8Base64String -Value '5Y2P6K6u5bCa5pyq5rOo5YaM' }
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5a+85YWlIHByb3ZpZGVyIOWJjeWFiOWQr+WKqCBDQyBTd2l0Y2jvvIh7MH3vvInvvJp7MX0=') -f $warmupReason, $ccSwitchExe)
            Start-Process -FilePath $ccSwitchExe | Out-Null
            Start-Sleep -Seconds 5

            if (-not (Wait-CcSwitchProtocolRegistration -TimeoutSeconds 25)) {
                throw (ConvertFrom-Utf8Base64String -Value '5ZCv5YqoIENDIFN3aXRjaCDlkI7ku43mnKrms6jlhowgY2Nzd2l0Y2g6Ly8g5Y2P6K6u44CC5aaC5p6cIFdpbmRvd3Mg5LuN5Zyo5a6M5oiQ5bqU55So5rOo5YaM77yM6K+356iN5ZCO5omL5Yqo6YeN6K+V5LiA5qyh44CC')
            }

            Start-Sleep -Seconds 3
        }
        else {
            throw (ConvertFrom-Utf8Base64String -Value 'Y2Nzd2l0Y2g6Ly8g5Y2P6K6u5pyq5rOo5YaM77yM5LiU5rKh5pyJ5om+5YiwIENDIFN3aXRjaCDlj6/miafooYzmlofku7bjgILor7flhYjlkK/liqjkuIDmrKEgQ0MgU3dpdGNoIOWQjumHjeivleOAgg==')
        }
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo6YCa6L+H5a6Y5pa5IGRlZXAgbGluayDlr7zlhaUgQ0MgU3dpdGNoIHByb3ZpZGVy77yaezB9') -f $ProviderInfo.Name)
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
        Name   = (ConvertFrom-Utf8Base64String -Value '6YWN572u5a+85YWl')
        Key    = 'cc-switch-provider'
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
        [switch]$DryRun,
        [switch]$Quiet
    )

    if ($DryRun) {
        if (-not $Quiet) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5aSN5Yi2IHNraWxsIHswfSAtPiB7MX0=') -f $SourcePath, $DestinationPath)
        }
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

function Read-SkillMetaFile {
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath
    )

    $metaPath = Join-Path $SkillPath '.skill-meta.json'
    if (-not (Test-Path -LiteralPath $metaPath)) {
        return $null
    }

    return Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
}

function Get-SkillMetaStringValue {
    param(
        [object]$Meta,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $value = Get-ObjectPropertyValue -Object $Meta -Name $Name
    if ($null -eq $value) {
        return ''
    }

    return ([string]$value).Trim()
}

function Test-SkillMetaMatchesSource {
    param(
        [object]$SourceMeta,
        [object]$DestinationMeta,
        [Parameter(Mandatory)]
        [string]$SkillName
    )

    $sourceRef = Get-SkillMetaStringValue -Meta $SourceMeta -Name 'source_ref'
    $destinationRef = Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'source_ref'
    if (-not [string]::IsNullOrWhiteSpace($sourceRef)) {
        return ($sourceRef -eq $destinationRef) -and
        ((Get-SkillMetaStringValue -Meta $SourceMeta -Name 'source_subpath') -eq (Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'source_subpath')) -and
        ((Get-SkillMetaStringValue -Meta $SourceMeta -Name 'source_branch') -eq (Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'source_branch'))
    }

    $sourceRegistryType = Get-SkillMetaStringValue -Meta $SourceMeta -Name 'registry_source_type'
    $destinationRegistryType = Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'registry_source_type'
    $sourceEntryName = Get-SkillMetaStringValue -Meta $SourceMeta -Name 'registry_entry_name'
    $destinationEntryName = Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'registry_entry_name'
    if ([string]::IsNullOrWhiteSpace($sourceEntryName)) {
        $sourceEntryName = $SkillName
    }
    if ([string]::IsNullOrWhiteSpace($destinationEntryName)) {
        $destinationEntryName = $SkillName
    }

    return ($sourceRegistryType -eq 'custom') -and ($destinationRegistryType -eq 'custom') -and ($sourceEntryName -eq $destinationEntryName)
}

function Get-SkillMetaUpdateStatus {
    param(
        [object]$SourceMeta,
        [object]$DestinationMeta,
        [Parameter(Mandatory)]
        [string]$SkillName
    )

    if ($null -eq $SourceMeta) {
        return [pscustomobject]@{ Known = $false; Available = $false }
    }

    if ($null -eq $DestinationMeta) {
        return [pscustomobject]@{ Known = $true; Available = $true }
    }

    if (-not (Test-SkillMetaMatchesSource -SourceMeta $SourceMeta -DestinationMeta $DestinationMeta -SkillName $SkillName)) {
        return [pscustomobject]@{ Known = $true; Available = $true }
    }

    $sourceRevision = Get-SkillMetaStringValue -Meta $SourceMeta -Name 'source_revision'
    if ([string]::IsNullOrWhiteSpace($sourceRevision)) {
        return [pscustomobject]@{ Known = $false; Available = $false }
    }

    $destinationRevision = Get-SkillMetaStringValue -Meta $DestinationMeta -Name 'source_revision'
    return [pscustomobject]@{
        Known     = $true
        Available = ($sourceRevision -ne $destinationRevision)
    }
}

function Get-SkillInstallState {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [Parameter(Mandatory)]
        [string]$SkillName
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return [pscustomobject]@{ State = 'Missing'; Detail = (ConvertFrom-Utf8Base64String -Value '55uu5qCH55uu5b2V5LiN5a2Y5Zyo') }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $DestinationPath 'SKILL.md'))) {
        return [pscustomobject]@{ State = 'Orphan'; Detail = (ConvertFrom-Utf8Base64String -Value '546w5pyJ55uu5b2V5rKh5pyJIFNLSUxMLm1k') }
    }

    try {
        $sourceMeta = Read-SkillMetaFile -SkillPath $SourcePath
    }
    catch {
        return [pscustomobject]@{ State = 'Orphan'; Detail = ((ConvertFrom-Utf8Base64String -Value '5p2l5rqQIG1ldGEg5peg5pWI77yaezB9') -f $_.Exception.Message) }
    }

    try {
        $destinationMeta = Read-SkillMetaFile -SkillPath $DestinationPath
    }
    catch {
        return [pscustomobject]@{ State = 'Orphan'; Detail = ((ConvertFrom-Utf8Base64String -Value '546w5pyJIG1ldGEg5peg5pWI77yaezB9') -f $_.Exception.Message) }
    }

    if ($null -eq $destinationMeta) {
        return [pscustomobject]@{ State = 'Orphan'; Detail = (ConvertFrom-Utf8Base64String -Value '546w5pyJIHNraWxsIOe8uuWwkSAuc2tpbGwtbWV0YS5qc29u') }
    }

    if ($null -eq $sourceMeta) {
        return [pscustomobject]@{ State = 'Tracked'; Detail = (ConvertFrom-Utf8Base64String -Value 'YnVuZGxlIOayoeaciSBtZXRh77yM5Zue6YCA5Yiw5pen54mI5ZCM5q2l') }
    }

    if (Test-SkillMetaMatchesSource -SourceMeta $sourceMeta -DestinationMeta $destinationMeta -SkillName $SkillName) {
        return [pscustomobject]@{ State = 'Tracked'; Detail = (ConvertFrom-Utf8Base64String -Value '546w5pyJIG1ldGEg5LiOIGJ1bmRsZSDmnaXmupDljLnphY0=') }
    }

    return [pscustomobject]@{ State = 'Foreign'; Detail = (ConvertFrom-Utf8Base64String -Value '546w5pyJIG1ldGEg5p2l5rqQ5LiOIGJ1bmRsZSDmnaXmupDkuI3ljLnphY0=') }
}

function Backup-SkillDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$DryRun,
        [switch]$Quiet
    )

    $parent = Split-Path -Parent $Path
    $name = Split-Path -Leaf $Path
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $parent ('{0}.legacy.{1}' -f $name, $timestamp)
    $suffix = 1
    while (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $parent ('{0}.legacy.{1}.{2}' -f $name, $timestamp, $suffix)
        $suffix++
    }

    if ($DryRun) {
        if (-not $Quiet) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5aSH5Lu9IHNraWxsIHswfSAtPiB7MX0=') -f $Path, $backupPath)
        }
        return $backupPath
    }

    Move-Item -LiteralPath $Path -Destination $backupPath
    return $backupPath
}

function Get-SkillImportDecision {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath,
        [Parameter(Mandatory)]
        [string]$SkillName,
        [switch]$NoReplaceOrphan,
        [switch]$ReplaceForeign,
        [switch]$RenameForeign
    )

    $installState = Get-SkillInstallState -SourcePath $SourcePath -DestinationPath $DestinationPath -SkillName $SkillName
    $finalPath = $DestinationPath
    $finalName = $SkillName

    if ($installState.State -eq 'Foreign' -and $RenameForeign) {
        $finalName = '{0}-indieark' -f $SkillName
        $finalPath = Join-Path (Split-Path -Parent $DestinationPath) $finalName
        $installState = Get-SkillInstallState -SourcePath $SourcePath -DestinationPath $finalPath -SkillName $finalName
    }

    $action = switch ($installState.State) {
        'Missing' { 'Copy' }
        'Tracked' { if (Test-SkillDirectoryInSync -SourcePath $SourcePath -DestinationPath $finalPath) { 'Skip' } else { 'Copy' } }
        'Orphan' { if ($NoReplaceOrphan) { 'Skip' } else { 'BackupThenCopy' } }
        'Foreign' { if ($ReplaceForeign) { 'BackupThenCopy' } else { 'Skip' } }
        default { 'Skip' }
    }

    return [pscustomobject]@{
        State     = $installState.State
        Detail    = $installState.Detail
        Action    = $action
        FinalName = $finalName
        FinalPath = $finalPath
    }
}

function Invoke-SkillImportDecision {
    param(
        [Parameter(Mandatory)]
        [object]$Decision,
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [switch]$DryRun,
        [switch]$Quiet
    )

    $backupPath = $null
    if ($Decision.Action -eq 'BackupThenCopy') {
        $backupPath = Backup-SkillDirectory -Path $Decision.FinalPath -DryRun:$DryRun -Quiet:$Quiet
        Copy-SkillDirectory -SourcePath $SourcePath -DestinationPath $Decision.FinalPath -DryRun:$DryRun -Quiet:$Quiet
    }
    elseif ($Decision.Action -eq 'Copy') {
        Copy-SkillDirectory -SourcePath $SourcePath -DestinationPath $Decision.FinalPath -DryRun:$DryRun -Quiet:$Quiet
    }

    return $backupPath
}

function Get-SkillDirectoriesFromExtractedRoot {
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $skillFiles = Get-ChildItem -LiteralPath $RootPath -Filter 'SKILL.md' -File -Recurse
    if (-not $skillFiles) {
        throw ((ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5om+5YiwIFNLSUxMLm1kIOaWh+S7tu+8mnswfQ==') -f $RootPath)
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
            throw ((ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5om+5YiwIFNLSUxMLm1kIOaWh+S7tu+8mnswfQ==') -f $ZipPath)
        }

        return @($entries)
    }
    finally {
        $archive.Dispose()
    }
}

function Expand-ZipArchiveWithProgress {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Initialize-Directory -Path $DestinationPath

    $resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).ProviderPath
    $destinationRoot = [IO.Path]::GetFullPath($DestinationPath)
    if (-not $destinationRoot.EndsWith([IO.Path]::DirectorySeparatorChar.ToString())) {
        $destinationRoot = $destinationRoot + [IO.Path]::DirectorySeparatorChar
    }
    $archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipPath)
    try {
        $entries = @($archive.Entries)
        $totalBytes = [int64](($entries | Measure-Object -Property Length -Sum).Sum)
        $processedBytes = [int64]0
        $lastProgressPercent = -1
        $label = ConvertFrom-Utf8Base64String -Value '6Kej5Y6L'
        $detail = Split-Path -Leaf $ZipPath

        foreach ($entry in $entries) {
            $relativePath = $entry.FullName.Replace('/', [IO.Path]::DirectorySeparatorChar).Replace('\', [IO.Path]::DirectorySeparatorChar)
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                continue
            }

            $targetPath = [IO.Path]::GetFullPath((Join-Path $destinationRoot $relativePath))
            if (-not $targetPath.StartsWith($destinationRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw ((ConvertFrom-Utf8Base64String -Value 'WmlwIOadoeebrui2iueVjO+8jOaLkue7neino+WOi++8mnswfQ==') -f $entry.FullName)
            }

            $isDirectory = [string]::IsNullOrEmpty($entry.Name)
            if ($isDirectory) {
                Initialize-Directory -Path $targetPath
                continue
            }

            Initialize-Directory -Path (Split-Path -Parent $targetPath)
            $inputStream = $null
            $outputStream = $null
            try {
                $inputStream = $entry.Open()
                $outputStream = [IO.File]::Open($targetPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $buffer = New-Object byte[] 1048576
                do {
                    $readBytes = $inputStream.Read($buffer, 0, $buffer.Length)
                    if ($readBytes -gt 0) {
                        $outputStream.Write($buffer, 0, $readBytes)
                        $processedBytes += $readBytes

                        if ($totalBytes -gt 0) {
                            $progressPercent = [int](($processedBytes * 100) / $totalBytes)
                            if ($progressPercent -lt 100 -and $progressPercent -ge ($lastProgressPercent + 5)) {
                                Write-OperationProgress -Label $label -Percent $progressPercent -Detail $detail
                                $lastProgressPercent = $progressPercent
                            }
                        }
                    }
                } while ($readBytes -gt 0)
            }
            finally {
                if ($outputStream) { $outputStream.Dispose() }
                if ($inputStream) { $inputStream.Dispose() }
            }
        }

        Write-OperationProgress -Label $label -Percent 100 -Detail $detail -Completed
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

function Split-DelimitedSelectionText {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    $normalized = $Value.Replace([char]0xFF0C, ',').Replace([char]0x3001, ',')
    return @($normalized -split ',')
}

function Split-SelectionTokens {
    param(
        [string[]]$Values
    )

    return @(
        $Values |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Split-DelimitedSelectionText -Value $_ } |
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
        Split-DelimitedSelectionText -Value $trimmed |
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
        Write-Log -Level 'WARN' -Message (ConvertFrom-Utf8Base64String -Value 'dGFyIOS4jeWPr+eUqO+8jOi3s+i/hyBwcm9maWxlIHJlZ2lzdHJ5IOino+WOiw==')
        return $null
    }

    & $tar.Source -xzf $archivePath -C $DestinationPath
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'cmVnaXN0cnkudGFyLmd6IOino+WOi+Wksei0pe+8jOmAgOWHuueggT17MH3vvJvot7Pov4cgcHJvZmlsZSDoj5zljZU=') -f $LASTEXITCODE)
        return $null
    }

    return $DestinationPath
}

function Get-RegistryMirrorAssetNames {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $root = Join-Path $RegistryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $root)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $root -Recurse -File |
        ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/' } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
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
                Name        = ConvertFrom-ProfileScalar -Value $Matches[1]
                Description = ''
                Tags        = @()
                Mcp         = @()
                Skills      = @()
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

function Get-SkillBundleProfiles {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        return @()
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skills-profile-{0}' -f [guid]::NewGuid().ToString('N'))
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).ProviderPath
        [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedZipPath, $tempRoot)
        $registryRoot = Expand-BundleRegistryArchive -ExtractedBundleRoot $tempRoot -DestinationPath (Join-Path $tempRoot 'registry')
        if ($registryRoot) {
            $skillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
            $profiles = @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot)
            foreach ($profile in $profiles) {
                $prereqs = @(Get-ProfilePrereqNames -RegistryRoot $registryRoot -SkillNames @($profile.Skills) -McpNames @($profile.Mcp))
                $profile | Add-Member -MemberType NoteProperty -Name Prereqs -Value $prereqs -Force
                $expandedSkills = @(Expand-ProfileSkillReferences -SkillNames @($profile.Skills) -SkillDirectories $skillDirs)
                $profile | Add-Member -MemberType NoteProperty -Name ExpandedSkills -Value $expandedSkills -Force
            }
            return @($profiles)
        }

        return @()
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
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

function Read-RegistrySkillEntries {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot
    )

    $path = Join-Path $RegistryRoot 'skills.yaml'
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    $section = ''
    $current = $null
    $inSource = $false
    foreach ($rawLine in (Get-Content -Encoding UTF8 -LiteralPath $path)) {
        $line = $rawLine.TrimEnd()
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($line -match '^(?<section>[A-Za-z_]+):\s*$') {
            if ($null -ne $current) {
                $entries.Add([pscustomobject]$current)
                $current = $null
            }
            $section = $Matches['section']
            $inSource = $false
            continue
        }

        if ($section -notin @('custom', 'vendored', 'external')) {
            continue
        }

        if ($trimmed -match '^-\s+name\s*:\s*(.+)$') {
            if ($null -ne $current) {
                $entries.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                Name        = ConvertFrom-ProfileScalar -Value $Matches[1]
                Section     = $section
                Category    = ''
                Description = ''
                Requires    = @()
                SourceType  = ''
                Repo        = ''
                Subpath     = ''
                Homepage    = ''
                ArchiveUrl  = ''
                DownloadUrl = ''
                LocalPath   = ''
                Branch      = ''
            }
            $inSource = $false
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if ($trimmed -match '^category\s*:\s*(.*)$') {
            $current['Category'] = ConvertFrom-ProfileScalar -Value $Matches[1]
            $inSource = $false
        }
        elseif ($trimmed -match '^description\s*:\s*(.*)$') {
            $current['Description'] = ConvertFrom-ProfileScalar -Value $Matches[1]
            $inSource = $false
        }
        elseif ($trimmed -match '^requires\s*:\s*(.*)$') {
            $current['Requires'] = @(ConvertFrom-ProfileInlineList -Value $Matches[1])
            $inSource = $false
        }
        elseif ($trimmed -match '^source\s*:\s*\{\s*(.+)\s*\}\s*$') {
            foreach ($part in (Split-DelimitedSelectionText -Value $Matches[1])) {
                if ($part -match '^\s*(?<key>[A-Za-z_]+)\s*:\s*(?<value>.+?)\s*$') {
                    $key = $Matches['key']
                    $value = ConvertFrom-ProfileScalar -Value $Matches['value']
                    switch ($key) {
                        'type' { $current['SourceType'] = $value }
                        'repo' { $current['Repo'] = $value }
                        'upstream' { if ([string]::IsNullOrWhiteSpace($current['Repo'])) { $current['Repo'] = $value } }
                        'subpath' { $current['Subpath'] = $value }
                        'homepage' { $current['Homepage'] = $value }
                        'archive' { $current['ArchiveUrl'] = $value }
                        'archive_url' { $current['ArchiveUrl'] = $value }
                        'download_url' { $current['DownloadUrl'] = $value }
                        'url' { $current['DownloadUrl'] = $value }
                        'path' { $current['LocalPath'] = $value }
                        'local_path' { $current['LocalPath'] = $value }
                        'branch' { $current['Branch'] = $value }
                    }
                }
            }
            $inSource = $false
        }
        elseif ($trimmed -match '^source\s*:\s*$') {
            $inSource = $true
        }
        elseif ($inSource -and $trimmed -match '^(type|repo|upstream|subpath|homepage|archive|archive_url|download_url|url|path|local_path|branch)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = ConvertFrom-ProfileScalar -Value $Matches[2]
            switch ($key) {
                'type' { $current['SourceType'] = $value }
                'repo' { $current['Repo'] = $value }
                'upstream' { if ([string]::IsNullOrWhiteSpace($current['Repo'])) { $current['Repo'] = $value } }
                'subpath' { $current['Subpath'] = $value }
                'homepage' { $current['Homepage'] = $value }
                'archive' { $current['ArchiveUrl'] = $value }
                'archive_url' { $current['ArchiveUrl'] = $value }
                'download_url' { $current['DownloadUrl'] = $value }
                'url' { $current['DownloadUrl'] = $value }
                'path' { $current['LocalPath'] = $value }
                'local_path' { $current['LocalPath'] = $value }
                'branch' { $current['Branch'] = $value }
            }
        }
        elseif ($trimmed -match '^(compat|bundle)\s*:') {
            $inSource = $false
        }
    }

    if ($null -ne $current) {
        $entries.Add([pscustomobject]$current)
    }

    return $entries.ToArray()
}

function Read-RegistryPrereqEntries {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot
    )

    $path = Join-Path $RegistryRoot 'prereqs.yaml'
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    $inInstall = $false
    foreach ($rawLine in (Get-Content -Encoding UTF8 -LiteralPath $path)) {
        $line = $rawLine.TrimEnd()
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^-\s+name\s*:\s*(.+)$') {
            if ($null -ne $current) {
                $entries.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                Name    = ConvertFrom-ProfileScalar -Value $Matches[1]
                Kind    = ''
                Check   = ''
                Install = @{}
            }
            $inInstall = $false
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if ($trimmed -match '^kind\s*:\s*(.*)$') {
            $current['Kind'] = ConvertFrom-ProfileScalar -Value $Matches[1]
            $inInstall = $false
        }
        elseif ($trimmed -match '^check\s*:\s*(.*)$') {
            $current['Check'] = ConvertFrom-ProfileScalar -Value $Matches[1]
            $inInstall = $false
        }
        elseif ($trimmed -match '^install\s*:\s*$') {
            $inInstall = $true
        }
        elseif ($inInstall -and $trimmed -match '^(?<key>[A-Za-z_]+)\s*:\s*(?<value>.*)$') {
            $current['Install'][$Matches['key']] = ConvertFrom-ProfileScalar -Value $Matches['value']
        }
        elseif ($trimmed -match '^(auth|notes|source|tags|category|description)\s*:') {
            $inInstall = $false
        }
    }

    if ($null -ne $current) {
        $entries.Add([pscustomobject]$current)
    }

    return $entries.ToArray()
}

function Read-RegistryMcpEntries {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot
    )

    $path = Join-Path $RegistryRoot 'mcp.yaml'
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    $inInstall = $false
    foreach ($rawLine in (Get-Content -Encoding UTF8 -LiteralPath $path)) {
        $line = $rawLine.TrimEnd()
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -match '^-\s+name\s*:\s*(.+)$') {
            if ($null -ne $current) {
                $entries.Add([pscustomobject]$current)
            }
            $current = [ordered]@{
                Name      = ConvertFrom-ProfileScalar -Value $Matches[1]
                Transport = 'stdio'
                Command   = ''
                Args      = @()
                Url       = ''
                Env       = @()
            }
            $inInstall = $false
            continue
        }

        if ($null -eq $current) {
            continue
        }

        if ($trimmed -match '^transport\s*:\s*(.*)$') {
            $current['Transport'] = ConvertFrom-ProfileScalar -Value $Matches[1]
            $inInstall = $false
        }
        elseif ($trimmed -match '^install\s*:\s*$') {
            $inInstall = $true
        }
        elseif ($inInstall -and $trimmed -match '^command\s*:\s*(.*)$') {
            $current['Command'] = ConvertFrom-ProfileScalar -Value $Matches[1]
        }
        elseif ($inInstall -and $trimmed -match '^args\s*:\s*(.*)$') {
            $argsText = (ConvertFrom-ProfileScalar -Value $Matches[1]).Trim()
            if ([string]::IsNullOrWhiteSpace($argsText) -or $argsText -eq '[]') {
                $current['Args'] = @()
            }
            else {
                try {
                    $current['Args'] = @($argsText | ConvertFrom-Json)
                }
                catch {
                    $current['Args'] = @(ConvertFrom-ProfileInlineList -Value $argsText)
                }
            }
        }
        elseif ($inInstall -and $trimmed -match '^url\s*:\s*(.*)$') {
            $current['Url'] = ConvertFrom-ProfileScalar -Value $Matches[1]
        }
        elseif ($inInstall -and $trimmed -match '^env\s*:\s*(.*)$') {
            $current['Env'] = @(ConvertFrom-ProfileInlineList -Value $Matches[1])
        }
        elseif ($trimmed -match '^(source|requires|compat|tags|notes|category|description)\s*:') {
            $inInstall = $false
        }
    }

    if ($null -ne $current) {
        $entries.Add([pscustomobject]$current)
    }

    return $entries.ToArray()
}

function Test-RegistryCommandSucceeded {
    param(
        [string]$CommandText
    )

    if ([string]::IsNullOrWhiteSpace($CommandText)) {
        return $false
    }

    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $CommandText *> $null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }

        if ($CommandText -match '^\s*lark\s+--version\s*$') {
            $larkCli = Get-Command lark-cli -ErrorAction SilentlyContinue
            if ($null -ne $larkCli) {
                return $true
            }
            return $false
        }

        return $false
    }
    catch {
        return $false
    }
}

function Invoke-PrereqInstallCommand {
    param(
        [Parameter(Mandatory)]
        [string]$CommandText,
        [switch]$DryRun
    )

    if ($CommandText -match '^winget\s+install(?:\s+--id)?\s+(?<id>[^\s]+)') {
        $packageId = $Matches['id']
        Invoke-WingetAction -Action 'install' -PackageId $packageId -DryRun:$DryRun
        return
    }

    if ($DryRun) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5a6J6KOF5YmN572u5L6d6LWW77yaezB9') -f $CommandText)
        return
    }

    if ($CommandText -match '^powershell(?:\.exe)?\s+-c\s+"(?<body>.*)"$') {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $Matches['body']
        if ($LASTEXITCODE -ne 0) {
            throw ('Prereq install command failed: {0}' -f $CommandText)
        }
        return
    }

    $tokens = @($CommandText -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($tokens.Count -eq 0) {
        return
    }

    $command = $tokens[0]
    $args = @($tokens | Select-Object -Skip 1)
    Write-OperationProgress -Label 'prereq' -Percent $null -Detail ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5omn6KGM5YmN572u5L6d6LWW5ZG95Luk77yaezB9') -f $CommandText)
    & $command @args
    if ($LASTEXITCODE -ne 0) {
        throw ('Prereq install command failed: {0}' -f $CommandText)
    }
}

function Get-SkillBundleInventory {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        return [pscustomobject]@{
            Profiles       = @()
            BundleSkills   = @()
            RegistrySkills = @()
            Mcp            = @()
            Prereqs        = @()
            McpAssets      = @()
            PrereqAssets   = @()
            SkillSources   = @()
            RegistryRoot   = ''
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skills-inventory-{0}' -f [guid]::NewGuid().ToString('N'))
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).ProviderPath
        [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedZipPath, $tempRoot)
        $registryRoot = Expand-BundleRegistryArchive -ExtractedBundleRoot $tempRoot -DestinationPath (Join-Path $tempRoot 'registry')
        $skillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
        $bundleSkills = @(
            $skillDirs |
            ForEach-Object { Split-Path -Leaf $_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        $profiles = @()
        $registrySkills = @()
        $mcpEntries = @()
        $prereqEntries = @()
        $mcpAssets = @()
        $prereqAssets = @()
        $skillSources = @(
            foreach ($skillDir in $skillDirs) {
                $skillName = Split-Path -Leaf $skillDir
                $meta = $null
                try {
                    $meta = Read-SkillMetaFile -SkillPath $skillDir
                }
                catch {
                    $meta = $null
                }
                [pscustomobject]@{
                    Name = $skillName
                    Meta = $meta
                }
            }
        )
        if ($registryRoot) {
            $profiles = @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot)
            foreach ($profile in $profiles) {
                $prereqs = @(Get-ProfilePrereqNames -RegistryRoot $registryRoot -SkillNames @($profile.Skills) -McpNames @($profile.Mcp))
                $profile | Add-Member -MemberType NoteProperty -Name Prereqs -Value $prereqs -Force
                $expandedSkills = @(Expand-ProfileSkillReferences -SkillNames @($profile.Skills) -SkillDirectories $skillDirs)
                $profile | Add-Member -MemberType NoteProperty -Name ExpandedSkills -Value $expandedSkills -Force
            }
            $registrySkills = @(Read-RegistrySkillEntries -RegistryRoot $registryRoot)
            $mcpEntries = @(Read-RegistryMcpEntries -RegistryRoot $registryRoot)
            $prereqEntries = @(Read-RegistryPrereqEntries -RegistryRoot $registryRoot)
            $mcpAssets = @(Get-RegistryMirrorAssetNames -RegistryRoot $registryRoot -RelativePath 'mcps')
            $prereqAssets = @(Get-RegistryMirrorAssetNames -RegistryRoot $registryRoot -RelativePath 'prereqs')
        }

        return [pscustomobject]@{
            Profiles       = $profiles
            BundleSkills   = $bundleSkills
            RegistrySkills = $registrySkills
            Mcp            = $mcpEntries
            Prereqs        = $prereqEntries
            McpAssets      = $mcpAssets
            PrereqAssets   = $prereqAssets
            SkillSources   = $skillSources
            RegistryRoot   = if ($registryRoot) { $registryRoot } else { '' }
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Get-RegistryPrereqInstallCommand {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Install
    )

    $isWindowsPlatform = ($env:OS -eq 'Windows_NT')
    $isMacPlatform = $false
    if (-not $isWindowsPlatform) {
        try {
            $isWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
            $isMacPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
        }
        catch {
        }
    }

    $platformKeys = if ($isWindowsPlatform) {
        @('windows', 'winget', 'scoop')
    }
    elseif ($isMacPlatform) {
        @('macos', 'brew', 'unix')
    }
    else {
        @('linux', 'unix')
    }

    foreach ($key in @($platformKeys + @('command', 'npm', 'pipx', 'pip', 'brew', 'winget', 'scoop'))) {
        if (-not $Install.ContainsKey($key)) {
            continue
        }

        $value = [string]$Install[$key]
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        switch ($key) {
            'npm' { return 'npm i -g {0}' -f $value }
            'pip' { return 'pip install {0}' -f $value }
            'pipx' { return 'pipx install {0}' -f $value }
            'brew' { return 'brew install {0}' -f $value }
            'winget' { return 'winget install --id {0}' -f $value }
            'scoop' { return 'scoop install {0}' -f $value }
            default { return $value }
        }
    }

    return $null
}

function Install-RegistryPrereqs {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [string[]]$PrereqNames,
        [switch]$DryRun
    )

    $names = @($PrereqNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $result = [ordered]@{
        Already   = @()
        Installed = @()
        Manual    = @()
        Missing   = @()
        Failed    = @()
    }

    if ($names.Count -eq 0) {
        return [pscustomobject]$result
    }

    $entries = @(Read-RegistryPrereqEntries -RegistryRoot $RegistryRoot)
    foreach ($name in $names) {
        $entry = $entries | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $entry) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5YmN572u5L6d6LWW5pyq5ZyoIHByZXJlcXMueWFtbCDkuK3lr7vliLDvvJp7MH0=') -f $name)
            $result.Missing += $name
            continue
        }

        $alreadyInstalled = Test-RegistryCommandSucceeded -CommandText $entry.Check
        if ((-not $alreadyInstalled) -and $name -eq 'lark' -and (Get-Command lark-cli -ErrorAction SilentlyContinue)) {
            $alreadyInstalled = $true
        }
        if ((-not $DryRun) -and $alreadyInstalled) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5YmN572u5L6d6LWW5bey5a6J6KOF77yaezB9') -f $name)
            $result.Already += $name
            continue
        }

        $install = $entry.Install
        if ($install.ContainsKey('manual') -and [string]$install['manual'] -eq 'true') {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5YmN572u5L6d6LWW6ZyA6KaB5omL5Yqo5a6J6KOF77yaezB9') -f $name)
            $result.Manual += $name
            continue
        }

        $commandText = Get-RegistryPrereqInstallCommand -Install $install

        if ([string]::IsNullOrWhiteSpace($commandText)) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5YmN572u5L6d6LWW57y65bCR5Y+v5omT6KGM5a6J6KOF5ZG95Luk77yaezB9') -f $name)
            $result.Missing += $name
            continue
        }

        try {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5a6J6KOF5YmN572u5L6d6LWW77yaezB9') -f $name)
            Invoke-PrereqInstallCommand -CommandText $commandText -DryRun:$DryRun
            $result.Installed += $name
        }
        catch {
            Write-Log -Level 'WARN' -Message ('Prereq install failed: {0}; {1}' -f $name, $_.Exception.Message)
            $result.Failed += $name
        }
    }

    if ($result.Failed.Count -gt 0) {
        Write-Log -Level 'WARN' -Message ('Prereq failed summary: {0}' -f ($result.Failed -join ', '))
    }

    return [pscustomobject]$result
}

function ConvertTo-TomlQuotedString {
    param([AllowNull()][string]$Value)
    return '"{0}"' -f (([string]$Value) -replace '\\', '\\' -replace '"', '\"')
}

function ConvertTo-TomlStringArray {
    param([string[]]$Values)
    $quoted = @($Values | ForEach-Object { ConvertTo-TomlQuotedString -Value $_ })
    return '[{0}]' -f ($quoted -join ', ')
}

function New-McpServerConfigObject {
    param(
        [Parameter(Mandatory)]
        [object]$Entry,
        [switch]$IncludeType
    )

    $config = [ordered]@{}
    $transport = ([string]$Entry.Transport).ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($transport)) {
        $transport = 'stdio'
    }

    if ($transport -eq 'stdio') {
        if ($IncludeType) {
            $config['type'] = 'stdio'
        }
        $config['command'] = [string]$Entry.Command
        $config['args'] = @($Entry.Args)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Entry.Url)) {
        $config['type'] = $transport
        $config['url'] = [string]$Entry.Url
    }
    else {
        return $null
    }

    if ($Entry.Env.Count -gt 0) {
        $envMap = [ordered]@{}
        foreach ($envName in @($Entry.Env)) {
            if (-not [string]::IsNullOrWhiteSpace($envName)) {
                $envMap[$envName] = '${' + $envName + '}'
            }
        }
        if ($envMap.Count -gt 0) {
            $config['env'] = $envMap
        }
    }

    return [pscustomobject]$config
}

function ConvertTo-ComparableConfigJson {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return ($Value | ConvertTo-Json -Depth 24 -Compress)
}

function Get-JsonMcpServerConfig {
    param(
        [AllowNull()]
        [object]$Config,
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $Config -or -not $Config.PSObject.Properties['mcpServers']) {
        return $null
    }

    $serverProperty = $Config.mcpServers.PSObject.Properties[$Name]
    if (-not $serverProperty) {
        return $null
    }

    return $serverProperty.Value
}

function Test-JsonMcpConfigObjectHasServer {
    param(
        [AllowNull()]
        [object]$Config,
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (Get-JsonMcpServerConfig -Config $Config -Name $Name)
}

function Test-JsonMcpConfigObjectServerInSync {
    param(
        [AllowNull()]
        [object]$Config,
        [Parameter(Mandatory)]
        [object]$Entry
    )

    $existing = Get-JsonMcpServerConfig -Config $Config -Name $Entry.Name
    if ($null -eq $existing) {
        return $false
    }

    $expected = New-McpServerConfigObject -Entry $Entry
    if ($null -eq $expected) {
        return $false
    }

    return (ConvertTo-ComparableConfigJson -Value $existing) -eq (ConvertTo-ComparableConfigJson -Value $expected)
}

function Read-JsonMcpConfigObject {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $null
    }

    try {
        $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigPath
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Set-JsonMcpServerConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        [Parameter(Mandatory)]
        [object[]]$Entries,
        [Parameter(Mandatory)]
        [string]$TargetName,
        [switch]$DryRun
    )

    $serverEntries = @($Entries | Where-Object {
            (($_.Transport -eq 'stdio' -and -not [string]::IsNullOrWhiteSpace($_.Command)) -or
            ($_.Transport -ne 'stdio' -and -not [string]::IsNullOrWhiteSpace($_.Url)))
        })
    if ($serverEntries.Count -eq 0) {
        return
    }

    if ($DryRun) {
        Write-Log -Message ('[dry-run] write {0} MCP config: {1} -> {2}' -f $TargetName, (($serverEntries | ForEach-Object { $_.Name }) -join ', '), $ConfigPath)
        return
    }

    Initialize-Directory -Path (Split-Path -Parent $ConfigPath)
    $config = $null
    if (Test-Path -LiteralPath $ConfigPath) {
        $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigPath
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $config = $raw | ConvertFrom-Json
        }
    }
    if (-not $config) {
        $config = [pscustomobject]@{}
    }
    $configPropertyNames = @($config.PSObject.Properties | ForEach-Object { $_.Name })
    if (-not ($configPropertyNames -contains 'mcpServers')) {
        $config | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value ([pscustomobject]@{})
    }

    foreach ($entry in $serverEntries) {
        $serverConfig = New-McpServerConfigObject -Entry $entry
        if (-not $serverConfig) {
            continue
        }
        $mcpPropertyNames = @($config.mcpServers.PSObject.Properties | ForEach-Object { $_.Name })
        if ($mcpPropertyNames -contains $entry.Name) {
            $config.mcpServers.PSObject.Properties.Remove($entry.Name)
        }
        $config.mcpServers | Add-Member -MemberType NoteProperty -Name $entry.Name -Value $serverConfig
    }

    if (Test-Path -LiteralPath $ConfigPath) {
        $backupPath = '{0}.bak.{1}' -f $ConfigPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force
    }

    $json = $config | ConvertTo-Json -Depth 24
    [System.IO.File]::WriteAllText($ConfigPath, ($json + "`n"), [System.Text.UTF8Encoding]::new($false))
    Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigPath | ConvertFrom-Json | Out-Null
    Write-Log -Message ('Wrote {0} MCP config: {1}' -f $TargetName, (($serverEntries | ForEach-Object { $_.Name }) -join ', '))
}

function Sync-ClaudeCodeMcpServers {
    param(
        [Parameter(Mandatory)]
        [object[]]$Entries,
        [switch]$DryRun
    )

    $serverEntries = @($Entries | Where-Object {
            (($_.Transport -eq 'stdio' -and -not [string]::IsNullOrWhiteSpace($_.Command)) -or
            ($_.Transport -ne 'stdio' -and -not [string]::IsNullOrWhiteSpace($_.Url)))
        })
    if ($serverEntries.Count -eq 0) {
        return
    }

    if ($DryRun) {
        Write-Log -Message ('[dry-run] register Claude Code user MCP: {0}' -f (($serverEntries | ForEach-Object { $_.Name }) -join ', '))
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($env:VIBE_CODING_USER_HOME)) {
        Write-Log -Level 'WARN' -Message ('Sandbox home is active; skip Claude Code CLI MCP registration: {0}' -f (($serverEntries | ForEach-Object { $_.Name }) -join ', '))
        return
    }

    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) {
        Write-Log -Level 'WARN' -Message ('Claude Code CLI not found; skip Claude Code MCP config: {0}' -f (($serverEntries | ForEach-Object { $_.Name }) -join ', '))
        return
    }

    foreach ($entry in $serverEntries) {
        $serverConfig = New-McpServerConfigObject -Entry $entry -IncludeType
        if (-not $serverConfig) {
            continue
        }
        $serverJson = $serverConfig | ConvertTo-Json -Depth 16 -Compress
        & $claude.Source mcp add-json $entry.Name $serverJson --scope user
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Level 'WARN' -Message ('Claude Code MCP registration failed: {0}' -f $entry.Name)
        }
    }
}

function Sync-JsonMcpClientConfigs {
    param(
        [Parameter(Mandatory)]
        [object[]]$Entries,
        [switch]$DryRun
    )

    $homeDir = Get-UserHomeDirectory
    $roamingDir = Get-UserRoamingAppDataDirectory
    if (-not [string]::IsNullOrWhiteSpace($roamingDir)) {
        Set-JsonMcpServerConfig -TargetName 'Claude Desktop' -ConfigPath (Join-Path $roamingDir 'Claude\claude_desktop_config.json') -Entries $Entries -DryRun:$DryRun
    }
    if (-not [string]::IsNullOrWhiteSpace($homeDir)) {
        Set-JsonMcpServerConfig -TargetName 'Cursor' -ConfigPath (Join-Path $homeDir '.cursor\mcp.json') -Entries $Entries -DryRun:$DryRun
        Set-JsonMcpServerConfig -TargetName 'Gemini CLI' -ConfigPath (Join-Path $homeDir '.gemini\settings.json') -Entries $Entries -DryRun:$DryRun
        Set-JsonMcpServerConfig -TargetName 'Antigravity' -ConfigPath (Join-Path $homeDir '.gemini\antigravity\mcp_config.json') -Entries $Entries -DryRun:$DryRun
    }

    Sync-ClaudeCodeMcpServers -Entries $Entries -DryRun:$DryRun
}

function Remove-TomlMcpServerBlock {
    param(
        [string]$Content,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $lines = @($Content -split "`r?`n")
    $output = New-Object System.Collections.Generic.List[string]
    $skip = $false
    $headerPattern = '^\[mcp_servers\.{0}\]\s*$' -f [regex]::Escape($Name)
    foreach ($line in $lines) {
        if ($line -match $headerPattern) {
            $skip = $true
            continue
        }
        if ($skip -and $line -match '^\[') {
            $skip = $false
        }
        if (-not $skip) {
            $output.Add($line)
        }
    }

    return (($output.ToArray() -join "`r`n").TrimEnd() + "`r`n")
}

function New-CodexMcpServerBlockText {
    param(
        [Parameter(Mandatory)]
        [object]$Entry
    )

    if ($Entry.Transport -ne 'stdio' -or [string]::IsNullOrWhiteSpace($Entry.Command)) {
        return ''
    }

    $blockLines = New-Object System.Collections.Generic.List[string]
    $blockLines.Add(('[mcp_servers.{0}]' -f $Entry.Name))
    $blockLines.Add(('command = {0}' -f (ConvertTo-TomlQuotedString -Value $Entry.Command)))
    $blockLines.Add(('args = {0}' -f (ConvertTo-TomlStringArray -Values @($Entry.Args))))
    if ($Entry.Env.Count -gt 0) {
        $envPairs = @($Entry.Env | ForEach-Object { '{0} = "${{{0}}}"' -f $_ })
        $blockLines.Add(('env = {{ {0} }}' -f ($envPairs -join ', ')))
    }

    return ($blockLines.ToArray() -join "`n")
}

function Get-CodexMcpServerBlockText {
    param(
        [AllowNull()]
        [string]$Content,
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return ''
    }

    $escaped = [regex]::Escape($Name)
    $pattern = '(?ms)^\[mcp_servers\.{0}\]\s*\r?\n(?<body>.*?)(?=^\[|\z)' -f $escaped
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return ''
    }

    return ('[mcp_servers.{0}]' -f $Name) + "`n" + $match.Groups['body'].Value.Trim()
}

function ConvertTo-NormalizedConfigText {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return (($Value -replace "`r`n", "`n") -replace "`r", "`n").Trim()
}

function Sync-CodexMcpServers {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [string[]]$McpNames,
        [switch]$DryRun
    )

    $names = @($McpNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($names.Count -eq 0) {
        return
    }

    $entries = @(Read-RegistryMcpEntries -RegistryRoot $RegistryRoot)
    $homeDir = Get-UserHomeDirectory
    $configDir = Join-Path $homeDir '.codex'
    $configPath = Join-Path $configDir 'config.toml'
    $content = if (Test-Path -LiteralPath $configPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath } else { '' }
    $blocks = New-Object System.Collections.Generic.List[string]

    foreach ($name in $names) {
        $entry = $entries | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $entry) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'TUNQIOacquWcqCBtY3AueWFtbCDkuK3lr7vliLDvvJp7MH0=') -f $name)
            continue
        }

        if ($entry.Transport -ne 'stdio' -or [string]::IsNullOrWhiteSpace($entry.Command)) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'TUNQIOWwmuacquaUr+aMgeiHquWKqOWGmeWFpSBDb2RleCDphY3nva7vvJp7MH0=') -f $name)
            continue
        }

        $content = Remove-TomlMcpServerBlock -Content $content -Name $name
        $blocks.Add((New-CodexMcpServerBlockText -Entry $entry).Replace("`n", "`r`n"))
    }

    if ($blocks.Count -eq 0) {
        return
    }

    if ($DryRun) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5YaZ5YWlIENvZGV4IE1DUCDphY3nva7vvJp7MH0=') -f ($names -join ', '))
        return
    }

    Initialize-Directory -Path $configDir
    if (Test-Path -LiteralPath $configPath) {
        $backupPath = '{0}.bak.{1}' -f $configPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
    }

    $newContent = ($content.TrimEnd() + "`r`n`r`n" + ($blocks.ToArray() -join "`r`n`r`n") + "`r`n")
    [System.IO.File]::WriteAllText($configPath, $newContent, [System.Text.UTF8Encoding]::new($false))

    $python = Get-PythonLauncher
    if ($python) {
        & $python -c "import sys,tomllib; tomllib.load(open(sys.argv[1],'rb'))" $configPath
        if ($LASTEXITCODE -ne 0) {
            throw ('Codex config TOML validation failed: {0}' -f $configPath)
        }
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bey5YaZ5YWlIENvZGV4IE1DUCDphY3nva7vvJp7MH0=') -f ($names -join ', '))
}

function Sync-RegistryMcpServers {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [string[]]$McpNames,
        [switch]$DryRun
    )

    $names = @($McpNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($names.Count -eq 0) {
        return
    }

    $entries = @(Read-RegistryMcpEntries -RegistryRoot $RegistryRoot | Where-Object { $names -contains $_.Name })
    $missingNames = @($names | Where-Object { $entries.Name -notcontains $_ })
    foreach ($name in $missingNames) {
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'TUNQIOacquWcqCBtY3AueWFtbCDkuK3lr7vliLDvvJp7MH0=') -f $name)
    }

    if ($entries.Count -eq 0) {
        return
    }

    Sync-CodexMcpServers -RegistryRoot $RegistryRoot -McpNames $names -DryRun:$DryRun
    Sync-JsonMcpClientConfigs -Entries $entries -DryRun:$DryRun
}

function Test-JsonMcpConfigHasServer {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $config = Read-JsonMcpConfigObject -ConfigPath $ConfigPath
    return Test-JsonMcpConfigObjectHasServer -Config $config -Name $Name
}

function Test-JsonMcpConfigServerInSync {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        [Parameter(Mandatory)]
        [object]$Entry
    )

    $config = Read-JsonMcpConfigObject -ConfigPath $ConfigPath
    return Test-JsonMcpConfigObjectServerInSync -Config $config -Entry $Entry
}

function Test-CodexMcpConfigHasServer {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $content = if (Test-Path -LiteralPath $ConfigPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigPath } else { '' }
    return -not [string]::IsNullOrWhiteSpace((Get-CodexMcpServerBlockText -Content $content -Name $Name))
}

function Test-CodexMcpConfigServerInSync {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        [Parameter(Mandatory)]
        [object]$Entry
    )

    $content = if (Test-Path -LiteralPath $ConfigPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigPath } else { '' }
    $existing = Get-CodexMcpServerBlockText -Content $content -Name $Entry.Name
    $expected = New-CodexMcpServerBlockText -Entry $Entry
    return (ConvertTo-NormalizedConfigText -Value $existing) -eq (ConvertTo-NormalizedConfigText -Value $expected)
}

function Test-ClaudeCodeMcpHasServer {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) {
        return $false
    }

    try {
        $output = & $claude.Source mcp list 2>$null | Out-String
        return $output -match ('(?m)^\s*{0}(\s|$)' -f [regex]::Escape($Name))
    }
    catch {
        return $false
    }
}

function Get-ClaudeCodeMcpServerNames {
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) {
        return @()
    }

    try {
        $output = & $claude.Source mcp list 2>$null | Out-String
        return @(
            $output -split "`r?`n" |
            ForEach-Object {
                if ($_ -match '^\s*(?<name>\S+)') {
                    $Matches['name']
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
    }
    catch {
        return @()
    }
}

function Get-SkillBundleComponentStatus {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,
        [switch]$IncludeSkills,
        [switch]$IncludeMcp,
        [switch]$IncludePrereqs,
        [int]$SkillProgressDelayMilliseconds = 0
    )

    $inventory = Get-SkillBundleInventory -ZipPath $ZipPath
    $homeDir = Get-UserHomeDirectory
    $roamingDir = Get-UserRoamingAppDataDirectory
    $scanAll = -not ($IncludeSkills -or $IncludeMcp -or $IncludePrereqs)
    $scanSkills = $scanAll -or $IncludeSkills
    $scanMcp = $scanAll -or $IncludeMcp
    $scanPrereqs = $scanAll -or $IncludePrereqs
    $bundleSkillSet = @{}
    foreach ($name in @($inventory.BundleSkills)) {
        $bundleSkillSet[$name.ToLowerInvariant()] = $true
    }
    $skillSourceByName = @{}
    foreach ($source in @($inventory.SkillSources)) {
        if ($null -eq $source -or [string]::IsNullOrWhiteSpace([string]$source.Name)) {
            continue
        }
        $skillSourceByName[[string]$source.Name.ToLowerInvariant()] = $source.Meta
    }

    $skillNames = @(
        @($inventory.BundleSkills) + @($inventory.RegistrySkills | ForEach-Object { $_.Name }) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
    $skillStatus = @()
    if ($scanSkills) {
        $centralRoot = Join-Path $homeDir '.skills-manager\skills'
        Write-OperationProgress -Label 'Skill' -Percent 0 -Detail ((ConvertFrom-Utf8Base64String -Value 'MC97MH0g5LiqIFNraWxsIOW8gOWni+ajgOafpQ==') -f $skillNames.Count)
        if ($SkillProgressDelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $SkillProgressDelayMilliseconds
        }
        $skillStatus = @(
            for ($i = 0; $i -lt $skillNames.Count; $i++) {
                $name = $skillNames[$i]
                $path = Join-Path $centralRoot $name
                $installed = Test-Path -LiteralPath (Join-Path $path 'SKILL.md')
                $sourceMeta = $null
                if ($skillSourceByName.ContainsKey($name.ToLowerInvariant())) {
                    $sourceMeta = $skillSourceByName[$name.ToLowerInvariant()]
                }
                $destinationMeta = $null
                if ($installed) {
                    try {
                        $destinationMeta = Read-SkillMetaFile -SkillPath $path
                    }
                    catch {
                        $destinationMeta = $null
                    }
                }
                $updateStatus = if ($installed) { Get-SkillMetaUpdateStatus -SourceMeta $sourceMeta -DestinationMeta $destinationMeta -SkillName $name } else { [pscustomobject]@{ Known = $true; Available = $false } }
                $skillProgressPercent = if ($skillNames.Count -gt 0) { [int]((($i + 1) * 100) / $skillNames.Count) } else { 100 }
                $skillProgressDetail = (ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogU2tpbGwg5bey5a6M5oiQ') -f ($i + 1), $skillNames.Count
                Write-OperationProgress -Label 'Skill' -Percent $skillProgressPercent -Detail $skillProgressDetail -Completed:(($i + 1) -ge $skillNames.Count)
                if ($SkillProgressDelayMilliseconds -gt 0) {
                    Start-Sleep -Milliseconds $SkillProgressDelayMilliseconds
                }
                [pscustomobject]@{
                    Name            = $name
                    Kind            = if ($bundleSkillSet.ContainsKey($name.ToLowerInvariant())) { 'bundle' } else { 'external' }
                    Installed       = $installed
                    UpdateAvailable = [bool]$updateStatus.Available
                    UpdateKnown     = [bool]$updateStatus.Known
                    Path            = $path
                }
            }
        )
        if ($skillNames.Count -eq 0) {
            Write-OperationProgress -Label 'Skill' -Percent 100 -Detail ((ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogU2tpbGwg5bey5a6M5oiQ') -f 0, 0) -Completed
        }
    }

    $mcpEntries = @($inventory.Mcp)
    $mcpStatus = @()
    if ($scanMcp) {
        Write-OperationProgress -Label 'MCP' -Percent 0 -Detail ((ConvertFrom-Utf8Base64String -Value 'MC97MH0g5LiqIE1DUCDlvIDlp4vmo4Dmn6U=') -f $mcpEntries.Count)
        $codexConfigPath = Join-Path (Join-Path $homeDir '.codex') 'config.toml'
        $codexConfigContent = if (Test-Path -LiteralPath $codexConfigPath) { Get-Content -Raw -Encoding UTF8 -LiteralPath $codexConfigPath } else { '' }
        $jsonTargets = @()
        if (-not [string]::IsNullOrWhiteSpace($roamingDir)) {
            $jsonTargets += [pscustomobject]@{ Name = 'Claude Desktop'; Path = Join-Path $roamingDir 'Claude\claude_desktop_config.json' }
        }
        $jsonTargets += @(
            [pscustomobject]@{ Name = 'Cursor'; Path = Join-Path $homeDir '.cursor\mcp.json' },
            [pscustomobject]@{ Name = 'Gemini CLI'; Path = Join-Path $homeDir '.gemini\settings.json' },
            [pscustomobject]@{ Name = 'Antigravity'; Path = Join-Path $homeDir '.gemini\antigravity\mcp_config.json' }
        )
        $jsonTargets = @($jsonTargets | ForEach-Object {
                [pscustomobject]@{
                    Name   = $_.Name
                    Path   = $_.Path
                    Config = Read-JsonMcpConfigObject -ConfigPath $_.Path
                }
            })
        $claudeCodeServers = @{}
        foreach ($serverName in @(Get-ClaudeCodeMcpServerNames)) {
            $claudeCodeServers[$serverName] = $true
        }
        $mcpStatus = @(
            for ($i = 0; $i -lt $mcpEntries.Count; $i++) {
                $entry = $mcpEntries[$i]
                $targets = New-Object System.Collections.Generic.List[string]
                $updateTargets = New-Object System.Collections.Generic.List[string]
                $codexBlock = Get-CodexMcpServerBlockText -Content $codexConfigContent -Name $entry.Name
                if (-not [string]::IsNullOrWhiteSpace($codexBlock)) {
                    $targets.Add('Codex')
                    $expectedCodexBlock = New-CodexMcpServerBlockText -Entry $entry
                    if ((ConvertTo-NormalizedConfigText -Value $codexBlock) -ne (ConvertTo-NormalizedConfigText -Value $expectedCodexBlock)) {
                        $updateTargets.Add('Codex')
                    }
                }
                foreach ($target in $jsonTargets) {
                    if (Test-JsonMcpConfigObjectHasServer -Config $target.Config -Name $entry.Name) {
                        $targets.Add($target.Name)
                        if (-not (Test-JsonMcpConfigObjectServerInSync -Config $target.Config -Entry $entry)) {
                            $updateTargets.Add($target.Name)
                        }
                    }
                }
                if ($claudeCodeServers.ContainsKey($entry.Name)) {
                    $targets.Add('Claude Code')
                }
                $mcpProgressPercent = if ($mcpEntries.Count -gt 0) { [int]((($i + 1) * 100) / $mcpEntries.Count) } else { 100 }
                $mcpProgressDetail = (ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogTUNQIOW3suWujOaIkA==') -f ($i + 1), $mcpEntries.Count
                Write-OperationProgress -Label 'MCP' -Percent $mcpProgressPercent -Detail $mcpProgressDetail -Completed:(($i + 1) -ge $mcpEntries.Count)
                [pscustomobject]@{
                    Name            = $entry.Name
                    Configured      = $targets.Count -gt 0
                    UpdateAvailable = $updateTargets.Count -gt 0
                    UpdateKnown     = $true
                    Targets         = $targets.ToArray()
                    UpdateTargets   = $updateTargets.ToArray()
                }
            }
        )
        if ($mcpEntries.Count -eq 0) {
            Write-OperationProgress -Label 'MCP' -Percent 100 -Detail ((ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogTUNQIOW3suWujOaIkA==') -f 0, 0) -Completed
        }
    }

    $prereqEntries = @($inventory.Prereqs)
    $prereqStatus = @()
    if ($scanPrereqs) {
        Write-OperationProgress -Label 'CLI' -Percent 0 -Detail ((ConvertFrom-Utf8Base64String -Value 'MC97MH0g5LiqIENMSSDlvIDlp4vmo4Dmn6U=') -f $prereqEntries.Count)
        $prereqStatus = @(
            for ($i = 0; $i -lt $prereqEntries.Count; $i++) {
                $entry = $prereqEntries[$i]
                $cliProgressPercent = if ($prereqEntries.Count -gt 0) { [int]((($i + 1) * 100) / $prereqEntries.Count) } else { 100 }
                $cliProgressDetail = (ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogQ0xJIOW3suWujOaIkA==') -f ($i + 1), $prereqEntries.Count
                Write-OperationProgress -Label 'CLI' -Percent $cliProgressPercent -Detail $cliProgressDetail -Completed:(($i + 1) -ge $prereqEntries.Count)
                $installed = Test-RegistryCommandSucceeded -CommandText $entry.Check
                if ((-not $installed) -and $entry.Name -eq 'lark' -and (Get-Command lark-cli -ErrorAction SilentlyContinue)) {
                    $installed = $true
                }
                [pscustomobject]@{
                    Name            = $entry.Name
                    Kind            = $entry.Kind
                    Installed       = $installed
                    UpdateAvailable = $false
                    UpdateKnown     = $false
                }
            }
        )
    }

    return [pscustomobject]@{
        Profiles       = @($inventory.Profiles)
        Skills         = $skillStatus
        Mcp            = $mcpStatus
        Prereqs        = $prereqStatus
        BundleSkills   = @($inventory.BundleSkills)
        RegistrySkills = @($inventory.RegistrySkills)
        McpAssets      = @($inventory.McpAssets)
        PrereqAssets   = @($inventory.PrereqAssets)
    }
}

function Expand-ProfileSkillReferences {
    param(
        [string[]]$SkillNames = @(),
        [string[]]$SkillDirectories = @()
    )

    $expanded = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $dirsByName = @{}
    $dirsByRegistryEntry = @{}

    foreach ($skillDir in @($SkillDirectories)) {
        $skillName = Split-Path -Leaf $skillDir
        if ([string]::IsNullOrWhiteSpace($skillName)) {
            continue
        }

        $dirsByName[$skillName.ToLowerInvariant()] = $skillName
        $metaPath = Join-Path $skillDir '.skill-meta.json'
        if (Test-Path -LiteralPath $metaPath) {
            try {
                $meta = Get-Content -Raw -Encoding UTF8 -LiteralPath $metaPath | ConvertFrom-Json
                $entryName = [string](Get-ObjectPropertyValue -Object $meta -Name 'registry_entry_name')
                if (-not [string]::IsNullOrWhiteSpace($entryName)) {
                    $entryKey = $entryName.ToLowerInvariant()
                    if (-not $dirsByRegistryEntry.ContainsKey($entryKey)) {
                        $dirsByRegistryEntry[$entryKey] = New-Object System.Collections.Generic.List[string]
                    }
                    $dirsByRegistryEntry[$entryKey].Add($skillName)
                }
            }
            catch {
            }
        }
    }

    foreach ($skillName in @($SkillNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)) {
        $key = $skillName.ToLowerInvariant()
        $matched = $false

        if ($dirsByName.ContainsKey($key)) {
            $name = [string]$dirsByName[$key]
            if (-not $seen.ContainsKey($name.ToLowerInvariant())) {
                $expanded.Add($name)
                $seen[$name.ToLowerInvariant()] = $true
            }
            $matched = $true
        }

        if ($dirsByRegistryEntry.ContainsKey($key)) {
            foreach ($name in @($dirsByRegistryEntry[$key])) {
                if (-not $seen.ContainsKey($name.ToLowerInvariant())) {
                    $expanded.Add($name)
                    $seen[$name.ToLowerInvariant()] = $true
                }
            }
            $matched = $true
        }

        if (-not $matched -and -not $seen.ContainsKey($key)) {
            $expanded.Add($skillName)
            $seen[$key] = $true
        }
    }

    return @($expanded)
}

function Get-SkillProfileComponentSummary {
    param(
        [object[]]$Profiles = @(),
        [string]$RegistryRoot,
        [string[]]$SkillDirectories = @()
    )

    $skillRefs = @($Profiles | ForEach-Object { $_.Skills } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $skills = if (@($SkillDirectories).Count -gt 0) {
        @(Expand-ProfileSkillReferences -SkillNames $skillRefs -SkillDirectories $SkillDirectories)
    }
    else {
        @($skillRefs)
    }
    $mcp = @($Profiles | ForEach-Object { $_.Mcp } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $prereqs = @()
    if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) {
        $prereqs = @(Get-ProfilePrereqNames -RegistryRoot $RegistryRoot -SkillNames $skillRefs -McpNames $mcp)
    }
    else {
        $prereqs = @($Profiles | ForEach-Object { $_.Prereqs } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    }

    return [pscustomobject]@{
        SuiteCount = @($Profiles).Count
        SkillCount = $skills.Count
        McpCount   = $mcp.Count
        CliCount   = $prereqs.Count
    }
}

function Get-ConsoleDisplayWidth {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }

    $width = 0
    foreach ($character in $Text.ToCharArray()) {
        if ([int][char]$character -gt 127) {
            $width += 2
        }
        else {
            $width += 1
        }
    }
    return $width
}

function ConvertTo-TruncatedConsoleText {
    param(
        [AllowNull()]
        [string]$Text,
        [int]$MaxWidth = 80
    )

    if ([string]::IsNullOrEmpty($Text) -or $MaxWidth -le 0) {
        return ''
    }
    if ((Get-ConsoleDisplayWidth -Text $Text) -le $MaxWidth) {
        return $Text
    }
    if ($MaxWidth -le 3) {
        return '...'.Substring(0, [Math]::Max(0, $MaxWidth))
    }

    $builder = New-Object System.Text.StringBuilder
    $currentWidth = 0
    $targetWidth = $MaxWidth - 3
    foreach ($character in $Text.ToCharArray()) {
        $characterWidth = if ([int][char]$character -gt 127) { 2 } else { 1 }
        if (($currentWidth + $characterWidth) -gt $targetWidth) {
            break
        }
        [void]$builder.Append($character)
        $currentWidth += $characterWidth
    }
    return ('{0}...' -f $builder.ToString())
}

function Get-SkillProfilePromptLineWidth {
    try {
        $width = [int]$Host.UI.RawUI.WindowSize.Width
        if ($width -ge 60) {
            return $width
        }
    }
    catch {
    }
    return 120
}

function Write-SkillProfilePromptOption {
    param(
        [Parameter(Mandatory)]
        [string]$Index,
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Description,
        [int]$SuiteCount = 0,
        [int]$SkillCount = 0,
        [int]$McpCount = 0,
        [int]$CliCount = 0
    )

    $prefix = ' {0,2}. ' -f $Index
    Write-Host ('{0}{1}' -f $prefix, $Name) -NoNewline
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $lineWidth = Get-SkillProfilePromptLineWidth
        $usedWidth = (Get-ConsoleDisplayWidth -Text ('{0}{1}' -f $prefix, $Name)) + 4
        $descriptionWidth = [Math]::Max(12, $lineWidth - $usedWidth)
        $displayDescription = ConvertTo-TruncatedConsoleText -Text $Description -MaxWidth $descriptionWidth
        Write-Host ('{0}{1}{2}' -f [char]0xFF08, $displayDescription, [char]0xFF09) -ForegroundColor DarkGray
    }
    else {
        Write-Host ''
    }

    Write-Host '     ' -NoNewline
    Write-Host ('Skill {0}' -f $SkillCount) -ForegroundColor Green -NoNewline
    Write-Host ([string][char]0xFF1B) -ForegroundColor DarkGray -NoNewline
    Write-Host ('MCP {0}' -f $McpCount) -ForegroundColor Cyan -NoNewline
    Write-Host ([string][char]0xFF1B) -ForegroundColor DarkGray -NoNewline
    Write-Host ('CLI {0}' -f $CliCount) -ForegroundColor Yellow
}

function Format-RegistryComponentPreview {
    param(
        [string[]]$Values = @(),
        [int]$MaxItems = 8
    )

    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($items.Count -eq 0) {
        return ConvertFrom-Utf8Base64String -Value '5peg'
    }

    $visible = @($items | Select-Object -First $MaxItems)
    $text = $visible -join ', '
    if ($items.Count -gt $MaxItems) {
        $text = '{0} ... {1}' -f $text, ((ConvertFrom-Utf8Base64String -Value '562JIHswfSDkuKo=') -f $items.Count)
    }
    return $text
}

function Write-SelectedProfileComponentPreview {
    param(
        [string[]]$Mcp = @(),
        [string[]]$Prereqs = @()
    )

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bCG5a6J6KOFIE1DUO+8mnswfQ==') -f (Format-RegistryComponentPreview -Values $Mcp))
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bCG5aSE55CGIENMSSDkvp3otZbvvJp7MH0=') -f (Format-RegistryComponentPreview -Values $Prereqs))
}

function Resolve-AllSkillSelection {
    param(
        [Parameter(Mandatory)]
        [string[]]$SkillDirectories,
        [string]$RegistryRoot
    )

    $registrySkillEntries = if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) { @(Read-RegistrySkillEntries -RegistryRoot $RegistryRoot) } else { @() }
    $wantedSkills = if ($registrySkillEntries.Count -gt 0) {
        @($registrySkillEntries | ForEach-Object { $_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    }
    else {
        @($SkillDirectories | ForEach-Object { Split-Path -Leaf $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
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
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6QIHByb2ZpbGUg5p2h55uuIHswfSDml7YgLnNraWxsLW1ldGEuanNvbiDml6DmlYjvvJp7MX0=') -f $skillName, $_.Exception.Message)
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

    $effectiveSkillCount = [Math]::Max($wantedSkills.Count, ($selectedSkillDirs.Count + $missingSkills.Count))
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5YWo6YOoIFNraWxs77yaezB9IOS4qu+8m01DUO+8mjAg5Liq77ybQ0xJ77yaMCDkuKo=') -f $effectiveSkillCount)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHNraWxs77yaezB9L3sxfQ==') -f $selectedSkillDirs.Count, $SkillDirectories.Count)
    if ($missingSkills.Count -gt 0) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bCG5oyJIGV4dGVybmFsIOadpea6kOWuieijheeahCBTa2lsbO+8mnswfQ==') -f ($missingSkills -join ', '))
    }
    Write-SelectedProfileComponentPreview -Mcp @() -Prereqs @()
    $script:LastSkillSelection = [pscustomobject]@{
        RegistryRoot     = $RegistryRoot
        Profiles         = @()
        WantedSkills     = @($wantedSkills)
        BundledSkillDirs = @($selectedSkillDirs)
        MissingSkills    = @($missingSkills)
        Mcp              = @()
        Prereqs          = @()
    }
    return @($selectedSkillDirs)
}

function Select-SkillDirectoriesForProfiles {
    param(
        [Parameter(Mandatory)]
        [string[]]$SkillDirectories,
        [object[]]$Profiles,
        [string[]]$RequestedProfiles,
        [string]$RegistryRoot,
        [switch]$AllSkills,
        [switch]$AllSuites
    )

    if ($AllSkills) {
        return @(Resolve-AllSkillSelection -SkillDirectories $SkillDirectories -RegistryRoot $RegistryRoot)
    }

    if (-not $Profiles -or $Profiles.Count -eq 0) {
        return @(Resolve-AllSkillSelection -SkillDirectories $SkillDirectories -RegistryRoot $RegistryRoot)
    }

    $tokens = @(Split-SelectionTokens -Values $RequestedProfiles)
    if ($tokens -contains '__ALL_SUITES__') {
        $AllSuites = $true
        $tokens = @($tokens | Where-Object { $_ -ne '__ALL_SUITES__' })
    }
    if ($tokens.Count -eq 0 -and -not $AllSuites -and -not (Test-InteractiveConsole)) {
        Write-Log -Message (ConvertFrom-Utf8Base64String -Value '5pyq5qOA5rWL5Yiw5Lqk5LqS5byP57uI56uv77yM5a6J6KOFIHJlZ2lzdHJ5IOWFqOmDqCBTa2lsbA==')
        return @(Resolve-AllSkillSelection -SkillDirectories $SkillDirectories -RegistryRoot $RegistryRoot)
    }

    if ($tokens.Count -eq 0) {
        Write-CodexProviderInputSection `
            -Title (ConvertFrom-Utf8Base64String -Value '6L6T5YWl5Yy6')
        Write-Host ('  {0}' -f (ConvertFrom-Utf8Base64String -Value '6K+36YCJ5oup6KaB5a6J6KOF55qE5o+S5Lu25aWX5Lu244CC')) -ForegroundColor DarkGray
        Write-Host ('  {0}' -f (ConvertFrom-Utf8Base64String -Value '5Y+v6L6T5YWl5bqP5Y+35oiW5ZCN56ew77yM5aSa5Liq55So6Iux5paH6YCX5Y+344CB5Lit5paH6YCX5Y+35oiW6aG/5Y+35YiG6ZqU77yb')) -ForegroundColor DarkGray
        Write-Host ('  {0}' -f (ConvertFrom-Utf8Base64String -Value '6L6T5YWlIDAg5a6J6KOF5YWo6YOoIFNraWxs77yb6L6T5YWlIDAwIOWuieijheaJgOacieWll+S7tu+8mw==')) -ForegroundColor DarkGray
        Write-Host ('  {0}' -f (ConvertFrom-Utf8Base64String -Value '5LiN5aGr55u05o6l5Zue6L2m5YiZ6Lez6L+H5o+S5Lu25a6J6KOF44CC')) -ForegroundColor DarkGray
        Write-Host ''
        $allSuitesSummary = Get-SkillProfileComponentSummary -Profiles $Profiles -RegistryRoot $RegistryRoot -SkillDirectories $SkillDirectories
        $registrySkillCount = if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) { (@(Read-RegistrySkillEntries -RegistryRoot $RegistryRoot)).Count } else { 0 }
        $allSkillPromptCount = @($SkillDirectories.Count, $registrySkillCount, $allSuitesSummary.SkillCount) | Measure-Object -Maximum | ForEach-Object { [int]$_.Maximum }
        Write-SkillProfilePromptOption `
            -Index '0' `
            -Name (ConvertFrom-Utf8Base64String -Value '5YWo6YOoIFNraWxs') `
            -Description (ConvertFrom-Utf8Base64String -Value '5a6J6KOFIHJlZ2lzdHJ5IOWFqOmDqCBTa2lsbO+8jOS4jeWuieijhSBNQ1AgLyBDTEnjgII=') `
            -SkillCount $allSkillPromptCount `
            -McpCount 0 `
            -CliCount 0
        Write-SkillProfilePromptOption `
            -Index '00' `
            -Name (ConvertFrom-Utf8Base64String -Value '5omA5pyJ5aWX5Lu2') `
            -Description (ConvertFrom-Utf8Base64String -Value 'UHJvZmlsZSDlubbpm4bvvJrlronoo4XmiYDmnInlpZfku7blvJXnlKjnmoQgU2tpbGzjgIFNQ1Ag5ZKMIENMSSDliY3nva7kvp3otZY=') `
            -SuiteCount $allSuitesSummary.SuiteCount `
            -SkillCount $allSuitesSummary.SkillCount `
            -McpCount $allSuitesSummary.McpCount `
            -CliCount $allSuitesSummary.CliCount
        for ($index = 0; $index -lt $Profiles.Count; $index++) {
            $profile = $Profiles[$index]
            $profileSummary = Get-SkillProfileComponentSummary -Profiles @($profile) -RegistryRoot $RegistryRoot -SkillDirectories $SkillDirectories
            Write-SkillProfilePromptOption `
                -Index ([string]($index + 1)) `
                -Name $profile.Name `
                -Description $profile.Description `
                -SkillCount $profileSummary.SkillCount `
                -McpCount $profileSummary.McpCount `
                -CliCount $profileSummary.CliCount
        }

        $answer = Read-Host (ConvertFrom-Utf8Base64String -Value 'UHJvZmlsZQ==')
        $tokens = @(Split-SelectionTokens -Values @($answer))
        if ($tokens.Count -eq 0) {
            Write-Log -Message (ConvertFrom-Utf8Base64String -Value '5pyq6YCJ5oupIFByb2ZpbGXvvIzlt7Lot7Pov4cgU2tpbGwg5a+85YWl44CC')
            $script:LastSkillSelection = [pscustomobject]@{
                RegistryRoot     = $RegistryRoot
                Profiles         = @()
                WantedSkills     = @()
                BundledSkillDirs = @()
                MissingSkills    = @()
                Mcp              = @()
                Prereqs          = @()
            }
            return @()
        }
        if ($tokens -contains '0') {
            return @(Resolve-AllSkillSelection -SkillDirectories $SkillDirectories -RegistryRoot $RegistryRoot)
        }
        if ($tokens -contains '00') {
            $AllSuites = $true
        }
    }

    $selectedProfiles = New-Object System.Collections.Generic.List[object]
    if ($AllSuites) {
        foreach ($profile in @($Profiles)) {
            $selectedProfiles.Add($profile)
        }
    }
    else {
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
                throw ((ConvertFrom-Utf8Base64String -Value '5pyq55+lIHNraWxsIHByb2ZpbGXvvJp7MH0=') -f $token)
            }

            $selectedProfiles.Add($matched)
        }
    }

    $wantedSkills = @($selectedProfiles | ForEach-Object { $_.Skills } | Sort-Object -Unique)
    $wantedMcp = @($selectedProfiles | ForEach-Object { $_.Mcp } | Sort-Object -Unique)
    $wantedPrereqs = @()
    if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) {
        $wantedPrereqs = @(Get-ProfilePrereqNames -RegistryRoot $RegistryRoot -SkillNames $wantedSkills -McpNames $wantedMcp)
    }

    if ($wantedSkills.Count -eq 0) {
        Write-Log -Level 'WARN' -Message (ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHByb2ZpbGUg5rKh5pyJ5byV55So5Lu75L2VIHNraWxs77yM5bey6Lez6L+HIFNraWxsIOWvvOWFpeOAgg==')
        return @()
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
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6QIHByb2ZpbGUg5p2h55uuIHswfSDml7YgLnNraWxsLW1ldGEuanNvbiDml6DmlYjvvJp7MX0=') -f $skillName, $_.Exception.Message)
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
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'cHJvZmlsZSDlvJXnlKjnmoQgc2tpbGwg5LiN5ZyoIGJ1bmRsZSDkuK3vvJp7MH0=') -f ($missingSkills -join ', '))
    }

    $selectedProfileNames = if ($AllSuites) { ConvertFrom-Utf8Base64String -Value '5omA5pyJ5aWX5Lu2' } else { @($selectedProfiles | ForEach-Object { $_.Name }) -join ', ' }
    $mcpDetail = if ($wantedMcp.Count -gt 0) { $wantedMcp -join ', ' } else { '(none)' }
    $prereqDetail = if ($wantedPrereqs.Count -gt 0) { $wantedPrereqs -join ', ' } else { '(none)' }
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHByb2ZpbGXvvJp7MH0=') -f $selectedProfileNames)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qE5aWX5Lu277yaezB9IOS4qu+8m1NraWxs77yaezF9IOS4qu+8m01DUO+8mnsyfSDkuKrvvJtDTEnvvJp7M30g5Liq') -f $selectedProfiles.Count, $wantedSkills.Count, $wantedMcp.Count, $wantedPrereqs.Count)
    Write-SelectedProfileComponentPreview -Mcp $wantedMcp -Prereqs $wantedPrereqs
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHNraWxs77yaezB9L3sxfQ==') -f $selectedSkillDirs.Count, $SkillDirectories.Count)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIE1DUO+8mnswfQ==') -f $mcpDetail)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6Q5Yiw55qE5YmN572u5L6d6LWW77yaezB9') -f $prereqDetail)

    $script:LastSkillSelection = [pscustomobject]@{
        RegistryRoot     = $RegistryRoot
        Profiles         = @($selectedProfiles | ForEach-Object { $_.Name })
        WantedSkills     = @($wantedSkills)
        BundledSkillDirs = @($selectedSkillDirs)
        MissingSkills    = @($missingSkills)
        Mcp              = @($wantedMcp)
        Prereqs          = @($wantedPrereqs)
    }

    return @($selectedSkillDirs)
}

function Select-SkillDirectoriesForExplicitSelection {
    param(
        [Parameter(Mandatory)]
        [string[]]$SkillDirectories,
        [string]$RegistryRoot,
        [string[]]$SkillNames,
        [string[]]$McpNames,
        [string[]]$PrereqNames
    )

    $wantedSkills = @(Split-SelectionTokens -Values $SkillNames | Sort-Object -Unique)
    $wantedMcp = @(Split-SelectionTokens -Values $McpNames | Sort-Object -Unique)
    $directPrereqs = @(Split-SelectionTokens -Values $PrereqNames | Sort-Object -Unique)
    $wantedPrereqs = @($directPrereqs)
    if (-not [string]::IsNullOrWhiteSpace($RegistryRoot)) {
        $wantedPrereqs += @(Get-ProfilePrereqNames -RegistryRoot $RegistryRoot -SkillNames $wantedSkills -McpNames $wantedMcp)
    }
    $wantedPrereqs = @($wantedPrereqs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

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
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6QIHNraWxsIG1ldGEg5aSx6LSl77yaezB9OyB7MX0=') -f $skillName, $_.Exception.Message)
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
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5Y2V6aG56YCJ5oup55qEIHNraWxsIOS4jeWcqOemu+e6vyBidW5kbGUg5Lit77yM5bCG5bCd6K+V5oyJIGV4dGVybmFsIOadpea6kOWkhOeQhu+8mnswfQ==') -f ($missingSkills -join ', '))
    }
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5Y2V6aG56YCJ5oup77yaU2tpbGwgezB9IOS4qu+8m01DUCB7MX0g5Liq77ybQ0xJIHsyfSDkuKo=') -f $wantedSkills.Count, $wantedMcp.Count, $wantedPrereqs.Count)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHNraWxs77yaezB9L3sxfQ==') -f $selectedSkillDirs.Count, $SkillDirectories.Count)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIE1DUO+8mnswfQ==') -f ($(if ($wantedMcp.Count -gt 0) { $wantedMcp -join ', ' } else { '(none)' })))
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6Q5Yiw55qE5YmN572u5L6d6LWW77yaezB9') -f ($(if ($wantedPrereqs.Count -gt 0) { $wantedPrereqs -join ', ' } else { '(none)' })))

    $script:LastSkillSelection = [pscustomobject]@{
        RegistryRoot     = $RegistryRoot
        Profiles         = @()
        WantedSkills     = @($wantedSkills)
        BundledSkillDirs = @($selectedSkillDirs)
        MissingSkills    = @($missingSkills)
        Mcp              = @($wantedMcp)
        Prereqs          = @($wantedPrereqs)
    }

    return @($selectedSkillDirs)
}

function Get-OptionalSkillTargets {
    $homeDir = Get-UserHomeDirectory
    $targets = New-Object System.Collections.Generic.List[object]

    $targets.Add([pscustomobject]@{
            Name    = 'codex'
            Path    = Join-Path $homeDir '.codex\skills'
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
                Name    = $target.Name
                Path    = $target.Path
                Enabled = (Test-Path -LiteralPath $target.Root)
            })
    }

    return $targets.ToArray()
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
            Available             = $true
            LaunchedSkillsManager = $false
        }
    }

    if ($DryRun -or [string]::IsNullOrWhiteSpace($SkillsManagerExe)) {
        return [pscustomobject]@{
            Available             = $false
            LaunchedSkillsManager = $false
        }
    }

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'c2tpbGxzLW1hbmFnZXIgREIg5bCa5LiN5a2Y5Zyo77yM5q2j5Zyo5ZCv5YqoIFNraWxscyBNYW5hZ2VyIOWIneWni+WMlu+8mnswfQ==') -f $SkillsManagerExe)
    Start-Process -FilePath $SkillsManagerExe | Out-Null

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $DbPath) {
            return [pscustomobject]@{
                Available             = $true
                LaunchedSkillsManager = $true
            }
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    return [pscustomobject]@{
        Available             = (Test-Path -LiteralPath $DbPath)
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
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'ezB9IOeahCAuc2tpbGwtbWV0YS5qc29uIOaXoOaViO+8jOWbnumAgOS4uuacrOWcsOadpea6kO+8mnsxfQ==') -f $SkillName, $_.Exception.Message)
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
        Name              = $SkillName
        Description       = ''
        SourceType        = $sourceType
        SourceRef         = $sourceRef
        SourceSubpath     = $sourceSubpath
        SourceBranch      = $sourceBranch
        SourceRevision    = $sourceRevision
        RegistryEntryName = $registryEntryName
        CentralPath       = $CentralPath
    }
}

function Resolve-SkillsManagerScenarioSelection {
    param(
        [ValidateSet('prompt', 'default', 'custom', 'skip')]
        [string]$Mode = 'prompt',
        [string]$Name
    )

    $resolvedMode = if ([string]::IsNullOrWhiteSpace($Mode)) { 'prompt' } else { $Mode }
    $resolvedName = $Name
    if ($resolvedMode -eq 'prompt') {
        if (Test-InteractiveConsole) {
            Write-Host ''
            Write-Host (ConvertFrom-Utf8Base64String -Value '6K+36YCJ5oup5a+85YWlIFNraWxsIOWQjuWmguS9leWGmeWFpSBTa2lsbHMgTWFuYWdlciDlnLrmma/vvJo=')
            Write-Host ('  1. {0}' -f (ConvertFrom-Utf8Base64String -Value '6buY6K6k5Zy65pmv77yI5b2T5YmN5ZCv55So77yJ'))
            Write-Host ('  2. {0}' -f (ConvertFrom-Utf8Base64String -Value '6Ieq5a6a5LmJ5Zy65pmv'))
            Write-Host ('  3. {0}' -f (ConvertFrom-Utf8Base64String -Value '6Lez6L+H5Zy65pmv5rOo5YaM77yI5Y+q5aSN5Yi2IFNraWxsIOaWh+S7tu+8iQ=='))
            $answer = Read-Host (ConvertFrom-Utf8Base64String -Value 'U2tpbGxzIE1hbmFnZXIg5Zy65pmv')
            switch ($answer.Trim()) {
                '1' { $resolvedMode = 'default' }
                '2' { $resolvedMode = 'custom' }
                default { $resolvedMode = 'skip' }
            }
        }
        else {
            $resolvedMode = 'skip'
        }
    }

    if ($resolvedMode -eq 'custom') {
        if ([string]::IsNullOrWhiteSpace($resolvedName)) {
            $resolvedName = ConvertFrom-Utf8Base64String -Value 'SW5kaWVBcmsgU2tpbGxz'
            if (Test-InteractiveConsole) {
                $answer = Read-Host ('{0} [{1}]' -f (ConvertFrom-Utf8Base64String -Value '6Ieq5a6a5LmJ5Zy65pmv5ZCN56ew'), $resolvedName)
                if (-not [string]::IsNullOrWhiteSpace($answer)) {
                    $resolvedName = $answer.Trim()
                }
            }
        }
    }

    return [pscustomobject]@{
        Mode = $resolvedMode
        Name = $resolvedName
    }
}

function Sync-SkillsManagerRegistry {
    param(
        [Parameter(Mandatory)]
        [object[]]$ImportedSkills,
        [switch]$SkipSkillsManagerLaunch,
        [ValidateSet('prompt', 'default', 'custom', 'skip')]
        [string]$ScenarioMode = 'prompt',
        [string]$ScenarioName,
        [switch]$DryRun
    )

    if ($ImportedSkills.Count -eq 0) {
        return
    }

    $scenarioSelection = Resolve-SkillsManagerScenarioSelection -Mode $ScenarioMode -Name $ScenarioName
    if ($scenarioSelection.Mode -eq 'skip') {
        Write-Log -Message (ConvertFrom-Utf8Base64String -Value '6Lez6L+HIFNraWxscyBNYW5hZ2VyIOWcuuaZr+azqOWGjO+8m+S7heWkjeWItiBTa2lsbCDmlofku7bjgII=')
        return [pscustomobject]@{
            Synchronized          = $false
            LaunchedSkillsManager = $false
        }
    }

    if ($DryRun) {
        $scenarioText = if ($scenarioSelection.Mode -eq 'custom') { (ConvertFrom-Utf8Base64String -Value '5YaZ5YWl6Ieq5a6a5LmJ5Zy65pmv77yaezB9') -f $scenarioSelection.Name } else { ConvertFrom-Utf8Base64String -Value '5YaZ5YWl6buY6K6k5Zy65pmv' }
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5rOo5YaMIHswfSDkuKogc2tpbGwg5YiwIHNraWxscy1tYW5hZ2VyIERC') -f $ImportedSkills.Count)
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIFNraWxscyBNYW5hZ2VyIOWcuuaZr++8mnswfQ==') -f $scenarioText)
        return
    }

    Update-CurrentProcessPath
    $python = Get-PythonLauncher
    if (-not $python) {
        Write-Log -Level 'WARN' -Message (ConvertFrom-Utf8Base64String -Value '5pys5qyhIFB5dGhvbiDov5jkuI3lj6/nlKjvvIzot7Pov4cgc2tpbGxzLW1hbmFnZXIgREIg5ZCM5q2l')
        return
    }

    $homeDir = Get-UserHomeDirectory
    $dbPath = Join-Path $homeDir '.skills-manager\skills-manager.db'
    $skillsManagerExe = if ($SkipSkillsManagerLaunch) { $null } else { Get-InstalledSkillsManagerExecutable }
    $dbState = Initialize-SkillsManagerDatabase -DbPath $dbPath -SkillsManagerExe $skillsManagerExe -DryRun:$DryRun
    if (-not $dbState.Available) {
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '5om+5LiN5YiwIHNraWxscy1tYW5hZ2VyIERC77yM6Lez6L+H5rOo5YaM5ZCM5q2l77yaezB9') -f $dbPath)
        return [pscustomobject]@{
            Synchronized          = $false
            LaunchedSkillsManager = $dbState.LaunchedSkillsManager
        }
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-registry-' + [guid]::NewGuid().ToString('N'))
    Initialize-Directory -Path $tempRoot

    $payloadPath = Join-Path $tempRoot 'skills.json'
    $scriptPath = Join-Path $tempRoot 'sync_skills_manager_registry.py'
    $payloadJson = @{
        skills   = $ImportedSkills
        scenario = @{
            mode = $scenarioSelection.Mode
            name = $scenarioSelection.Name
        }
    } | ConvertTo-Json -Depth 8
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
scenario = payload.get('scenario') or {}
scenario_mode = scenario.get('mode') or 'skip'
scenario_name = (scenario.get('name') or '').strip()

if scenario_mode == 'default':
    active = cur.execute("SELECT scenario_id FROM active_scenario WHERE key='current'").fetchone()
    if active:
        scenario_id = active[0]
    else:
        first = cur.execute("SELECT id FROM scenarios ORDER BY created_at ASC LIMIT 1").fetchone()
        if not first:
            raise RuntimeError('No scenario found in skills-manager.db')
        scenario_id = first[0]
elif scenario_mode == 'custom':
    if not scenario_name:
        scenario_name = 'IndieArk Skills'
    existing_scenario = cur.execute("SELECT id FROM scenarios WHERE name=? LIMIT 1", (scenario_name,)).fetchone()
    if existing_scenario:
        scenario_id = existing_scenario[0]
        cur.execute("UPDATE scenarios SET updated_at=? WHERE id=?", (now, scenario_id))
    else:
        scenario_id = str(uuid.uuid4())
        max_sort = cur.execute("SELECT COALESCE(MAX(sort_order), 0) FROM scenarios").fetchone()[0] or 0
        cur.execute(
            "INSERT INTO scenarios (id, name, description, icon, sort_order, created_at, updated_at) VALUES (?, ?, NULL, 'code-2', ?, ?, ?)",
            (scenario_id, scenario_name, int(max_sort) + 1, now, now)
        )
else:
    scenario_id = None

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

    if scenario_id:
        cur.execute(
            "INSERT OR REPLACE INTO scenario_skills (scenario_id, skill_id, added_at) VALUES (?, ?, ?)",
            (scenario_id, skill_id, now)
        )
        cur.execute("DELETE FROM scenario_skill_tools WHERE scenario_id=? AND skill_id=?", (scenario_id, skill_id))
    cur.execute("DELETE FROM skill_targets WHERE skill_id=?", (skill_id,))

    for target in skill.get('Targets', []):
        if scenario_id:
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
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'c2tpbGxzLW1hbmFnZXIg5rOo5YaM5ZCM5q2l5aSx6LSl77yM6YCA5Ye656CBPXswfQ==') -f $LASTEXITCODE)
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    return [pscustomobject]@{
        Synchronized          = $true
        LaunchedSkillsManager = $dbState.LaunchedSkillsManager
    }
}

function Import-SkillDirectoryToTargets {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        [Parameter(Mandatory)]
        [string]$SkillName,
        [Parameter(Mandatory)]
        [string]$CentralRoot,
        [Parameter(Mandatory)]
        [object[]]$Targets,
        [switch]$NoReplaceOrphan,
        [switch]$ReplaceForeign,
        [switch]$RenameForeign,
        [switch]$DryRun
    )

    $centralPath = Join-Path $CentralRoot $SkillName
    $centralDecision = Get-SkillImportDecision `
        -SourcePath $SourcePath `
        -DestinationPath $centralPath `
        -SkillName $SkillName `
        -NoReplaceOrphan:$NoReplaceOrphan `
        -ReplaceForeign:$ReplaceForeign `
        -RenameForeign:$RenameForeign

    [void](Invoke-SkillImportDecision -Decision $centralDecision -SourcePath $SourcePath -DryRun:$DryRun -Quiet)

    if ($centralDecision.Action -eq 'Skip' -and $centralDecision.State -in @('Orphan', 'Foreign')) {
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '6Lez6L+HIHNraWxs77ya546w5pyJ55uu5b2V54q25oCB5Li6IHswfe+8mnsxfQ==') -f $centralDecision.State, $centralDecision.FinalPath)
        return [pscustomobject]@{
            Imported      = $false
            Copied        = $false
            Metadata      = $null
            EffectiveName = $centralDecision.FinalName
            TargetCount   = 0
        }
    }

    $effectiveSkillName = $centralDecision.FinalName
    $effectiveCentralPath = $centralDecision.FinalPath
    $skillTargets = New-Object System.Collections.Generic.List[object]
    $targetChanged = $false
    $copySourcePath = if ((-not $DryRun) -and (Test-Path -LiteralPath $effectiveCentralPath)) { $effectiveCentralPath } else { $SourcePath }

    foreach ($target in $Targets | Where-Object { $_.Enabled }) {
        $targetPath = Join-Path $target.Path $effectiveSkillName
        $targetDecision = Get-SkillImportDecision `
            -SourcePath $SourcePath `
            -DestinationPath $targetPath `
            -SkillName $effectiveSkillName `
            -NoReplaceOrphan:$NoReplaceOrphan `
            -ReplaceForeign:$ReplaceForeign `
            -RenameForeign:$false
        [void](Invoke-SkillImportDecision -Decision $targetDecision -SourcePath $copySourcePath -DryRun:$DryRun -Quiet)

        if ($targetDecision.Action -ne 'Skip' -or $targetDecision.State -eq 'Tracked') {
            $skillTargets.Add([pscustomobject]@{
                    Tool = $target.Name
                    Path = $targetDecision.FinalPath
                })
        }

        if ($targetDecision.Action -ne 'Skip') {
            $targetChanged = $true
        }
    }

    $skillMetadata = Read-SkillMetadata -SkillPath $SourcePath -SkillName $effectiveSkillName -CentralPath $effectiveCentralPath
    $skillMetadata | Add-Member -MemberType NoteProperty -Name 'Targets' -Value $skillTargets -Force

    return [pscustomobject]@{
        Imported      = $true
        Copied        = -not ($centralDecision.Action -eq 'Skip' -and -not $targetChanged)
        Metadata      = $skillMetadata
        EffectiveName = $effectiveSkillName
        TargetCount   = $skillTargets.Count
        Action        = $centralDecision.Action
    }
}

function ConvertTo-GitHubUrl {
    param([string]$Repo)

    if ([string]::IsNullOrWhiteSpace($Repo)) {
        return ''
    }
    if ($Repo -match '^(https?://|git@)') {
        return $Repo
    }
    return 'https://github.com/{0}' -f $Repo
}

function Get-ExternalSkillSourceLabel {
    param([Parameter(Mandatory)][object]$Entry)

    if (-not [string]::IsNullOrWhiteSpace($Entry.Repo)) {
        $repoUrl = ConvertTo-GitHubUrl -Repo $Entry.Repo
        if (-not [string]::IsNullOrWhiteSpace($Entry.Subpath)) {
            return '{0}#{1}' -f $repoUrl, $Entry.Subpath
        }
        return $repoUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($Entry.ArchiveUrl)) {
        return $Entry.ArchiveUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($Entry.DownloadUrl)) {
        return $Entry.DownloadUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($Entry.LocalPath)) {
        return $Entry.LocalPath
    }
    if (-not [string]::IsNullOrWhiteSpace($Entry.Homepage)) {
        return $Entry.Homepage
    }
    return '(no source)'
}

function Resolve-RegistryLocalSkillPath {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot,
        [Parameter(Mandatory)]
        [string]$LocalPath
    )

    $expanded = [Environment]::ExpandEnvironmentVariables($LocalPath)
    if ([IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }
    return (Join-Path $RegistryRoot $expanded)
}

function Expand-ExternalSkillArchive {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    Initialize-Directory -Path $DestinationPath
    $lower = $ArchivePath.ToLowerInvariant()
    if ($lower.EndsWith('.zip')) {
        Expand-ZipArchiveWithProgress -ZipPath $ArchivePath -DestinationPath $DestinationPath
        return
    }

    if ($lower.EndsWith('.tar.gz') -or $lower.EndsWith('.tgz')) {
        $tar = Get-Command tar -ErrorAction SilentlyContinue
        if (-not $tar) {
            throw 'tar is required to extract external skill archive'
        }
        & $tar.Source -xzf $ArchivePath -C $DestinationPath
        if ($LASTEXITCODE -ne 0) {
            throw ('external skill archive extraction failed: {0}' -f $ArchivePath)
        }
        return
    }

    throw ('unsupported external skill archive: {0}' -f $ArchivePath)
}

function Invoke-GitCloneWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$GitPath,
        [Parameter(Mandatory)]
        [string[]]$CloneArgs,
        [int]$MaxAttempts = 2
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        & $GitPath @CloneArgs
        if ($LASTEXITCODE -eq 0) {
            return
        }
        if ($attempt -lt $MaxAttempts) {
            Write-Log -Level 'WARN' -Message ('git clone failed; retrying ({0}/{1})' -f $attempt, $MaxAttempts)
            Start-Sleep -Seconds 2
        }
    }

    throw ('git clone failed after {0} attempts' -f $MaxAttempts)
}

function Write-ExternalSkillMeta {
    param(
        [Parameter(Mandatory)]
        [string]$SkillPath,
        [Parameter(Mandatory)]
        [object]$Entry,
        [string]$Revision
    )

    $meta = [ordered]@{
        name                 = $Entry.Name
        registry_entry_name  = $Entry.Name
        source_type          = if ([string]::IsNullOrWhiteSpace($Entry.SourceType)) { 'external' } else { $Entry.SourceType }
        source_ref           = Get-ExternalSkillSourceLabel -Entry $Entry
        source_subpath       = $Entry.Subpath
        source_branch        = $Entry.Branch
        source_revision      = $Revision
        registry_source_type = 'external'
    }
    $json = ($meta | ConvertTo-Json -Depth 5)
    [System.IO.File]::WriteAllText((Join-Path $SkillPath '.skill-meta.json'), ($json + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Resolve-ExternalSkillPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [object]$Entry
    )

    if (-not [string]::IsNullOrWhiteSpace($Entry.Subpath)) {
        return (Join-Path $RepoRoot $Entry.Subpath)
    }

    $direct = Join-Path $RepoRoot 'SKILL.md'
    if (Test-Path -LiteralPath $direct) {
        return $RepoRoot
    }

    $named = Join-Path $RepoRoot $Entry.Name
    if (Test-Path -LiteralPath (Join-Path $named 'SKILL.md')) {
        return $named
    }

    $skillFile = Get-ChildItem -LiteralPath $RepoRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($skillFile) {
        return $skillFile.Directory.FullName
    }

    return $null
}

function Import-ExternalSkillsFromSelection {
    param(
        [Parameter(Mandatory)]
        [object]$Selection,
        [Parameter(Mandatory)]
        [string]$CentralRoot,
        [Parameter(Mandatory)]
        [object[]]$Targets,
        [switch]$NoReplaceOrphan,
        [switch]$ReplaceForeign,
        [switch]$RenameForeign,
        [switch]$DryRun
    )

    $importedSkills = New-Object System.Collections.Generic.List[object]
    $copiedCount = 0
    $failedCount = 0
    $missingNames = @($Selection.MissingSkills | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($missingNames.Count -eq 0 -or [string]::IsNullOrWhiteSpace($Selection.RegistryRoot)) {
        return [pscustomobject]@{ ImportedSkills = @(); CopiedCount = 0; PlannedCount = 0; FailedCount = 0; RequiredPrereqs = @() }
    }

    $entries = @(Read-RegistrySkillEntries -RegistryRoot $Selection.RegistryRoot)
    $externalEntries = @($entries | Where-Object { $_.Section -eq 'external' -and ($missingNames -contains $_.Name) })
    $requiredPrereqs = New-Object System.Collections.Generic.List[string]
    if (@($externalEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Repo) }).Count -gt 0) {
        $requiredPrereqs.Add('git')
    }

    foreach ($entry in $externalEntries) {
        foreach ($required in @($entry.Requires)) {
            if (-not [string]::IsNullOrWhiteSpace($required)) {
                $requiredPrereqs.Add($required)
            }
        }

        $sourceLabel = Get-ExternalSkillSourceLabel -Entry $entry
        $hasAutoSource = (-not [string]::IsNullOrWhiteSpace($entry.Repo)) -or
        (-not [string]::IsNullOrWhiteSpace($entry.ArchiveUrl)) -or
        (-not [string]::IsNullOrWhiteSpace($entry.DownloadUrl)) -or
        (-not [string]::IsNullOrWhiteSpace($entry.LocalPath))

        if (-not $hasAutoSource) {
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'ZXh0ZXJuYWwgc2tpbGwg57y65bCRIHJlcG/vvIzml6Dms5Xoh6rliqjlronoo4XvvJp7MH0=') -f $entry.Name)
            continue
        }

        if ($DryRun) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5a6J6KOFIGV4dGVybmFsIHNraWxs77yaezB9IC0+IHsxfQ==') -f $entry.Name, $sourceLabel)
            $copiedCount++
            continue
        }

        $workRoot = $null
        try {
            $sourceRoot = $null
            $revision = ''

            if (-not [string]::IsNullOrWhiteSpace($entry.Repo)) {
                $git = Get-Command git -ErrorAction SilentlyContinue
                if (-not $git) {
                    throw (ConvertFrom-Utf8Base64String -Value '5a6J6KOFIGV4dGVybmFsIHNraWxsIOmcgOimgeWPr+eUqCBnaXQ=')
                }

                $repoUrl = ConvertTo-GitHubUrl -Repo $entry.Repo
                $workRoot = Join-Path ([IO.Path]::GetTempPath()) ('external-skill-' + [guid]::NewGuid().ToString('N'))
                $cloneArgs = @('clone', '--depth', '1')
                if (-not [string]::IsNullOrWhiteSpace($entry.Branch)) {
                    $cloneArgs += @('--branch', $entry.Branch)
                }
                $cloneArgs += @($repoUrl, $workRoot)
                Invoke-GitCloneWithRetry -GitPath $git.Source -CloneArgs $cloneArgs
                $sourceRoot = $workRoot
                $revision = (& $git.Source -C $workRoot rev-parse HEAD 2>$null | Select-Object -First 1)
            }
            elseif (-not [string]::IsNullOrWhiteSpace($entry.LocalPath)) {
                $sourceRoot = Resolve-RegistryLocalSkillPath -RegistryRoot $Selection.RegistryRoot -LocalPath $entry.LocalPath
                if (-not (Test-Path -LiteralPath $sourceRoot)) {
                    throw ('external skill local path not found: {0}' -f $sourceRoot)
                }
            }
            else {
                $archiveUrl = if (-not [string]::IsNullOrWhiteSpace($entry.ArchiveUrl)) { $entry.ArchiveUrl } else { $entry.DownloadUrl }
                $workRoot = Join-Path ([IO.Path]::GetTempPath()) ('external-skill-' + [guid]::NewGuid().ToString('N'))
                Initialize-Directory -Path $workRoot
                if ($archiveUrl -match '^https?://') {
                    $fileName = Split-Path -Leaf ([uri]$archiveUrl).AbsolutePath
                    if ([string]::IsNullOrWhiteSpace($fileName)) {
                        $fileName = 'archive.zip'
                    }
                    elseif ($fileName -notmatch '\.(zip|tar\.gz|tgz)$') {
                        $fileName = '{0}.zip' -f $fileName
                    }
                    $archivePath = Join-Path $workRoot $fileName
                    Invoke-DownloadFile -Url $archiveUrl -DestinationPath $archivePath
                }
                else {
                    $archivePath = Resolve-RegistryLocalSkillPath -RegistryRoot $Selection.RegistryRoot -LocalPath $archiveUrl
                }
                $sourceRoot = Join-Path $workRoot 'src'
                Expand-ExternalSkillArchive -ArchivePath $archivePath -DestinationPath $sourceRoot
            }

            $skillPath = Resolve-ExternalSkillPath -RepoRoot $sourceRoot -Entry $entry
            if ([string]::IsNullOrWhiteSpace($skillPath) -or -not (Test-Path -LiteralPath (Join-Path $skillPath 'SKILL.md'))) {
                throw ('SKILL.md not found in external skill source: {0}' -f $entry.Name)
            }

            Write-ExternalSkillMeta -SkillPath $skillPath -Entry $entry -Revision $revision
            $importResult = Import-SkillDirectoryToTargets `
                -SourcePath $skillPath `
                -SkillName $entry.Name `
                -CentralRoot $CentralRoot `
                -Targets $Targets `
                -NoReplaceOrphan:$NoReplaceOrphan `
                -ReplaceForeign:$ReplaceForeign `
                -RenameForeign:$RenameForeign `
                -DryRun:$DryRun

            if ($importResult.Imported) {
                $importedSkills.Add($importResult.Metadata)
            }
            if ($importResult.Copied) {
                $copiedCount++
            }
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'ZXh0ZXJuYWwgc2tpbGwg5bey5ZCM5q2l77yaezB977yb5Yqo5L2cPXsxfe+8m+ebruaghz17Mn0g5Liq') -f $entry.Name, $importResult.Action, $importResult.TargetCount)
        }
        catch {
            $failedCount++
            Write-Log -Level 'WARN' -Message ('external skill install failed: {0}; {1}' -f $entry.Name, $_.Exception.Message)
        }
        finally {
            if ($workRoot -and (Test-Path -LiteralPath $workRoot)) {
                Remove-Item -LiteralPath $workRoot -Recurse -Force
            }
        }
    }

    $unknownMissing = @($missingNames | Where-Object { $externalEntries.Name -notcontains $_ })
    foreach ($name in $unknownMissing) {
        Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'cHJvZmlsZSDlvJXnlKjnmoQgc2tpbGwg5peg5rOV5Yy56YWNIGJ1bmRsZSDmiJYgZXh0ZXJuYWzvvJp7MH0=') -f $name)
    }

    $importedSkillItems = $importedSkills.ToArray()
    $requiredPrereqItems = @($requiredPrereqs.ToArray() | Sort-Object -Unique)

    return [pscustomobject]@{
        ImportedSkills  = $importedSkillItems
        CopiedCount     = $copiedCount
        PlannedCount    = $externalEntries.Count
        FailedCount     = $failedCount
        RequiredPrereqs = $requiredPrereqItems
    }
}

function Install-SkillBundle {
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,
        [string[]]$SkillProfiles,
        [string[]]$SkillNames,
        [string[]]$McpNames,
        [string[]]$PrereqNames,
        [switch]$AllSkills,
        [switch]$AllSuites,
        [switch]$NoReplaceOrphan,
        [switch]$ReplaceForeign,
        [switch]$RenameForeign,
        [switch]$SkipSkillsManagerLaunch,
        [ValidateSet('prompt', 'default', 'custom', 'skip')]
        [string]$SkillsManagerScenarioMode = 'prompt',
        [string]$SkillsManagerScenarioName,
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw ((ConvertFrom-Utf8Base64String -Value '5om+5LiN5YiwIFNraWxsIGJ1bmRsZe+8mnswfQ==') -f $ZipPath)
    }

    $homeDir = Get-UserHomeDirectory
    $centralRoot = Join-Path $homeDir '.skills-manager\skills'
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('skills-bundle-' + [guid]::NewGuid().ToString('N'))
    $targets = Get-OptionalSkillTargets
    $importedSkills = New-Object System.Collections.Generic.List[object]
    $copiedSkillCount = 0

    try {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg5ZSv5LiA5p2l5rqQ55uu5b2V77yaezB9') -f $centralRoot)
        Initialize-Directory -Path $tempRoot
        Expand-ZipArchiveWithProgress -ZipPath $ZipPath -DestinationPath $tempRoot
        $allSkillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
        $registryRoot = Expand-BundleRegistryArchive -ExtractedBundleRoot $tempRoot -DestinationPath (Join-Path $tempRoot 'registry')
        $profiles = if ($registryRoot) { @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot) } else { @() }
        $explicitSkillNames = @(Split-SelectionTokens -Values $SkillNames)
        $explicitMcpNames = @(Split-SelectionTokens -Values $McpNames)
        $explicitPrereqNames = @(Split-SelectionTokens -Values $PrereqNames)
        $hasExplicitComponents = ($explicitSkillNames.Count + $explicitMcpNames.Count + $explicitPrereqNames.Count) -gt 0
        $skillDirs = if ($hasExplicitComponents) {
            @(Select-SkillDirectoriesForExplicitSelection -SkillDirectories $allSkillDirs -RegistryRoot $registryRoot -SkillNames $explicitSkillNames -McpNames $explicitMcpNames -PrereqNames $explicitPrereqNames)
        }
        else {
            $requestedProfiles = if ($AllSuites) { @($profiles | ForEach-Object { $_.Name }) } else { @($SkillProfiles) }
            @(Select-SkillDirectoriesForProfiles -SkillDirectories $allSkillDirs -Profiles $profiles -RequestedProfiles $requestedProfiles -RegistryRoot $registryRoot -AllSkills:$AllSkills -AllSuites:$AllSuites)
        }

        $selection = $script:LastSkillSelection
        $selectionHasWork = $hasExplicitComponents -or $AllSkills -or $AllSuites -or `
        (@($SkillProfiles).Count -gt 0) -or `
        ($selection -and (
                @($selection.WantedSkills).Count -gt 0 -or
                @($selection.MissingSkills).Count -gt 0 -or
                @($selection.Mcp).Count -gt 0 -or
                @($selection.Prereqs).Count -gt 0
            ))
        if (@($skillDirs).Count -eq 0 -and -not $selectionHasWork) {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5bey6Lez6L+HIFNraWxsIOWvvOWFpe+8m+emu+e6vyBidW5kbGUg5YyF5ZCrIHswfSDkuKogc2tpbGwg55uu5b2V77yM5pyq5aSE55CG44CC') -f @($allSkillDirs).Count)
        }
        else {
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5Y+R546wIHswfSDkuKogc2tpbGwg55uu5b2V77yb6YCJ5LitIHsxfSDkuKo=') -f @($allSkillDirs).Count, @($skillDirs).Count)
        }
        $featurePrereqs = @()
        if ($selection -and -not [string]::IsNullOrWhiteSpace($selection.RegistryRoot)) {
            $featurePrereqs += @($selection.Prereqs)
            if (@($selection.MissingSkills).Count -gt 0) {
                $registrySkillEntries = @(Read-RegistrySkillEntries -RegistryRoot $selection.RegistryRoot)
                $externalEntries = @($registrySkillEntries | Where-Object { $_.Section -eq 'external' -and ($selection.MissingSkills -contains $_.Name) })
                if ($externalEntries.Count -gt 0) {
                    if (@($externalEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Repo) }).Count -gt 0) {
                        $featurePrereqs += 'git'
                    }
                    foreach ($externalEntry in $externalEntries) {
                        $featurePrereqs += @($externalEntry.Requires)
                    }
                }
            }
            $null = Install-RegistryPrereqs -RegistryRoot $selection.RegistryRoot -PrereqNames $featurePrereqs -DryRun:$DryRun
        }

        $skillImportIndex = 0
        $skillImportTotal = @($skillDirs).Count
        foreach ($skillDir in $skillDirs) {
            $skillImportIndex++
            $skillName = Split-Path -Leaf $skillDir
            $skillImportPercent = if ($skillImportTotal -gt 0) { [int](($skillImportIndex * 100) / $skillImportTotal) } else { 100 }
            $skillImportDetail = (ConvertFrom-Utf8Base64String -Value 'ezB9L3sxfSDkuKogU2tpbGwg5bey5a6M5oiQ') -f $skillImportIndex, $skillImportTotal
            Write-OperationProgress -Label 'Skill' -Percent $skillImportPercent -Detail $skillImportDetail -Completed:($skillImportIndex -ge $skillImportTotal)
            $importResult = Import-SkillDirectoryToTargets `
                -SourcePath $skillDir `
                -SkillName $skillName `
                -CentralRoot $centralRoot `
                -Targets $targets `
                -NoReplaceOrphan:$NoReplaceOrphan `
                -ReplaceForeign:$ReplaceForeign `
                -RenameForeign:$RenameForeign `
                -DryRun:$DryRun

            if ($importResult.Imported) {
                $importedSkills.Add($importResult.Metadata)
            }

            if (-not $importResult.Copied) {
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg5bey6Lez6L+H77yaezB9') -f $importResult.EffectiveName)
                continue
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg5bey5ZCM5q2l77yaezB977yb5Yqo5L2cPXsxfe+8m+ebruaghz17Mn0g5Liq') -f $importResult.EffectiveName, $importResult.Action, $importResult.TargetCount)
            $copiedSkillCount++

        }

        if ($selection -and -not [string]::IsNullOrWhiteSpace($selection.RegistryRoot)) {
            $externalResult = Import-ExternalSkillsFromSelection `
                -Selection $selection `
                -CentralRoot $centralRoot `
                -Targets $targets `
                -NoReplaceOrphan:$NoReplaceOrphan `
                -ReplaceForeign:$ReplaceForeign `
                -RenameForeign:$RenameForeign `
                -DryRun:$DryRun

            foreach ($metadata in @($externalResult.ImportedSkills)) {
                $importedSkills.Add($metadata)
            }
            $copiedSkillCount += [int]$externalResult.CopiedCount

            Sync-RegistryMcpServers -RegistryRoot $selection.RegistryRoot -McpNames $selection.Mcp -DryRun:$DryRun
        }

        $registrySyncResult = $null
        if ($importedSkills.Count -gt 0) {
            $registrySyncResult = Sync-SkillsManagerRegistry -ImportedSkills $importedSkills -SkipSkillsManagerLaunch:$SkipSkillsManagerLaunch -ScenarioMode $SkillsManagerScenarioMode -ScenarioName $SkillsManagerScenarioName -DryRun:$DryRun
        }

        if (-not $DryRun -and -not $SkipSkillsManagerLaunch -and $importedSkills.Count -gt 0 -and $registrySyncResult -and $registrySyncResult.Synchronized) {
            $skillsManagerExe = Get-InstalledSkillsManagerExecutable
            $alreadyLaunchedForDbInit = ($null -ne $registrySyncResult -and $registrySyncResult.LaunchedSkillsManager)
            if ($skillsManagerExe -and -not $alreadyLaunchedForDbInit) {
                Write-Log -Message (ConvertFrom-Utf8Base64String -Value '5bey5a+85YWlIHNraWxsIOW5tuWQjOatpSBza2lsbHMtbWFuYWdlciBEQu+8m+ato+WcqOWQr+WKqCBTa2lsbHMgTWFuYWdlcg==')
                Start-Process -FilePath $skillsManagerExe | Out-Null
            }
        }

        $detail = if ($copiedSkillCount -gt 0) {
            (ConvertFrom-Utf8Base64String -Value '5bey5a+85YWlIHswfSDkuKogc2tpbGw=') -f $copiedSkillCount
        }
        elseif ($selection -and (@($selection.Mcp).Count + @($selection.Prereqs).Count) -gt 0) {
            (ConvertFrom-Utf8Base64String -Value '5bey5aSE55CGIFNraWxsIHswfSDkuKrvvJtNQ1AgezF9IOS4qu+8m0NMSSB7Mn0g5Liq') -f $copiedSkillCount, @($selection.Mcp).Count, @($selection.Prereqs).Count
        }
        elseif (@($skillDirs).Count -eq 0) {
            ConvertFrom-Utf8Base64String -Value '5pyq5a+85YWlIFNraWxs'
        }
        else {
            ConvertFrom-Utf8Base64String -Value '5YWo6YOoIHNraWxsIOW3suWQjOatpQ=='
        }

        return [pscustomobject]@{
            Name   = 'skills.zip'
            Key    = 'skills-bundle'
            Status = 'ok'
            Source = 'local-zip'
            Detail = $detail
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
    'Get-AppInstallDecision',
    'Get-AppInstallDecisionBatch',
    'Initialize-CodexWorkspaceDirectory',
    'Install-AppFromDefinition',
    'Get-CcSwitchProviderByName',
    'Read-CodexProviderInput',
    'Import-CcSwitchCodexProvider',
    'Get-SkillBundleProfiles',
    'Get-SkillBundleInventory',
    'Get-SkillBundleComponentStatus',
    'Install-SkillBundle'
)
