# Module 3 - Logging and Recovery

## Multiple Log Files for one database

```sql
USE Master;
GO
IF db_id('TWO_LOGS') IS NOT NULL
    DROP DATABASE TWO_LOGS;
GO
```

Create a database with 2 log files

```sql 
CREATE DATABASE TWO_LOGS 
  ON PRIMARY
  (NAME = Data , 
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data\TWO_LOGS.mdf' 
        , SIZE = 10  MB)
   LOG ON
  (NAME = TWO_LOGS1,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data\TWO_LOGS1.ldf' 
        , SIZE = 5 MB
        , MAXSIZE = 2 GB),
  (NAME = TWO_LOGS2, 
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data\DATATWO_LOGS2.ldf' 
        , SIZE = 5 MB);
GO
```

Notice multiple VLFs for each file

```sql
USE TWO_LOGS;
GO

DBCC LOGINFO;
GO
```

Perform some work to be logged

```sql
SELECT * INTO Orders
    FROM AdventureWorks2012.Sales.SalesOrderDetail;
GO
```

DBCC LOGINFO returns VLFs Ordered by FileId, then FSeqNo

```sql
DBCC LOGINFO;
```

Before running this next part, be sure to run the script to create a table to store the results of DBCC LOGINFO

```sql
USE master;
GO
IF object_id('sp_LOGINFO') IS NOT NULL
	DROP TABLE sp_loginfo;
GO
CREATE TABLE sp_LOGINFO 
(RecoveryUnitId int,
 FileId tinyint,
 FileSize bigint, 
 StartOffset bigint,
 FSeqNo int,
 Status tinyint,
 Parity tinyint,
 CreateLSN numeric(25,0) );
GO
```

```sql
TRUNCATE TABLE sp_LOGINFO;
INSERT INTO sp_LOGINFO
   EXEC ('DBCC LOGINFO');
GO
```

Examine the VLFs in usage (FSeqNo) order


Unused VLFs have a Status of 0, so the CASE forces those to the end

```sql
SELECT * FROM sp_LOGINFO
ORDER BY CASE FSeqNo WHEN 0 THEN 9999999 ELSE FSeqNo END;
GO
```

## DBCC LOGINFO

```sql
USE Master
DBCC LOGINFO;
GO
```

```sql
USE pubs;
DBCC LOGINFO;
GO
```

```sql
IF db_id('newdb') IS NOT NULL
    DROP DATABASE newdb;
GO
CREATE DATABASE newdb;
GO
```

```sql
USE newdb;
DBCC LOGINFO;
GO
```

```sql
USE AdventureWorks2012;
DBCC LOGINFO;
GO
```

### Log Truncation
First, grow the log, after backing it up

```sql
ALTER DATABASE newdb SET RECOVERY FULL;
GO 
BACKUP DATABASE newdb
    TO DISK = 'C:\BACKUPS\newdb.bak' WITH INIT;
GO
```

```sql
USE newdb;
DBCC LOGINFO;
```

Perform transactions in the db until most VLFs have status = 2

```sql
SELECT * INTO Orders FROM AdventureWorks2012.Sales.SalesOrderDetail;
DROP TABLE Orders;
GO 5
```

```sql
DBCC LOGINFO;
```

Notice that backing up the database does not clear the log

```sql
BACKUP DATABASE newdb
    TO DISK = 'C:\BACKUPS\newdb.bak' WITH INIT;
GO
```

```sql
DBCC LOGINFO;
```

However, backing up the transaction log does clear the log

```sql
BACKUP LOG newdb
    TO DISK = 'C:\BACKUPS\newdb_log.bak' WITH INIT;
GO
```

```sql
DBCC LOGINFO;
```

To truncate without backing up, change the recovery model to SIMPLE

```sql
SELECT * INTO Orders FROM AdventureWorks2012.Sales.SalesOrderDetail;
DROP TABLE Orders;
GO 5
```

```sql
DBCC LOGINFO;
```

```sql
ALTER DATABASE newdb SET RECOVERY SIMPLE;
GO 
```

```sql
DBCC LOGINFO;
```

Truncation of the log does not SHRINK the file!

## Shrinking the log

We'll start out similarly to the first demo, forcing the log for the credit database to grow

```sql
USE CREDIT
GO
ALTER DATABASE credit SET RECOVERY FULL;
GO
BACKUP DATABASE credit 
    TO DISK = 'C:\BACKUPS\credit.bak' WITH INIT;
GO
DBCC LOGINFO;
```

Perform transactions in the db to grow the log much larger

```sql
SELECT * INTO newcharge FROM charge
DROP TABLE newcharge;
GO 15
DBCC LOGINFO;
```

Look at size of log

```sql
SELECT name, size as pages, size*8/1000 as MB 
   FROM sys.database_files;
GO
```

Shrink the log

```sql
ALTER DATABASE credit SET RECOVERY SIMPLE;
DBCC SHRINKFILE(2, 5);
GO
DBCC LOGINFO;
SELECT name, size as pages, size*8/1000 as MB 
   FROM sys.database_files;
GO
```

How small can we shrink it?

```sql
ALTER DATABASE credit SET RECOVERY SIMPLE;
GO
DBCC SHRINKFILE(2, 1);
GO
DBCC LOGINFO;
SELECT name, size as pages, size*8/1000 as MB 
   FROM sys.database_files;
GO
```

What happens when we try to grow the log again?

```sql
SELECT * INTO newcharge FROM charge
DROP TABLE newcharge;
GO 
DBCC LOGINFO;
```

Will it grow that much every time?

```sql
SELECT * INTO newcharge FROM charge
DROP TABLE newcharge;
GO 2
DBCC LOGINFO;
```

Why are most of the VLFs marked as status 0 and why did the log not grow much more?

### Check for auto-truncate mode

If last_log_backup_lsn is NULL, log is in auto-truncate mode

```sql
SELECT db_name(database_id) AS 'database',last_log_backup_lsn 
FROM master.sys.database_recovery_status
WHERE database_id = db_id('credit');
GO
```

```sql
ALTER DATABASE credit SET RECOVERY FULL;
GO
```

```sql
BACKUP DATABASE credit 
    TO DISK = 'C:\BACKUPS\credit.bak' WITH INIT;
GO
```

```sql
SELECT db_name(database_id) AS 'database',last_log_backup_lsn 
FROM master.sys.database_recovery_status
WHERE database_id = db_id('credit');
GO
```

## Create a table to hold the results of DBCC LOGINFO

```sql
USE master;
GO
IF object_id('sp_LOGINFO') IS NOT NULL
	DROP TABLE sp_loginfo;
GO
CREATE TABLE sp_LOGINFO 
(RecoveryUnitId int,
 FileId tinyint,
 FileSize bigint, 
 StartOffset bigint,
 FSeqNo int,
 Status tinyint,
 Parity tinyint,
 CreateLSN numeric(25,0) );
GO
```

Insert contents from DBCC Loginfo to table.

```sql
TRUNCATE TABLE sp_LOGINFO;
INSERT INTO sp_LOGINFO
   EXEC ('DBCC LOGINFO')
```

Examine the log table for contents
```sql
SELECT * FROM sp_LOGINFO
```
