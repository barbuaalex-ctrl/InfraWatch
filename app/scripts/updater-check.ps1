param([string]$FixtureDirectory,[string]$ArchivePath,[string]$ExpectedHash,[string]$ExpectedVersion)
$ErrorActionPreference='Stop'
$target=(Resolve-Path -LiteralPath $FixtureDirectory).Path
if($target -notlike ([IO.Path]::GetTempPath()+'infrawatch-updater-test-*')){throw 'Fixture must be an isolated temporary directory'}
$script:restartArguments=$null
function Start-Process { param($FilePath,$ArgumentList,$WindowStyle) $script:restartArguments=$ArgumentList }
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\agent\Update-Agent.ps1') -Raw
$source=$source -replace '(?m)^.*MessageBox.*$',' throw'
& ([scriptblock]::Create($source)) -AgentDirectory $target -ArchivePath $ArchivePath -ExpectedHash $ExpectedHash -ExpectedVersion $ExpectedVersion -OldProcessId 2147483647 -ResumeMonitoring
$version=(Get-Content -LiteralPath (Join-Path $target 'version.json') -Raw|ConvertFrom-Json).version
if($version -ne $ExpectedVersion){throw 'Update version was not installed'}
if((Get-Content -LiteralPath (Join-Path $target 'config.json') -Raw) -ne 'keep-config'){throw 'Config was changed'}
if((Get-Content -LiteralPath (Join-Path $target 'connection.json') -Raw) -ne 'keep-pairing'){throw 'Pairing was changed'}
if($script:restartArguments -notcontains '-AutoStart'){throw 'Monitoring was not scheduled to resume'}
function TestFile-Hash($file){$s=[IO.File]::OpenRead($file);$h=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($h.ComputeHash($s))}finally{$s.Dispose();$h.Dispose()}}
$before=TestFile-Hash (Join-Path $target 'Agent.ps1')
$failed=$false
try{& ([scriptblock]::Create($source)) -AgentDirectory $target -ArchivePath $ArchivePath -ExpectedHash ('0'*64) -ExpectedVersion $ExpectedVersion -OldProcessId 2147483647}catch{$failed=$true}
if(-not $failed){throw 'Invalid archive hash was accepted'}
if((TestFile-Hash (Join-Path $target 'Agent.ps1')) -ne $before){throw 'Failed update modified installed agent'}
Write-Output 'PASS: verified update installed, pairing/config preserved, resume requested, invalid hash rejected.'
