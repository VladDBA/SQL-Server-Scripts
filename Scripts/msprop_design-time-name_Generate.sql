/*
		Script that can be used when manually adding new fields to an SSRS model (.smdl file)
	to generate the values required by the "msprop:design-time-name" column attribute, 
	or by the "Attribute ID" field attribute.
*/
DECLARE @UID VARCHAR(100);
SELECT @UID =LOWER(CONVERT(VARCHAR(100), CAST(HASHBYTES('MD5',
                                                  CONVERT(VARCHAR(19), GETDATE()
                                        , 21))
                                               AS
                                                     UNIQUEIDENTIFIER)));
SELECT @UID AS [msprop:design-time-name], N'G'+@UID AS [Attribute ID];
