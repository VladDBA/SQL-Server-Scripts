# Readme

## Intro
 This script automates the installation of SQL Server 2017, 2019, and 2022.
 It also patches and configures the instance based on the host's resources, allows for static TCP port confiugration, inbound firwall rules creation, and also using custom configuration scripts.
 This was created to help me speed up my home lab SQL Server builds, but it's written to respect most production environments' standards.

## Prerequisites:
 1. The script needs to be in the same folder with the SQL Server installation kit (same directory as setup.exe).
 2. The configuration files need to be in the same directory as the script and should respect the following naming convention:
    - for named instance - 2022_NamedInstTemplate.ini or 2019_NamedInstTemplate.ini or 2017_NamedInstTemplate.ini
	- for default instance - 2022_DefaultInstTemplate.ini or 2019_DefaultInstTemplate.ini or 2017_DefaultInstTemplate.ini
 3. If the script should also install a cumulative update pack, then the CU install kit needs to be in the CUInstallKit directory,
    in the same parent directory as this script.
	The CU installation kit should match the following naming convention SQLServer[YYYY]-KB[KBNumber]-x64.exe.
	You can have multiple CUs in the directory, only the latest one will be installed.
 4. If SQL Server 19 or above should be installed then the SSMS installation kit should be in the SSMSInstallKit directory, in the same
    parent directory as this script.
	The SSMS installation kit should match the following naming convention SSMS-Setup*.exe.
 5. The script should be executed from PowerShell opened as admin.
 6. The script has been designed to work and tested with the provided configuration files (see the ConfigFileTemplates folder).

 Directory structure example using SQL Server 2019's installation kit
 ![Screenshot1](https://raw.githubusercontent.com/VladDBA/SQL-Server-Scripts/main/PowerShell/SQLServerInstall/SQLServerPSInstall.png)

## Behavior
 This script does the following:
 - Installs SQL Server 2017 or 2019 or 2022.
 - Writes the configuration file used to C:\Temp
 - Sets the sa password to the one provided.
 - Adds the user executing this script as a member of the sysadmin fixed server role.
 - Configures MAXDOP based on the number of CPU cores on the machine (up to 8).
 - Configures the number of tempdb data files based on the number of CPU cores on the machine (up to 8).
 - Sets Max Memory for the instance depending on the input or by calculating it based on the installed physical memory.
 - Tweaks model database file sizes and growth increments.
 - Sets the model database to use the simple recovery model.
 - Sets CTP to 50.
 - Runs any custom .sql script file provided via the -CustomScript parameter.
 - Installs CU pack, if there's any present in the CUInstallKit directory.
 - Configures a static TCP port if one is provided.
 - Adds inbound firewall rules for SQL Server, if requested.
 - Installs SSMS if requested and if SSMS 19.x is not already installed.
 - Reboots the machine.

## Parameters

| Parameter | Description |
| :--- | :--- |
| `-InstanceName` | Should be the name of the instance in case of a named instance. Leave empty if -IsDefault is used. |
| `-saPwd` | Mandatory. The password that will be set for the sa account during installation.|
| `-IsDefault` | Optional. Switch. If -IsDefault is used then a default instance will be installed.|
| `-InstanceRootDir` | Optional. The parent directory where the instance's main directory will be created. Defaults to D:\MSSQL if not provided|
| `-InstanceCollation` | Optional. The collation that the instance should use. Defaults to SQL_Latin1_General_CP1_CI_AS if not provided.|
| `-StaticPort` | Optional. The static TCP port that should be configured for the instance. |
| `-AddFirewallRules` | Optional. Switch. Adds inbound firewall rules for the TCP ports used by SQL Server and the SQL Server Browser service.|
| `-InstallSSMS` | Optional. Switch. If used, the script will check if SSMS 19 is installed and will install it if it's not.|
| `-AutoMaxMemory` | Optional. Switch. If used, the script will calculate Max Memory based on the installed physical memory. Leaving the greater of 4GB or 10% to the OS.|
| `-MaxMemoryMB` | Optional. The value in MB that the instance's Max Memory parameter should be set to. If neither -AutoMaxMemory nor -MaxMemoryMB are used, then the script will default to 4GB.|
| `-DontPatch` | Optional. Switch. When used, the script skips applying the CU patch even if the installation kit is in the CUInstallKit directory.|
| `-CustomScript` | Optional. Used to provide the path to a custom .sql script that does some extra post-install configuration.|
| `-AutoReboot` | Optional. Switch. When used, the script skips prompting to confirm the reboot and just reboots the machine.|

## Usage examples
 1. Install an instance named SQL2019 with the basic config, apply any CU kit that might exist in the CUInstallKit directory, using the default collation, and with `SuperStr0ngPassword` as the sa password
     ```PowerShell
     .\InstallSQLServer.ps1 SQL2019 -saPwd SuperStr0ngPassword
     ```
 
 2. Install an instance named SQL2022_test, configure the instance to use static TCP port 1455, add firewall rules for it, auto configure the isntance's Max Memory parameter, and also install SSMS if it's not already installed 
     ```PowerShell
     .\InstallSQLServer.ps1 SQL2022_test -saPwd SuperStr0ngPassword -StaticPort 1455 -AddFirewallRules -InstallSSMS -AutoMaxMemory
	 ```
 3. Install a default instance, don't apply the CU kit available in the CUInstallKit directory, use the SQL_Latin1_General_CP1_CS_AS collation, set Max Memory to 2GB, and run a custom config script.
     ```PowerShell
    .\InstallSQLServer.ps1 -saPwd SuperStr0ngPassword -IsDefault -MaxMemoryMB 2048 -DontPatch -CustomScript C:\temp\AdditionalConfig.sql
	```
 

## Changelog:
 - 2024-06-18 - Added components from older script used for SQL Server 2017
 - 2023-02-13 - Minor changes and moved to GitHub
 - 2024-02-10 - Added firewall rules configuration and Comment-Based help
 - 2023-12-31 - Added SQL Server 2022 support
 - 2022-05-27 - Added static port configuration
 - 2022-03-12 - Initial version of the script

## More info
[Related blog post](https://vladdba.com/2024/06/18/automate-sql-server-installation-powershell)

## MIT License
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
