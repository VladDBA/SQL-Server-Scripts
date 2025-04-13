/* 
   Get SQL Server client connection information
   Author: Vlad Drumea
   More info: https://vladdba.com/2025/04/13/query-connection-information-in-sql-server/
   From https://github.com/VladDBA/SQL-Server-Scripts/
   License https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/
SET CONCAT_NULL_YIELDS_NULL ON;
SELECT [d].[name]                                                                            AS [database],
       COUNT([c].[connection_id])                                                            AS [connections_count],
       RTRIM(LTRIM([s].[login_name]))                                                        AS [login_name],
       ISNULL([s].[host_name], N'N/A')                                                       AS [client_host_name],
       REPLACE(REPLACE([c].[client_net_address], N'<', N''), N'>', N'')                      AS [client_IP],
       [c].[net_transport]                                                                   AS [protocol],
	   ISNULL(NULLIF(CAST(SUM(CASE 
	                            WHEN LOWER([s].[status]) = N'preconnect' 
	   						    THEN 1 ELSE 0 
	   						  END) AS VARCHAR(20))+ ' preconnect', '0 preconnect')+'; ', '')
	   
	   +ISNULL(NULLIF(CAST(SUM(CASE 
	                             WHEN LOWER([s].[status]) = N'dormant' 
	   							 THEN 1 ELSE 0 
	   						   END) AS VARCHAR(20))+' dormant', '0 dormant')+'; ', '')
	   +ISNULL(NULLIF(CAST(SUM(CASE 
	                             WHEN LOWER([s].[status]) = N'running' 
	   							 THEN 1 ELSE 0 
	   						   END) AS VARCHAR(20))+' running', '0 running')+'; ', '')
	   +ISNULL(NULLIF(CAST(SUM(CASE 
	                             WHEN LOWER([s].[status]) = N'sleeping' 
	   							 THEN 1 ELSE 0 
	   						   END) AS VARCHAR(20))+' sleeping', '0 sleeping'), '')          AS [sessions_by_state],
       MAX([c].[connect_time])                                                               AS [oldest_connection_time],
       MIN([c].[connect_time])                                                               AS [newest_connection_time],
       [s].[program_name]                                                                    AS [program]
FROM   sys.[dm_exec_sessions] AS [s]
       LEFT JOIN sys.[databases] AS [d]
              ON [d].[database_id] = [s].[database_id]
       INNER JOIN sys.[dm_exec_connections] AS [c]
               ON [s].[session_id] = [c].[session_id]
GROUP  BY [d].[database_id],
          [d].[name],
          [s].[login_name],
          [s].[security_id],
          [s].[host_name],
          [c].[client_net_address],
          [c].[net_transport],
          [s].[program_name]
ORDER  BY [connections_count] DESC;