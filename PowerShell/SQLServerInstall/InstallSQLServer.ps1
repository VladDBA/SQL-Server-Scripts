<#
.SYNOPSIS
 This script allows the automated installation of SQL Server 2019 and 2022.
 It also patches and configures the instance based on the host's resources, allows for static TCP port confiugration,
 inbound firwall rules creation, and also using custom configuration scripts.
 This was created to help me speed up my home lab SQL Server builds, but it's written to respect most production environments' standards.

.DESCRIPTION
 Prerequisites:
 1. The script needs to be in the same folder with the SQL Server installation kit (same directory as setup.exe).
 2. The configuration files need to be in the same directory as the script and should respect the following naming convention:
    - for named instance - 2022_NamedInstTemplate.ini or 2019_NamedInstTemplate.ini
	- for default instance - 2022_DefaultInstTemplate.ini or 2019_DefaultInstTemplate.ini
 3. If the script should also install a cumulative update pack, then the CU install kit needs to be in the CUInstallKit directory,
    in the same parent directory as this script.
	The CU installation kit should match the following naming convention SQLServer[YYYY]-KB[KBNumber]-x64.exe.
	You can have multiple CUs in the directory, only the latest one will be installed.
 4. If SQL Server 19.x should be installed then the SSMS installation kit should be in the SSMSInstallKit directory, in the same
    parent directory as this script.
	The SSMS installation kit should match the following naming convention SSMS-Setup*.exe.
 5. The script should be executed from PowerShell opened as admin.
 6. The script has been designed to work and tested with the provided configuration files.

 Behavior
 This script does the following:
 - Installs SQL Server 2019 or 2022.
 - Writes the configuration file used to C:\Temp
 - Sets the sa password to the one provided.
 - Adds the user executing this script as a member of the sysadmin fixed server role.
 - Configures MAXDOP based on the number of cores on the machine (up to 8).
 - Configures Max Memory for the instance depending on the input.
 - Tweaks model database file sizes and growth increments.
 - Sets the model database to use the simple recovery model.
 - Sets CTP to 50.
 - Runs any custom confiugration .sql script file provided via the -CustomScript parameter.
 - Installs CU pack, if there's any present in the CUInstallKit directory.
 - Configures a static TCP port if one is provided.
 - Adds inbound firewall rules for SQL Server, if requested.
 - Installs SSMS if requested and if SSMS 19.x is not already installed.
 - Reboots the machine.

 Changelog:
 2024-06-18 - Added components from older script use for SQL Server 2017
 2024-02-13 - Minor changes and moved to GitHub
 2024-02-10 - Added firewall rules configuration and Comment-Based help
 2023-12-31 - Added SQL Server 2022 support
 2022-05-27 - Added static port configuration
 2022-03-12 - Initial version of the script

 MIT License
 Copyright (c) 2024 Vlad Drumea

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

.PARAMETER InstanceName
 Should be the name of the instance in case of a named instance. Leave empty if -IsDefault is used.

.PARAMETER saPwd
 Mandatory. The password that will be set for the sa account during installation.

.PARAMETER IsDefault
 Optional. Switch. If -IsDefault is used then a default instance will be installed.

.PARAMETER InstanceRootDir
 Optional. The parent directory where the instance's main directory will be created. Defaults to D:\MSSQL if not provided.

.PARAMETER BackupRootDir
 Optional. The parent directory where the instance's database backup files will be stored. Defaults to the value of -InstanceRootDir if not provided.

.PARAMETER UserDataRootDir
 Optional. The parent directory where the instance's user database data files will be stored. Defaults to the value of -InstanceRootDir if not provided.

.PARAMETER UserTLogRootDir
 Optional. The parent directory where the instance's user database tlog files will be stored. Defaults to the value of -UserDataRootDir if not provided.

.PARAMETER TempdbDataRootDir
 Optional. The parent directory where the instance's Tempdb data files will be stored. Defaults to the value of -InstanceRootDir if not provided.

