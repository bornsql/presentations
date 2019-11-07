------------------------------------------
-- EXAMPLE 1: Database BackupTestEx1
------------------------------------------

USE [master];
GO

SET NOCOUNT ON;
GO

SELECT @@VERSION;
GO

-- Hey! Yes, you! Have you turned on backup
-- compression at the server level?

SELECT	name, value, value_in_use
FROM	sys.configurations
WHERE	name = N'backup compression default';
GO

EXEC sp_configure 'backup compression default', 1;
RECONFIGURE;
GO

-- Create a new database for demo purposes
DROP DATABASE IF EXISTS BackupTestEx1;
GO

CREATE DATABASE BackupTestEx1;
GO

ALTER DATABASE BackupTestEx1 SET ACCELERATED_DATABASE_RECOVERY = ON;
GO

USE BackupTestEx1;
GO

DROP TABLE IF EXISTS dbo.TableTest;
GO

CREATE TABLE TableTest
(
	Column1 UNIQUEIDENTIFIER PRIMARY KEY
);
GO

-- Insert some data
INSERT INTO dbo.TableTest
SELECT TOP 1000000 NEWID()
FROM sys.columns s1
CROSS JOIN sys.columns s2;

-- See how the data looks
SELECT COUNT(*) FROM dbo.TableTest;
GO
SELECT TOP (10) * FROM dbo.TableTest;
GO

-- Take a full backup
BACKUP DATABASE BackupTestEx1
TO DISK = '/var/opt/mssql/data/BackupTestEx1.bak';
GO

-- Take a log backup to record any changes
-- and truncate (set inactive) the VLFs
BACKUP LOG BackupTestEx1
TO DISK = '/var/opt/mssql/data/BackupTestEx1Log1.trn';
GO

-- Insert more data
INSERT INTO dbo.TableTest
SELECT TOP 1000000 NEWID()
FROM sys.columns s1
CROSS JOIN sys.columns s2;

-- Take another log backup to record changes
BACKUP LOG BackupTestEx1
TO DISK = '/var/opt/mssql/data/BackupTestEx1Log2.trn';
GO

-- Take a differential backup to record changes
BACKUP DATABASE BackupTestEx1
TO DISK = '/var/opt/mssql/data/BackupTestEx1.diff'
WITH DIFFERENTIAL;
GO

-- Insert more data
INSERT INTO dbo.TableTest
SELECT TOP 1000000 NEWID()
FROM sys.columns s1
CROSS JOIN sys.columns s2;

-- One more log backup to record these changes
BACKUP LOG BackupTestEx1
TO DISK = '/var/opt/mssql/data/BackupTestEx1Log3.trn';
GO

-- Similate a disaster recovery scenario
USE [master];
GO

DROP DATABASE IF EXISTS BackupTestEx1;
GO

-- Restore full backup, with recovery 
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1.bak';
GO

-- See how the data looks
USE BackupTestEx1;
GO

SELECT COUNT (*) FROM dbo.TableTest;
GO

USE [master];
GO

DROP DATABASE IF EXISTS BackupTestEx1;
GO

-- Restore full backup, with no recovery 
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1.bak'
WITH NORECOVERY;
GO

-- Restore most recent transaction log file
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log3.trn'
WITH RECOVERY;
GO

-- Transaction log backups are incremental, so all of them are required
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log1.trn'
WITH NORECOVERY;
GO
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log2.trn'
WITH NORECOVERY;
GO
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log3.trn'
WITH NORECOVERY;
GO

-- Roll forward committed transactions and roll back uncommitted transactions
RESTORE DATABASE BackupTestEx1
WITH RECOVERY;
GO

-- See how the data looks
USE BackupTestEx1;
GO

SELECT COUNT (*) FROM dbo.TableTest;
GO

USE [master];
GO

DROP DATABASE IF EXISTS BackupTestEx1;
GO

-- Restore full backup, with no recovery 
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1.bak'
WITH NORECOVERY;
GO

-- Restore differential backup, with no recovery 
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1.diff'
WITH NORECOVERY;
GO

-- Differential backups are not incremental...
-- so this will fail
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log1.trn'
WITH NORECOVERY;
GO
-- and this will fail too
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log2.trn'
WITH NORECOVERY;
GO
-- ... but this transaction log backup will work
-- because of the LSN
RESTORE DATABASE BackupTestEx1
FROM DISK = '/var/opt/mssql/data/BackupTestEx1Log3.trn'
WITH NORECOVERY;
GO

-- Roll forward committed transactions and roll back uncommitted transactions
RESTORE DATABASE BackupTestEx1
WITH RECOVERY;
GO

-- See how the data looks
USE BackupTestEx1;
GO

SELECT COUNT (*) FROM dbo.TableTest;
GO
