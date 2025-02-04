DECLARE @DatabaseName    NVARCHAR(128),
        @DataDestination NVARCHAR(256),
        @TLogDestination NVARCHAR(256);

/*Set your database name and new destination folder paths here*/
SELECT @DatabaseName = N'',
       @DataDestination = N'',
       @TLogDestination = N'';

/*Internal variables*/
DECLARE @LineFeed       NVARCHAR(5) = CHAR(13) + CHAR(10),
        @Command        NVARCHAR(2000),
        @ServiceName    NVARCHAR(256),
        @ServiceAccount NVARCHAR(256),
        @PreHeader      NVARCHAR(20);

SET @PreHeader = @LineFeed + REPLICATE(' ', 10)
/*Clean input*/
SET @DatabaseName = LTRIM(RTRIM(@DatabaseName));
SET @DataDestination = LTRIM(RTRIM(@DataDestination)) ;
SET @TLogDestination = LTRIM(RTRIM(@TLogDestination)) ;
/*Make sure the database exists*/
IF (DB_ID(@DatabaseName)) IS NULL
BEGIN
   RAISERROR('The database you specified does not exist. Please check the name and try again.', 16, 1);
   RETURN;
END;
IF (@DataDestination = N'' AND @TLogDestination = N'')
BEGIN
   RAISERROR('You didn''t specify any destination path(s). Please provide the destination path(s) and try again.', 16, 1);
   RETURN;
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

PRINT @PreHeader + N'##   Run in PowerShell   ##'

/*Make sure that path exists, create it if not*/
SET @Command = N'#Create data directory' + @LineFeed
              + N'If(!(Test-Path -Path "' + @DataDestination
              + N'" -PathType container )){' + @LineFeed
              + N' New-Item -Path "' + @DataDestination
              + N'" -ItemType Directory}' + @LineFeed
			  + N'#Grant permissions to service account' + @LineFeed
              + N'$GrantPart = ''"' + @ServiceAccount
              + N'":(OI)(CI)F''' + @LineFeed + N'icacls.exe "'
              + @DataDestination + N'" /GRANT $GrantPart'
              + @LineFeed

IF((@DataDestination <> @TLogDestination)
  AND @TLogDestination <> N'' )
  BEGIN
      SET @Command += N'#Create TLog directory' + @LineFeed
                      + N'If(!(Test-Path -Path "'
                      + @TLogDestination
                      + N'" -PathType container )){' + @LineFeed
                      + N' New-Item -Path "' + @TLogDestination
                      + N'" -ItemType Directory}' + @LineFeed
					  + N'#Grant permissions to service account' + @LineFeed
                      + N'icacls.exe "' + @TLogDestination
                      + N'" /GRANT $GrantPart' + @LineFeed
  END;

IF @DatabaseName = N'tempdb'
  BEGIN
      PRINT @Command;

      PRINT @PreHeader + N'/*   Run in SSMS   */'

      SELECT @Command = N'USE master' + @LineFeed + N'GO' + @LineFeed;

      SELECT @Command += N'ALTER DATABASE [' + @DatabaseName
                         + N'] MODIFY FILE (NAME = [' + [f].[name]
                         + N'],' + N' FILENAME = '''
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'' THEN @TLogDestination
                             ELSE @DataDestination
                           END + N'' +
                         + SUBSTRING([physical_name], LEN([physical_name]) -CHARINDEX(N'\', REVERSE([physical_name]))+2, LEN([physical_name]))
                         + N''');' + @LineFeed + N'GO' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName);

      PRINT @Command;
	  PRINT @PreHeader + N'##   Run in PowerShell   ##';
      SELECT @Command = N'#Restart the SQL Server service'
                        + @LineFeed+N'Restart-Service -DisplayName "'
                        + @ServiceName + N'" -Force' + @LineFeed
						+ N'#Remove leftover tempdb files'+ @LineFeed;

      SELECT @Command += N'Remove-Item -Path "' + [physical_name]
                         + N'"' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName);

      PRINT @Command;
  END;
ELSE
  BEGIN
      /*Move the files*/
	  SET @Command += N'#Move the database files to the new fodler(s)'+ @LineFeed
      SELECT @Command += N'Move-Item "' + [physical_name]
                         + N'" -Destination "'
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'' THEN @TLogDestination
                             ELSE @DataDestination
                           END + N'"' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName);

      PRINT @Command

      PRINT @PreHeader + N'/*   Run in SSMS   */'

      /*Update path in metadata*/
      IF ( @DataDestination NOT LIKE N'%\' )
        BEGIN
            SET @DataDestination += N'\'
        END;

      IF ( @TLogDestination NOT LIKE N'%\' )
        BEGIN
            SET @TLogDestination += N'\'
        END;

      SELECT @Command = N'USE master' + @LineFeed + N'GO' + @LineFeed;

      SELECT @Command += N'ALTER DATABASE [' + @DatabaseName
                         + N'] MODIFY FILE (NAME = [' + [f].[name]
                         + N'],' + N' FILENAME = '''
                         + CASE
                             WHEN [type] = 1
                                  AND @TLogDestination <> N'' THEN @TLogDestination
                             ELSE @DataDestination
                           END + N'' +
                         + SUBSTRING([physical_name], LEN([physical_name]) -CHARINDEX(N'\', REVERSE([physical_name]))+2, LEN([physical_name]))
                         + N''');' + @LineFeed + N'GO' + @LineFeed
      FROM   sys.[master_files] [f]
      WHERE  [f].[database_id] = DB_ID(@DatabaseName);

      PRINT @Command;

      SET @Command = N'ALTER DATABASE [' + @DatabaseName
                     + N'] SET ONLINE;' + @LineFeed + N'GO' + @LineFeed
                     + 'SELECT [name], [state_desc] ' + @LineFeed
                     + N' FROM [sys].[databases]' + @LineFeed
                     + N'WHERE [name] = N''' + @DatabaseName + ''';';

      PRINT @Command
  END;