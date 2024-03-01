/* 
      Description: Generates 1GB of data and writes 4 passes of it into a table, measuring the duration and stalls for each pass
	    Ideally, you'd run this when the database isn't being used 
	  or create a dedicated database on the same storage and config that you'd want to test.
      Create date: 2024-02-28
      Author: Vlad Drumea
      Website: https://vladdba.com
      From: https://github.com/VladDBA/SQL-Server-Scripts/
      More info:
      License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.speed_test') IS NOT NULL
  BEGIN
      DROP TABLE dbo.[speed_test];
  END;

IF OBJECT_ID('dbo.io_stats_writes') IS NOT NULL
  BEGIN
      DROP TABLE dbo.[io_stats_writes];
  END;

DECLARE @Source TABLE
  (
     [ID]      INT,
     [string1] NVARCHAR(198),
     [string2] NVARCHAR(198)
  );

DECLARE @Row     INT,
        @Records INT,
        @Pass    TINYINT;

SET @Records = 1179620; /* 1179620 records =~1GB*/

/* Populate the source table
	Note: I'm using a table variable because in my tests it works a bit faster than a temp table, 
even though SQL Server ends up making a temp table for it in the background anyway.
*/
SET @Row = 1;

WHILE @Row <= @Records
  BEGIN
      INSERT INTO @Source
      VALUES      (@Row,
                   N'Aa0Aa1Aa2Aa3Aa4Aa5Aa6Aa7Aa8Aa9Ab0Ab1Ab2Ab3Ab4Ab5Ab6Ab7Ab8Ab9Ac0Ac1Ac2Ac3Ac4Ac5Ac6Ac7Ac8Ac9Ad0Ad1Ad2Ad3Ad4Ad5Ad6Ad7Ad8Ad9Ae0Ae1Ae2Ae3Ae4Ae5Ae6Ae7Ae8Ae9Af0Af1Af2Af3Af4Af5Af6Af7Af8Af9Ag0Ag1Ag2Ag3Ag4Ag5',
                   N'5gA4gA3gA2gA1gA0gA9fA8fA7fA6fA5fA4fA3fA2fA1fA0fA9eA8eA7eA6eA5eA4eA3eA2eA1eA0eA9dA8dA7dA6dA5dA4dA3dA2dA1dA0dA9cA8cA7cA6cA5cA4cA3cA2cA1cA0cA9bA8bA7bA6bA5bA4bA3bA2bA1bA0bA9aA8aA7aA6aA5aA4aA3aA2aA1aA0aA')

      SET @Row += 1;

      IF @Row > @Records
        BEGIN
            BREAK;
        END;
  END;

/*Create relevant tables*/
CREATE TABLE [speed_test]
  (
     [ID]      INT,
     [string1] NVARCHAR(198),
     [string2] NVARCHAR(198)
  );

CREATE TABLE [dbo].[io_stats_writes]
  (
     [pass]                      TINYINT NOT NULL,
     [pre_sample_time]           DATETIME2 NULL,
     [post_sample_time]          DATETIME2 NULL,
     [duration_ms] AS DATEDIFF(millisecond, [pre_sample_time], [post_sample_time]),
     [file_id]                   INT NOT NULL,
     [db_name]                   NVARCHAR(128) NULL,
     [file_logical_name]         SYSNAME NULL,
     [pre_size_on_disk_MB]       INT NULL,
     [post_size_on_disk_MB]      INT NULL,
     [delta_size_on_disk_MB] AS ( [post_size_on_disk_MB] - [pre_size_on_disk_MB] ),
     [pre_io_stall_write_ms]     BIGINT NULL,
     [post_io_stall_write_ms]    BIGINT NULL,
     [delta_io_stall_write_ms] AS ( [post_io_stall_write_ms] - [pre_io_stall_write_ms] ),
     [avg_io_stall_write_ms] AS ( ( [post_io_stall_write_ms] - [pre_io_stall_write_ms] ) / ( [post_num_of_writes] - [pre_num_of_writes] ) ),
     [pre_num_of_writes]         BIGINT NULL,
     [post_num_of_writes]        BIGINT NULL,
     [delta_num_of_writes] AS ( [post_num_of_writes] - [pre_num_of_writes] ),
     [pre_num_of_bytes_written]  BIGINT NULL,
     [post_num_of_bytes_written] BIGINT NULL,
     [delta_bytes_written] AS ( [post_num_of_bytes_written] - [pre_num_of_bytes_written] ),
     [delta_written_MB] AS CAST(( ( [post_num_of_bytes_written] - [pre_num_of_bytes_written] ) / 1024.0 / 1024.0 ) AS NUMERIC(6, 2)),
     [physical_name]             NVARCHAR(260) NULL,
     [type_desc]                 NVARCHAR(60) NULL
  );

SET @Pass = 1;

