USE [master];
GO

SELECT
	@@VERSION;
GO

-- Azure Data Studio tip: select the whole column
-- and double-click on the right to expand it out.

-- Reset demo
DROP DATABASE IF EXISTS [TemporalDemo];
GO

-- Create new database
CREATE DATABASE [TemporalDemo];
GO

USE [TemporalDemo];
GO

-- Create new temporal table without specifying history table
CREATE TABLE dbo.Employee
(
	[EmployeeID] INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	[Name] NVARCHAR(100) NOT NULL,
	[Position] NVARCHAR(100) NOT NULL,
	[Department] NVARCHAR(100) NOT NULL,
	[Address] NVARCHAR(1024) NOT NULL,
	[AnnualSalary] DECIMAL(10, 2) NOT NULL,
	[ValidFrom] DATETIME2(3) GENERATED ALWAYS AS ROW START,
	[ValidTo] DATETIME2(3) GENERATED ALWAYS AS ROW END,
	PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON);
GO

-- Have a look at the temporal table in the Object Explorer

-- Note the history table name and schema
-- Note the default PAGE compression

-- Query to show that the table is PAGE compressed by default
SELECT SCHEMA_NAME(sys.objects.schema_id) AS [SchemaName],
	OBJECT_NAME(sys.objects.object_id) AS [ObjectName],
	[rows],
	[data_compression_desc],
	[index_id] AS [IndexID_on_Table]
FROM sys.partitions
INNER JOIN sys.objects
	ON sys.partitions.object_id = sys.objects.object_id
WHERE data_compression > 0
	AND SCHEMA_NAME(sys.objects.schema_id) <> 'SYS'
ORDER BY SchemaName,
	ObjectName;
GO

--- Insert some test data
INSERT INTO dbo.Employee
(
	Name,
	Position,
	Department,
	Address,
	AnnualSalary
)
VALUES
(
	N'Lorraine Baines',
	N'Legal Assistant',
	N'Legal Aid',
	N'1727 Bushnell Avenue, Hill Valley, California, 91030',
	2500
);

-- See what the data looks like
SELECT * FROM dbo.Employee;

-- Note that the PERIOD columns are included

-- Lorraine gets married
-- 1950s patriarchy says change your name!
UPDATE	dbo.Employee
SET		Name = N'Lorraine McFly'
WHERE	EmployeeID = 1;

-- See what the data looks like
-- (Remember to copy the time)
SELECT * FROM dbo.Employee;

-- Run all SELECTs and walk through each one

-- TODO: Correct these start and end dates and times
DECLARE @ChangeDate DATETIME2(3) = '2021-05-05 23:39:14.462'; -- actual change

DECLARE @StartDate DATETIME2(3) = DATEADD(DAY, -1, @ChangeDate);
DECLARE @EndDate DATETIME2(3) = DATEADD(MILLISECOND, 1, @ChangeDate); -- granularity depends on decimals
DECLARE @AsOfDate DATETIME2(3) = DATEADD(MILLISECOND, -1, @ChangeDate);

-- Current only
SELECT 'CURRENT' as [Type], * FROM dbo.Employee;

-- Current and History
SELECT 'ALL' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME ALL;

-- Current or History, at specific point in time
SELECT 'AS OF' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME AS OF @AsOfDate;
  
-- Current and History, all matching rows in range
-- Includes rows changed on upper bound
SELECT 'BETWEEN' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME BETWEEN @StartDate AND @ChangeDate;

-- Current and History, all matching rows in range
-- Excludes rows changed on upper bound
SELECT 'FROM TO' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME FROM @StartDate TO @ChangeDate;

-- Current and History, rows that became active and ended in range
-- Any rows with an end period in the future is excluded
SELECT 'CONTAINED IN' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME CONTAINED IN (@StartDate, @EndDate);

-------------









-- Drop the database and rebuild it



