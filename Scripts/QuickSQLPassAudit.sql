/*
		Audit SQL Logins for easy to guess/simple passwords
		From https://github.com/VladDBA/SQL-Server-Scripts/
		License https://github.com/VladDBA/SQL-Server-Scripts/blob/0a990ac2fbf633681872e95dca1d941df05c6932/LICENSE.md
		The script relies on STRING_SPLIT so it only works on SQL Server 2016 and newer
*/
SET NOCOUNT ON;
DECLARE @UseInstInfo   BIT,
        @BaseWordsList NVARCHAR(1200);

/*List of comma separated custom words spaces are not required*/
SET @BaseWordsList = N'contoso,fakeproject'; /*Add your custom words here*/
/*Change this to 1 to use databse names, logins and instance name for password candidates*/
SET @UseInstInfo = 1;




/*Setting up temp tables*/
IF OBJECT_ID(N'tempdb..#WordList') IS NOT NULL
  BEGIN
      DROP TABLE #WordList;
  END;

IF OBJECT_ID(N'tempdb..#SpecChars') IS NOT NULL
  BEGIN
      DROP TABLE #SpecChars;
  END;

CREATE TABLE #WordList
  (
     ID   INT NOT NULL IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
     Word NVARCHAR(128)
  );

CREATE TABLE #SpecChars
  (
     SpecChar NVARCHAR(2)
  );

/*Inserting special characters*/
INSERT INTO #SpecChars (SpecChar) VALUES (N'!');
INSERT INTO #SpecChars (SpecChar) VALUES (N'^');
INSERT INTO #SpecChars (SpecChar) VALUES (N'?');
INSERT INTO #SpecChars (SpecChar) VALUES (N'.');
INSERT INTO #SpecChars (SpecChar) VALUES (N',');
INSERT INTO #SpecChars (SpecChar) VALUES (N'~');
INSERT INTO #SpecChars (SpecChar) VALUES (N'#');
INSERT INTO #SpecChars (SpecChar) VALUES (N'@');
INSERT INTO #SpecChars (SpecChar) VALUES (N'$');
INSERT INTO #SpecChars (SpecChar) VALUES (N'&');
INSERT INTO #SpecChars (SpecChar) VALUES (N')');
INSERT INTO #SpecChars (SpecChar) VALUES (N'(');
INSERT INTO #SpecChars (SpecChar) VALUES (N'-');
INSERT INTO #SpecChars (SpecChar) VALUES (N'=');
INSERT INTO #SpecChars (SpecChar) VALUES (N'_');
INSERT INTO #SpecChars (SpecChar) VALUES (N'+');
INSERT INTO #SpecChars (SpecChar) VALUES (N':');
INSERT INTO #SpecChars (SpecChar) VALUES (N';');
INSERT INTO #SpecChars (SpecChar) VALUES (N'"');
INSERT INTO #SpecChars (SpecChar) VALUES (N'<');
INSERT INTO #SpecChars (SpecChar) VALUES (N'>');
INSERT INTO #SpecChars (SpecChar) VALUES (N'/');
INSERT INTO #SpecChars (SpecChar) VALUES (N' ');
INSERT INTO #SpecChars (SpecChar) VALUES (N'*');
INSERT INTO #SpecChars (SpecChar) VALUES (N'\');
INSERT INTO #SpecChars (SpecChar) VALUES (N'}');
INSERT INTO #SpecChars (SpecChar) VALUES (N'{');
INSERT INTO #SpecChars (SpecChar) VALUES (N']');
INSERT INTO #SpecChars (SpecChar) VALUES (N'[');
INSERT INTO #SpecChars (SpecChar) VALUES (N'!!');
INSERT INTO #SpecChars (SpecChar) VALUES (N'^^');
INSERT INTO #SpecChars (SpecChar) VALUES (N'??');
INSERT INTO #SpecChars (SpecChar) VALUES (N'..');
INSERT INTO #SpecChars (SpecChar) VALUES (N',,');
INSERT INTO #SpecChars (SpecChar) VALUES (N'~~');
INSERT INTO #SpecChars (SpecChar) VALUES (N'##');
INSERT INTO #SpecChars (SpecChar) VALUES (N'@@');
INSERT INTO #SpecChars (SpecChar) VALUES (N'$$');
INSERT INTO #SpecChars (SpecChar) VALUES (N'&&');
INSERT INTO #SpecChars (SpecChar) VALUES (N'))');
INSERT INTO #SpecChars (SpecChar) VALUES (N'((');
INSERT INTO #SpecChars (SpecChar) VALUES (N'--');
INSERT INTO #SpecChars (SpecChar) VALUES (N'==');
INSERT INTO #SpecChars (SpecChar) VALUES (N'__');
INSERT INTO #SpecChars (SpecChar) VALUES (N'++');
INSERT INTO #SpecChars (SpecChar) VALUES (N'::');
INSERT INTO #SpecChars (SpecChar) VALUES (N';;');
INSERT INTO #SpecChars (SpecChar) VALUES (N'""');
INSERT INTO #SpecChars (SpecChar) VALUES (N'<<');
INSERT INTO #SpecChars (SpecChar) VALUES (N'>>');
INSERT INTO #SpecChars (SpecChar) VALUES (N'//');
INSERT INTO #SpecChars (SpecChar) VALUES (N'  ');
INSERT INTO #SpecChars (SpecChar) VALUES (N'**');
INSERT INTO #SpecChars (SpecChar) VALUES (N'\\');
INSERT INTO #SpecChars (SpecChar) VALUES (N'}}');
INSERT INTO #SpecChars (SpecChar) VALUES (N'{{');
INSERT INTO #SpecChars (SpecChar) VALUES (N']]');
INSERT INTO #SpecChars (SpecChar) VALUES (N'[[');
INSERT INTO #SpecChars (SpecChar) VALUES (N'');

