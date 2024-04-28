/*	Description: Use this script if you have more than the recommended number of tempdb data files
	Create date: 2024-03-10
	Author: Vlad Drumea
	Website: https://vladdba.com
	From: https://github.com/VladDBA/SQL-Server-Scripts/
	More info: https://vladdba.com/2024/03/11/script-to-delete-extra-tempdb-data-files
	License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
	Usage: 
	  On a fairly quiet environment:
		1. Paste this script in a Query Editor window.
		2. Set @NumFilesToDrop to the number of files you want to DROP.
		3. Execute it.
	  On a busy environment: 
		1. Create a SQL Server Agent job.
		2. Add a step containing the T-SQL below. 
		3. Set @NumFilesToDrop to the number of files you want to DROP.
		4. Schedule the job to run at instance startup.
		5. Restart the the instance during a maintenance window.
		6. Delete the SQL Server Agent job since if it runs again it will delete more tempdb data files. 

*/

USE [tempdb];

DECLARE @NumFilesToDrop TINYINT,
        @FileName       NVARCHAR(128),
        @SQL            NVARCHAR(500);

SET @NumFilesToDrop = 0; /*specify how many data files you want dropped */

DECLARE DropTempDBFiles CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT [name]
  FROM   sys.[database_files]
  WHERE  [type] = 0
  ORDER  BY [file_id] DESC;

OPEN DropTempDBFiles;

FETCH NEXT FROM DropTempDBFiles INTO @FileName;

WHILE @@FETCH_STATUS = 0
      AND @NumFilesToDrop > 0
  BEGIN
      /*empty file*/
      SET @SQL = N'DBCC SHRINKFILE (N''' + @FileName
                 + N''' , EMPTYFILE);';

      EXEC (@SQL);

      /*delete file*/
      SET @SQL = N'ALTER DATABASE [tempdb]  REMOVE FILE ['
                 + @FileName + N'];';

      EXEC (@SQL);

      /*another one bites the dust*/
      SET @NumFilesToDrop -= 1;

      IF @NumFilesToDrop <= 0
        BEGIN
            BREAK;
        END

      FETCH NEXT FROM DropTempDBFiles INTO @FileName;
  END;
CLOSE DropTempDBFiles;
DEALLOCATE DropTempDBFiles;