-- Create new temporal table and specify history table
USE [master];
GO

-- Reset demo
DROP DATABASE IF EXISTS [TemporalDemo];
GO

-- Create new database
CREATE DATABASE [TemporalDemo];
GO

USE [TemporalDemo];
GO

-- Pretend this schema is in another filegroup
CREATE SCHEMA [History];
GO

CREATE TABLE dbo.Employee
(
	[EmployeeID] INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	[Name] NVARCHAR(100) NOT NULL,
	[Position] NVARCHAR(100) NOT NULL,
	[Department] NVARCHAR(100) NOT NULL,
	[Address] NVARCHAR(1024) NOT NULL,
	[AnnualSalary] DECIMAL(10, 2) NOT NULL,
	[ValidFrom] DATETIME2(3) GENERATED ALWAYS AS ROW START,
	[ValidTo] DATETIME2(3) GENERATED ALWAYS AS ROW END,
	PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = History.Employee));
GO

-- Look at the table in the Object Explorer
-- if you're using Azure Data Studio, and
-- use metadata queries to see the objects

-- Observe the object properties on the tables involved
-- 0 = non-temporal table
-- 1 = history table for system-versioned table
-- 2 = system-versioned temporal table

-- Observe the object properties on the tables involved
-- 0 = non-temporal table
-- 1 = history table for system-versioned table
-- 2 = system-versioned temporal table

SELECT
	N'dbo.Employee' AS TableName,
	OBJECTPROPERTYEX(OBJECT_ID(N'dbo.Employee'), 'TableTemporalType'),
	'2 = system-versioned temporal table' AS [Type]

UNION ALL

SELECT
	N'History.Employee' AS TableName,
	OBJECTPROPERTYEX(OBJECT_ID(N'History.Employee'), 'TableTemporalType'),
	'1 = history table for system-versioned table' AS [Type];
GO

SELECT
	schema_name(schema_id) as SchemaName,
	name as TableName,
	temporal_type_desc
FROM
	sys.tables
WHERE name <> 'sysdiagrams';

------------------------------





-- Convert existing table to temporal table and specify history table
USE [master];
GO

-- Reset demo
DROP DATABASE IF EXISTS [TemporalDemo];
GO

-- Create new database
CREATE DATABASE [TemporalDemo];
GO

USE [TemporalDemo];
GO

-- Create plain-old table
CREATE TABLE dbo.Employee
(
	[EmployeeID] INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	[Name] NVARCHAR(100) NOT NULL,
	[Position] NVARCHAR(100) NOT NULL,
	[Department] NVARCHAR(100) NOT NULL,
	[Address] NVARCHAR(1024) NOT NULL,
	[AnnualSalary] DECIMAL(10, 2) NOT NULL
);
GO


DROP SCHEMA IF EXISTS [History];
GO
CREATE SCHEMA [History];
GO

-- Add the two PERIOD columns. Note that they can be
-- any length of DATETIME2

ALTER TABLE Employee
ADD
	ValidFrom DATETIME2(3) GENERATED ALWAYS AS ROW START HIDDEN
		CONSTRAINT DF_ValidStart
			DEFAULT SYSUTCDATETIME(),
	ValidTo DATETIME2(3) GENERATED ALWAYS AS ROW END HIDDEN
		CONSTRAINT DF_ValidTo
			DEFAULT CONVERT(DATETIME2(3), '9999-12-31 23:59:59.999'),
	PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo);
GO

-- Note the HIDDEN keyword! This is explicitly to avoid breaking
-- existing queries and applications, for backward compatibility

-- SELECT * FROM dbo.Employee

-- Set versioning on
-- DATA_CONSISTENCY_CHECK is ON by default, shown here for completion
ALTER TABLE Employee SET
	(SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = History.Employee, DATA_CONSISTENCY_CHECK = ON
	)
);

