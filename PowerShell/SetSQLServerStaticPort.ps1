<#
.SYNOPSIS
  This script enables TCP/IP if not enabled, sets Listen ALL to Yes if it's set to No,
 disables dynamic port, sets the static port in IPAll to the specified port number.
 Optionally adds inbound firewall rules for both the instance and the SQL Server Browser service.

.PARAMETER InstanceName
 Should be the name of the instance for which you want to make the port changes.

.PARAMETER Version
 The version of the SQL Server instance. E.g. 2019

.PARAMETER StaticPort
 The static TCP port that should be configured for the instance.

.PARAMETER AddFirewallRules
 Optional. Switch. Adds inbound firewall rules for the TCP ports used by SQL Server and the SQL Server Browser service.
 
.NOTES
 Author: Vlad Drumea (VladDBA)
 Website: https://vladdba.com/
 GitHub: https://github.com/VladDBA
 Related blog post: https://vladdba.com/2024/04/18/sql-server-static-port-powershell/

 Copyright: (c) 2024 by Vlad Drumea, licensed under MIT
 License: MIT https://opensource.org/licenses/MIT

.EXAMPLE
 PS>.\SetSQLServerStaticPort.ps1 SQL2019 2019 1488 -AddFirewallRules
 Sets the static port to 1488 for instance SQL2019, running SQL Server 2019, and adds the appropriate firewall rules

#> 

[cmdletbinding()]
param(
    [Parameter(Position = 0, Mandatory = $True)]
    [string]$InstanceName,
    [Parameter(Position = 1, Mandatory = $True)]
    [int]$Version,
    [Parameter(Position = 2, Mandatory = $True)]
    [int]$StaticPort,
    [Parameter(Mandatory = $False)]
    [switch]$AddFirewallRules
)

if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -ne $true) { 
    Write-Host " You need to run PowerShell as administrator for this script to work."  -fore Red
    Exit
}
##Figure out SQL Server build number
if($Version -eq 2016){
    $MajorVersion = 13
} elseif ($Version -eq 2017) {
    $MajorVersion = 14
} elseif ($Version -eq 2019) {
    $MajorVersion = 15
} elseif ($Version -eq 2022) {
    $MajorVersion = 16
} elseif ($Version -eq 2025) {
    $MajorVersion = 17
}

##Make sure the TCPIP protocol is enabled
$TcpStateRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL$MajorVersion.$InstanceName\MSSQLServer\SuperSocketNetLib\Tcp"
[int]$IsTcpEnabled = Get-ItemProperty -Path Registry::"$TcpStateRegPath" -Name Enabled | Select-Object -ExpandProperty Enabled
if($IsTcpEnabled -eq 0){
    Write-Host " The TCP/IP protocol for instance $InstanceName is disabled. Enabling it now."
    Set-ItemProperty -Path Registry::"$TcpStateRegPath" -Name Enabled -Value 1
}

##Make sure the Listen ALL is set to Yes protocol is enabled
$TcpStateRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL$MajorVersion.$InstanceName\MSSQLServer\SuperSocketNetLib\Tcp"
[int]$IsTcpEnabled = Get-ItemProperty -Path Registry::"$TcpStateRegPath" -Name ListenOnAllIPs | Select-Object -ExpandProperty ListenOnAllIPs
if($IsTcpEnabled -eq 0){
    Write-Host " The TCP/IP protocol for instance $InstanceName is not set to listen on all IPs.`n  Setting Listen All to Yes now."
    Set-ItemProperty -Path Registry::"$TcpStateRegPath" -Name ListenOnAllIPs -Value 1
}

Write-Host " Setting static TCP port $StaticPort for instance $InstanceName."
$PortPaths = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL$MajorVersion.$InstanceName\MSSQLServer\SuperSocketNetLib\Tcp" | Select-Object -ExpandProperty Name
foreach ($PortPath in $PortPaths) {
    if ($PortPath -notlike "*IPAll") {
        #disable dynamic TCP port
        Set-ItemProperty -Path Registry::"$PortPath" -Name TcpDynamicPorts -Value ''
        #And disable IP to avoid it overriding IPALL
        Set-ItemProperty -Path Registry::"$PortPath" -Name Enabled -Value 0
    }
    else {
        #clear out current dynamic TCP port value and set static TCP port
        Set-ItemProperty -Path Registry::"$PortPath" -Name TcpDynamicPorts -Value ''
        Set-ItemProperty -Path Registry::"$PortPath" -Name TcpPort -Value $StaticPort
    } 
}

##Create firewall rules if requested
if ($AddFirewallRules) {
    Write-Host " Adding firewall rules..."
    Write-Host " ->Adding firewall rule 'SQL Server $InstanceName'."
    #Get path of SQL Server executable for this instance
    $SQLServerFWProgram = Get-WmiObject -Class win32_service -Filter "DisplayName = 'SQL Server ($InstanceName)'" | Select-object -ExpandProperty PathName
    $SQLServerFWProgram = $SQLServerFWProgram -replace " -s$InstanceName", ""
    $SQLServerFWProgram = $SQLServerFWProgram -replace '"', ''

    $SQLServerFWDescription = "Inbound rule for SQL Server $InstanceName to allow connections to TCP port $StaticPort"
    New-NetFirewallRule -DisplayName "SQL Server $InstanceName" -Description $SQLServerFWDescription -Direction Inbound -Program $SQLServerFWProgram -LocalPort $StaticPort -Protocol TCP -Action Allow | Out-Null
    #Check if the rule exists firts
    try {
        $TestRule = Get-NetFirewallRule -DisplayName "SQL Server Browser service" -ErrorAction Stop | Select-Object -ExpandProperty DisplayName -ErrorAction Stop
        Write-Host " ->A firewall rule with the name '$TestRule' already exists."
    }
    catch {
        Write-Host " ->Adding firewall rule 'SQL Server Browser service'."
        #Get path of SQL Server Browser executable
        $SQLServerBrowserFWProgram = Get-WmiObject -Class win32_service -Filter "DisplayName = 'SQL Server Browser'" | Select-object -ExpandProperty PathName
        $SQLServerBrowserFWProgram = $SQLServerBrowserFWProgram -replace '"', ''
        $SQLServerBrowserFWDescription = "Inbound rule for SQL Server Browser service to allow connections to UDP port 1434"
        New-NetFirewallRule -DisplayName "SQL Server Browser service" -Description $SQLServerBrowserFWDescription -Direction Inbound -Program $SQLServerBrowserFWProgram -LocalPort 1434 -Protocol UDP -Action Allow | Out-Null
    }	
}

#Restart SQL Server and SQL Server Browser Service
Write-Host " Restarting services after port changes"
Restart-Service -DisplayName "SQL Server ($InstanceName)" -Force
Restart-Service -DisplayName "SQL Server Browser" -Force