/* 
   Get NULL counts for all columns in a table
   Author: Vlad Drumea
   More info: 
   From https://github.com/VladDBA/SQL-Server-Scripts/
   License https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/

/*
  Set the target table name
  Valid formats: 
    TableName
    SchemaName.TableName
    [SchemaName].[TableName]
*/
DECLARE @TableName NVARCHAR(261) = 'Person.Person',
        @OutputToTable BIT       = 0;       /*Set to 1 to save results to table*/


/*Make sure the table name is valid*/
DECLARE @ObjectId INT = OBJECT_ID(@TableName,N'U');
IF @ObjectId IS NULL
  BEGIN
      RAISERROR('Please provide a valid table name',11,1) WITH NOWAIT; 
      RETURN;
  END;

/*Internal variables*/
DECLARE @FullQuotedTableName NVARCHAR(261) = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjectId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjectId)),
        @FullTableName       NVARCHAR(261) = OBJECT_SCHEMA_NAME(@ObjectId) + N'.' + OBJECT_NAME(@ObjectId),
        @AggList             NVARCHAR(MAX),
        @ValuesList          NVARCHAR(MAX),
        @LineFeed            NVARCHAR(2) = CHAR(13) + CHAR(10),
        @SQL                 NVARCHAR(MAX);

 
/*Create results table*/
IF OBJECT_ID(N'dbo.null_cols_table', N'U') IS NULL AND @OutputToTable = 1
  BEGIN
      CREATE TABLE [dbo].[null_cols_table]
        (
           [id]               INT IDENTITY(1, 1) NOT NULL,
           [table_name]       NVARCHAR(257),
           [column_name]      NVARCHAR(128),
           [column_id]        INT,
           [data_type]        NVARCHAR(128),
           [nullable]         BIT,
           [null_count]       BIGINT,
           [record_count]     BIGINT,
           [non_null_records] BIGINT,
           [time_of_check]    DATETIME2(3) DEFAULT GETDATE() NOT NULL
        );
       /*Create a clustered index on it*/
       CREATE CLUSTERED INDEX [cix_null_cols_table]
         ON [dbo].[null_cols_table]([id]);
  END;

WITH cols AS
(
    SELECT
        c.[column_id],
        c.[name],
        c.[is_nullable],
        [DataType] =
            CASE
                WHEN t.[name] IN (N'char', N'varchar', N'binary', N'varbinary')
                    THEN t.[name] + N'(' + CASE WHEN c.[max_length] = -1 THEN N'max' ELSE CAST(c.max_length AS NVARCHAR(10)) END + N')'
                WHEN t.[name] IN (N'nchar', N'nvarchar')
                    THEN t.[name] + N'(' + CASE WHEN c.[max_length] = -1 THEN N'max' ELSE CAST(c.max_length / 2 AS NVARCHAR(10)) END + N')'
                WHEN t.[name] IN (N'decimal', N'numeric')
                    THEN t.[name] + N'(' + CAST(c.[precision] AS NVARCHAR(10)) + N',' + CAST(c.[scale] AS NVARCHAR(10)) + N')'
                WHEN t.[name] IN (N'datetime2', N'datetimeoffset', N'time')
                    THEN t.[name] + N'(' + CAST(c.[scale] AS NVARCHAR(10)) + N')'
                ELSE t.[name]
            END
    FROM [sys].[columns] AS c
    JOIN [sys].[types]   AS t
      ON t.[user_type_id] = c.[system_type_id]  /*resolves alias types to their base system type*/
    WHERE c.[object_id] = @ObjectId
)
SELECT
    /*Only nullable columns need a COUNT_BIG expression*/
    @AggList = STUFF((
        SELECT N', COUNT_BIG(CASE WHEN ' + QUOTENAME([name]) + N' IS NULL THEN 1 END) AS n' + CAST([column_id] AS NVARCHAR(10))
        FROM [cols]
        WHERE [is_nullable] = 1
        ORDER BY [column_id]
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N''),
    @ValuesList = STUFF((
        SELECT N', (N''' + REPLACE([name], N'''', N'''''') + N''', ' + CAST([column_id] AS NVARCHAR(10))
               + N', N''' + [DataType] + N''', CAST(' + CAST([is_nullable] AS NVARCHAR(1)) + N' AS bit), '
               + CASE WHEN [is_nullable] = 1
                      THEN N'm.n' + CAST([column_id] AS NVARCHAR(10))
                      ELSE N'CAST(0 AS BIGINT)'
                 END + N')'
        FROM [cols]
        ORDER BY [column_id]
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

SET @AggList = ISNULL(@AggList + N', ', N'') + N'COUNT_BIG(*) AS rc';

SET @SQL = @LineFeed + N'SELECT @TableName    AS [table_name],' + @LineFeed + N'v.[column_name],'
           + @LineFeed + N'v.[column_id],' + @LineFeed + N'v.[data_type],' + @LineFeed + N'v.[nullable],'
           + @LineFeed + N'v.[null_count],' + @LineFeed + N'm.[rc]                 AS [record_count],'
           + @LineFeed + N'm.[rc] - v.[null_count]  AS [non_null_records]'
           + @LineFeed + N'FROM (SELECT ' + @AggList + N' FROM ' + @FullQuotedTableName + N') AS m'
           + @LineFeed + N'CROSS APPLY (VALUES ' + @ValuesList + N') AS v([column_name], [column_id], [data_type], [nullable], [null_count])'
           + @LineFeed + N'ORDER BY v.[column_id];';

IF @OutputToTable = 1
  BEGIN
      SET @SQL = N'INSERT INTO [dbo].[null_cols_table] ([table_name], [column_name], [column_id], [data_type], [nullable], [null_count], [record_count], [non_null_records])'
                 + @LineFeed + @SQL;
  END;
  /*SELECT @SQL AS [Generated SQL];*/
EXEC sys.sp_executesql @SQL, N'@TableName NVARCHAR(261)', @TableName = @FullTableName;
IF @OutputToTable = 1
  BEGIN
      SELECT *
      FROM [dbo].[null_cols_table]
      WHERE [table_name] = @FullTableName
      ORDER BY [nullable] DESC;
  END;