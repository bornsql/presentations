-- Restore the WideWorldImporters database from Microsoft's GitHub repo at:
-- https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

USE [WideWorldImporters];
GO

-- Look at a the temporal table
SELECT *
FROM [Application].[People];

-- Look at some random data
SELECT *
FROM [Application].[People]
WHERE [PersonID] IN ( 9, 3017 );

-- Look at the temporal plus the history
SELECT *
FROM [Application].[People] FOR SYSTEM_TIME ALL;

-- Same, but for the random data
SELECT *
FROM [Application].[People] FOR SYSTEM_TIME ALL
WHERE [PersonID] IN ( 9, 3017 )
ORDER BY [PersonID],
         [ValidTo];

-- AS OF
SELECT *
FROM [Application].[People]
    FOR SYSTEM_TIME AS OF '2016-03-13 08:00:00.0000000'
WHERE [PersonID] IN ( 9, 3017 );

-- BETWEEN
SELECT *
FROM [Application].[People]
    FOR SYSTEM_TIME BETWEEN '2016-05-31 23:12:00.0000000' AND '2016-05-31 23:13:00.0000000'
WHERE [PersonID] IN ( 9, 3017 )
ORDER BY [PersonID],
         [ValidTo];

-- FROM and TO
SELECT *
FROM [Application].[People]
    FOR SYSTEM_TIME FROM '2016-05-31 23:12:00.0000000' TO '2016-05-31 23:13:00.0000000'
WHERE [PersonID] IN ( 9, 3017 )
ORDER BY [PersonID],
         [ValidTo];

-- CONTAINED IN
SELECT *
FROM [Application].[People]
    FOR SYSTEM_TIME CONTAINED IN('2016-05-31 23:12:00.0000000', '2016-05-31 23:13:00.0000000')
WHERE [PersonID] IN ( 9, 3017 )
ORDER BY [PersonID],
         [ValidTo];

-- Let's do some damage
UPDATE [Application].[People]
SET [IsEmployee] = 1
--WHERE [PeopleID] = 3017;

-- Get the time of the incident, and subtract the smallest possible
-- granularity before that. E.g. if it's DATETIME2(7), take off 100 nanoseconds.
SELECT *
FROM [Application].[People]
    FOR SYSTEM_TIME AS OF '2021-10-26 18:53:08.8164582';

-------------------------------------------------
-------------------------------------------------
-- First way: keep the history of the disaster
-------------------------------------------------
-------------------------------------------------

SELECT * INTO ##table
FROM [Application].[People]
    FOR SYSTEM_TIME AS OF '2021-10-26 18:53:08.8164582';

SELECT * FROM [##table];

UPDATE [p]
SET [p].[FullName] = [t].[FullName],
    [p].[PreferredName] = [t].[PreferredName],
    -- [p].[SearchName] = [t].[SearchName], -- Computed Column
    [p].[IsPermittedToLogon] = [t].[IsPermittedToLogon],
    [p].[LogonName] = [t].[LogonName],
    [p].[IsExternalLogonProvider] = [t].[IsExternalLogonProvider],
    [p].[HashedPassword] = [t].[HashedPassword],
    [p].[IsSystemUser] = [t].[IsSystemUser],
    [p].[IsEmployee] = [t].[IsEmployee],
    [p].[IsSalesperson] = [t].[IsSalesperson],
    [p].[UserPreferences] = [t].[UserPreferences],
    [p].[PhoneNumber] = [t].[PhoneNumber],
    [p].[FaxNumber] = [t].[FaxNumber],
    [p].[EmailAddress] = [t].[EmailAddress],
    [p].[Photo] = [t].[Photo],
    [p].[CustomFields] = [t].[CustomFields],
    -- [p].[OtherLanguages] = [t].[OtherLanguages], -- Computed Column
    [p].[LastEditedBy] = [t].[LastEditedBy]
FROM [Application].[People] AS [p]
    INNER JOIN [##table] AS [t]
        ON [p].[PersonID] = [t].[PersonID];

SELECT *
FROM [Application].[People];

-------------------------------------------------
-------------------------------------------------
-- Second way: remove the history of the disaster
-------------------------------------------------
-------------------------------------------------

SELECT * FROM [##table]

-- Don't run the entire transaction at once because it will fail.
-- Run each section on its own.
BEGIN TRAN

ALTER TABLE [Application].[People] SET (SYSTEM_VERSIONING = OFF);
ALTER TABLE  [Application].[People] DROP PERIOD FOR SYSTEM_TIME;

UPDATE [p]
SET [p].[FullName] = [t].[FullName],
    [p].[PreferredName] = [t].[PreferredName],
    -- [p].[SearchName] = [t].[SearchName], -- Computed Column
    [p].[IsPermittedToLogon] = [t].[IsPermittedToLogon],
    [p].[LogonName] = [t].[LogonName],
    [p].[IsExternalLogonProvider] = [t].[IsExternalLogonProvider],
    [p].[HashedPassword] = [t].[HashedPassword],
    [p].[IsSystemUser] = [t].[IsSystemUser],
    [p].[IsEmployee] = [t].[IsEmployee],
    [p].[IsSalesperson] = [t].[IsSalesperson],
    [p].[UserPreferences] = [t].[UserPreferences],
    [p].[PhoneNumber] = [t].[PhoneNumber],
    [p].[FaxNumber] = [t].[FaxNumber],
    [p].[EmailAddress] = [t].[EmailAddress],
    [p].[Photo] = [t].[Photo],
    [p].[CustomFields] = [t].[CustomFields],
    -- [p].[OtherLanguages] = [t].[OtherLanguages], -- Computed Column
    [p].[LastEditedBy] = [t].[LastEditedBy],
    [p].[ValidFrom] = [t].[ValidFrom],
    [p].[ValidTo] = '9999-12-31 23:59:59.9999999'
FROM [Application].[People] AS [p]
    INNER JOIN [##table] AS [t]
        ON [p].[PersonID] = [t].[PersonID];

ALTER TABLE [Application].[People] ADD PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);

-- Here we remove any record of the incident
DELETE FROM [Application].[People_Archive]
WHERE
[ValidFrom] = '2021-10-26 18:53:08.8164583' OR 
[ValidTo] = '2021-10-26 18:53:08.8164583';

-- Turn back on system versioning
ALTER TABLE [Application].[People]
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE=[Application].[People_Archive]));
COMMIT;

-- Show the results after cleanup
SELECT * FROM [Application].[People_Archive]
SELECT * FROM [Application].[People]

-- This fails because you can't drop a table if system versioning is enabled
DROP TABLE IF EXISTS [Application].[People]

-- Dropping a column drops it in the history table too with no warning!
ALTER TABLE [Application].[People] DROP COLUMN [OtherLanguages]
