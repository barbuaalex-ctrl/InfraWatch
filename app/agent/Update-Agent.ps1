param([Parameter(Mandatory=$true)][string]$AgentDirectory,[Parameter(Mandatory=$true)][string]$ArchivePath,[Parameter(Mandatory=$true)][string]$ExpectedHash,[Parameter(Mandatory=$true)][string]$ExpectedVersion,[Parameter(Mandatory=$true)][int]$OldProcessId,[switch]$ResumeMonitoring)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$target=(Resolve-Path -LiteralPath $AgentDirectory).Path
$work=Join-Path ([IO.Path]::GetTempPath()) ('infrawatch-update-work-'+[guid]::NewGuid().ToString())
$null=New-Item -ItemType Directory -Path $work
$backedUp=@();$installed=@();$files=@('Agent.ps1','Start Agent.cmd','version.json','Update-Agent.ps1')
function File-Hash($file){$stream=[IO.File]::OpenRead($file);$sha=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}}
try{
 if(-not (Test-Path -LiteralPath (Join-Path $target 'Agent.ps1'))){throw 'Agent folder not found.'}
 if((File-Hash $ArchivePath) -ne $ExpectedHash){throw 'Downloaded archive failed its integrity check.'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
 try{foreach($entry in $zip.Entries){if($entry.FullName -ne 'InfraWatch-Agent/' -and $entry.FullName -notin ($files|ForEach-Object {'InfraWatch-Agent/'+$_})){throw 'Unexpected file in update package.'}}}finally{$zip.Dispose()}
 [IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath,(Join-Path $work 'extracted'))
 $incoming=Join-Path $work 'extracted\InfraWatch-Agent'
 $newVersion=Get-Content -LiteralPath (Join-Path $incoming 'version.json') -Raw|ConvertFrom-Json
 if($newVersion.version -ne $ExpectedVersion){throw 'Update version does not match.'}
 foreach($file in $files){if(-not(Test-Path -LiteralPath (Join-Path $incoming $file))){throw ('Missing '+$file)}}
 Wait-Process -Id $OldProcessId -Timeout 30 -ErrorAction SilentlyContinue
 if(Get-Process -Id $OldProcessId -ErrorAction SilentlyContinue){throw 'Close the old agent before updating.'}
 $backup=Join-Path $work 'backup';$null=New-Item -ItemType Directory -Path $backup
 foreach($file in $files){$existing=Join-Path $target $file;if(Test-Path -LiteralPath $existing){Copy-Item -LiteralPath $existing -Destination (Join-Path $backup $file);$backedUp+=$file};$installed+=$file;Copy-Item -LiteralPath (Join-Path $incoming $file) -Destination $existing -Force}
 $launchArguments=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $target 'Agent.ps1')+'"'));if($ResumeMonitoring){$launchArguments+='-AutoStart'}
 Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $launchArguments -WindowStyle Hidden
}catch{
 foreach($file in $installed){$saved=Join-Path $work ('backup\'+$file);if($file -in $backedUp){Copy-Item -LiteralPath $saved -Destination (Join-Path $target $file) -Force}else{Remove-Item -LiteralPath (Join-Path $target $file) -ErrorAction SilentlyContinue}}
 [System.Windows.Forms.MessageBox]::Show('Update failed. Existing connection files were preserved. '+$_.Exception.Message,'InfraWatch update')|Out-Null
}finally{
 if((Split-Path -Parent $work) -eq [IO.Path]::GetTempPath().TrimEnd('\')){Remove-Item -LiteralPath $work -Recurse -Force}
}