WHILE @Pass <= 4
  BEGIN
      /*Pre-pass snapshot*/
      INSERT INTO [io_stats_writes]
                  ([pass],
                   [pre_sample_time],
                   [file_id],
                   [db_name],
                   [file_logical_name],
                   [pre_size_on_disk_MB],
                   [pre_io_stall_write_ms],
                   [pre_num_of_writes],
                   [pre_num_of_bytes_written],
                   [physical_name],
                   [type_desc])
      SELECT @Pass                                                             AS [pass],
             GETDATE()                                                         AS [pre_sample_time],
             [df].[file_id],
             DB_NAME([vfs].[database_id])                                      AS [db_name],
             [df].name                                                         AS [file_logical_name],
             CAST(( ( [vfs].[size_on_disk_bytes] / 1024.0 ) / 1024.0 ) AS INT) AS [pre_size_on_disk_MB],
             [vfs].[io_stall_write_ms]                                         AS [pre_io_stall_write_ms],
             [vfs].[num_of_writes]                                             AS [pre_num_of_writes],
             [vfs].[num_of_bytes_written]                                      AS [pre_num_of_bytes_written],
             [df].[physical_name],
             [df].[type_desc]
      FROM   sys.dm_io_virtual_file_stats (NULL, NULL) AS [vfs]
             INNER JOIN sys.[database_files] AS [df]
                     ON [vfs].[file_id] = [df].[file_id]
                        AND [vfs].[database_id] = DB_ID()
      WHERE  [vfs].[num_of_writes] > 0
      OPTION(RECOMPILE);
	  /*insert 1GB of data*/
      INSERT INTO [speed_test] WITH(TABLOCK)
      SELECT [ID],
             [string1],
             [string2]
      FROM   @Source;
	  /*post-pass snapshot*/
      WITH [post_insert]
           AS (SELECT [mf].[file_id],
                      DB_NAME([vfs].[database_id])                                      AS [db_name],
                      [mf].[name]                                                       AS [file_logical_name],
                      CAST(( ( [vfs].[size_on_disk_bytes] / 1024.0 ) / 1024.0 ) AS INT) AS [post_size_on_disk_MB],
                      [vfs].[io_stall_write_ms]                                         AS [post_io_stall_write_ms],
                      [vfs].[num_of_writes]                                             AS [post_num_of_writes],
                      [vfs].[num_of_bytes_written]                                      AS [post_num_of_bytes_written],
                      [mf].[physical_name],
                      [mf].[type_desc]
               FROM   sys.dm_io_virtual_file_stats (NULL, NULL) AS [vfs]
                      INNER JOIN sys.[database_files] AS [mf]
                              ON [vfs].[file_id] = [mf].[file_id]
                                 AND [vfs].[database_id] = DB_ID()
               WHERE  [vfs].[num_of_writes] > 0)
      UPDATE [sw]
      SET    [sw].[post_sample_time] = GETDATE(),
             [sw].[post_io_stall_write_ms] = [pi].[post_io_stall_write_ms],
             [sw].[post_num_of_bytes_written] = [pi].[post_num_of_bytes_written],
             [sw].[post_num_of_writes] = [pi].[post_num_of_writes],
             [sw].[post_size_on_disk_mb] = [pi].[post_size_on_disk_mb]
      FROM   [io_stats_writes] [sw]
             INNER JOIN [post_insert] AS [pi]
                     ON [sw].[file_id] = [pi].[file_id]
      WHERE  [sw].[pass] = @Pass
      OPTION(RECOMPILE);

      SET @Pass +=1;

      IF @Pass = 5
        BEGIN
            BREAK;
        END;
  END;

      /*Get results*/
/*Summary avg*/
SELECT DB_NAME()                                      AS [database],
       COUNT([pass])                                  AS [passes],
       [physical_name]                                AS [file_physical_name],
       [type_desc]                                    AS [file_type],
       CAST(AVG([delta_written_MB]) AS NUMERIC(6, 2)) AS [written_per_pass_MB],
       AVG([duration_ms])                             AS [avg_duration_ms],
       AVG([avg_io_stall_write_ms])                   AS [avg_io_stall_write_ms],
       AVG([delta_num_of_writes])                     AS [avg_writes_per_pass],
       AVG([delta_size_on_disk_MB])                   AS [avg_file_size_increase_MB]
FROM   [io_stats_writes]
GROUP  BY [physical_name],
          [type_desc],
          [file_id]
ORDER  BY [file_id] ASC
OPTION(RECOMPILE); 
/*Summary totals*/
SELECT DB_NAME()                                      AS [database],
       [physical_name]                                AS [file_physical_name],
       [type_desc]                                    AS [file_type],
       CAST(SUM([delta_written_MB]) AS NUMERIC(6, 2)) AS [total_written_MB],
       SUM([duration_ms])                             AS [total_duration_ms],
       SUM([avg_io_stall_write_ms])                   AS [total_io_stall_write_ms],
       SUM([delta_num_of_writes])                     AS [total_writes],
       SUM([delta_size_on_disk_MB])                   AS [total_file_size_increase_MB]
FROM   [io_stats_writes]
GROUP  BY [physical_name],
          [type_desc],
          [file_id]
ORDER  BY [file_id] ASC
OPTION(RECOMPILE); 
/*Details*/
SELECT DB_NAME()               AS [database],
       [pass],
       [file_logical_name],
       [physical_name]         AS [file_physical_name],
       [type_desc]             AS [file_type],
       [duration_ms],
       [delta_size_on_disk_MB] AS [file_size_increase_MB],
       [avg_io_stall_write_ms],
       [delta_num_of_writes]   AS [writes],
       [delta_written_MB]      AS [written_MB]
FROM   [io_stats_writes]
ORDER  BY [pass],
          [file_id] ASC
OPTION(RECOMPILE); 

      
	  /*Cleanup*/
IF OBJECT_ID('dbo.speed_test') IS NOT NULL
  BEGIN
      DROP TABLE dbo.[speed_test];
  END;
IF OBJECT_ID('dbo.io_stats_writes') IS NOT NULL
  BEGIN
      DROP TABLE dbo.[io_stats_writes];
  END;