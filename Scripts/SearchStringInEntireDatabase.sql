/* 
	Script to search for a string in an entire SQL Server database
	By Vlad Drumea
	From: https://github.com/VladDBA/SQL-Server-Scripts/
	Blog: https://vladdba.com/
	More info about this script: https://vladdba.com/2023/12/13/script-to-search-for-a-string-in-an-entire-sql-server-database/
	License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/

SET NOCOUNT ON;

DECLARE @SearchString  NVARCHAR(500)=N'',/*Your string goes here*/
        @UseLike       BIT = 1,/* set to 1 will do LIKE '%String%', 0 does = 'String'*/
        @IsUnicode     BIT = 1,/* set to 1 will treat the @SearchString as Unicode in the WHERE clause, 
                                  set to 0 will treat it as non-Unicode - recommended when dealing with (var)char or text columns
                                  the script also matches the input data type with that of the column to avoid performance issues caused by upconverting*/
        @CaseSensitive BIT = 0,/*set this to 1 only if you use a case-sensitive collation and are not sure about the case of the string*/
        @SQL           NVARCHAR(MAX),
        @TableName     NVARCHAR(500),
        @WhereClause   NVARCHAR(MAX),
        @LineFeed      NVARCHAR(5) = CHAR(13) + CHAR(10),
        @RecordCount   INT,
        @ParamDef      NVARCHAR(200);

IF OBJECT_ID(N'tempdb..#SearchResults', N'U') IS NOT NULL
  BEGIN
      DROP TABLE #SearchResults;
  END;

CREATE TABLE #SearchResults
  (
     [ID]           INT IDENTITY(1, 1) NOT NULL PRIMARY KEY CLUSTERED,
     [TableName]    NVARCHAR(500),
     [RecordsFound] INT,
     [SearchString] NVARCHAR(500),
     [WhereClause]  NVARCHAR(MAX),
     [Query] AS N'SELECT * FROM ' + [TableName] + N' WHERE '
        + RTRIM([WhereClause]) + N';' PERSISTED
  );

IF @CaseSensitive = 1
  BEGIN
      SET @SearchString = LOWER(@SearchString);
  END;

DECLARE SearchDB CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
WITH QueryParts AS
(
/*Build the table list*/
    SELECT QUOTENAME(t.TABLE_SCHEMA) + '.' + QUOTENAME(t.TABLE_NAME) AS [QuotedTabName],
          STUFF(
          (
		  /*Build the WHERE clause*/
            SELECT N'OR ' + 
			CASE
              WHEN c.DATA_TYPE LIKE N'%text'
              THEN N'CAST('
              ELSE N''
            END +
            CASE 
			 WHEN @CaseSensitive = 1 
			 THEN N'LOWER('+ QUOTENAME(c.COLUMN_NAME) + N')'
			 ELSE  QUOTENAME(c.COLUMN_NAME)
			END +
            CASE
              WHEN c.DATA_TYPE = N'ntext'
              THEN N' AS NVARCHAR(MAX))'
              WHEN c.DATA_TYPE = N'text'
              THEN N' AS VARCHAR(MAX))'
              ELSE N''
            END +
			CASE
              /*only use LIKE when the column is wider than the string*/
			  WHEN @UseLike = 1 AND c.CHARACTER_MAXIMUM_LENGTH > LEN(@SearchString)
			  THEN N' LIKE '+
			  CASE
			    WHEN @IsUnicode = 1 AND c.DATA_TYPE LIKE N'n%'
			    THEN N'N'
			    ELSE N''
			  END +
			  N'''%' + @SearchString + N'%'' '
			  ELSE N' = '+
			  CASE
			   WHEN @IsUnicode = 1 AND c.DATA_TYPE LIKE N'n%'
			   THEN N'N'
			   ELSE N''
			  END + N'''' + @SearchString + N''' '
			 END
            FROM INFORMATION_SCHEMA.COLUMNS AS c
            WHERE c.TABLE_CATALOG=t.TABLE_CATALOG AND c.TABLE_SCHEMA=t.TABLE_SCHEMA AND c.TABLE_NAME=t.TABLE_NAME
              AND (c.DATA_TYPE LIKE N'%char' OR c.DATA_TYPE LIKE N'%text')
			  /*Only search in columns that can actually hold a string the length of the search term*/
			  AND c.CHARACTER_MAXIMUM_LENGTH >= LEN(@SearchString)
            FOR XML PATH('')
          ),1,3,'') AS [WhereClause]
    FROM INFORMATION_SCHEMA.TABLES AS t
    WHERE t.TABLE_TYPE='BASE TABLE'
)
SELECT [QuotedTabName],
       [WhereClause]
FROM   [QueryParts]
WHERE  [WhereClause] IS NOT NULL

OPEN SearchDB;

FETCH NEXT FROM SearchDB INTO @TableName, @WhereClause;

WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @SQL = N'SELECT @RecordCountOut = COUNT(*) FROM '
                 + @TableName + N' WITH(NOLOCK) WHERE '
                 + @WhereClause + N';'
      SET @ParamDef = N'@RecordCountOut INT OUTPUT';

      EXECUTE sp_executesql
        @SQL,
        @ParamDef,
        @RecordCountOut= @RecordCount OUTPUT;

      IF @RecordCount > 0
        BEGIN
            RAISERROR ('%d matching records found in table %s .',10,1,@RecordCount,@TableName) WITH NOWAIT;
            INSERT INTO #SearchResults
                        ([TableName],
                         [SearchString],
                         [RecordsFound],
                         [WhereClause])
            VALUES      (@TableName,
                         @SearchString,
                         @RecordCount,
                         @WhereClause);
        END;

      FETCH NEXT FROM SearchDB INTO @TableName, @WhereClause;
  END;
CLOSE SearchDB;
DEALLOCATE SearchDB;
/*Get the summary*/
SELECT [TableName],
       [RecordsFound],
       [SearchString],
       [WhereClause],
       [Query]
FROM   #SearchResults
ORDER  BY [RecordsFound] ASC;
/*Query the identified tables to get specific records*/
RAISERROR ('%sRetrieving results from tables.',10,1,@LineFeed) WITH NOWAIT;
SET @SQL = CAST(N' '+@LineFeed AS NVARCHAR(MAX));
SELECT @SQL += REPLACE([Query], N'SELECT ', N'SELECT '''+REPLACE(REPLACE([TableName], ']', ''), '[', '')+N''' AS TableName, ')
               + @LineFeed
FROM   #SearchResults
ORDER  BY [RecordsFound] ASC;

PRINT @SQL;
EXEC(@SQL);

DROP TABLE #SearchResults;