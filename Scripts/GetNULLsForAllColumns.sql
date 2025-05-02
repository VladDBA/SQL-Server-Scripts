/* 
   Get NULL counts for all columns in a table
   Author: Vlad Drumea
   More info: https://vladdba.com/2025/05/02/count-all-nulls-in-a-table-in-sql-server/
   From https://github.com/VladDBA/SQL-Server-Scripts/
   License https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/
DECLARE @TabName NVARCHAR(261);

/*
  Set the target table name
  Valid formats: 
    TableName
	SchemaName.TableName
	[SchemaName].[TableName]
*/
SET @TabName = N'Person.Person';


/*Make sure the table name is valid*/
IF OBJECT_ID(@TabName, N'U') IS NULL
  BEGIN
      RAISERROR('Please provide a valid table name',11,1) WITH NOWAIT;

      RETURN;
  END;

/*Create results table*/
IF OBJECT_ID(N'null_cols_table', N'U') IS NULL
  BEGIN
      CREATE TABLE [null_cols_table]
        (
           [id]            INT IDENTITY(1, 1) NOT NULL,
           [table_name]    NVARCHAR(128),
           [column_name]   NVARCHAR(128),
           [column_id]     INT,
           [data_type]     NVARCHAR(128),
           [nullable]      BIT,
           [null_count]    BIGINT,
           [record_count]  BIGINT,
           [non_null_records] AS ( [record_count] - [null_count] ) PERSISTED,
           [time_of_check] DATETIME2(3)
        );

      /*Create a clustered index on it*/
      CREATE CLUSTERED INDEX cix_null_cols_table
        ON null_cols_table([id]);

      /*Create index to support the WHERE in the updates*/
      CREATE INDEX ncix_null_cols_table
        ON null_cols_table([table_name], [column_name], [time_of_check]);
  END;

DECLARE @SQL           NVARCHAR(MAX),
        @ParmDefInsert NVARCHAR(500),
        @ParmDefUpdate NVARCHAR(500),
        @ColName       NVARCHAR(128),
        @ColID         INT,
        @DataType      NVARCHAR(128),
        @NullCount     BIGINT,
        @TimeStamp     DATETIME2(3),
        @LineFeed      NVARCHAR(5);

SET @LineFeed = CHAR(13) + CHAR(10);
SET @TimeStamp = GETDATE();
SET @ParmDefInsert = N'@TabNameIn NVARCHAR(261), @ColNameIn NVARCHAR(128), @DataTypeIn NVARCHAR(128),';
SET @ParmDefInsert += N' @ColIDIn NVARCHAR(128), @TimeStampIn DATETIME2(3)';
SET @ParmDefUpdate = N'@TabNameIn NVARCHAR(261), @ColNameIn NVARCHAR(128), @TimeStampIn DATETIME2(3)';

/*Cursor for null columns*/
DECLARE NullColl CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT [name],
         [column_id],
         TYPE_NAME([system_type_id]) AS [data_type]
  FROM   sys.[all_columns]
  WHERE  [object_id] = OBJECT_ID(@TabName)
         AND [is_nullable] = 1;

OPEN NullColl;

FETCH NEXT FROM NullColl INTO @ColName, @ColID, @DataType;

WHILE @@FETCH_STATUS = 0
  BEGIN
      BEGIN
          SET @SQL = N'INSERT INTO null_cols_table ([table_name], [column_name], [data_type],[column_id] ,[nullable],[time_of_check])'
          SET @SQL += @LineFeed
                      + N'VALUES (@TabNameIn, @ColNameIn,@DataTypeIn, @ColIDIn, 1,@TimeStampIn);'

          EXECUTE sp_executesql
            @SQL,
            @ParmDefInsert,
            @TabNameIn  = @TabName,
            @ColNameIn  = @ColName,
            @DataTypeIn = @DataType,
            @ColIDIn    = @ColID,
            @TimeStampIn= @TimeStamp;
      END;

      BEGIN
          SET @SQL = N'UPDATE null_cols_table SET [null_count] = (SELECT COUNT(*) FROM '
                     + @TabName + N' WITH(NOLOCK) WHERE ' + @ColName
                     + N' IS NULL) ' + @LineFeed
                     + N'WHERE [table_name] = @TabNameIn'
                     + @LineFeed
                     + N'AND [column_name] = @ColNameIn'
                     + @LineFeed
                     + N'AND [time_of_check] = @TimeStampIn;';

          EXECUTE sp_executesql
            @SQL,
            @ParmDefUpdate,
            @TabNameIn  = @TabName,
            @ColNameIn  = @ColName,
            @TimeStampIn= @TimeStamp;
      END;

      FETCH NEXT FROM NullColl INTO @ColName, @ColID, @DataType;
  END;

CLOSE NullColl;

DEALLOCATE NullColl;

/*Populate result table with non-nullable columns*/
DECLARE NotNull CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT [name],
         [column_id],
         TYPE_NAME([system_type_id]) AS [data_type]
  FROM   sys.[all_columns]
  WHERE  [object_id] = OBJECT_ID(@TabName)
         AND [is_nullable] = 0;

INSERT INTO [null_cols_table]
            ([table_name],
             [column_name],
             [data_type],
             [column_id],
             [null_count],
             [nullable],
             [time_of_check])
SELECT @TabName,
       [name],
       TYPE_NAME([system_type_id]) AS [data_type],
       [column_id],
       0, 0, @TimeStamp
FROM   sys.[all_columns]
WHERE  [object_id] = OBJECT_ID(@TabName)
       AND [is_nullable] = 0;

SET @SQL = N'UPDATE null_cols_table  SET record_count = (SELECT COUNT(*) FROM '
           + @LineFeed + @TabName + N' WITH(NOLOCK))'
           + @LineFeed
           + N'WHERE [table_name] = @TabNameIn'
           + @LineFeed
           + N'AND [time_of_check] = @TimeStampIn;';

EXECUTE sp_executesql
  @SQL,
  @ParmDefUpdate,
  @TabNameIn  = @TabName,
  @ColNameIn  = @ColName,
  @TimeStampIn= @TimeStamp;

/*Return results from this run*/
SELECT *
FROM   [null_cols_table]
WHERE  [table_name] = @TabName
       AND [time_of_check] = @TimeStamp; 
