$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
$scratch=Join-Path $root ('.local/component-core-'+[guid]::NewGuid().ToString('N'))
if (-not [IO.Path]::GetFullPath($scratch).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.local/')),[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected fixture path' }
$source=Join-Path $scratch 'source'
$central=Join-Path $scratch 'central'
[void](New-Item -ItemType Directory -Path $source,$central -Force)
[IO.File]::WriteAllText((Join-Path $source 'SKILL.md'),'new fixture content')
[IO.File]::WriteAllText((Join-Path $source '.skill-meta.json'),'{"source_ref":"fixture/new","name":"example"}')
Import-Module (Join-Path $root 'modules/common.psm1') -Force -DisableNameChecking
$module=Get-Module common
$events=[Collections.Generic.List[object]]::new()
Set-InstallerEventSink -Sink {param($event);$events.Add($event)}.GetNewClosure()
$assertions=0
function Assert-True($Value,$Message) { if (-not $Value) {throw $Message};$script:assertions++ }
function Import-Fixture($Name,[switch]$Preserve,[switch]$Rename,[switch]$Replace,[switch]$Preview) {
    & $module {param($Source,$Central,$Name,$Preserve,$Rename,$Replace,$Preview)
        Import-SkillDirectoryToTargets -SourcePath $Source -CentralRoot $Central -SkillName $Name -Targets @([pscustomobject]@{Enabled=$false;Name='fixture';Path=$Central}) -NoReplaceOrphan:$Preserve -RenameForeign:$Rename -ReplaceForeign:$Replace -DryRun:$Preview
    } $source $central $Name ([bool]$Preserve) ([bool]$Rename) ([bool]$Replace) ([bool]$Preview)
}
$existing=Join-Path $central 'orphan'
[void](New-Item -ItemType Directory -Path $existing)
[IO.File]::WriteAllText((Join-Path $existing 'SKILL.md'),'original')
$preserved=Import-Fixture orphan -Preserve
Assert-True (-not $preserved.Copied -and $events[$events.Count-1].result.Status -eq 'skipped') 'Orphan preservation produces a structured skipped outcome'
$preview=Import-Fixture orphan -Preview
$previewEvent=$events[$events.Count-1].result
Assert-True ($previewEvent.Status -eq 'preview' -and $previewEvent.Backups.Count -eq 1) 'Preview reports planned backup paths'
Assert-True ([IO.File]::ReadAllText((Join-Path $existing 'SKILL.md')) -eq 'original' -and -not (Test-Path $previewEvent.Backups[0])) 'Preview leaves source, destination and backups untouched'
$replaced=Import-Fixture orphan
$backup=$events[$events.Count-1].result.Backups[0]
Assert-True ((Test-Path $backup) -and [IO.File]::ReadAllText((Join-Path $backup 'SKILL.md')) -eq 'original') 'Real fixture replacement retains original backup'
$foreign=Join-Path $central 'foreign'
[void](New-Item -ItemType Directory -Path $foreign)
[IO.File]::WriteAllText((Join-Path $foreign 'SKILL.md'),'foreign original')
[IO.File]::WriteAllText((Join-Path $foreign '.skill-meta.json'),'{"source_ref":"fixture/other"}')
$renamed=Import-Fixture foreign -Rename
Assert-True ($renamed.EffectiveName -eq 'foreign-indieark' -and [IO.File]::ReadAllText((Join-Path $foreign 'SKILL.md')) -eq 'foreign original') 'Foreign rename preserves the original directory'
$updated=Import-Fixture foreign -Replace
Assert-True ($events[$events.Count-1].result.Backups.Count -eq 1) 'Explicit foreign replacement produces a backup outcome'
$tracked=Import-Fixture foreign
Assert-True ($events[$events.Count-1].result.Status -eq 'skipped') 'Identical tracked skills report skipped rather than success'
# Parameterized lookup is exercised against an isolated SQLite database, never the user database.
$fixtureHome=Join-Path $scratch 'home'
$db=Join-Path $fixtureHome '.cc-switch/cc-switch.db'
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $db) -Force)
$dbScript=Join-Path $scratch 'create-db.py'
[IO.File]::WriteAllText($dbScript,"import sqlite3,sys`nc=sqlite3.connect(sys.argv[1])`nc.execute('create table providers(id text,name text,app_type text)')`nc.execute('insert into providers values(?,?,?)',('test',`"Name with '' quote`",'codex'))`nc.commit()`nc.close()`n")
& python $dbScript $db
if ($LASTEXITCODE -ne 0) {throw 'Fixture SQLite initialization failed'}
$previousHome=$env:VIBE_CODING_USER_HOME
try {
    $env:VIBE_CODING_USER_HOME=$fixtureHome
    $provider=Get-CcSwitchProviderByName -ProviderName "Name with '' quote"
    Assert-True ($provider.Id -eq 'test') 'Bound provider lookup accepts quote characters'
    $none=Get-CcSwitchProviderByName -ProviderName "x' OR 1=1 --"
    Assert-True ($null -eq $none) 'Provider name cannot alter the SQLite query'
    $bundleRoot=Join-Path $scratch 'bundle'
    foreach ($name in @('a','b')) {
        $dir=Join-Path $bundleRoot $name
        [void](New-Item -ItemType Directory -Path $dir -Force)
        [IO.File]::WriteAllText((Join-Path $dir 'SKILL.md'),'fixture skill')
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=Join-Path $scratch 'fixture.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($bundleRoot,$zip)
    $stopFile=Join-Path $scratch 'stop'
    $events.Clear()
    Set-InstallerEventSink -StopPath $stopFile -Sink {param($event);$events.Add($event);if($event.type -eq 'component-result' -and $event.key -eq 'skill:a' -and $event.result.Status -eq 'preview'){[IO.File]::WriteAllText($stopFile,'stop')}}.GetNewClosure()
    $bundle=Install-SkillBundle -ZipPath $zip -SkillNames a,b -NoReplaceOrphan -SkipSkillsManagerLaunch -SkillsManagerScenarioMode skip -DryRun
    Assert-True (@($events | Where-Object { $_.type -eq 'component-result' -and $_.key -eq 'skill:a' -and $_.result.Status -eq 'preview' }).Count -eq 1) 'Real bundle emits per-skill preview outcomes'
    Assert-True (@($events | Where-Object { $_.type -eq 'component-result' -and $_.key -eq 'skill:b' }).Count -eq 0) 'Stop after a component prevents subsequent component actions'
    Assert-True (-not (Test-Path (Join-Path $fixtureHome '.codex')) -and -not (Test-Path (Join-Path $fixtureHome '.skills-manager'))) 'Real bundle dry-run creates no user skill directories'
} finally { $env:VIBE_CODING_USER_HOME=$previousHome; Set-InstallerEventSink -Sink $null }
Write-Output ("PASS: $assertions real component fixture assertions; user configuration unchanged")