.PARAMETER TempdbTLogRootDir
 Optional. The parent directory where the instance's Tempdb tlog files will be stored. Defaults to the value of -TempdbDataRootDir if not provided.
 
.PARAMETER InstanceCollation
 Optional. The collation that the instance should use. Defaults to SQL_Latin1_General_CP1_CI_AS if not provided.

.PARAMETER StaticPort
 Optional. The static TCP port that should be configured for the instance.

.PARAMETER AddFirewallRules
 Optional. Switch. Adds inbound firewall rules for the TCP ports used by SQL Server and the SQL Server Browser service.

.PARAMETER InstallSSMS
 Optional. Switch. If used, the script will check if SSMS 19 is installed and will install it if it's not.

.PARAMETER AutoMaxMemory
 Optional. Switch. If used, the script will calculate Max Memory based on the installed physical memory. Leaving the greater of 4GB or 10% to the OS.

.PARAMETER MaxMemoryMB
 Optional. The value in MB that the instance's Max Memory parameter should be set to. If neither -AutoMaxMemory nor -MaxMemoryMB are used, then the script will default to 4GB.

.PARAMETER DontPatch
 Optional. Switch. When used, the script skips applying the CU patch even if the installation kit is in the CUInstallKit directory.

.PARAMETER CustomScript
 Optional. Used to provide the path to a custom .sql script that does some extra post-install configuration.

.PARAMETER AutoReboot
 Optional. Switch. When used, the script skips prompting to confirm the reboot and just reboots the machine.

.LINK

.NOTES
 Author: Vlad Drumea (VladDBA)
 Website: https://vladdba.com/
 GitHub: https://github.com/VladDBA

 Copyright: (c) 2024 by Vlad Drumea, licensed under MIT
 License: MIT https://opensource.org/licenses/MIT

.EXAMPLE
 PS>.\InstallSQLServer.ps1 SQL2019 -saPwd SuperStr0ngPassword
 Installs a SQL Server instance named SQL2019 with the sa password set as SuperStr0ngPassword

.EXAMPLE
 PS>.\InstallSQLServer.ps1 SQL2019 -saPwd SuperStr0ngPassword -StaticPort 1455 -AddFirewallRules -InstallSSMS
 Installs a SQL Server instance named SQL2019 with the sa password set as SuperStr0ngPassword, sets 1455 as the static TCP port, 
 adds firewall rules and installs SSMS

.EXAMPLE
 PS>.\InstallSQLServer.ps1 -saPwd SuperStr0ngPassword -IsDefault
 Installs a default instance with the sa password set as SuperStr0ngPassword

.EXAMPLE
 PS>.\InstallSQLServer.ps1 SQL2022_01 -saPwd SuperStr0ngPassword -AutoMaxMemory -InstanceRootDir D:\ -UserDataRootDir D:\ -UserTLogRootDir E:\ -TempdbDataRootDir E:\ -BackupRootDir F:\
 Install a named instance, SQL2022_01, apply CU, auto configure memory, use SQL_Latin1_General_CP1_CS_AS collation, have the system databases 
 and user database data files on drive D, tempdb files and user database tlog files on drive E, and backups on drive F 