-- Insert a row and query temporal table
-- (no data in history, one row in current)
INSERT INTO dbo.Employee
(
	Name,
	Position,
	Department,
	Address,
	AnnualSalary
)
VALUES
(
	N'Lorraine Baines',
	N'Legal Assistant',
	N'Legal Aid',
	N'1727 Bushnell Avenue, Hill Valley, California, 91030',
	2500
);

-- See what the data looks like
SELECT * FROM dbo.Employee;

-- Note that the PERIOD columns do not appear in the output now (HIDDEN keyword)

-- Modify a row and query temporal table
-- (one row in history, one row in current)
UPDATE	dbo.Employee
SET		Name = N'Lorraine McFly'
WHERE	EmployeeID = 1;

-- See what the data looks like
-- (copy the date again)
SELECT *, ValidFrom, ValidTo FROM dbo.Employee;

-- TODO: Correct these start and end dates and times
DECLARE @ChangeDate DATETIME2(3) = '2021-05-05 23:54:30.729'; -- actual change

DECLARE @StartDate DATETIME2(3) = DATEADD(DAY, -1, @ChangeDate);
DECLARE @EndDate DATETIME2(3) = DATEADD(MILLISECOND, 1, @ChangeDate);
DECLARE @AsOfDate DATETIME2(3) = DATEADD(MILLISECOND, -1, @ChangeDate);

-- Current only
SELECT 'CURRENT' AS [Type], *, ValidFrom, ValidTo FROM dbo.Employee;

-- Current and History
SELECT 'ALL' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME ALL;

-- Current or History, at specific point in time
SELECT 'AS OF' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME AS OF @AsOfDate;
  
-- Current and History, all matching rows in range
SELECT 'BETWEEN' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME BETWEEN @StartDate AND @EndDate;

-- Current and History, all matching rows in range > @StartDate
SELECT 'FROM TO' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME FROM @StartDate TO @EndDate;

-- Current and History, rows that became active and ended in range
SELECT 'CONTAINED IN' as [Type], * FROM dbo.Employee
FOR SYSTEM_TIME CONTAINED IN (@StartDate, @EndDate);

--------


-- Delete a row and query temporal table
-- (two rows in history, no row in current)
DELETE FROM dbo.Employee WHERE EmployeeID = 1;

-- See what the data looks like
SELECT * FROM dbo.Employee;

-- Grab everything
SELECT *, ValidFrom, ValidTo FROM dbo.Employee
FOR SYSTEM_TIME ALL;

-- Select from history table directly (depends on security access)
SELECT * FROM History.Employee;


-------


-- Insert many rows into temporal table

INSERT INTO dbo.Employee
(
	Name,
	Position,
	Department,
	Address,
	AnnualSalary
)
VALUES
(
	N'Lorraine Baines',
	N'Legal Assistant',
	N'Legal Aid',
	N'1727 Bushnell Avenue, Hill Valley, California, 91030',
	2500
),
(
	N'George McFly',
	N'Legal Writer',
	N'Documentation',
	N'9303 Lyon Drive, Hill Valley, California, 91030',
	3200
),
(
	N'Biff Tannen',
	N'Custodian',
	N'Janitorial',
	N'1809 Bushnell Ave, Hill Valley, California 91030',
	1900
),
(
	N'Jennifer Parker',
	N'Paralegal',
	N'Mergers & Acquisitions',
	N'2331 Spruce Street, Hill Valley, California, 91030',
	12500
),
(
	N'Marty McFly',
	N'Desk Jockey',
	N'Not Much To Be Honest',
	N'9303 Lyon Drive, Hill Valley, California, 91030',
	3000
);

-- Current only
SELECT * FROM dbo.Employee;

-- Current and History
SELECT * FROM dbo.Employee
FOR SYSTEM_TIME ALL;







-- Delete all rows (no WHERE clause)
DELETE FROM dbo.Employee;





-- Review temporal table history with different period-style queries again

