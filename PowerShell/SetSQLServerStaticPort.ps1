<#
.SYNOPSIS
 This script disables dynamic port for the specified instance, sets the static port in IPAll to the specified port number,
 and can optionally add inbound firewall rules for both the instance and the SQL Server Browser service.

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
}

Write-Host " Setting static TCP port $StaticPort for instance $InstanceName."
$PortPaths = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL$MajorVersion.$InstanceName\MSSQLServer\SuperSocketNetLib\Tcp" | Select-Object -ExpandProperty Name
foreach ($PortPath in $PortPaths) {
    if ($PortPath -notlike "*IPAll") {
        #disable dynamic TCP port
        Set-ItemProperty -Path Registry::"$PortPath" -Name TcpDynamicPorts -Value ''
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