#>
[cmdletbinding()]
param(
	[Parameter(Position = 0, Mandatory = $False)]
	[string]$InstanceName,
	[Parameter(Mandatory = $True)]
	[string]$saPwd,
	[Parameter(Mandatory = $False)]
	[switch]$IsDefault,
	[Parameter(Mandatory = $False)]
	[string]$InstanceRootDir = "D:\MSSQL",
	[Parameter(Mandatory = $False)]
	[string]$BackupRootDir = $InstanceRootDir,
	[Parameter(Mandatory = $False)]
	[string]$UserDataRootDir = $InstanceRootDir,
	[Parameter(Mandatory = $False)]
	[string]$UserTLogRootDir = $UserDataRootDir,
	[Parameter(Mandatory = $False)]
	[string]$TempdbDataRootDir = $InstanceRootDir,
	[Parameter(Mandatory = $False)]
	[string]$TempdbTLogRootDir = $TempdbDataRootDir,
	[Parameter(Mandatory = $False)]
	[string]$InstanceCollation,
	[Parameter(Mandatory = $False)]
	[int]$StaticPort = 0,
	[Parameter(Mandatory = $False)]
	[switch]$AddFirewallRules,
	[Parameter(Mandatory = $False)]
	[switch]$InstallSSMS,
	[Parameter(Mandatory = $False)]
	[switch]$AutoMaxMemory,
	[Parameter(Mandatory = $False)]
	[int]$MaxMemoryMB = 4096,
	[Parameter(Mandatory = $False)]
	[switch]$DontPatch,
	[Parameter(Mandatory = $False)]
	[string]$CustomScript,
	[Parameter(Mandatory = $False)]
	[switch]$AutoReboot
)

#Get script path
$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

##Handling Input
# If trailing backslash, remove it so it doesn't mess with the paths in the config file
if ($InstRootDir -like "*\") {
	$InstRootDir = $InstRootDir -replace ".{1}$"
}

# is it a default instance or a named one?
if (($IsDefault) -and ([string]::IsNullOrEmpty($InstanceName))) {
	$InstanceName = "MSSQLSERVER"
}
elseif (($IsDefault) -and (!([string]::IsNullOrEmpty($InstanceName))) -and ($InstanceName -ne "MSSQLSERVER")) {
	Write-Host " You've set -IsDefault while also providing a value for -InstanceName." -fore Red
	Write-Host " ->You can't have a named default instance. Using $InstanceName as the instance name"
	$IsDefault = $false
}
elseif (($IsDefault) -and (!([string]::IsNullOrEmpty($InstanceName))) -and ($InstanceName -eq "MSSQLSERVER")) {
	Write-Host " You don't have to provide $InstanceName as the instance name when using the -IsDefault switch." fore Yellow
}
elseif (($IsDefault -eq $False) -and ([string]::IsNullOrEmpty($InstanceName))) {
	Write-Host " An instance name was not provided." -Fore Yellow
	while ([string]::IsNullOrEmpty($InstanceName)) {
		$InstanceName = Read-Host -Prompt "Please provide a name for your instance:"
	}
}

# what port are we using?
if ($StaticPort -ne 0) {
	if ($StaticPort -le 1023) {
		Write-Host " I'm not the network police, but you're opting to use a well-known port." -fore Yellow
		Write-Host " ->This can lead to port conflicts between your instance and other services." -fore Yellow
	}
 elseif ($StaticPort -eq 1434) {
		Write-Host " $StaticPort is used by the SQL Server Browser service and should be left alone." fore yellow
		Write-Host " ->Incrementing port number by 1" -fore Yellow
		$StaticPort += 1
	}
}

# You have the right to a collation. If you don't have a colation, one will be provided for you. 
if ([string]::IsNullOrEmpty($InstanceCollation)) {
	Write-Host " A specific collation was not provided for -InstanceCollation" -Fore Yellow
	$InstanceCollation = "SQL_Latin1_General_CP1_CI_AS"
	Write-Host " ->Defaulting to SQL Server's standard collation - $InstanceCollation"
}

#Determine MAX Memory
if ($AutoMaxMemory) {
	#Get physical memory
	$TotalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum / 1mb
	#Determine if 10% of installed memory is greater than 4GB
	$10PercentRAM = $TotalRAM / 10
	$10PercentRAM = [math]::Round($10PercentRAM)
	if (4096 -ge $10Percent) { 
		$MaxMemoryMB = $TotalRAM - 4096 
	}
 else { 
		$MaxMemoryMB = $TotalRAM - $10Percent 
	}
	if ($MaxMemoryMB -lt 0) {
		$MaxMemoryMB = 4096
		Write-Host " Installed physical memory could not be determined."
		Write-Host " ->Max Memory has defaulted to " -NoNewline
	}
 else {
		Write-Host " You've opted to automatically set Max Memory."
		Write-Host " ->Max Memory has been calculated as " -NoNewline
	}
	Write-Host "$MaxMemoryMB MB"
}

