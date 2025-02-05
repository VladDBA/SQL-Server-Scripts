/*
         Description:  This script generates the required T-SQL and PowerShell commands 
        to move database data and/or transaction log files to new locations.
         Create date: 2025-02-05
         Author: Vlad Drumea
         Website: https://vladdba.com
         From: https://github.com/VladDBA/SQL-Server-Scripts/
         More info: 
         License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
         It generates commands to:
           - Set the database offline (if not tempdb) - T-SQL
           - Create the new folder(s) if they don't exist - PowerShell
           - Grant the SQL Server service account permissions to the new folder(s) - PowerShell
           - Move the database files to the new folder(s) (if not tempdb) - PowerShell
           - Update the path in the metadata - T-SQL
           - Set the database online (if not tempdb) - T-SQL
           - Restart the SQL Server service (if tempdb) - PowerShell
           - Remove the old files (if tempdb) - PowerShell

         Usage:
           1. Set the database name 
           2. Set at least one of destination folder paths
           3. Run the script in SSMS
           4. Copy the output and run it in SSMS and PowerShell as instructed
*/

SET NOCOUNT ON;
DECLARE @DatabaseName      NVARCHAR(128),
        @DataDestination   NVARCHAR(200),
        @TLogDestination   NVARCHAR(200);

/*Set your database name and new destination folder paths here*/
SELECT @DatabaseName    = N'',
       @DataDestination = N'',
       @TLogDestination = N'';

/*Internal variables*/
DECLARE @LineFeed       NVARCHAR(5) = CHAR(13) + CHAR(10),
        @Command        NVARCHAR(2000),
        @ServiceName    NVARCHAR(256),
        @ServiceAccount NVARCHAR(256),
        @PreHeader      NVARCHAR(20);
DECLARE @FileTypes TABLE
    ([FType]    TINYINT,
     [DestPath] NVARCHAR(256));

SET @PreHeader = @LineFeed + REPLICATE(' ', 10)
/*Clean input*/
SET @DatabaseName = LTRIM(RTRIM(@DatabaseName));
SET @DataDestination = LTRIM(RTRIM(@DataDestination));
SET @TLogDestination = LTRIM(RTRIM(@TLogDestination));

/*Make sure the database exists*/
IF ( DB_ID(@DatabaseName) ) IS NULL
  BEGIN
      RAISERROR('The database you specified does not exist. Please check the name and try again.',16,1);

      RETURN;
  END;
/*Make sure at least one destination path is provided*/
IF ( @DataDestination = N''
     AND @TLogDestination = N'' )
  BEGIN
      RAISERROR('You didn''t specify any destination path(s). Please provide the destination path(s) and try again.',16,1);
      RETURN;
  END;

