$ErrorActionPreference = 'Stop'
$nic = Get-NetAdapter | Where-Object MacAddress -eq '50-C7-6F-00-0C-00'
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object PrefixOrigin -ne WellKnown | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress 10.1.99.20 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses 10.1.99.1
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*' | Set-NetFirewallRule -RemoteAddress 192.168.15.128
New-Item -ItemType Directory -Path C:\BKS4 -Force | Out-Null
$ProgressPreference = 'SilentlyContinue'
$webClient = New-Object Net.WebClient
foreach ($f in 'CCM.msi','Data1.cab','setup.exe','VersionInfo.txt') { $webClient.DownloadFile(('http://192.168.15.128:18084/'+$f),('C:\BKS4\'+$f)) }
'BKS4 bootstrap complete' | Out-File C:\BKS4\bootstrap-ok.txt
