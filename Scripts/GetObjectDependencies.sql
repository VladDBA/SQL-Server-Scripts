/* 
   Get object dependencies 
   Author: Vlad Drumea
   More info: 
   From https://github.com/VladDBA/SQL-Server-Scripts/
   License https://github.com/VladDBA/SQL-Server-Scripts/blob/main/LICENSE.md
*/

  /*provide an object name or leave empty to search the entire database*/
DECLARE @ObjectName NVARCHAR(261) = N'';

SELECT QUOTENAME(SCHEMA_NAME([ob].[schema_id]))
       + N'.' + QUOTENAME([ob].[name])
       + ISNULL(N'.'+QUOTENAME([col].[name]), N'')               AS [referencing_object_name],
       [ob].[type_desc]                                          AS [referencing_object_type],
       ISNULL(QUOTENAME([sed].[referenced_server_name])+N'.', N'')
       + ISNULL(QUOTENAME([sed].[referenced_database_name])+N'.', N'')
       + ISNULL(QUOTENAME([sed].[referenced_schema_name])+N'.', N'')
       + ISNULL(QUOTENAME([sed].[referenced_entity_name]), N'')
       + ISNULL(N'.' + QUOTENAME([tgcol].[name]), N'')           AS [fully_qulified_referenced_object],
       ISNULL([tgob].[type_desc], [sed].[referenced_class_desc]) AS [referenced_object_type_or_class],
       [sed].[referenced_server_name],
       [sed].[referenced_database_name],
       [sed].[referenced_schema_name],
       [sed].[referenced_entity_name],
       [tgcol].[name]                                            AS [referenced_column_name],
       [sed].[is_schema_bound_reference],
       [sed].[is_ambiguous],
       [sed].[is_caller_dependent]
FROM   sys.[sql_expression_dependencies] [sed]
       INNER JOIN sys.[all_objects] AS [ob]
               ON [sed].[referencing_id] = [ob].[object_id]
       LEFT JOIN sys.[all_columns] [col]
              ON [sed].[referencing_minor_id] = [col].[column_id]
                 AND [sed].[referencing_id] = [col].[object_id]
       LEFT JOIN sys.[all_objects] AS [tgob]
              ON [sed].[referenced_id] = [tgob].[object_id]
                 AND [sed].[referenced_server_name] IS NULL
                 AND
                 (
                   [sed].[referenced_database_name] IS NULL
                    OR [sed].[referenced_database_name] = DB_NAME()
                  )
       LEFT JOIN sys.[all_columns] [tgcol]
              ON [sed].[referenced_minor_id] = [tgcol].[column_id]
                 AND [sed].[referenced_id] = [tgcol].[object_id]
                 AND [sed].[referenced_server_name] IS NULL
                 AND
                 (
                   [sed].[referenced_database_name] IS NULL
                    OR [sed].[referenced_database_name] = DB_NAME()
                  )
WHERE  [sed].[referencing_id] = CASE
                                  WHEN @ObjectName <> N'' THEN OBJECT_ID(@ObjectName)
                                  ELSE [sed].[referencing_id]
                                END
        OR [sed].[referenced_id] = CASE
                                     WHEN @ObjectName <> N'' THEN OBJECT_ID(@ObjectName)
                                     ELSE [sed].[referenced_id]
                                   END
ORDER  BY [referencing_object_name];