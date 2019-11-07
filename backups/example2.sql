------------------------------------------
-- EXAMPLE 2: Database BackupTestEx2
------------------------------------------

-- Copy only backup with transaction log backups
-- Delete the old backup files from the drive if they exist

USE [master];
GO

-- Create a new database for demo purposes
DROP DATABASE IF EXISTS BackupTestEx2;
GO

CREATE DATABASE BackupTestEx2;
GO

USE BackupTestEx2;
GO

DROP TABLE IF EXISTS dbo.TableTest;
GO

CREATE TABLE TableTest
(
	Column1 INT PRIMARY KEY IDENTITY(1, 1)
);
GO

-- Insert some data
INSERT INTO dbo.TableTest
DEFAULT VALUES;
GO 10

-- See how it looks
SELECT	*
FROM	dbo.TableTest;
GO

-- Everyone needs a good full backup to seed the backup chain
BACKUP DATABASE BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2.bak';
GO

-- Let's do a copy-only backup now as well
BACKUP DATABASE BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2CopyOnly.bak'
WITH COPY_ONLY;
GO

-- Insert some data
INSERT INTO dbo.TableTest
DEFAULT VALUES;
GO 10

-- Let's do a copy-only log backup as well
-- Does not truncate the log
BACKUP LOG BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2CopyOnly.trn'
WITH COPY_ONLY;
GO

-- Does truncate the log
BACKUP LOG BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2Log1.trn';
GO

-- Let's do another full backup for fun
BACKUP DATABASE BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2Full2.bak';
GO

-- Insert some more data
INSERT INTO dbo.TableTest
DEFAULT VALUES;
GO 10


BACKUP LOG BackupTestEx2
TO DISK = '/var/opt/mssql/data/BackupTestEx2Log2.trn';
GO

-- Prove that Copy-Only Backups don't
-- affect the backup chain
USE [master];
GO

DROP DATABASE IF EXISTS BackupTestEx2;
GO

-- Restore copy-only backup, with no recovery 
RESTORE DATABASE BackupTestEx2
FROM DISK = '/var/opt/mssql/data/BackupTestEx2CopyOnly.bak'
WITH NORECOVERY;
GO
RESTORE LOG BackupTestEx2
FROM DISK = '/var/opt/mssql/data/BackupTestEx2Log1.trn'
WITH NORECOVERY;
GO
RESTORE LOG BackupTestEx2
FROM DISK = '/var/opt/mssql/data/BackupTestEx2Log2.trn'
WITH NORECOVERY;
GO
RESTORE DATABASE BackupTestEx2
WITH RECOVERY;
GO

-- See that all the data is there
USE BackupTestEx2;
GO

SELECT	*
FROM	dbo.TableTest;
GO

-- That works even with the full backup that
-- was taken in between, because transaction
-- logs are incremental

-- Let's try with the second full backup
USE [master];
GO

DROP DATABASE IF EXISTS BackupTestEx2;
GO


-- Restore full backup, with log
RESTORE DATABASE BackupTestEx2
FROM DISK = '/var/opt/mssql/data/BackupTestEx2Full2.bak'
WITH NORECOVERY;
GO
RESTORE LOG BackupTestEx2
FROM DISK = '/var/opt/mssql/data/BackupTestEx2Log2.trn';
GO

-- See that all the data is there
USE BackupTestEx2;
GO

SELECT	*
FROM	dbo.TableTest;
GO

-- Always run DBCC CHECKDB after a restore
DBCC CHECKDB WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO
