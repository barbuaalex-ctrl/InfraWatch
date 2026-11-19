$ErrorActionPreference='Stop'
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\agent\Pairing-Agent.ps1') -Raw
$source=$source.Replace('[System.Windows.Forms.Application]::Run($form)','')
$source=$source.Replace('$PSScriptRoot',"'H:\infrawatch app\agent'")
$tempFolder=Join-Path ([System.IO.Path]::GetTempPath()) ('infrawatch-agent-runtime-'+[guid]::NewGuid().ToString())
$null=New-Item -ItemType Directory -Path $tempFolder
try{
 Invoke-Expression $source
 $expectedVersion=(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\agent\version.json') -Raw|ConvertFrom-Json).version
 if($form.Text -ne ('infrawatch-agent v'+$expectedVersion)){throw 'Agent title version mismatch'}
 $settingsPath=Join-Path $tempFolder 'connection.json'
 $address.Text='http://127.0.0.1:3000'
 $script:deviceId='';$script:deviceToken='';$script:requestId=''
 $script:metricsSent=$false
 function Check-AgentUpdate{$script:lastUpdateCheck=Get-Date}
 $script:metricCount=0
 $script:versionReported=$false
 function Call-API($route,$body,$headers=@{},$method='POST'){
  if($route -eq '/api/pairing/request'){if(-not $body.inventory.hostname){throw 'Hostname missing'};return @{requestId='test-request';requestSecret='test-secret';code='ABC-234';expiresAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+300000}}
  if($route -eq '/api/pairing/test-request'){return @{status='approved';serverId='test-device';token='test-token'}}
  if($route -eq '/api/agents/test-device/metrics'){$script:metricCount++;if($body.agentVersion -eq $expectedVersion){$script:versionReported=$true};if($script:metricCount -eq 1 -and (-not $body.inventory.osName -or $null -eq $body.inventory.ramGB)){throw 'Hardware inventory missing'};if($script:metricCount -gt 1 -and $body.ContainsKey('inventory')){throw 'Hardware inventory was sent again unnecessarily'};if($null -eq $body.diskFreeGB -or $null -eq $body.diskTotalGB){throw 'Disk capacity missing'};$script:metricsSent=$true;return @{ok=$true}}
  throw 'Unexpected route'
 }
 Tick-Agent
 if($code.Text -ne 'ABC-234'){throw ('Pairing code not shown: '+$values.Text)}
 if($code -isnot [System.Windows.Forms.TextBox] -or -not $code.ReadOnly){throw 'Pairing code must be selectable and read-only'}
 $code.SelectAll()
 if($code.SelectedText -ne 'ABC-234'){throw 'Pairing code cannot be selected'}
 if(-not $copyCode.Enabled){throw 'Copy code is not enabled during pairing'}
 Tick-Agent
 if(-not $script:metricsSent -or $code.Text -ne 'CONNECTED'){throw ('Metrics not sent: '+$values.Text)}
 if($copyCode.Enabled){throw 'Copy code should be disabled after pairing'}
 if($timer.Interval -ne 1000){throw 'Metric timer is not one second'}
 if(-not $script:versionReported){throw 'Agent version was not reported'}
 $previousInventory=$script:lastInventory
 Send-Metrics
 if($script:lastInventory -ne $previousInventory){throw 'Hardware inventory was reread on the next sample'}
 $saved=Get-Content -LiteralPath $settingsPath -Raw|ConvertFrom-Json
 if($saved.protectedToken -eq 'test-token'){throw 'Token not protected'}
 $decoded=[System.Net.NetworkCredential]::new('',(ConvertTo-SecureString $saved.protectedToken)).Password
 if($decoded -ne 'test-token'){throw 'Saved credentials cannot be read'}
 Stop-Agent
 if($timer.Enabled){throw 'Timer still active'}
 Write-Output 'PASS: Windows PowerShell UI, real hardware inventory, pairing state, encrypted saved credentials, Stop.'
}finally{
 if($timer){$timer.Dispose()};if($form){$form.Dispose()}
 if((Split-Path -Parent $tempFolder) -eq [System.IO.Path]::GetTempPath().TrimEnd('\')){Remove-Item -LiteralPath $tempFolder -Recurse -Force}
}