-- Current only
SELECT * FROM dbo.Employee;

-- Current and History
SELECT *, ValidFrom, ValidTo FROM dbo.Employee
FOR SYSTEM_TIME ALL;

------




-- Attempt TRUNCATE on current table (will it error?)
TRUNCATE TABLE dbo.Employee;

-- Attempt TRUNCATE on history table (will it error?)
TRUNCATE TABLE History.Employee;

-- This is for later -- might need a couple of attempts
CHECKPOINT

-- Attempt ALTER TABLE ALTER COLUMN on current table
-- (does it change in both tables?)
CHECKPOINT
GO
CHECKPOINT
GO
ALTER TABLE dbo.Employee ALTER COLUMN AnnualSalary MONEY NOT NULL;

SELECT * FROM fn_dblog(NULL,NULL)

-- Review changes in Object Explorer

CHECKPOINT;

-- Attempt DROP COLUMN on current table
-- (does this change both tables too?)
ALTER TABLE dbo.Employee DROP COLUMN AnnualSalary;

SELECT * FROM fn_dblog(NULL,NULL)


-- What's in the history?
SELECT * FROM dbo.Employee
FOR SYSTEM_TIME ALL;

-- What are the implications of these two changes?
-- Remember the Marketing Slide?
-- Can this be used for forensic auditing on its own?
-- Not even the default trace keeps a record of this

-----


-- Create in-memory temporal table
-- requires in-memory filegroup

USE [master];
GO

-- Reset demo
DROP DATABASE IF EXISTS [TemporalDemo];
GO

-- Create new database
CREATE DATABASE [TemporalDemo];
GO

USE [TemporalDemo];
GO

CREATE SCHEMA [History];
GO

USE [master]
GO
ALTER DATABASE [TemporalDemo]
	ADD FILEGROUP [InMemory]
		CONTAINS MEMORY_OPTIMIZED_DATA 
GO
ALTER DATABASE [TemporalDemo]
	ADD FILE (
		NAME = N'InMemoryFile',
		FILENAME = N'C:\SQL\Data\InMemoryFile'
		-- FILENAME = N'/var/opt/mssql/data/InMemoryFile' -- Linux
	)
TO FILEGROUP [InMemory];
GO

USE [TemporalDemo];
GO

SELECT * FROM sys.database_files;
GO

-- Create in-memory temporal table
CREATE TABLE dbo.Employee
(
	[EmployeeID] INT NOT NULL IDENTITY(1,1) PRIMARY KEY
		NONCLUSTERED HASH WITH (BUCKET_COUNT = 100),
	[Name] NVARCHAR(100) NOT NULL,
	[Position] NVARCHAR(100) NOT NULL,
	[Department] NVARCHAR(100) NOT NULL,
	[Address] NVARCHAR(1024) NOT NULL,
	[AnnualSalary] DECIMAL(10, 2) NOT NULL,
	[ValidFrom] DATETIME2(3) GENERATED ALWAYS AS ROW START,
	[ValidTo] DATETIME2(3) GENERATED ALWAYS AS ROW END,
	PERIOD FOR SYSTEM_TIME(ValidFrom, ValidTo)
)
WITH (
	MEMORY_OPTIMIZED = ON,
	DURABILITY = SCHEMA_AND_DATA,
	SYSTEM_VERSIONING = ON (
		HISTORY_TABLE = History.Employee
	)
);
GO



------


