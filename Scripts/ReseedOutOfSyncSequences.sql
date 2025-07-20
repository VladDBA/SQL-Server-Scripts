/*	Description: Someone (probably an Oracle dev) decided it's a good idea to use sequences combined with default constraints instead of identity columns.
                 Someone else went ahead and loaded some data that already had values for the sequence related columns.
                 And now, your users are getting unique constraint violations or duplicate key errors because the sequence is not in sync when trying to add new records. 
                 This script will reseed those sequences to the maximum value of the column they are used on.
                 It also works if the sequence is ahead of the maximum value, it will just reset it to the maximum value + 1.
                 It won't touch sequences that are already in sync.
    
	Create date: 2025-07-20
	Author: Vlad Drumea
	Website: https://vladdba.com
	From: https://github.com/VladDBA/SQL-Server-Scripts/
	More info: 
	License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
	Usage: 
	  1. Paste this script in a Query Editor window.
	  2. Execute it.
	  3. Mock whoever thought it was a good idea to use sequences with default constraints instead of identity columns.
*/
DECLARE @TabName  NVARCHAR(261),
        @ColName  SYSNAME,
        @SeqName  NVARCHAR(261),
        @CurrVal  BIGINT,
        @MaxID    BIGINT,
        @State    NVARCHAR(9),
        @ParamDef NVARCHAR(300),
        @SQL      NVARCHAR(MAX);
DECLARE seq_reseed_cursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT QUOTENAME(SCHEMA_NAME([t].[schema_id]))
         + N'.' + QUOTENAME([t].[name])           AS [table_name],
         [c].[name]                               AS [column_name],
         QUOTENAME(SCHEMA_NAME([sq].[schema_id]))
         + N'.' + QUOTENAME([sq].[name])          AS [sequence_name],
         TRY_CAST([sq].[current_value] AS BIGINT) AS [current_value]
  FROM   sys.[columns] AS [c]
         INNER JOIN sys.[tables] AS [t]
                 ON [c].[object_id] = [t].[object_id]
         INNER JOIN sys.[default_constraints] AS [dc]
                 ON [c].[default_object_id] = [dc].[object_id]
         INNER JOIN sys.[sequences] AS [sq]
                 /*yes, I'm joining on a function, call the cops*/
                 ON OBJECT_ID(REPLACE(REPLACE([dc].[definition], N'(NEXT VALUE FOR ', N''), N')', N'')) = [sq].[object_id]
  WHERE  [t].[type] = 'U'

OPEN seq_reseed_cursor;

FETCH NEXT FROM seq_reseed_cursor INTO @TabName, @ColName, @SeqName, @CurrVal;

WHILE @@FETCH_STATUS = 0
  BEGIN
      -- SELECT @CurrVal = CAST(current_value AS BIGINT) FROM sys.sequences WHERE [name] = @SeqName;
      SET @SQL = N'SELECT @MaxIDOut = ISNULL(MAX('
                 + QUOTENAME(@ColName) + N'),0) FROM ' + @TabName
                 + N' WITH (NOLOCK);'
      SET @ParamDef = N'@MaxIDOut BIGINT OUTPUT';

      EXEC sp_executesql
        @SQL,
        @ParamDef,
        @MaxIDOut = @MaxID OUTPUT;

      IF((@MaxID > @CurrVal)
         OR(@MaxID < @CurrVal - 1))
        BEGIN
            SELECT @State = CASE
                              WHEN @MaxID > @CurrVal THEN N'behind'
                              ELSE N'ahead of'
                            END;

            RAISERROR ('Sequence %s is %s column %s.%s - will be reseeded.',10,1,@SeqName,@State,@TabName,@ColName) WITH NOWAIT;

            SET @SQL = N'ALTER SEQUENCE ' + @SeqName
                       + N' RESTART WITH '
                       + CAST(@MaxID+1 AS NVARCHAR(30)) + N';';

            EXEC sp_executesql
              @SQL;
        END;

      FETCH NEXT FROM seq_reseed_cursor INTO @TabName, @ColName, @SeqName, @CurrVal;
  END;
CLOSE seq_reseed_cursor;
DEALLOCATE seq_reseed_cursor;
GO
