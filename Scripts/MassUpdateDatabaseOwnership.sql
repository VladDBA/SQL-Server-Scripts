/* 
	Script to find databases owned by a specific 
	user and change ownership to sa or another user
	From https://github.com/VladDBA/SQL-Server-Scripts/
	License https://github.com/VladDBA/SQL-Server-Scripts/blob/0a990ac2fbf633681872e95dca1d941df05c6932/LICENSE.md
*/
USE [master]
GO

		/* Variable declaration */
DECLARE @ExecSQL      NVARCHAR(1000),
        @OldOwner     NVARCHAR(128),
        @NewOwner     NVARCHAR(128),
        @DatabaseName NVARCHAR(128);


SET @OldOwner = N'OldUserName'; /*Change this*/
SET @NewOwner = N'sa'; /*Change this if needed*/


DECLARE ChangeDBOwner CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT DISTINCT N'[' + [db].[name] + N']'
  FROM   [master].[sys].[databases] [db]
         LEFT JOIN [master].[sys].[server_principals] AS [sp]
                ON [db].[owner_sid] = [sp].[sid]
  WHERE
    [sp].[name] = @OldOwner;

OPEN ChangeDBOwner;

FETCH NEXT FROM ChangeDBOwner INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @ExecSQL = N'ALTER AUTHORIZATION ON DATABASE::' + @DatabaseName +
                     N' TO ['
                     + @NewOwner + N'];';

      EXEC (@ExecSQL);

      FETCH NEXT FROM ChangeDBOwner INTO @DatabaseName;
  END;

CLOSE ChangeDBOwner;
DEALLOCATE ChangeDBOwner;
