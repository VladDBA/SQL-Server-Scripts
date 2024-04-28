/*	Description: Use this script if you want to switch a whole instance 
	(model database and all user databases) to use the SIMPLE recovery model
	Create date: 2024-04-29
	Author: Vlad Drumea
	Website: https://vladdba.com
	From: https://github.com/VladDBA/SQL-Server-Scripts/
	More info: 
	License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
	Usage: 
		1. Paste this script in a Query Editor window.
		2. Execute it.
*/

    /*Set model to SIMPLE recovery*/
ALTER DATABASE [model] SET RECOVERY SIMPLE;
GO
DECLARE @DatabaseName NVARCHAR(130),
        @LogFileName  NVARCHAR(128),
        @SQL          NVARCHAR(500),
        @LineFeed     NVARCHAR(5);

SET @LineFeed = CHAR(13) + CHAR(10);

DECLARE SwitchToSimple CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT QUOTENAME([d].[name]),
         [f].[name]
  FROM   sys.[databases] AS [d]
         INNER JOIN sys.[master_files] AS [f]
                 ON [d].[database_id] = [f].[database_id]
  WHERE  [d].[recovery_model] = 1
         AND [d].[state] = 0
         AND [f].[state] = 0
         AND [f].[type] = 1;

OPEN SwitchToSimple;

FETCH NEXT FROM SwitchToSimple INTO @DatabaseName, @LogFileName;

WHILE @@FETCH_STATUS = 0
  BEGIN
      /*set database to SIMPLE recovery*/
      SET @SQL = N'USE [master];' + @LineFeed
                 + N'ALTER DATABASE ' + @DatabaseName
                 + N' SET RECOVERY SIMPLE;' + @LineFeed;

      EXEC(@SQL);
	  /*Run a checkpoint and shrink the transaction log file*/
      SET @SQL = N'USE ' + @DatabaseName + N';' + @LineFeed
                 + N'CHECKPOINT;' + @LineFeed
                 + N'DBCC SHRINKFILE (N''' + @LogFileName
                 + N''', 1);' + @LineFeed;

      EXEC(@SQL);

      FETCH NEXT FROM SwitchToSimple INTO @DatabaseName, @LogFileName;
  END;

CLOSE SwitchToSimple;

DEALLOCATE SwitchToSimple; 