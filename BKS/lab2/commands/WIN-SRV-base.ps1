New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 10.1.100.12 -PrefixLength 28 -DefaultGateway 10.1.100.1 | Out-Null
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 8.8.8.8
Set-TimeZone -Id 'Russian Standard Time'
$ts = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty $ts -Name fDenyTSConnections -Value 0
Set-ItemProperty "$ts\WinStations\RDP-Tcp" -Name UserAuthentication -Value 1
Set-ItemProperty "$ts\WinStations\RDP-Tcp" -Name SecurityLayer -Value 2
$gp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
New-Item $gp -Force | Out-Null
Set-ItemProperty $gp -Name UserAuthentication -Value 1 -Type DWord
Set-ItemProperty $gp -Name SecurityLayer -Value 2 -Type DWord
Disable-NetFirewallRule -DisplayGroup 'Remote Desktop'
New-NetFirewallRule -DisplayName 'RDP via WireGuard' -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress 10.1.200.0/24 -Action Allow | Out-Null
New-NetFirewallRule -DisplayName 'ICMPv4 echo (DMZ, HQ, VPN)' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress 10.1.100.0/28,10.1.10.0/27,10.1.200.0/24 -Action Allow | Out-Null
$pw = ConvertTo-SecureString 'Lab2-Vpn-Win#7' -AsPlainText -Force
New-LocalUser -Name rdpuser -Password $pw -FullName 'Remote operator' -PasswordNeverExpires | Out-Null
Add-LocalGroupMember -Group 'Remote Desktop Users' -Member rdpuser
Install-WindowsFeature Web-Server
Set-Content C:\inetpub\wwwroot\index.html '<h1>WIN-SRV (DMZ 10.1.100.12) - BKS lab 2</h1>'