##Handling internal variables
#Getting the version based on the config file name
if ($InstanceName -eq "MSSQLSERVER") {
	$ConfigTemplateName = Get-ChildItem -Path $ScriptPath -name *_DefaultInstTemplate.ini
	$Version = $ConfigTemplateName -replace "_DefaultInstTemplate.ini", ""
}
else {

	$ConfigTemplateName = Get-ChildItem -Path $ScriptPath -name *_NamedInstTemplate.ini
	$Version = $ConfigTemplateName -replace "_NamedInstTemplate.ini", ""
}

#Determine build version
if ($Version -eq "2022") {
	$MajorVersion = "16"
}
elseif ($Version -eq "2019") {
	$MajorVersion = "15"
}
elseif ($Version -eq "2017") {
	$MajorVersion = "14"
}

#Set SQLCMD instance name
if ($InstanceName -eq "MSSQLSERVER") {
	$CmdInstance = "localhost"
}
else {
	$CmdInstance = "localhost\$InstanceName"
}

$HostName = [System.Net.Dns]::GetHostName()

$TempDir = "C:\Temp"
$InstallConfigFile = $TempDir + "\" + $InstanceName + "_Config.ini"
$InstancePath = $InstanceRootDir + "\" + $InstanceName
$InstanceOldPath = $InstancePath + "_old"


#Load config file template into memory
[string]$ConfigTemplate = [System.IO.File]::ReadAllText("$ScriptPath\$ConfigTemplateName")

#Check if there's already an instance with that name and cancel if yes
$ServiceName = Get-Service -Name "SQL Server ($InstanceName)" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName
if ($ServiceName -eq "SQL Server ($InstanceName)") {
	Write-Host " An instance named $InstanceName is already installed on this machine!" -Fore Red
	Write-Host " ->Canceling installation."
	Read-Host -Prompt "Press Enter to end script execution."
	Exit
}

#Check if there's a leftover directory from a previous instance with the same name
if (Test-Path $InstancePath) {
	try {
		Write-Host " Found leftover instance directory from a previous installation." -fore Yellow
		Write-Host " ->Attempting to rename it..."
		Rename-Item -Path $InstancePath -NewName $InstanceOldPath -ErrorAction Stop	
		Write-Host " ->Old instance directory renamed to $InstanceOldPath."
	}
	catch {
		#Might fail if not running from elevated PS, so trying elevated PS too
		try {
			Start-Process -Wait -FilePath "powershell" -Verb RunAs -ArgumentList "-command Rename-Item -Path $InstancePath -NewName $InstanceOldPath" -ErrorAction Stop
			Write-Host " ->Old instance directory renamed to $InstanceOldPath."	
		}
		catch {
			Write-Host " ->Failed to rename the directory" -fore Red
			Read-Host -Prompt "Press Enter to end script execution."
			Exit
		}
	}
		
}

#Get current user's Windows/AD account
$WinSysadminAccount = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if (([string]::IsNullOrEmpty($WinSysadminAccount)) -or ($WinSysadminAccount -eq "The command completed successfully." )) {
	# Use admin account as a fallback in case user account can't be retrieved
	$HasWinSysadminAccount = "N"
	$WinSysadminAccount = "Administrator"
}
else {
	$HasWinSysadminAccount = "Y"
}

#Create temp directory if it doesn't exist
if (!(Test-Path C:\Temp)) {
	New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null
}
#Get physical core count
try {
	[int]$CoreCount = ( (Get-CimInstance -ClassName Win32_Processor).NumberOfCores | Measure-Object -Sum).Sum
}
catch {
	Write-Host " Cannot determine number of CPU cores, defaulting to 4." -fore Yellow
	[int]$CoreCount = 4
}
#Don't end up with MAXDOP and tempdb data files count higher than 8
if ($CoreCount -gt 8) {
	$CoreCount = 8
}