/*Variable declaration*/
DECLARE @BaseWord    NVARCHAR(100),
        @SpChar      NVARCHAR(2),
        @CurrentYear SMALLINT,
        @ShortYear   TINYINT,
        @Year        SMALLINT,
        @EndYear     SMALLINT,
        @Common      NVARCHAR(200),
        @OrigYear    SMALLINT,
        @OrigShYear  TINYINT,
        @OSpChar     NVARCHAR(2);

/*Commonly used base words and keyboard walks*/
SET @Common = N'summer,spring,autumn,fall,winter,password,welcome123,hello,qwerty,asdf';
SET @Common = @Common
              + N',letmein,qwerty123,123456qwerty,123asdf,qwertyuiop,zxcv,secret';
/*Append common base words to provided base words*/
SET @BaseWordsList = @BaseWordsList + N',' + @Common;
/*Cleanup any potential spaces after or before the comma*/
SELECT @BaseWordsList = REPLACE(REPLACE(@BaseWordsList, N', ',','),N' ,',',')
/*Get current year, calculate Year, EndYear and ShortYear*/
SELECT @CurrentYear = DATEPART(YEAR, GETDATE());

SELECT @Year = @CurrentYear - 9,
       @EndYear = @CurrentYear + 3;

SELECT @ShortYear = @Year - 2000;

SET @OrigYear = @Year;
SET @OrigShYear = @ShortYear;

/*
	Split words in @BaseWordsList and insert into #BaseWords table one per row
*/
IF OBJECT_ID(N'tempdb..#BaseWords') IS NOT NULL
  BEGIN
      DROP TABLE #BaseWords;
  END;

CREATE TABLE #BaseWords
  (
     Word          NVARCHAR(120)
  );

BEGIN
    INSERT INTO #BaseWords
                (Word)
    SELECT value
    FROM STRING_SPLIT(@BaseWordsList, N','); 
END;
/*Empty string*/
INSERT INTO #WordList
           (Word)
VALUES ('')
/*Generate password candidates */
DECLARE WordCursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
  SELECT DISTINCT Word
  FROM   #BaseWords;

OPEN WordCursor;

FETCH NEXT FROM WordCursor INTO @BaseWord;

