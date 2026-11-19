param([switch]$AutoStart)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$agentVersion='unversioned'
try{$agentVersion=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'version.json') -Raw|ConvertFrom-Json).version}catch{}
$script:deviceId=''; $script:deviceToken=''; $script:requestId=''; $script:requestSecret=''; $script:expiresAt=0; $script:inventory=$null; $script:lastInventory=Get-Date '2000-01-01'
$script:inventorySent=$false
$script:cpuCounter=$null;$script:memoryCounter=$null
try{$script:cpuCounter=New-Object System.Diagnostics.PerformanceCounter('Processor','% Processor Time','_Total');$null=$script:cpuCounter.NextValue()}catch{}
try{$script:memoryCounter=New-Object System.Diagnostics.PerformanceCounter('Memory','Available Bytes')}catch{}
$settingsPath=Join-Path $PSScriptRoot 'connection.json'
$configPath=Join-Path $PSScriptRoot 'config.json'
$baseAddress=''
if(Test-Path -LiteralPath $configPath){try{$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json;$baseAddress=$config.serverUrl;if($config.serverId -and $config.token){$script:deviceId=$config.serverId;$script:deviceToken=$config.token}}catch{}}
if(Test-Path -LiteralPath $settingsPath){try{$saved=Get-Content -LiteralPath $settingsPath -Raw|ConvertFrom-Json;$secure=ConvertTo-SecureString $saved.protectedToken;$script:deviceToken=[System.Net.NetworkCredential]::new('',$secure).Password;$script:deviceId=$saved.serverId;$baseAddress=$saved.serverUrl}catch{$script:deviceId='';$script:deviceToken=''}}
function Read-Inventory {
 $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
 $computer=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
 $script:bootTime=$os.LastBootUpTime;$script:totalPhysicalBytes=[double]$computer.TotalPhysicalMemory
 $cpus=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
 $gpu=@();try{$gpu=@(Get-CimInstance Win32_VideoController -ErrorAction Stop|ForEach-Object {$_.Name})}catch{}
 $drives=@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop|ForEach-Object {@{name=$_.DeviceID;sizeGB=[math]::Round($_.Size/1GB,1);freeGB=[math]::Round($_.FreeSpace/1GB,1)}})
 return @{hostname=$env:COMPUTERNAME;manufacturer=$computer.Manufacturer;model=$computer.Model;osName=$os.Caption;osVersion=$os.Version;architecture=$os.OSArchitecture;cpuName=($cpus.Name -join ', ');cores=[int](($cpus|Measure-Object NumberOfCores -Sum).Sum);threads=[int](($cpus|Measure-Object NumberOfLogicalProcessors -Sum).Sum);ramGB=[math]::Round($computer.TotalPhysicalMemory/1GB,1);gpu=$gpu;disks=$drives}
}
$form=New-Object System.Windows.Forms.Form;$form.Text='infrawatch-agent v'+$agentVersion;$form.Size=New-Object System.Drawing.Size(510,490);$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#101522');$form.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#E7EDFF');$form.Font=New-Object System.Drawing.Font('Segoe UI',10)
function Label($text,$top,$height=25){$l=New-Object System.Windows.Forms.Label;$l.Text=$text;$l.Location=New-Object System.Drawing.Point(22,$top);$l.Size=New-Object System.Drawing.Size(455,$height);$form.Controls.Add($l);return $l}
$title=Label ('InfraWatch Agent v'+$agentVersion) 20 32;$title.Font=New-Object System.Drawing.Font('Segoe UI',15,[System.Drawing.FontStyle]::Bold)
$null=Label 'InfraWatch address' 65
$address=New-Object System.Windows.Forms.TextBox;$address.Location=New-Object System.Drawing.Point(22,92);$address.Size=New-Object System.Drawing.Size(450,28);$address.Text=$baseAddress;$form.Controls.Add($address)
$code=New-Object System.Windows.Forms.TextBox;$code.Text='READY TO CONNECT';$code.Location=New-Object System.Drawing.Point(22,140);$code.Size=New-Object System.Drawing.Size(310,45);$code.ReadOnly=$true;$code.BorderStyle='None';$code.BackColor=$form.BackColor;$code.Font=New-Object System.Drawing.Font('Consolas',23,[System.Drawing.FontStyle]::Bold);$code.ForeColor=[System.Drawing.ColorTranslator]::FromHtml('#AB96FF');$code.ShortcutsEnabled=$true;$form.Controls.Add($code)
$code.Width=310
$copyCode=New-Object System.Windows.Forms.Button;$copyCode.Text='Copy code';$copyCode.Location=New-Object System.Drawing.Point(345,145);$copyCode.Size=New-Object System.Drawing.Size(125,36);$copyCode.Enabled=$false;$copyCode.FlatStyle='Flat';$copyCode.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#25314A');$copyCode.ForeColor=[System.Drawing.Color]::White;$form.Controls.Add($copyCode)
$copyCode.Add_Click({try{if($script:requestId -and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -lt $script:expiresAt -and $code.Text -match '^[A-Z2-9]{3}-[A-Z2-9]{3}$'){[System.Windows.Forms.Clipboard]::SetText($code.Text);$copyCode.Text='Copied!';$status.Text='Code copied. Paste it in InfraWatch.'}else{$copyCode.Enabled=$false;$status.Text='No active pairing code. Click Stop, then Start for a new code.'}}catch{$status.Text='Clipboard is busy. Try Copy code again.'}})
$hint=Label 'Click Start. Enter the code in Devices > Add device.' 190 42
$start=New-Object System.Windows.Forms.Button;$start.Text='Start';$start.Location=New-Object System.Drawing.Point(22,245)
$stop=New-Object System.Windows.Forms.Button;$stop.Text='Stop';$stop.Location=New-Object System.Drawing.Point(145,245);$stop.Enabled=$false
foreach($b in @($start,$stop)){$b.Size=New-Object System.Drawing.Size(110,36);$b.FlatStyle='Flat';$b.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#7357DE');$b.ForeColor=[System.Drawing.Color]::White;$form.Controls.Add($b)}
$status=Label 'Stopped. No data is being sent.' 300 35
$values=Label '' 342 40
$updateButton=New-Object System.Windows.Forms.Button;$updateButton.Text='Check for updates';$updateButton.Location=New-Object System.Drawing.Point(22,395);$updateButton.Size=New-Object System.Drawing.Size(230,32);$updateButton.FlatStyle='Flat';$updateButton.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#25314A');$updateButton.ForeColor=[System.Drawing.Color]::White;$form.Controls.Add($updateButton)
$script:updateManifest=$null;$script:lastUpdateCheck=Get-Date '2000-01-01'
function Check-AgentUpdate{
 $script:lastUpdateCheck=Get-Date
 try{$manifest=Invoke-RestMethod -Uri ($address.Text.Trim().TrimEnd('/')+'/api/agent-release') -TimeoutSec 5 -ErrorAction Stop;$script:lastUpdateCheck=Get-Date
 if([version]$manifest.version -gt [version]$agentVersion){$script:updateManifest=$manifest;$updateButton.Text='Update to v'+$manifest.version}else{$script:updateManifest=$null;$updateButton.Text='Up to date / v'+$agentVersion}
 }catch{$updateButton.Text='Check for updates'}
}
function AgentFile-Hash($file){$stream=[IO.File]::OpenRead($file);$sha=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}}
$updateButton.Add_Click({
 if(-not $script:updateManifest){Check-AgentUpdate;return}
 if([System.Windows.Forms.MessageBox]::Show(('Install v'+$script:updateManifest.version+' and restart the agent? Your device connection will be kept.'),'InfraWatch update','YesNo') -ne 'Yes'){return}
 $updateButton.Enabled=$false;$wasRunning=$timer.Enabled;$timer.Stop()
 try{
  $manifest=$script:updateManifest;if($manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $manifest.updateUrl -ne '/agent/update.zip'){throw 'Invalid update information'}
  $downloadDirectory=Join-Path ([IO.Path]::GetTempPath()) ('infrawatch-agent-download-'+[guid]::NewGuid().ToString());$null=New-Item -ItemType Directory -Path $downloadDirectory
  $archive=Join-Path $downloadDirectory 'update.zip';Invoke-WebRequest -UseBasicParsing -Uri ($address.Text.Trim().TrimEnd('/')+$manifest.updateUrl) -OutFile $archive -TimeoutSec 30 -ErrorAction Stop
  if((AgentFile-Hash $archive) -ne $manifest.sha256){throw 'Download integrity check failed'}
  $helper=Join-Path $downloadDirectory 'Update-Agent.ps1';Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Update-Agent.ps1') -Destination $helper
  $updateArguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$helper+'"'),'-AgentDirectory',('"'+$PSScriptRoot+'"'),'-ArchivePath',('"'+$archive+'"'),'-ExpectedHash',$manifest.sha256,'-ExpectedVersion',$manifest.version,'-OldProcessId',$PID)
  if($wasRunning){$updateArguments+='-ResumeMonitoring'}
  Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $updateArguments -WindowStyle Hidden
  $form.Close()
 }catch{$status.Text='Update failed: '+$_.Exception.Message;$updateButton.Enabled=$true;if($wasRunning){$timer.Start()}}
})
$timer=New-Object System.Windows.Forms.Timer;$timer.Interval=1000
function Stop-Agent{$timer.Stop();$start.Enabled=$true;$stop.Enabled=$false;$address.Enabled=$true;$copyCode.Enabled=$false;$script:requestId='';$script:requestSecret=''}
function Call-API($route,$body,$headers=@{},$method='POST'){
 $parameters=@{Uri=$address.Text.Trim().TrimEnd('/')+$route;Method=$method;Headers=$headers;TimeoutSec=8;ErrorAction='Stop'}
 if($method -eq 'POST'){$parameters.ContentType='application/json';$parameters.Body=($body|ConvertTo-Json -Depth 8)}
 return Invoke-RestMethod @parameters
}
function Send-Metrics{
 $includeInventory=$false
 if(-not $script:inventory -or ((Get-Date)-$script:lastInventory).TotalHours -ge 1){$script:inventory=Read-Inventory;$script:lastInventory=Get-Date;$includeInventory=$true;$script:inventorySent=$false}
 $cpu=$null
 if($script:cpuCounter){try{$cpu=[math]::Round([math]::Min(100,[math]::Max(0,$script:cpuCounter.NextValue())),1)}catch{}}
 if($null -eq $cpu){$cpu=(Get-CimInstance Win32_Processor -ErrorAction Stop|Measure-Object LoadPercentage -Average).Average}
 if($null -eq $cpu){throw 'CPU reading unavailable'}
 $disk=New-Object System.IO.DriveInfo($env:SystemDrive)
 $availableBytes=$null
 if($script:memoryCounter){try{$availableBytes=$script:memoryCounter.NextValue()}catch{}}
 if($null -eq $availableBytes){$availableBytes=(Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreePhysicalMemory*1KB}
 $ram=[math]::Round([math]::Max(0,[math]::Min(100,(1-$availableBytes/$script:totalPhysicalBytes)*100)),1);$used=[math]::Round((1-$disk.TotalFreeSpace/$disk.TotalSize)*100,1)
 $gpuUsage=$null
 try{
  $engines=@(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop | Where-Object {$_.Name -match 'engtype_3D'})
  if($engines.Count -gt 0){$busiest=($engines | Group-Object {($_.Name -split '_eng_')[0] -replace '^pid_\d+_',''} | ForEach-Object {($_.Group|Measure-Object UtilizationPercentage -Sum).Sum} | Measure-Object -Maximum).Maximum;$gpuUsage=[math]::Round([math]::Min(100,[double]$busiest),1)}
 }catch{}
 $freeGB=[math]::Round($disk.TotalFreeSpace/1GB,1);$totalGB=[math]::Round($disk.TotalSize/1GB,1)
 $body=@{hostname=$env:COMPUTERNAME;cpu=[double]$cpu;ram=$ram;gpu=$gpuUsage;disk=$used;diskFreeGB=$freeGB;diskTotalGB=$totalGB;systemDrive=$env:SystemDrive;uptimeSeconds=[math]::Floor(((Get-Date)-$script:bootTime).TotalSeconds)}
 if($includeInventory -or -not $script:inventorySent){$body.inventory=$script:inventory}
 $body.agentVersion=$agentVersion
 $null=Call-API ('/api/agents/'+$script:deviceId+'/metrics') $body @{'x-agent-token'=$script:deviceToken}
 $script:inventorySent=$true
 $code.Text='CONNECTED';$copyCode.Enabled=$false;$hint.Text='Paired securely. This connection is remembered.';$status.Text='Live / 1-second interval / '+(Get-Date -Format 'HH:mm:ss');$values.Text="CPU $cpu% | RAM $ram% | $freeGB GB free of $totalGB GB"
}
function Tick-Agent{
 try{
  if(((Get-Date)-$script:lastUpdateCheck).TotalMinutes -ge 30){Check-AgentUpdate}
  if($script:deviceId){Send-Metrics;return}
  if(-not $script:requestId){
   $script:inventory=Read-Inventory;$script:lastInventory=Get-Date
   $request=Call-API '/api/pairing/request' @{inventory=$script:inventory}
   $script:requestId=$request.requestId;$script:requestSecret=$request.requestSecret;$script:expiresAt=[double]$request.expiresAt
   $code.Text=$request.code;$copyCode.Enabled=$true;$copyCode.Text='Copy code';$hint.Text='Copy code, then paste in Devices > Add device > Computer / Server.';$status.Text='Waiting for approval. Code expires in 5 minutes.';return
  }
  $approval=Call-API ('/api/pairing/'+$script:requestId) $null @{'x-pairing-secret'=$script:requestSecret} 'GET'
  if($approval.status -eq 'approved'){
   $script:deviceId=$approval.serverId;$script:deviceToken=$approval.token
   try{$protected=ConvertFrom-SecureString (ConvertTo-SecureString $script:deviceToken -AsPlainText -Force);@{serverUrl=$address.Text.Trim().TrimEnd('/');serverId=$script:deviceId;protectedToken=$protected}|ConvertTo-Json|Set-Content -LiteralPath $settingsPath -Encoding UTF8}catch{[System.Windows.Forms.MessageBox]::Show('Connected, but could not save this connection. Keep the agent in a writable folder.')}
   Send-Metrics
  }else{$remaining=[math]::Max(0,[math]::Ceiling(($script:expiresAt-[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())/1000));$status.Text="Waiting for approval / code valid for $remaining seconds"}
 }catch{
  $status.Text='Connection problem. Check InfraWatch is running.';$values.Text=$_.Exception.Message
  if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 409){$code.Text='PAUSED';$status.Text='Paused from InfraWatch.';$hint.Text='Resume monitoring in Device Settings.';$values.Text='No metrics are being accepted while paused.'}
  if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 410){Stop-Agent;$code.Text='CODE EXPIRED';$hint.Text='Click Start to generate a fresh code.'}
  if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401){Stop-Agent;$script:deviceId='';$script:deviceToken='';$code.Text='PAIR AGAIN';$hint.Text='The device was removed. Click Start for a new code.';if(Test-Path -LiteralPath $settingsPath){Remove-Item -LiteralPath $settingsPath}}
 }
}
$timer.Add_Tick({Tick-Agent})
$start.Add_Click({$parsed=$null;if(-not [Uri]::TryCreate($address.Text.Trim(),[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -notin @('http','https')){[System.Windows.Forms.MessageBox]::Show('Enter the InfraWatch address, e.g. http://192.168.0.200:3000');return};$start.Enabled=$false;$stop.Enabled=$true;$address.Enabled=$false;$status.Text='Connecting...';$timer.Start();Tick-Agent})
$stop.Add_Click({Stop-Agent;$code.Text='STOPPED';$status.Text='Stopped. No data is being sent.';$hint.Text='Click Start to reconnect.'})
$form.Add_FormClosed({$timer.Stop();$timer.Dispose();if($script:cpuCounter){$script:cpuCounter.Dispose()};if($script:memoryCounter){$script:memoryCounter.Dispose()}})
$form.Add_Shown({if($AutoStart){$start.PerformClick()}})
[System.Windows.Forms.Application]::Run($form)