#If user db and/or tempdb and/or backup paths are different than $InstanceRootDir 
#they'll need to be created otherwise the install errors out
if (($InstanceRootDir -ne $BackupRootDir) -and (!(Test-Path  "$BackupRootDir\$InstanceName\Backup"))) {
	New-Item -ItemType "directory" -Path "$BackupRootDir\$InstanceName\Backup" | Out-Null
}
if (($InstanceRootDir -ne $UserDataRootDir) -and (!(Test-Path  "$UserDataRootDir\$InstanceName\Data"))) {
	New-Item -ItemType "directory" -Path "$UserDataRootDir\$InstanceName\Data" | Out-Null
}

if (($InstanceRootDir -ne $UserTLogRootDir) -and (!(Test-Path  "$UserTLogRootDir\$InstanceName\TLog"))) {
	New-Item -ItemType "directory" -Path "$UserTLogRootDir\$InstanceName\TLog" | Out-Null
}

if (($InstanceRootDir -ne $TempdbDataRootDir) -and (!(Test-Path  "$TempdbDataRootDir\$InstanceName\TempDB"))) {
	New-Item -ItemType "directory" -Path "$TempdbDataRootDir\$InstanceName\TempDB" | Out-Null
}

if (($InstanceRootDir -ne $TempdbTLogRootDir) -and (!(Test-Path  "$TempdbTLogRootDir\$InstanceName\TLog"))) {
	New-Item -ItemType "directory" -Path "$TempdbTLogRootDir\$InstanceName\TLog" | Out-Null
}

#Prepare config file
[string]$ConfigFile = $ConfigTemplate -replace "PSReplaceInstanceName", $InstanceName
[string]$ConfigFile = $ConfigFile -replace "PSReplaceCollation", $InstanceCollation
[string]$ConfigFile = $ConfigFile -replace "PSReplaceInstRootDir", $InstanceRootDir
[string]$ConfigFile = $ConfigFile -replace "PSReplaceBkpRootDir", $BackupRootDir
[string]$ConfigFile = $ConfigFile -replace "PSReplaceUserDataRootDir", $UserDataRootDir
#There's something weird with UserTLogRootDir
if ([string]::IsNullOrEmpty($UserTLogRootDir)) {
	$UserTLogRootDir = $UserDataRootDir
}
[string]$ConfigFile = $ConfigFile -replace "PSReplaceUserTLogRootDir", $UserTLogRootDir
[string]$ConfigFile = $ConfigFile -replace "PSReplaceTempdbDataRootDir", $TempdbDataRootDir
[string]$ConfigFile = $ConfigFile -replace "PSReplaceTempdbTLogRootDir", $TempdbTLogRootDir
[string]$ConfigFile = $ConfigFile -replace "PSReplaceCoreCount", $CoreCount
[string]$ConfigFile = $ConfigFile -replace "PSReplaceMaxMemory", $MaxMemoryMB

$ConfigFile | Out-File -Encoding ASCII -FilePath $InstallConfigFile -Force