WHILE @@FETCH_STATUS = 0
  BEGIN
      DECLARE SpecCharCursor CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR
        SELECT SpecChar
        FROM   #SpecChars

      OPEN SpecCharCursor;

      FETCH NEXT FROM SpecCharCursor INTO @SpChar;

      WHILE @@FETCH_STATUS = 0
        BEGIN
            /*Append year and short year*/
            WHILE @Year <= @EndYear
              BEGIN
                  INSERT INTO #WordList
                              (Word)
                  SELECT @BaseWord + CAST(@Year AS NVARCHAR(4))
                         + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT @BaseWord
                         + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(LEFT(@BaseWord, 1))
                         + LOWER(SUBSTRING(@BaseWord, 2, LEN ( @BaseWord )))
                         + CAST(@Year AS NVARCHAR(4)) + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(LEFT(@BaseWord, 1))
                         + LOWER(SUBSTRING(@BaseWord, 2, LEN ( @BaseWord )))
                         + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(@BaseWord)
                         + CAST(@Year AS NVARCHAR(4)) + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(@BaseWord)
                         + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;

                  /*Wrapping in special characters*/
                  IF @SpChar <> N''
                    BEGIN
                        SELECT @OSpChar = CASE
                                            WHEN @SpChar = N')' THEN N'('
                                            WHEN @SpChar = N'))' THEN N'(('
                                            WHEN @SpChar = N']' THEN N'['
                                            WHEN @SpChar = N']]' THEN N'[['
                                            WHEN @SpChar = N'>' THEN N'<'
                                            WHEN @SpChar = N'>>' THEN N'<<'
                                            WHEN @SpChar = N'}' THEN N'{'
                                            WHEN @SpChar = N'}}' THEN N'{{'
                                            WHEN @SpChar = N'\\' THEN N'//'
                                            WHEN @SpChar = N'\' THEN N'/'
                                            WHEN @SpChar = N'/' THEN N'\'
                                            WHEN @SpChar = N'//' THEN N'\\'
                                            WHEN @SpChar = N'[' THEN N']'
                                            WHEN @SpChar = N'[[' THEN N']]'
                                            WHEN @SpChar = N'(' THEN N')'
                                            WHEN @SpChar = N'((' THEN N'))'
                                            WHEN @SpChar = N'{' THEN N'}'
                                            WHEN @SpChar = N'{{' THEN N'}}'
                                            WHEN @SpChar = N'<' THEN N'>'
                                            WHEN @SpChar = N'<<' THEN N'>>'
                                            ELSE @SpChar
                                          END;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + @BaseWord
                               + CAST(@Year AS NVARCHAR(4)) + @SpChar;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + @BaseWord
                               + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(LEFT(@BaseWord, 1))
                               + LOWER(SUBSTRING(@BaseWord, 2, LEN ( @BaseWord )))
                               + CAST(@Year AS NVARCHAR(4)) + @SpChar;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(LEFT(@BaseWord, 1))
                               + LOWER(SUBSTRING(@BaseWord, 2, LEN ( @BaseWord )))
                               + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(@BaseWord)
                               + CAST(@Year AS NVARCHAR(4)) + @SpChar;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(@BaseWord)
                               + CAST(@ShortYear AS NVARCHAR(2)) + @SpChar;
                    END;

                  SET @Year +=1;
                  SET @ShortYear +=1;
              END;

            /*Reset years*/
            SET @Year = @OrigYear;
            SET @ShortYear = @OrigShYear;

            /*Only append special characters */
            INSERT INTO #WordList
                        (Word)
            SELECT @BaseWord + @SpChar;

            INSERT INTO #WordList
                        (Word)
            SELECT UPPER(LEFT(@BaseWord, 1))
                   + LOWER(SUBSTRING(@BaseWord, 2, LEN( @BaseWord )))
                   + @SpChar;

            INSERT INTO #WordList
                        (Word)
            SELECT UPPER(@BaseWord) + @SpChar;

            /*Wrapping in special characters */
            IF @SpChar <> N''
              BEGIN
                  SELECT @OSpChar = CASE
                                      WHEN @SpChar = N')' THEN N'('
                                      WHEN @SpChar = N'))' THEN N'(('
                                      WHEN @SpChar = N']' THEN N'['
                                      WHEN @SpChar = N']]' THEN N'[['
                                      WHEN @SpChar = N'>' THEN N'<'
                                      WHEN @SpChar = N'>>' THEN N'<<'
                                      WHEN @SpChar = N'}' THEN N'{'
                                      WHEN @SpChar = N'}}' THEN N'{{'
                                      WHEN @SpChar = N'\\' THEN N'//'
                                      WHEN @SpChar = N'\' THEN N'/'
                                      WHEN @SpChar = N'/' THEN N'\'
                                      WHEN @SpChar = N'//' THEN N'\\'
                                      WHEN @SpChar = N'[' THEN N']'
                                      WHEN @SpChar = N'[[' THEN N']]'
                                      WHEN @SpChar = N'(' THEN N')'
                                      WHEN @SpChar = N'((' THEN N'))'
                                      WHEN @SpChar = N'{' THEN N'}'
                                      WHEN @SpChar = N'{{' THEN N'}}'
                                      WHEN @SpChar = N'<' THEN N'>'
                                      WHEN @SpChar = N'<<' THEN N'>>'
                                      ELSE @SpChar
                                    END;

                  INSERT INTO #WordList
                              (Word)
                  SELECT @OSpChar + @BaseWord + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT @OSpChar + UPPER(LEFT(@BaseWord, 1))
                         + LOWER(SUBSTRING(@BaseWord, 2, LEN( @BaseWord )))
                         + @SpChar;

                  INSERT INTO #WordList
                              (Word)
                  SELECT @OSpChar + UPPER(@BaseWord) + @SpChar;
              END;

            IF @UseInstInfo = 1
              /*Use instance data to generate passwords*/
              BEGIN
                  INSERT INTO #WordList
                  SELECT UPPER([name]) + @SpChar
                  FROM   sys.sql_logins
                  WHERE  [name] NOT LIKE N'##%';

                  INSERT INTO #WordList
                  SELECT [name] + @SpChar
                  FROM   sys.sql_logins
                  WHERE  [name] NOT LIKE N'##%';

                  INSERT INTO #WordList
                  SELECT LOWER([name]) + @SpChar
                  FROM   sys.sql_logins
                  WHERE  [name] NOT LIKE N'##%';

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(LEFT([name], 1))
                         + LOWER(SUBSTRING([name], 2, LEN([name])))
                         + @SpChar
                  FROM   sys.sql_logins
                  WHERE  [name] NOT LIKE N'##%';

                  INSERT INTO #WordList
                              (Word)
                  SELECT [name] + @SpChar
                  FROM   sys.databases
                  WHERE  [database_id] > 4;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER([name]) + @SpChar
                  FROM   sys.databases
                  WHERE  [database_id] > 4;

                  INSERT INTO #WordList
                  SELECT LOWER([name]) + @SpChar
                  FROM   sys.databases
                  WHERE  [database_id] > 4;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(LEFT([name], 1))
                         + LOWER(SUBSTRING([name], 2, LEN([name])))
                         + @SpChar
                  FROM   sys.databases
                  WHERE  [database_id] > 4;

                  INSERT INTO #WordList
                              (Word)
                  SELECT UPPER(CAST(ISNULL(SERVERPROPERTY('InstanceName'), @@SERVERNAME) AS NVARCHAR(100) ))
                         + @SpChar;

                  INSERT INTO #WordList
                  SELECT LOWER(CAST(ISNULL(SERVERPROPERTY('InstanceName'), @@SERVERNAME) AS NVARCHAR(100) ))
                         + @SpChar;

                  /*Wrapping in special characters */
                  IF @SpChar <> N''
                    BEGIN
                        SELECT @OSpChar = CASE
                                            WHEN @SpChar = N')' THEN N'('
                                            WHEN @SpChar = N'))' THEN N'(('
                                            WHEN @SpChar = N']' THEN N'['
                                            WHEN @SpChar = N']]' THEN N'[['
                                            WHEN @SpChar = N'>' THEN N'<'
                                            WHEN @SpChar = N'>>' THEN N'<<'
                                            WHEN @SpChar = N'}' THEN N'{'
                                            WHEN @SpChar = N'}}' THEN N'{{'
                                            WHEN @SpChar = N'\\' THEN N'//'
                                            WHEN @SpChar = N'\' THEN N'/'
                                            WHEN @SpChar = N'/' THEN N'\'
                                            WHEN @SpChar = N'//' THEN N'\\'
                                            WHEN @SpChar = N'[' THEN N']'
                                            WHEN @SpChar = N'[[' THEN N']]'
                                            WHEN @SpChar = N'(' THEN N')'
                                            WHEN @SpChar = N'((' THEN N'))'
                                            WHEN @SpChar = N'{' THEN N'}'
                                            WHEN @SpChar = N'{{' THEN N'}}'
                                            WHEN @SpChar = N'<' THEN N'>'
                                            WHEN @SpChar = N'<<' THEN N'>>'
                                            ELSE @SpChar
                                          END;

                        INSERT INTO #WordList
                        SELECT @OSpChar + UPPER([name]) + @SpChar
                        FROM   sys.sql_logins
                        WHERE  [name] NOT LIKE N'##%';

                        INSERT INTO #WordList
                        SELECT @OSpChar + [name] + @SpChar
                        FROM   sys.sql_logins
                        WHERE  [name] NOT LIKE N'##%';

                        INSERT INTO #WordList
                        SELECT @OSpChar + LOWER([name]) + @SpChar
                        FROM   sys.sql_logins
                        WHERE  [name] NOT LIKE N'##%';

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(LEFT([name], 1))
                               + LOWER(SUBSTRING([name], 2, LEN([name])))
                               + @SpChar
                        FROM   sys.sql_logins
                        WHERE  [name] NOT LIKE N'##%';

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + [name] + @SpChar
                        FROM   sys.databases
                        WHERE  [database_id] > 4;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER([name]) + @SpChar
                        FROM   sys.databases
                        WHERE  [database_id] > 4;

                        INSERT INTO #WordList
                        SELECT @OSpChar + LOWER([name]) + @SpChar
                        FROM   sys.databases
                        WHERE  [database_id] > 4;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar + UPPER(LEFT([name], 1))
                               + LOWER(SUBSTRING([name], 2, LEN([name])))
                               + @SpChar
                        FROM   sys.databases
                        WHERE  [database_id] > 4;

                        INSERT INTO #WordList
                                    (Word)
                        SELECT @OSpChar
                               + UPPER(CAST(ISNULL(SERVERPROPERTY('InstanceName'), @@SERVERNAME) AS NVARCHAR(100) ))
                               + @SpChar;

                        INSERT INTO #WordList
                        SELECT @OSpChar
                               + LOWER(CAST(ISNULL(SERVERPROPERTY('InstanceName'), @@SERVERNAME) AS NVARCHAR(100) ))
                               + @SpChar;
                    END;
              END;

            FETCH NEXT FROM SpecCharCursor INTO @SpChar;
        END;

      /*Loop only once through system info */
      SET @UseInstInfo = 0;

      CLOSE SpecCharCursor;

      DEALLOCATE SpecCharCursor;

      FETCH NEXT FROM WordCursor INTO @BaseWord;
  END;

CLOSE WordCursor;

DEALLOCATE WordCursor;
/*Check passwords against the hashes in the sys.sql_logins catalog view*/
SELECT [SL].[name]                                      AS [LoginName],
       [P].[Word]                                       AS [Password],
       IS_SRVROLEMEMBER (N'sysadmin', [SL].[name])      AS [IsSysAdmin],
       IS_SRVROLEMEMBER (N'serveradmin', [SL].[name])   AS [IsServerAdmin],
       IS_SRVROLEMEMBER (N'securityadmin', [SL].[name]) AS [IsSecurityAdmin],
       IS_SRVROLEMEMBER (N'dbcreator', [SL].[name])     AS [IsDBCreator]
FROM   sys.sql_logins AS [SL]
       INNER JOIN #WordList AS [P]
               ON PWDCOMPARE([P].[Word], [SL].[password_hash]) = 1
WHERE  [SL].[name] NOT LIKE N'##%';

DROP TABLE #WordList;