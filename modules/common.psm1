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
    $levelText = switch ($Level) {
        'INFO' { ConvertFrom-Utf8Base64String -Value '5L+h5oGv' }
        'WARN' { ConvertFrom-Utf8Base64String -Value '6K2m5ZGK' }
        'ERROR' { ConvertFrom-Utf8Base64String -Value '6ZSZ6K+v' }
        default { $Level }
    }
    Write-Host ('[{0}] [{1}] {2}' -f $timestamp, $levelText, $Message)
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
        ForEach-Object { $_ -split ',' } |
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
            Name = (ConvertFrom-Utf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
            Key = 'codex-workspace'
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
        Name = (ConvertFrom-Utf8Base64String -Value 'Q29kZXgg5bel5L2c5Yy6')
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

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5p+l6K+iIEdpdEh1YiDmnIDmlrAgUmVsZWFzZe+8mnswfQ==') -f $Repo)
    $release = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1

    if (-not $asset) {
        throw ((ConvertFrom-Utf8Base64String -Value '5LuT5bqTIHswfSDmsqHmnInmj5DkvpvljLnphY3otYTkuqfvvJp7MX0=') -f $Repo, $AssetPattern)
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

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IOi/m+W6pu+8mnswfSU=') -f $progressPercent)
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
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'd2luZ2V0IHswfSB7MX0g5LuN5Zyo6L+Q6KGMLi4u') -f $Action, $PackageId)
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
                Detail = (ConvertFrom-Utf8Base64String -Value 'ezB9IOiwg+eUqOWksei0pe+8mnsxfQ==') -f $commandName, $_.Exception.Message
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
            Detail = (ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5qOA5rWL6KeE5YiZ')
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
        Detail = (ConvertFrom-Utf8Base64String -Value '5rKh5pyJ5qOA5rWL6KeE5YiZ')
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
            Detail = (ConvertFrom-Utf8Base64String -Value '5pyq5a6J6KOF')
        }
    }

    if ($installIfMissingOnly) {
        return [pscustomobject]@{
            Action = 'skip'
            Reason = 'present'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = (ConvertFrom-Utf8Base64String -Value '5bey5qOA5rWL5Yiw5bqU55So77yM5LiU5ZCv55SoIGluc3RhbGxJZk1pc3NpbmdPbmx5')
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$installed.Version)) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'unknown-installed-version'
            InstalledVersion = $null
            DesiredVersion = $desired.Version
            Detail = (ConvertFrom-Utf8Base64String -Value '5peg5rOV56Gu5a6a5bey5a6J6KOF54mI5pys')
        }
    }

    if (-not $desired.Found -or [string]::IsNullOrWhiteSpace([string]$desired.Version)) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'unknown-target-version'
            InstalledVersion = $installed.Version
            DesiredVersion = $null
            Detail = (ConvertFrom-Utf8Base64String -Value '5bey5qOA5rWL5Yiw5a6J6KOF54mI5pys77yM5L2G55uu5qCH54mI5pys5LiN5Y+v5q+U6L6D')
        }
    }

    $comparison = Compare-VersionStrings -LeftVersion $installed.Version -RightVersion $desired.Version
    if ($null -eq $comparison) {
        return [pscustomobject]@{
            Action = 'install'
            Reason = 'non-comparable'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5ZKM55uu5qCH54mI5pys5LiN5Y+v5q+U6L6D')
        }
    }

    if ($comparison -ge 0) {
        return [pscustomobject]@{
            Action = 'skip'
            Reason = 'current'
            InstalledVersion = $installed.Version
            DesiredVersion = $desired.Version
            Detail = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5Li65pyA5paw')
        }
    }

    return [pscustomobject]@{
        Action = 'install'
        Reason = 'outdated'
        InstalledVersion = $installed.Version
        DesiredVersion = $desired.Version
        Detail = (ConvertFrom-Utf8Base64String -Value '5bey5a6J6KOF54mI5pys5L2O5LqO55uu5qCH54mI5pys')
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
                    Detail = (ConvertFrom-Utf8Base64String -Value '5Li75a6J6KOF5Zmo6L+U5Zue6ZSZ6K+v5ZCO77yM5bqU55So5bey5Y+v5qOA5rWL')
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
        Detail = (ConvertFrom-Utf8Base64String -Value '5aSN5p+l5ZCO5LuN5peg5rOV56Gu6K6k5bqU55So5bey5a6J6KOF')
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
                Name = $Definition.name
                Key = $Definition.key
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

    switch ($InstallerType) {
        'msi' {
            $args = @('/i', $PackagePath, '/qn', '/norestart') + $SilentArgs
            $argumentLine = (($args | ForEach-Object { ConvertTo-WindowsProcessArgument -Value ([string]$_) }) -join ' ')
            if ($DryRun) {
                Write-Log -Message ('[DryRun] msiexec.exe {0}' -f $argumentLine)
                return
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5q2j5Zyo5a6J6KOFIE1TSe+8mnswfQ==') -f (Split-Path -Leaf $PackagePath))
            $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentLine -Wait -PassThru
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
            $proc = Start-Process -FilePath $PackagePath -ArgumentList $argumentLine -Wait -PassThru
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
        [switch]$DryRun
    )

    $downloadsRoot = Join-Path $WorkspaceRoot 'downloads'
    Initialize-Directory -Path $downloadsRoot
    $decision = Get-AppInstallDecision -Definition $Definition

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
                Name = $Definition.name
                Key = $Definition.key
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
                Name = $Definition.name
                Key = $Definition.key
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
                    Name = $Definition.name
                    Key = $Definition.key
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

    $name = Read-HostWithDefaultValue -Prompt (ConvertFrom-Utf8Base64String -Value 'Q0MgU3dpdGNoIHByb3ZpZGVyIOWQjeensA==') -DefaultValue $name
    $baseUrl = Read-HostWithDefaultValue -Prompt 'API base URL' -DefaultValue $baseUrl
    $model = Read-HostWithDefaultValue -Prompt (ConvertFrom-Utf8Base64String -Value '5qih5Z6L5ZCN56ew') -DefaultValue $model

    $apiKey = $PresetApiKey
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $secureApiKey = Read-Host (ConvertFrom-Utf8Base64String -Value 'U0vvvIjnlZnnqbrkvb/nlKjpu5jorqQgc2st77yM6L6T5YWl5Lya6ZqQ6JeP77yJ') -AsSecureString
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
            Write-Log -Message (ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5pys5qyh5Yia5a6J6KOF5oiW5pu05paw5LqGIENDIFN3aXRjaO+8jOWvvOWFpSBwcm92aWRlciDliY3kvJrlhYjlkK/liqjkuIDmrKHlupTnlKjlrozmiJDms6jlhow=')
        }

        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5bCG6YCa6L+HIGNjc3dpdGNoOi8vIGRlZXAgbGluayDlr7zlhaUgcHJvdmlkZXLvvJp7MH0gLT4gezF9') -f $ProviderInfo.Name, $ProviderInfo.BaseUrl)
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
        State = $installState.State
        Detail = $installState.Detail
        Action = $action
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
            return @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot)
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
        Write-Log -Message (ConvertFrom-Utf8Base64String -Value '5pyq5qOA5rWL5Yiw5Lqk5LqS5byP57uI56uv77yM5a6J6KOFIGJ1bmRsZSDkuK3nmoTlhajpg6ggc2tpbGw=')
        return @($SkillDirectories)
    }

    if ($tokens.Count -eq 0) {
        Write-Host ''
        Write-Host (ConvertFrom-Utf8Base64String -Value '5ZG95Luk5qih5byP6YCJ5oup5pa55byP77yaLVNraWxsUHJvZmlsZSAi5ZCN56ewMSIsIuWQjeensDIiIOmAieaLqSBQcm9maWxl77yMLUFsbFNraWxscyDlr7zlhaXlhajpg6jvvIwtU2tpcFNraWxscyDot7Pov4cgU2tpbGzjgILnm7TmjqXlm57ovabpu5jorqTlr7zlhaXlhajpg6ggU2tpbGzjgII=')
        Write-Host (ConvertFrom-Utf8Base64String -Value '6K+36YCJ5oup6KaB5a6J6KOF55qEIEluZGllQXJrIFByb2ZpbGXvvIjlj6/ovpPlhaXluo/lj7cv5ZCN56ew77yM5aSa5Liq55So6YCX5Y+35YiG6ZqU77yb55u05o6l5Zue6L2m5a6J6KOF5YWo6YOoIHNraWxs77yJ77ya')
        Write-Host (ConvertFrom-Utf8Base64String -Value 'ICAwLiDlhajpg6ggc2tpbGzvvIjlhbzlrrnml6fpgLvovpHvvIk=')
        for ($index = 0; $index -lt $Profiles.Count; $index++) {
            $profile = $Profiles[$index]
            Write-Host ('  {0}. {1} - {2}' -f ($index + 1), $profile.Name, $profile.Description)
        }

        $answer = Read-Host (ConvertFrom-Utf8Base64String -Value 'UHJvZmlsZQ==')
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
            throw ((ConvertFrom-Utf8Base64String -Value '5pyq55+lIHNraWxsIHByb2ZpbGXvvJp7MH0=') -f $token)
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
        Write-Log -Level 'WARN' -Message (ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHByb2ZpbGUg5pyq5byV55So5Lu75L2VIHNraWxs77yM5a6J6KOFIGJ1bmRsZSDkuK3nmoTlhajpg6ggc2tpbGw=')
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

    $selectedProfileNames = @($selectedProfiles | ForEach-Object { $_.Name }) -join ', '
    $mcpDetail = if ($wantedMcp.Count -gt 0) { $wantedMcp -join ', ' } else { '(none)' }
    $prereqDetail = if ($wantedPrereqs.Count -gt 0) { $wantedPrereqs -join ', ' } else { '(none)' }
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHByb2ZpbGXvvJp7MH0=') -f $selectedProfileNames)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIHNraWxs77yaezB9L3sxfQ==') -f $selectedSkillDirs.Count, $SkillDirectories.Count)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6YCJ5Lit55qEIE1DUO+8mnswfQ==') -f $mcpDetail)
    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '6Kej5p6Q5Yiw55qE5YmN572u5L6d6LWW77yaezB9') -f $prereqDetail)

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

    Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'c2tpbGxzLW1hbmFnZXIgREIg5bCa5LiN5a2Y5Zyo77yM5q2j5Zyo5ZCv5YqoIFNraWxscyBNYW5hZ2VyIOWIneWni+WMlu+8mnswfQ==') -f $SkillsManagerExe)
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
        [switch]$SkipSkillsManagerLaunch,
        [switch]$DryRun
    )

    if ($ImportedSkills.Count -eq 0) {
        return
    }

    if ($DryRun) {
        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'W+a8lOe7g10g5rOo5YaMIHswfSDkuKogc2tpbGwg5YiwIHNraWxscy1tYW5hZ2VyIERC') -f $ImportedSkills.Count)
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
            Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value 'c2tpbGxzLW1hbmFnZXIg5rOo5YaM5ZCM5q2l5aSx6LSl77yM6YCA5Ye656CBPXswfQ==') -f $LASTEXITCODE)
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
        [switch]$NoReplaceOrphan,
        [switch]$ReplaceForeign,
        [switch]$RenameForeign,
        [switch]$SkipSkillsManagerLaunch,
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
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempRoot -Force
        $allSkillDirs = @(Get-SkillDirectoriesFromExtractedRoot -RootPath $tempRoot)
        $registryRoot = Expand-BundleRegistryArchive -ExtractedBundleRoot $tempRoot -DestinationPath (Join-Path $tempRoot 'registry')
        $profiles = if ($registryRoot) { @(Read-SkillProfilesFromRegistry -RegistryRoot $registryRoot) } else { @() }
        $skillDirs = @(Select-SkillDirectoriesForProfiles -SkillDirectories $allSkillDirs -Profiles $profiles -RequestedProfiles $SkillProfiles -RegistryRoot $registryRoot -AllSkills:$AllSkills)

        Write-Log -Message ((ConvertFrom-Utf8Base64String -Value '5Y+R546wIHswfSDkuKogc2tpbGwg55uu5b2V77yb6YCJ5LitIHsxfSDkuKo=') -f $allSkillDirs.Count, $skillDirs.Count)

        $skillImportIndex = 0
        $skillImportTotal = $skillDirs.Count
        foreach ($skillDir in $skillDirs) {
            $skillImportIndex++
            $skillName = Split-Path -Leaf $skillDir
            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg6L+b5bqm77yaezB9L3sxfSB7Mn0=') -f $skillImportIndex, $skillImportTotal, $skillName)
            $sourcePath = $skillDir
            $centralPath = Join-Path $centralRoot $skillName
            $centralDecision = Get-SkillImportDecision `
                -SourcePath $sourcePath `
                -DestinationPath $centralPath `
                -SkillName $skillName `
                -NoReplaceOrphan:$NoReplaceOrphan `
                -ReplaceForeign:$ReplaceForeign `
                -RenameForeign:$RenameForeign

            $centralBackupPath = Invoke-SkillImportDecision -Decision $centralDecision -SourcePath $sourcePath -DryRun:$DryRun -Quiet

            if ($centralDecision.Action -eq 'Skip' -and $centralDecision.State -in @('Orphan', 'Foreign')) {
                Write-Log -Level 'WARN' -Message ((ConvertFrom-Utf8Base64String -Value '6Lez6L+HIHNraWxs77ya546w5pyJ55uu5b2V54q25oCB5Li6IHswfe+8mnsxfQ==') -f $centralDecision.State, $centralDecision.FinalPath)
                continue
            }

            $effectiveSkillName = $centralDecision.FinalName
            $effectiveCentralPath = $centralDecision.FinalPath
            $skillTargets = New-Object System.Collections.Generic.List[object]
            $targetChanged = $false
            $copySourcePath = if ((-not $DryRun) -and (Test-Path -LiteralPath $effectiveCentralPath)) { $effectiveCentralPath } else { $sourcePath }

            foreach ($target in $targets | Where-Object { $_.Enabled }) {
                $targetPath = Join-Path $target.Path $effectiveSkillName
                $targetDecision = Get-SkillImportDecision `
                    -SourcePath $sourcePath `
                    -DestinationPath $targetPath `
                    -SkillName $effectiveSkillName `
                    -NoReplaceOrphan:$NoReplaceOrphan `
                    -ReplaceForeign:$ReplaceForeign `
                    -RenameForeign:$false
                $targetBackupPath = Invoke-SkillImportDecision -Decision $targetDecision -SourcePath $copySourcePath -DryRun:$DryRun -Quiet

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

            $skillMetadata = Read-SkillMetadata -SkillPath $sourcePath -SkillName $effectiveSkillName -CentralPath $effectiveCentralPath
            $skillMetadata | Add-Member -MemberType NoteProperty -Name 'Targets' -Value $skillTargets -Force
            $importedSkills.Add($skillMetadata)

            if ($centralDecision.Action -eq 'Skip' -and -not $targetChanged) {
                Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg5bey6Lez6L+H77yaezB9') -f $effectiveSkillName)
                continue
            }

            Write-Log -Message ((ConvertFrom-Utf8Base64String -Value 'U2tpbGwg5bey5ZCM5q2l77yaezB977yb5Yqo5L2cPXsxfe+8m+ebruaghz17Mn0g5Liq') -f $effectiveSkillName, $centralDecision.Action, $skillTargets.Count)
            $copiedSkillCount++

        }

        $registrySyncResult = $null
        if ($importedSkills.Count -gt 0) {
            $registrySyncResult = Sync-SkillsManagerRegistry -ImportedSkills $importedSkills -SkipSkillsManagerLaunch:$SkipSkillsManagerLaunch -DryRun:$DryRun
        }

        if (-not $DryRun -and -not $SkipSkillsManagerLaunch -and $importedSkills.Count -gt 0) {
            $skillsManagerExe = Get-InstalledSkillsManagerExecutable
            $alreadyLaunchedForDbInit = ($null -ne $registrySyncResult -and $registrySyncResult.LaunchedSkillsManager)
            if ($skillsManagerExe -and -not $alreadyLaunchedForDbInit) {
                Write-Log -Message (ConvertFrom-Utf8Base64String -Value '5bey5a+85YWlIHNraWxsIOW5tuWQjOatpSBza2lsbHMtbWFuYWdlciBEQu+8m+ato+WcqOWQr+WKqCBTa2lsbHMgTWFuYWdlcg==')
                Start-Process -FilePath $skillsManagerExe | Out-Null
            }
        }

        return [pscustomobject]@{
            Name = 'skills.zip'
            Key = 'skills-bundle'
            Status = 'ok'
            Source = 'local-zip'
            Detail = if ($copiedSkillCount -eq 0) { ConvertFrom-Utf8Base64String -Value '5YWo6YOoIHNraWxsIOW3suWQjOatpQ==' } else { (ConvertFrom-Utf8Base64String -Value '5bey5a+85YWlIHswfSDkuKogc2tpbGw=') -f $copiedSkillCount }
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
    'Get-SkillBundleProfiles',
    'Install-SkillBundle'
)
