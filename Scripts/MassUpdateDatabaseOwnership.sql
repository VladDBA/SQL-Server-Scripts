/* 
	Script to find databases owned by a specific 
	user and change ownership to sa or another user
*/
DECLARE @ExecSQL      VARCHAR(1000),
        @OldOwner     VARCHAR(128),
        @NewOwner     VARCHAR(128),
        @DatabaseName VARCHAR(128);

SET @OldOwner = 'OldUserName'; /*Change this*/
SET @NewOwner = 'sa'; /*Change this if needed*/

DECLARE ChangeDBOwner CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT DISTINCT '[' + db.name + ']'
  FROM   sys.databases db
         LEFT JOIN sys.server_principals sp
                ON db.owner_sid = sp.sid
  WHERE
    sp.name = @OldOwner;

OPEN ChangeDBOwner;

FETCH NEXT FROM ChangeDBOwner INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @ExecSQL = 'ALTER AUTHORIZATION ON DATABASE::' + @DatabaseName +
                     ' TO '
                     + @NewOwner + ';';

      EXEC (@ExecSQL);

      FETCH NEXT FROM ChangeDBOwner INTO @DatabaseName;
  END; 