Write-Host " Starting SQL Server installation for instance $InstanceName..."
Write-Host " ->Note: if nothing happens, you might have a pending reboot. Restart the machine and try again." -fore Yellow
Start-Process -Wait -FilePath "$ScriptPath\Setup.exe" -ArgumentList "/SAPWD=$saPwd /QS /Action=install /IACCEPTSQLSERVERLICENSETERMS /SQLSYSADMINACCOUNTS=$WinSysadminAccount /ConfigurationFile=$InstallConfigFile"
#Check if install finished and service is running
$ServiceName = Get-Service -Name "SQL Server ($InstanceName)" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" } | Select-Object -ExpandProperty DisplayName
if ($null -eq $ServiceName) {
	while ($null -eq $ServiceName) {
		Start-Sleep -Seconds 35
		$ServiceName = Get-Service -Name "SQL Server ($InstanceName)" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" } | Select-Object -ExpandProperty DisplayName
	}
}
#Wait 5 seconds for the system databases to be initialized
Start-Sleep -Seconds 5
Write-Host " Instance installation finished." -Fore Green
Write-Host " Proceeding with post-install configuration steps..."
#SQL Server CTP and model db tweaks
$InstanceConfigTweaks = @"
EXEC sys.sp_configure N'show advanced options', N'1';
GO
RECONFIGURE WITH OVERRIDE;
GO
EXEC sys.sp_configure N'cost threshold for parallelism', N'50';
GO
$(if($Version -eq "2017"){
"EXEC sys.sp_configure N'max server memory (MB)', N'$MaxMemoryMB';`nGO`nRECONFIGURE WITH OVERRIDE;`nGO"
})
RECONFIGURE WITH OVERRIDE;
GO
EXEC sys.sp_configure N'backup compression default', N'1';
GO
RECONFIGURE WITH OVERRIDE;
GO
EXEC sys.sp_configure N'show advanced options', N'0';
GO
RECONFIGURE WITH OVERRIDE;
GO
ALTER DATABASE [model] SET RECOVERY SIMPLE WITH NO_WAIT;
GO
ALTER DATABASE [model] MODIFY FILE (NAME = N'modeldev', FILEGROWTH = 400MB);
GO
ALTER DATABASE [model] MODIFY FILE (NAME = N'modellog', FILEGROWTH = 300MB);
GO
"@

#If local Admin account was added as a workaround for the install error, drop it here
if ($HasWinSysadminAccount -eq "N") {
	$InstanceConfigTweaks = $InstanceConfigTweaks + @"
DECLARE @SQL NVARCHAR(300);
DECLARE @WinSysAdminLogin NVARCHAR(128);
SELECT @WinSysAdminLogin = [name] FROM sys.server_principals 
WHERE [name] LIKE N'%Administrator';
SET @SQL = N'DROP LOGIN ['+ @WinSysAdminLogin +N'];'
EXEC(@SQL);
GO
"@
}

#Refresh path environment variable so we can use sqlcmd if it wasn't available on the machine prior to this installation
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

$TestQuery = "SET NOCOUNT ON;`nSELECT 'XYZ';`nGO"
#Waiting for the instance to get out of single user mode 
[string]$sqlcmdOut = sqlcmd -S $CmdInstance -U sa -P $saPwd -Q $TestQuery -x  2>&1 | Out-String
#cleanup output noise
$sqlcmdOut = $sqlcmdOut -replace " ", ""
$sqlcmdOut = $sqlcmdOut -replace "-", ""
$sqlcmdOut = $sqlcmdOut -replace "`r`n", ""
while ($sqlcmdOut -ne "XYZ") {
	Write-Host " The instance is not connectable yet - waiting 20 seconds..."
	Start-Sleep -Seconds 20
	[string]$sqlcmdOut = sqlcmd -S $CmdInstance -U sa -P $saPwd -Q $TestQuery -x  2>&1 | Out-String
	$sqlcmdOut = $sqlcmdOut -replace " ", ""
	$sqlcmdOut = $sqlcmdOut -replace "-", ""
	$sqlcmdOut = $sqlcmdOut -replace "`r`n", ""
}

[string]$sqlcmdOut = sqlcmd -S $CmdInstance -U sa -P $saPwd -Q $InstanceConfigTweaks -x  2>&1 | Out-String
#Cleaning up the output
$sqlcmdOut = $sqlcmdOut -replace ". Run the RECONFIGURE statement to install" , ""
Write-Host $sqlcmdOut

if (!([string]::IsNullOrEmpty($CustomScript))) {
	Write-Host " Running custom script..."
	$sqlcmdOut = sqlcmd -S $CmdInstance -U sa -P $saPwd -i "$CustomScript" -x  2>&1 | Out-String
	#Not cleaning up this string
	Write-Host $sqlcmdOut
}