INSERT INTO dbo.Employee
(
	Name,
	Position,
	Department,
	Address,
	AnnualSalary
)
VALUES
(
	N'Lorraine Baines',
	N'Legal Assistant',
	N'Legal Aid',
	N'1727 Bushnell Avenue, Hill Valley, California, 91030',
	2500
),
(
	N'George McFly',
	N'Legal Writer',
	N'Documentation',
	N'9303 Lyon Drive, Hill Valley, California, 91030',
	3200
),
(
	N'Biff Tannen',
	N'Custodian',
	N'Janitorial',
	N'1809 Bushnell Ave, Hill Valley, California 91030',
	1900
),
(
	N'Jennifer Parker',
	N'Paralegal',
	N'Mergers & Acquisitions',
	N'2331 Spruce Street, Hill Valley, California, 91030',
	12500
),
(
	N'Marty McFly',
	N'Desk Jockey',
	N'Not Much To Be Honest',
	N'9303 Lyon Drive, Hill Valley, California, 91030',
	3000
);

-- Current only
SELECT * FROM dbo.Employee;

DELETE FROM dbo.Employee;

-- Using RSCI? Watch out for this problem:

-- A query that accesses memory optimized tables using the READ COMMITTED
-- isolation level, cannot access disk based tables when the database option
-- READ_COMMITTED_SNAPSHOT is set to ON. Provide a supported isolation level
-- for the memory optimized table using a table hint, such as WITH (SNAPSHOT).

SELECT * FROM dbo.Employee
FOR SYSTEM_TIME ALL
WITH (SNAPSHOT); -- Needed for RCSI
------




-- Periodic archival of current / historic data (temporal rolling window)

-- Books Online:

-- Removing unnecessary data from history (DELETE or TRUNCATE)
-- Removing data from current table without versioning (DELETE, TRUNCATE)
-- Partition SWITCH OUT from current table
-- Partition SWITCH IN into history table

-- If you stop versioning temporarily as a prerequisite
-- for table maintenance, Microsoft strongly recommends
-- doing this inside a transaction to keep data consistency.

BEGIN TRAN
ALTER TABLE dbo.Employee SET (SYSTEM_VERSIONING = OFF);
TRUNCATE TABLE History.Employee;
ALTER TABLE dbo.Employee SET (
	SYSTEM_VERSIONING = ON (
		HISTORY_TABLE = History.Employee
	)
);
COMMIT TRAN;
-- ROLLBACK TRAN;



-- !BUT! Transactions don't work for In-Memory tables


-- This all works in Azure SQL Database
-- Temporal tables work on all tiers (Basic, Standard, Premium)
-- In-Memory features require Premium tier

------------------------








-- Retention Policy (2017+ and Azure SQL Database)

-- Check if it retention policy is enabled
SELECT
	is_temporal_history_retention_enabled,
	name
FROM
	sys.databases
WHERE name in ('master', 'msdb', 'tempdb', 'TemporalDemo');
GO

-- You can change it with ALTER DATABASE statement.

-- ALTER DATABASE [TemporalDemo]
-- SET TEMPORAL_HISTORY_RETENTION OFF;
-- GO

-- It is also automatically set to OFF after
-- a point-in-time restore.

-- You can alter an existing table, or
-- set the retention period on table creation
ALTER TABLE dbo.Employee SET (SYSTEM_VERSIONING = OFF);
GO

ALTER TABLE dbo.Employee SET (
	SYSTEM_VERSIONING = ON (
		HISTORY_TABLE = History.Employee,
		HISTORY_RETENTION_PERIOD = 9 MONTHS
	));
GO

-- Now we run this query from Microsoft Docs to
-- check out the new temporal retention hotness
SELECT DB.is_temporal_history_retention_enabled,
	SCHEMA_NAME(T1.schema_id) AS TemporalTableSchema,
	T1.name AS TemporalTableName,
	SCHEMA_NAME(T2.schema_id) AS HistoryTableSchema,
	T2.name AS HistoryTableName,
	T1.history_retention_period,
	T1.history_retention_period_unit_desc
FROM sys.tables T1
OUTER APPLY (
	SELECT is_temporal_history_retention_enabled
	FROM sys.databases
	WHERE name = DB_NAME()
	) AS DB
LEFT JOIN sys.tables T2
	ON T1.history_table_id = T2.object_id
WHERE T1.temporal_type = 2;
GO