IF ( @DataDestination NOT LIKE N'%\' )
  BEGIN
      SET @DataDestination += N'\'
  END;

IF ( @TLogDestination NOT LIKE N'%\' )
  BEGIN
      SET @TLogDestination += N'\'
  END;

INSERT INTO @FileTypes
            ([FType],
             [DestPath])
VALUES      (0,@DataDestination),
            (1,@TLogDestination);

/*Are we moving only data files or only tlg files?*/
IF( @DataDestination = N'\' )
  BEGIN
      /*Not moving data files*/
      DELETE FROM @FileTypes
      WHERE  [FType] = 0;
  END;

IF( @TLogDestination = N'\' )
  BEGIN
      /*Not moving TLog files*/
      DELETE FROM @FileTypes
      WHERE  [FType] = 1;
  END;

IF( @DatabaseName <> N'tempdb' )
  BEGIN
      /*Set database offline*/
      PRINT @PreHeader + N'/*   Run in SSMS   */'

      SET @Command = N'USE [master]' + @LineFeed + N'GO' + @LineFeed;
      SET @Command += N'ALTER DATABASE [' + @DatabaseName
                      + N'] SET OFFLINE WITH ROLLBACK IMMEDIATE;';
      SET @Command +=@LineFeed + N'GO' + @LineFeed;

      PRINT @Command
  END;

/*Get svc account and svc name*/
SELECT @ServiceName = [servicename],
       @ServiceAccount = [service_account]
FROM   [sys].[dm_server_services]
WHERE  [servicename] LIKE N'SQL Server%'
       AND [servicename] NOT LIKE N'SQL Server Agent%'
       AND [filename] LIKE N'%sqlservr%'

PRINT @PreHeader + N'##   Run in PowerShell opened as Administrator   ##'

/*Make sure that path exists, create it if not*/
SET @Command = @LineFeed+N'#Make sure PS plays nice with icacls'
               + @LineFeed+N'$GrantPart = ''"' + @ServiceAccount
               + N'":(OI)(CI)F''' + @LineFeed;

SELECT @Command += @LineFeed+N'#Create directory' + @LineFeed
                   + N'If(!(Test-Path -Path "'
                   + CASE
                       WHEN MAX([FType]) = 0 THEN @DataDestination
                       WHEN MAX([FType]) = 1 THEN @TLogDestination
                     END
                   + N'" -PathType container )){' + @LineFeed
                   + N' New-Item -Path "'
                   + CASE
                       WHEN MAX([FType]) = 0 THEN @DataDestination
                       WHEN MAX([FType]) = 1 THEN @TLogDestination
                     END
                   + N'" -ItemType Directory}' + @LineFeed
                   + @LineFeed+N'#Grant permissions to service account on directory'
                   + @LineFeed + N'icacls.exe "'
                   + CASE
                       WHEN MAX([FType]) = 0 THEN @DataDestination
                       WHEN MAX([FType]) = 1 THEN @TLogDestination
                     END
                   + N'" /GRANT $GrantPart' + @LineFeed
FROM   @FileTypes
GROUP  BY [DestPath];

IF @DatabaseName = N'tempdb'
  BEGIN
      PRINT @Command;
      PRINT @PreHeader + N'/*   Run in SSMS   */';

      SELECT @Command = N'USE [master]' + @LineFeed + N'GO' + @LineFeed;

      SELECT @Command +=  N'ALTER DATABASE [' + @DatabaseName
                         + N'] MODIFY FILE (NAME = [' + [f].[name]
                         + N'],' + N' FILENAME = '''
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'\' THEN @TLogDestination
                             WHEN [type] = 0
                                  AND @DataDestination <> N'\' THEN @DataDestination
                           END
                         + N'' +
                         + SUBSTRING([physical_name], LEN([physical_name]) -CHARINDEX(N'\', REVERSE([physical_name]))+2, LEN([physical_name]))
                         + N''');' + @LineFeed + N'GO' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName)
	  AND [f].[type] IN (SELECT FType FROM @FileTypes);

      PRINT @Command;
      PRINT @PreHeader + N'##   Run in PowerShell opened as Administrator   ##';

      SELECT @Command = N'#Restart the SQL Server service'
                        + @LineFeed
                        + N'Restart-Service -DisplayName "'
                        + @ServiceName + N'" -Force' + @LineFeed
                        + @LineFeed+ N'#Remove no longer used tempdb files'
                        + @LineFeed;

      SELECT @Command += N'Remove-Item -Path "' + [physical_name]
                         + N'"' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName)
	  AND [f].[type] IN (SELECT FType FROM @FileTypes);

      PRINT @Command;
  END;
ELSE
  BEGIN
      /*Move the files*/
      SET @Command +=@LineFeed+ N'#Move the database files to the new fodler(s)'
                      + @LineFeed

      SELECT @Command += N'Move-Item "' + [physical_name]
                         + N'" -Destination "'
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'\' THEN @TLogDestination
                             WHEN [type] = 0
                                  AND @DataDestination <> N'\' THEN @DataDestination
                           END
                         + N'"' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName)
	  AND [f].[type] IN (SELECT FType FROM @FileTypes);

      PRINT @Command;
      PRINT @PreHeader + N'/*   Run in SSMS   */'

      /*Update path in metadata*/
      SELECT @Command = N'USE [master]' + @LineFeed + N'GO' + @LineFeed;

      SELECT @Command += N'ALTER DATABASE [' + @DatabaseName
                         + N'] MODIFY FILE (NAME = [' + [f].[name]
                         + N'],' + N' FILENAME = '''
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'\' THEN @TLogDestination
                             WHEN [type] = 0
                                  AND @DataDestination <> N'\' THEN @DataDestination
                           END
                         + SUBSTRING([physical_name], LEN([physical_name]) -CHARINDEX(N'\', REVERSE([physical_name]))+2, LEN([physical_name]))
                         + N''');' + @LineFeed + N'GO' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName)
             AND [type] IN (SELECT [FType]
                            FROM   @FileTypes);

      PRINT @Command;

      SET @Command = N'ALTER DATABASE [' + @DatabaseName
                     + N'] SET ONLINE;' + @LineFeed + N'GO' + @LineFeed
                     + @LineFeed
                     + 'SELECT [name], [state_desc] ' + @LineFeed
                     + N' FROM [sys].[databases]' + @LineFeed
                     + N'WHERE [name] = N''' + @DatabaseName + ''';';
      PRINT @Command
  END;