Write-Host " Instance configuration finished." -Fore Green
$CUPath = $ScriptPath + "\CUInstallKit"
try {
	$CUKit = Get-ChildItem -Path $CUPath -name SQLServer$Version-KB*-x64.exe | Sort-Object -Descending | Select-Object -first 1
}
catch {
	Write-Host " Patch kit not found, skipping instance patching."
}
if ((!([string]::IsNullOrEmpty($CUKit))) -and ($DontPatch -ne $true)) {
	Write-Host " Applying patch $CUKit to instance $InstanceName."
	Start-Process -Wait -FilePath "$CUPath\$CUKit" -ArgumentList "/qs /IAcceptSQLServerLicenseTerms /Action=Patch /InstanceName=$InstanceName"
	Start-Sleep -Seconds 5
}
# Return instance build version and CU info
$VersQuery = "SET NOCOUNT ON;`nSELECT SERVERPROPERTY('ProductVersion'), ISNULL(SERVERPROPERTY('ProductUpdateLevel'), '');`nGO"
try {
	[string]$VersInfo = sqlcmd -S $CmdInstance -U sa -P $saPwd -Q $VersQuery -x | Out-String -ErrorAction Stop
	[string]$VersInfo = $VersInfo -replace "--", ""
	[string]$VersInfo = $VersInfo -replace "  ", ""
	[string]$VersInfo = $VersInfo.Trim()
	if ($VersInfo -like "1*") {
		[string]$VersInfo = $VersInfo -replace "CU", " - CU"
		Write-Host " Instance version: $VersInfo"
	}
	
}
catch {
	Write-Host " Instance version info could not be obtained."
}

##Set static port if provided
if ($StaticPort -ne 0) {
	Write-Host " Setting static TCP port $StaticPort."
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
}

##Create firewall rules if requested
if ($AddFirewallRules) {
	Write-Host " Adding firewall rules..."
	Write-Host " ->Adding firewall rule 'SQL Server $InstanceName'."
	#Get path of SQL Server executable for this instance
	$SQLServerFWProgram = Get-WmiObject -Class win32_service -Filter "DisplayName = 'SQL Server ($InstanceName)'" | Select-object -ExpandProperty PathName
	$SQLServerFWProgram = $SQLServerFWProgram -replace " -s$InstanceName", ""
	$SQLServerFWProgram = $SQLServerFWProgram -replace '"', ''

	if (($StaticPort -eq 0) -or ($InstanceName -eq "MSSQLSERVER")) {
		#default instance port
		$SQLServerFWDescription = "Inbound rule for SQL Server $InstanceName to allow connections to TCP port 1433"
		New-NetFirewallRule -DisplayName "SQL Server $InstanceName" -Description $SQLServerFWDescription -Direction Inbound -Program $SQLServerFWProgram -LocalPort 1433 -Protocol TCP -Action Allow | Out-Null
	}
 else {
		$SQLServerFWDescription = "Inbound rule for SQL Server $InstanceName to allow connections to TCP port $StaticPort"
		New-NetFirewallRule -DisplayName "SQL Server $InstanceName" -Description $SQLServerFWDescription -Direction Inbound -Program $SQLServerFWProgram -LocalPort $StaticPort -Protocol TCP -Action Allow | Out-Null
	}
	#Check if the rule exists first
	try {
		$TestRule = Get-NetFirewallRule -DisplayName "SQL Server Browser service" -ErrorAction Stop | Select-Object -ExpandProperty DisplayName -ErrorAction Stop
		Write-Host " ->A firewall rule with the name '$TestRule' already exists."
		$BrowserRuleExists = 'Y'
	}
	catch {
		Write-Host " ->Adding firewall rule 'SQL Server Browser service'."
		$BrowserRuleExists = 'N'
		#Get path of SQL Server Browser executable
		$SQLServerBrowserFWProgram = Get-WmiObject -Class win32_service -Filter "DisplayName = 'SQL Server Browser'" | Select-object -ExpandProperty PathName
		$SQLServerBrowserFWProgram = $SQLServerBrowserFWProgram -replace '"', ''
		$SQLServerBrowserFWDescription = "Inbound rule for SQL Server Browser service to allow connections to UDP port 1434"
		New-NetFirewallRule -DisplayName "SQL Server Browser service" -Description $SQLServerBrowserFWDescription -Direction Inbound -Program $SQLServerBrowserFWProgram -LocalPort 1434 -Protocol UDP -Action Allow | Out-Null
	}	
}

