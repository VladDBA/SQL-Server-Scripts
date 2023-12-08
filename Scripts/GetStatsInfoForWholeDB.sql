/*
		Get statistics data for tables and indexed views with 1k+ records
		Run it in the context of the database for which you want to see stats data
		From https://github.com/VladDBA/SQL-Server-Scripts/
		License https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/

SELECT DB_NAME() AS [database],
	   SCHEMA_NAME([obj].[schema_id]) + '.' 
	   + [obj].[name]							AS [object_name],
	   [obj].[type_desc]						AS [object_type],
       [stat].[name]							AS [stats_name],
	   CASE 
	   WHEN [stat].[auto_created] = 1 THEN 'Auto-Created'
	   WHEN [stat].[auto_created] = 1 THEN 'User-Created'
	   ELSE 'Index'
	   END										AS [origin],
       [stat].[filter_definition],
       [sp].[last_updated],
       ISNULL([sp].[rows],0)					AS [rows],
	   ISNULL([sp].[unfiltered_rows],0)			AS [unfiltered_rows],
       ISNULL([sp].[rows_sampled],0)			AS [rows_sampled],
       CASE 
		WHEN [sp].[rows] IS NULL THEN 0 
		ELSE (CAST(CAST([sp].[rows_sampled] AS FLOAT) 
		/ CAST([sp].[rows] AS FLOAT) 
		* 100.00 AS DECIMAL(5,2))) 
       END										AS [sample_percent],
	   ISNULL([sp].[modification_counter],0)	AS [modification_counter],
	   CASE 
		WHEN [sp].[modification_counter] IS NULL THEN 0 
		ELSE (CAST(CAST([sp].[modification_counter] AS FLOAT) 
		/ CAST([sp].[rows] AS FLOAT) 
		* 100.00 AS DECIMAL(38,2))) 
       END										AS [modified_percent],
       ISNULL([sp].[steps],0)					AS [steps],
	   'No'										AS [partitioned],
	   0										AS [partition_number]
FROM   [sys].[stats] AS [stat]
       CROSS APPLY [sys].[dm_db_stats_properties]([stat].[object_id],
                                              [stat].[stats_id]) AS [sp]
       INNER JOIN [sys].[objects] AS [obj]
               ON [stat].[object_id] = [obj].[object_id]
WHERE
  [obj].[type] IN ( 'U', 'V' )		/*limit objects to tables and potentially indexed views*/
  AND [stat].[is_incremental] = 0	/*limit to non-incremental stats only */
  AND [sp].[rows] >= 1000			/*only get tables with 1k rows or more*/
UNION 
SELECT DB_NAME() AS [database],
	   SCHEMA_NAME([obj].[schema_id]) + '.' 
		+ [obj].[name]							AS [object_name],
	   [obj].[type_desc]						AS [object_type],
       [stat].[name] AS [stats_name],
	   CASE 
		WHEN [stat].[auto_created] = 1 THEN 'Auto-Created'
		WHEN [stat].[auto_created] = 1 THEN 'User-Created'
		ELSE 'Index'
	   END										AS [origin],
       [stat].[filter_definition],
       [sip].[last_updated],
       ISNULL([sip].[rows],0)					AS [rows],
	   ISNULL([sip].[unfiltered_rows],0)		AS [unfiltered_rows],
       ISNULL([sip].[rows_sampled],0)			AS [rows_sampled],
       CASE WHEN [sip].[rows] IS NULL THEN 0 
	   ELSE (CAST(CAST([sip].[rows_sampled] AS FLOAT) 
	   / CAST([sip].[rows] AS FLOAT) 
	   * 100.00 AS DECIMAL(5,2))) 
	   END										AS [sample_percent],
       ISNULL([sip].[modification_counter],0)	AS [modification_counter],
	   CASE 
		WHEN [sip].[modification_counter] IS NULL THEN 0 
		ELSE (CAST(CAST([sip].[modification_counter] AS FLOAT) 
		/ CAST([sip].[rows] AS FLOAT) 
		* 100.00 AS DECIMAL(5,2))) 
       END										AS [modified_percent],
       ISNULL([sip].[steps],0)					AS [steps],
	   'Yes'									AS [partitioned],
	   [sip].[partition_number]
FROM   [sys].[stats] AS [stat]
       CROSS APPLY [sys].[dm_db_incremental_stats_properties]([stat].[object_id],
                                              [stat].[stats_id]) AS [sip]
       INNER JOIN [sys].[objects] AS [obj]
               ON [stat].[object_id] = [obj].[object_id]
WHERE
  [obj].[type] IN ( 'U', 'V' )		/*limit objects to tables and potentially indexed views*/
  AND [stat].[is_incremental] = 1	/*limit to incremental stats only */
  AND [sip].[rows] >= 1000			/*only get tables with 1k rows or more*/
ORDER BY [modified_percent] DESC;
