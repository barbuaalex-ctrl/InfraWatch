Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'InfraWatch Agent'
$form.Size = New-Object System.Drawing.Size(450,345)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#101522')
$form.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#E7EDFF')
$form.Font = New-Object System.Drawing.Font('Segoe UI',10)
function Add-Label($text,$top) { $label=New-Object System.Windows.Forms.Label; $label.Text=$text; $label.Location=New-Object System.Drawing.Point(20,$top); $label.Size=New-Object System.Drawing.Size(395,25); $form.Controls.Add($label); return $label }
$null=Add-Label 'InfraWatch address (PC IP + port, e.g. http://192.168.1.10:3000)' 15
$address=New-Object System.Windows.Forms.TextBox; $address.Location=New-Object System.Drawing.Point(20,40); $address.Width=390; $address.Text='http://192.168.1.10:3000'; $form.Controls.Add($address)
$null=Add-Label 'Server ID (from Add Windows laptop)' 72
$serverId=New-Object System.Windows.Forms.TextBox; $serverId.Location=New-Object System.Drawing.Point(20,95); $serverId.Width=390; $form.Controls.Add($serverId)
$null=Add-Label 'Agent token' 122
$token=New-Object System.Windows.Forms.TextBox; $token.Location=New-Object System.Drawing.Point(20,145); $token.Width=390; $token.UseSystemPasswordChar=$true; $form.Controls.Add($token)
$start=New-Object System.Windows.Forms.Button; $start.Text='Start'; $start.Location=New-Object System.Drawing.Point(20,180); $form.Controls.Add($start)
$stop=New-Object System.Windows.Forms.Button; $stop.Text='Stop'; $stop.Location=New-Object System.Drawing.Point(110,180); $stop.Enabled=$false; $form.Controls.Add($stop)
$status=Add-Label 'Stopped. No data is being sent.' 220
$values=Add-Label '' 250
$configPath=Join-Path $PSScriptRoot 'config.json'
if(Test-Path -LiteralPath $configPath){
 try{
  $config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  if(-not $config.serverUrl -or -not $config.serverId -or -not $config.token){throw 'Missing configuration'}
  $address.Text=$config.serverUrl;$serverId.Text=$config.serverId;$token.Text=$config.token
  $form.Text='InfraWatch - '+$config.name
  foreach($control in @($form.Controls)){if($control -ne $start -and $control -ne $stop -and $control -ne $status -and $control -ne $values){$control.Visible=$false}}
  $title=Add-Label $config.name 20;$title.Font=New-Object System.Drawing.Font('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
  $null=Add-Label 'Ready to connect. Click Start.' 60
  $start.Location=New-Object System.Drawing.Point(20,100);$stop.Location=New-Object System.Drawing.Point(130,100)
  $status.Location=New-Object System.Drawing.Point(20,155);$values.Location=New-Object System.Drawing.Point(20,190)
  $form.Size=New-Object System.Drawing.Size(450,280)
 }catch{[System.Windows.Forms.MessageBox]::Show('Invalid config.json. Download a new package from InfraWatch.');exit}
}
foreach($button in @($start,$stop)){$button.FlatStyle='Flat';$button.BackColor=[System.Drawing.ColorTranslator]::FromHtml('#7357DE');$button.ForeColor=[System.Drawing.Color]::White;$button.Size=New-Object System.Drawing.Size(95,35)}
$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=5000
function Send-Metrics {
 try {
  $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
  $cpu=(Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object LoadPercentage -Average).Average
  if ($null -eq $cpu) { throw 'CPU reading unavailable' }
  $disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction Stop
  $ram=[math]::Round((1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,1)
  $used=[math]::Round((1-$disk.FreeSpace/$disk.Size)*100,1)
  $uptime=((Get-Date)-$os.LastBootUpTime).TotalSeconds
  $body=@{hostname=$env:COMPUTERNAME;cpu=[double]$cpu;ram=$ram;disk=$used;uptimeSeconds=[math]::Floor($uptime)} | ConvertTo-Json
  $uri=$address.Text.Trim().TrimEnd('/')+'/api/agents/'+$serverId.Text.Trim()+'/metrics'
  $null=Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' -Headers @{'x-agent-token'=$token.Text.Trim()} -Body $body -TimeoutSec 8 -ErrorAction Stop
  $status.Text='Connected - last sent '+(Get-Date -Format 'HH:mm:ss')
  $values.Text="CPU $cpu% | RAM $ram% | Disk $used%"
 } catch { $status.Text='Disconnected - check address, token and network.'; $values.Text=$_.Exception.Message }
}
$timer.Add_Tick({Send-Metrics})
$start.Add_Click({
 $parsed=$null
 if (-not [Uri]::TryCreate($address.Text.Trim(),[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -notin @('http','https') -or -not $serverId.Text.Trim() -or -not $token.Text.Trim()) { [System.Windows.Forms.MessageBox]::Show('Enter the full address, server ID and token.'); return }
 $address.Enabled=$false; $serverId.Enabled=$false; $token.Enabled=$false; $start.Enabled=$false; $stop.Enabled=$true
 $status.Text='Connecting...'; $timer.Start(); Send-Metrics
})
$stop.Add_Click({$timer.Stop(); $start.Enabled=$true; $stop.Enabled=$false; $address.Enabled=$true; $serverId.Enabled=$true; $token.Enabled=$true; $status.Text='Stopped. No data is being sent.'})
$form.Add_FormClosed({$timer.Stop();$timer.Dispose()})
[System.Windows.Forms.Application]::Run($form)