#Restart SQL Server and SQL Server Browser Service
if (($AddFirewallRules) -or ($StaticPort -ne 0)) {
	Write-Host " Restarting services after port and/or firewall rules change"
	Restart-Service -DisplayName "SQL Server ($InstanceName)" -Force
	Restart-Service -DisplayName "SQL Server Browser" -Force
}

if ($InstallSSMS) {
	#Check if SSMS 19 is installed, and install it if not
	Write-Host " "
	Write-Host " Checking if SSMS 19 or newer is installed..."
	[string]$SSMSVers = Get-CimInstance -Class Win32_Product -Filter "Name = 'SQL Server Management Studio' and Version >= '19.0.0'" | Sort-Object -Descending -Property Version | Select-Object -ExpandProperty Version -First 1
	if ([string]::IsNullOrEmpty($SSMSVers)) {
		Write-Host " ->SSMS 19 or newer is not installed, installing it now..."
		$SSMSPath = $ScriptPath + "\SSMSInstallKit"
		try {
			$SSMSKit = Get-ChildItem -Path $SSMSPath -name SSMS-Setup*.exe | Sort-Object -Descending | Select-Object -first 1
		}
		catch {
			Write-Host " SSMS kit not found, skipping SSMS installation."
		}
		if (!([string]::IsNullOrEmpty($SSMSKit))) {
			Start-Process -Wait -FilePath "$SSMSPath\$SSMSKit" -ArgumentList "/Install /passive /norestart"
		}
	 
	}
	else {
		Write-Host " ->SSMS $SSMSVers already installed."
	}
}

Write-Host ("=" * 90)
Write-Host " SQL Server $Version installation and configuration - " -NoNewline
Write-Host "Done" -Fore Green
Write-Host " Instance: " -NoNewline
if ($InstanceName -eq "MSSQLSERVER") {
	Write-Host "$HostName"
}
else {
	Write-Host "$HostName\$InstanceName"
}
Write-Host " Instance directory: "
Write-Host "  $InstancePath"
Write-Host " Collation: $InstanceCollation"
Write-Host " sa password: $saPwd"
if ($StaticPort -ne 0) {
	Write-Host " TCP port: $StaticPort"
}
if ($AddFirewallRules) {
	Write-Host " Firwall rule(s) added:"
	Write-Host "  SQL Server $InstanceName"
	if ($BrowserRuleExists -ne 'Y') {
		Write-Host "  SQL Server Browser service"
	}
}
if ($HasWinSysadminAccount -eq "Y") {
	Write-Host " The following user has been added as a sysadmin on the instance:"
	Write-Host "   $WinSysadminAccount" -fore yellow
}
Write-Host " The config .ini file used for the installation has been saved as:"
Write-Host " $InstallConfigFile"
Write-Host " "
Write-Host ("=" * 90)
Write-Host "The machine needs to be restarted to complete the installation."
if ($AutoReboot -eq $false) {
	$RebootNow = Read-Host -Prompt "Restart now?(empty defaults to N)[Y/N]"
}
if (($RebootNow -eq "Y") -or ($AutoReboot)) {
	Write-Host "The machine will be restarted in 5 seconds..."
	Start-Sleep -Seconds 5
	Restart-Computer
}
else {
	Read-Host -Prompt "Press Enter to end scritp execution."
}