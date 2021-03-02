	/*
		This is a script that can be used to kill multiple sessions
	on a SQL Server isntance, while also providing the ability to 
	target sessions based on specific filters.
	For more info visit: 
	*/
USE [master]
GO

		/* Variable declaration */
DECLARE  @SPID				SMALLINT
		,@ExecSQL			VARCHAR(11)
		,@Confirm			BIT
		,@ForLogin			NVARCHAR(128)
		,@SPIDState			VARCHAR(1)
		,@OmitLogin			NVARCHAR(128)
		,@ForDatabase		NVARCHAR(128)
		,@ReqOlderThanMin	INT;

		/* Filters */
SET @Confirm			= 0;	/* Just a precaution to make sure you've set the right filters before running this, switch to 1 to execute */
SET @ForLogin			= N'';	/* Only kill SPIDs belonging to this login, empty string = all logins */
SET @SPIDState			= '';	/* S = only kill sleeping SPIDs, R = only kill running SPIDs, empty string = kill SPIDs regardless of state*/
SET @OmitLogin			= N'';	/* Kill all SPIDs except the login name specified here, epty string = omit none */
SET @ForDatabase		= N'';	/* Kill only SPIDs hitting this database, empty string = all databases */
SET @ReqOlderThanMin	= 0;	/* Kill SPIDs whose last request start time is older than or equal to the value specified (in minutes),
									0 = the moment this query is executed*/

IF (@Confirm = 0)
BEGIN 
PRINT '@Confirm is set 0. The script has exited without killing any sessions.'
RETURN
END
DECLARE KillSPIDCursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT DISTINCT [session_id]
  FROM   [master].[sys].[dm_exec_sessions]
  WHERE
    [login_name] = CASE
                     /* Get all SPIDs */
                     WHEN @OmitLogin = N''
                          AND @ForLogin = N'' THEN
                       [login_name]
                     /* Get all SPIDs except for the ones belonging to @OmitLogin */
                     WHEN @OmitLogin <> N''
                          AND @ForLogin = N'' THEN
                       (SELECT DISTINCT [login_name]
                        FROM   [master].[sys].[dm_exec_sessions]
                        WHERE
                         [login_name] <> @OmitLogin)
                     /* Get all SPIDs belonging to a specific login */
                     WHEN @ForLogin <> N'' THEN
                       @ForLogin
                   END
    AND [session_id] <> @@SPID /* Exclude this SPID */
    AND [is_user_process] = 1 /* Target only non-system SPIDs */
    AND [database_id] = CASE
                          WHEN @ForDatabase <> N'' THEN
                            DB_ID(@ForDatabase)
                          ELSE [database_id]
                        END
    AND [login_name] NOT IN (SELECT [service_account]
                             FROM   [master].[sys].[dm_server_services]
                             WHERE
                              [status] = 4)
    AND [status] = CASE
                     WHEN @SPIDState = 'S' THEN
                       N'sleeping'
					 WHEN @SPIDState = 'R' THEN
					   N'running'
                     ELSE [status]
                   END
	AND [last_request_start_time] <= CASE
									   WHEN @ReqOlderThanMin = 0 THEN
										 GETDATE()
									   WHEN @ReqOlderThanMin > 0 THEN 
									     DATEADD(MINUTE,-@ReqOlderThanMin,GETDATE())
									 END;
OPEN KillSPIDCursor;

FETCH NEXT FROM KillSPIDCursor INTO @SPID;

WHILE @@FETCH_STATUS = 0
  BEGIN
      SET @ExecSQL = 'KILL ' + CAST(@SPID AS VARCHAR(5)) + ';';
      EXEC (@ExecSQL);
      FETCH NEXT FROM KillSPIDCursor INTO @SPID;
  END;

CLOSE KillSPIDCursor;
DEALLOCATE KillSPIDCursor;
