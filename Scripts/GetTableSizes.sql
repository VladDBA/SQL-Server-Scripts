/* 
	Script to search for a string in an entire SQL Server database
	By Vlad Drumea
	From: https://github.com/VladDBA/SQL-Server-Scripts/
	Blog: https://vladdba.com/
    More info about this script: https://vladdba.com/2023/08/24/script-to-get-table-sizes-in-sql-server/
	License: https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/

/*Make sure temp table doesn't exist*/
IF OBJECT_ID(N'tempdb.dbo.#NcIx', N'U') IS NOT NULL
    DROP TABLE #NcIx;
/*Get NC index info into temp table*/
SELECT t.[object_id],
       COUNT(DISTINCT ix.index_id)              AS [NcIndexes],
       CAST(( ( SUM([au].[total_pages]) * 8 ) 
	   / 1024.00 / 1024.00 ) AS NUMERIC(15, 3)) AS [TotalSizeGB]
INTO   #NcIx
FROM   sys.tables AS t
       INNER JOIN sys.indexes AS ix
               ON t.[object_id] = ix.[object_id]
       INNER JOIN sys.partitions AS p
               ON ix.[object_id] = p.[object_id]
                  AND ix.index_id = p.index_id
       INNER JOIN sys.allocation_units AS au
               ON p.[partition_id] = au.container_id
WHERE  /*Only get nc indexes*/
  ix.[index_id] > 1
GROUP  BY t.[object_id]; 
/*Return tables info*/
SELECT SCHEMA_NAME(t.[schema_id])+'.'+t.[name]     AS [TableName],
       CASE
         WHEN ix.[type_desc] = N'CLUSTERED' 
		 THEN ix.[name]
         ELSE N'  --N/A--'
       END                                         AS [ClusteredIndexName],
       ix.[type_desc]                              AS [TableType],
       SUM(CASE
             /*we only care for in row data if we don't want to get weird 
             duplicate counts from LOB and/or offrow data*/
             WHEN au.[type] = 1 THEN p.[rows]
             ELSE 0
           END)                                    AS [Records],
       CAST(( ( SUM(au.total_pages) * 8 ) 
	     / 1024.00 / 1024.00 ) AS NUMERIC(15, 3))  AS [AllocatedSpaceGB],
       CAST(( ( SUM(au.used_pages) * 8 ) 
	     / 1024.00 / 1024.00 ) AS NUMERIC(15, 3))  AS [UsedSpaceGB],
       p.[data_compression_desc]                   AS [CompressionType],
       /*since we're joining with sys.allocation_units we get 
	   duplicate partition counts for LOB and offrow allocation 
	   types, so we only care for allocation_unit.type 1*/
       SUM(CASE
             WHEN au.[type] = 1 THEN 1
             ELSE 0
           END)                                    AS [Partitions],
       ISNULL(NcIx.NcIndexes, 0)                   AS [NCIndexes],
       ISNULL(NcIx.TotalSizeGB, 0.00)              AS [NCIXTotalAllocGB]
FROM   sys.tables AS t
       INNER JOIN sys.indexes AS ix
               ON t.[object_id] = ix.[object_id]
       INNER JOIN sys.partitions AS p
               ON ix.[object_id] = p.[object_id]
                  AND ix.index_id = p.index_id
       INNER JOIN sys.allocation_units AS au
               ON p.[partition_id] = au.container_id
       LEFT JOIN #NcIx AS NcIx
              ON t.[object_id] = NcIx.[object_id]
WHERE  /*Only get clusters and heaps*/
  ix.index_id IN ( 0, 1 )
GROUP  BY t.[schema_id], 
          t.[name],
          ix.[name],
          ix.[type_desc],
          p.data_compression_desc,
          NcIx.NcIndexes,
          NcIx.TotalSizeGB
ORDER  BY [AllocatedSpaceGB] DESC;
/*Delete temp table*/
IF OBJECT_ID(N'tempdb.dbo.#NcIx', N'U') IS NOT NULL
    DROP TABLE #NcIx;