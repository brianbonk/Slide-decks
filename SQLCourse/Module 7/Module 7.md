# Concurrency

## Transaction counts

Observe transaction behavior  with @@trancount

```sql
SET IMPLICIT_TRANSACTIONS OFF;
```

```sql
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
```

```sql
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
```

```sql
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
```

```sql
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
BEGIN TRAN
SELECT @@TRANCOUNT;
ROLLBACK TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
COMMIT TRAN
SELECT @@TRANCOUNT;
```

## Create a database to test Snapshot Isolation

The script creates the database and a table with 3 rows

It contains the query to check the Snapshot isolation settings for the database 

Enable or disable the two snapshot database options

Drop the database if it already exists

```sql
IF db_id('testsi') IS NOT NULL
    DROP DATABASE testsi;
GO
```

```sql
CREATE DATABASE testsi;
GO
```

```sql
USE testsi;
GO
```

```sql
SELECT name, snapshot_isolation_state_desc, 
		is_read_committed_snapshot_on 
FROM     sys.databases 
WHERE   name= 'testsi';
GO
```

```sql
CREATE TABLE t1
(col1 int primary key, col2 int);
GO
```

```sql
INSERT INTO t1 SELECT 1,10;
INSERT INTO t1 SELECT 2,20;
INSERT INTO t1 SELECT 3,30;
```

```sql
ALTER DATABASE testsi SET allow_snapshot_isolation ON;

-- ALTER DATABASE testsi SET allow_snapshot_isolation OFF;
```

## UPDATE Statement and examine DMV

```sql
USE testsi;
```

Run this update transaction after starting the SELECT transaction to see that the SELECT will continue to read old data

```sql
BEGIN TRAN
 UPDATE T1 SET col2 = 200
	WHERE col1 = 1;
COMMIT TRAN
```

Repeat the transaction above, and then rerun the SELECT, to see the length of the version chain growing

```sql
SELECT transaction_sequence_num, commit_sequence_num, 
	is_snapshot, session_id,first_snapshot_sequence_num,
	max_version_chain_traversed, elapsed_time_seconds
FROM  sys.dm_tran_active_snapshot_database_transactions;
```

Inspect the version store, if desired

```sql
SELECT *
 FROM sys.dm_tran_version_store;
```

## Locks, lock hints and timeouts

```sql
USE PUBS;
GO
```

Compare the difference between different ways of controlling locking

```sql
SELECT * FROM titles
WHERE type = 'popular_comp';
GO

-- Lock one row in the titles table with a KEY lock
-- Open additional query windows for the other connections     
--and remove the comment markers 
BEGIN TRAN
UPDATE titles
SET price = price * 0.2
WHERE title_id = 'PC1035';

-- Locking info
SELECT resource_type, resource_associated_entity_id, 
    request_status, request_mode,request_session_id, 
    resource_description, resource_database_id 
    FROM sys.dm_tran_locks
	WHERE resource_type <> 'DATABASE';

--    -- Connection 2
--    USE pubs
--    SELECT * FROM titles
--    WHERE type = 'popular_comp';


-- 
-- -- Connection 3
-- USE pubs
-- SELECT * FROM titles WITH (NOLOCK)
-- WHERE type = 'popular_comp';


-- 
-- -- Connection 4
-- USE pubs
-- SELECT * FROM titles WITH (READPAST)
-- WHERE type = 'popular_comp';

-- 
-- -- Connection 5
-- SET LOCK_TIMEOUT 5000
-- GO
-- USE pubs
-- SELECT * FROM titles 
-- WHERE type = 'popular_comp';

-- -- Connection 6
-- SET LOCK_TIMEOUT 5000;
-- USE pubs;
-- GO
-- 
--  -- This transaction should time out when trying 
--  --  to update titles

 --  -- First, verify which city the UTAH authors live in
 --SELECT * FROM authors
 --WHERE state = 'UT';

-- BEGIN TRAN

-- UPDATE AUTHORS 
-- SET city = 'Provo'
-- WHERE state = 'UT';
-- 
-- UPDATE titles
-- SET advance = 30000
-- WHERE title_id = 'PC1035';
-- COMMIT TRAN
-- 
-- -- What happens to the table that was updated 
-- --    when the transaction times out?
-- SELECT * FROM authors
-- WHERE state = 'UT';
-- 
-- 

-- Rollback the very first transaction in the first query window
ROLLBACK TRAN
```

## Repeatable Read

Observe the difference between READ COMMITTED, pessimistic concurrency and REPEATABLE READ

```sql
USE PUBS;
GO
```

```sql
-- First uncomment the first SET statement to see 
-- that the second connection can update the data
-- In READ COMMITTED level, the SHARE locks that 
-- the first transaction acquires will be released
-- before the query in the second window runs

-- SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- After committing the transaction, recomment the first SET, and uncomment the second SET below.
--   Rerun the transaction to see that in REPEATABLE READ level, the SHARE locks will be held, so the 
--     second connection will NOT be able to update the data

-- SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

BEGIN TRAN

SELECT avg(price) FROM titles
WHERE type = 'business';

-- -- Now run these statements in another query window
-- USE PUBS
-- UPDATE titles
-- SET price = price * 1.1
-- WHERE title_id = 'bu1032';

SELECT avg(price) FROM titles
WHERE type = 'business';

COMMIT TRAN;
```

## Serializable

Compare REPEATABLE READ and SERIALIZABLE isolation level, pessimistic concurrency

```sql
USE PUBS;

-- First uncomment the first SET statement to see that the --  second connection can insert a new row
--  In READ COMMITTED level, the SHARE locks that the first
--   transaction acquires will be released
--     before the query in the second window runs

-- SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;


BEGIN TRAN

SELECT * FROM titles
WHERE title_id like 'BU%';
 
-- Now run these statements in another query window, change the title_id the second time
-- USE PUBS;
-- INSERT INTO titles VALUES ('BU8888', 'SQL Server 2008 Internals', 'business', '0877', 59.95, 6000.00, 12, 3333, 'Everything you ever wanted to know about SQL Server 2008', '2008.12.25');


SELECT * FROM titles
WHERE title_id like 'BU%';

COMMIT TRAN

-- After committing the transaction, recomment the first SET,
--   and uncomment the second SET below.
--   Try to run the following INSERT transaction;
--   key-range locks will be held, so the INSERT will block
--     second connection will NOT be able to insert new data


-- SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;


BEGIN TRAN

SELECT * FROM titles
WHERE title_id like 'BU%';
 
-- -- Now run these statements in another query window, change the title_id the second time
-- USE PUBS
-- INSERT INTO titles VALUES ('BU9999', 'SQL Server 2012 Internals', 'business', '0877', 59.99, 8000.00, 15, 4444, 'Everything you ever wanted to know about SQL Server 2012', '2012.12.25');


SELECT * FROM titles
WHERE title_id like 'BU%';

COMMIT TRAN
```

## Multigranular locks with and without and index

Create a copy of the titles table with  no indexes

```sql
USE PUBS;
SELECT * INTO newtitles
FROM titles;
GO
```

```sql
BEGIN TRAN
UPDATE newtitles
 SET price = price * 0.9
 WHERE title_id = 'bu1032';

-- Notice the RID (row) locks when accessing the table with no clustered index

SELECT resource_type, resource_database_id, 
    resource_description, resource_associated_entity_id, 
    request_mode, request_status, request_session_id
FROM sys.dm_tran_locks
WHERE resource_type <> 'DATABASE';
 

COMMIT TRAN
```

```sql
BEGIN TRAN
UPDATE titles
 SET price = price * 0.9
 WHERE title_id = 'bu1032';

-- Notice the KEY locks when accessing the table 
--    with a clustered index; there are exactly as many
-- KEY locks as there were RID locks in the previous 
--   transaction.  KEY locks are the same thing
-- as row locks, and are only acquired when locking rows 
--  in an index. In this case, the data
-- row are keys in the clustered index. 
-- You will NEVER see RID locks when the table 
--   has a clustered index. 


SELECT resource_type, resource_database_id, 
    resource_description, resource_associated_entity_id, 
    request_mode, request_status, request_session_id
FROM sys.dm_tran_locks 
WHERE resource_type <> 'DATABASE';

COMMIT TRAN
```

## Range locks

```sql
USE pubs;
GO
IF OBJECTPROPERTY (object_id('NewTitles'), 
                       'IsUserTable') = 1	
    DROP TABLE NewTitles; 
GO  
SELECT * INTO NewTitles 
FROM Titles;
GO
CREATE UNIQUE CLUSTERED INDEX NewTitles_index ON NewTitles(title_ID);
GO
```

Verify how many rows are in the range

```sql
SELECT * FROM  NewTitles 
WHERE title_id like 'MC%';


SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

```sql
BEGIN TRAN
   
SELECT * FROM  NewTitles 
WHERE title_id like 'MC%';

-- After running SELECT transaction, uncomment the BEGIN TRAN and the
-- UPDATE, and run it 
--BEGIN TRAN
--UPDATE  NewTitles 
--SET price = price * 1.1
--WHERE title_id like 'MC%';


SELECT resource_type, resource_database_id, 
    resource_description, resource_associated_entity_id, request_mode, 
    request_status, request_session_id
FROM sys.dm_tran_locks 
WHERE resource_type <> 'DATABASE';



SELECT count(*) FROM sys.dm_tran_locks 
WHERE request_mode like 'Range%';

ROLLBACK TRAN
```

## Playing with snapshot databases

SQL Server has the ability to make snapshots of an entire database. This snapshot can be used to query data without interfeering with the original data.

It can also be used to make backups and retores - but don't do that in production :)

```sql
USE master;
GO
```

Get the SQL Server data path

```sql
DECLARE @data_path nvarchar(256);
SET @data_path = (SELECT SUBSTRING(physical_name, 1, CHARINDEX(N'master.mdf', LOWER(physical_name)) - 1)
                  FROM master.sys.master_files
                  WHERE database_id = 1 AND file_id = 1);

-- execute the CREATE DATABASE statement 
EXECUTE (
'CREATE DATABASE credit_snapshot  ON
    ( NAME = Credit_Data, FILENAME = '''+ @data_path + 'Credit_Data.sdf''),
    ( NAME = CreditTables, FILENAME = '''+ @data_path + 'CreditTables.sdf''),
    ( NAME = CreditIndexes, FILENAME = '''+ @data_path + 'CreditIndexes.sdf'') 
AS SNAPSHOT OF credit');
GO
```

Inspect the avg charge amount, then update it

```sql
USE CREDIT;
GO
SELECT avg(charge_amt) FROM charge;
GO
```

```sql
UPDATE charge SET charge_amt = charge_amt * 0.75;
GO
```

```sql
SELECT avg(charge_amt) FROM charge;
GO
```

In the snapshot database, note that the average is the original amount

```sql
USE credit_snapshot;
GO
SELECT avg(charge_amt) FROM charge;
GO
```

```sql
USE master;
GO
RESTORE DATABASE credit FROM DATABASE_snapshot = 'credit_snapshot';
GO
DROP DATABASE credit_snapshot
GO
```

## Helper queries - to use when you need them

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.

Get additional information about blocked processes

```sql
SELECT 
    t1.resource_type,
    'database'=db_name(resource_database_id),
    'blk object' = t1.resource_associated_entity_id,
    t1.request_mode,
    t1.request_session_id,
    t2.blocking_session_id,
	 t2.wait_duration_ms,

    (SELECT SUBSTRING(text, t3.statement_start_offset/2 + 1,
 		(CASE WHEN t3.statement_end_offset = -1 
 			THEN LEN(CONVERT(nvarchar(max),text)) * 2 
       			ELSE t3.statement_end_offset 
 			END - t3.statement_start_offset)/2)
	 FROM sys.dm_exec_sql_text(sql_handle)) AS query_text, t2.resource_description
FROM 
    	sys.dm_tran_locks as t1 
    	  JOIN sys.dm_os_waiting_tasks as t2
    	     ON t1.lock_owner_address = t2.resource_address 
          JOIN sys.dm_exec_requests as t3
			 ON t1.request_request_id = t3.request_id AND 
              t2.session_id = t3.session_id;
```

Who has open transactions on the server 


```sql
-- Details returned:
-- 	session ID 
--	transaction begin time 
--	how many log records have been generated by the transaction 
--	how much log space has been taken up by those log records 
--	how much log space has been reserved in case the transaction rolls back 
--	the last T-SQL that was executed in the context of the transaction 
--	the last query plan that was executed (only for currently executing plans) 

SELECT s_tst.[session_id],
   s_es.[login_name] AS [Login Name],
   S_tdt.[database_transaction_begin_time] AS [Begin Time],
   s_tdt.[database_transaction_log_record_count] AS [Log Records],
   s_tdt.[database_transaction_log_bytes_used] AS [Log Bytes],
   s_tdt.[database_transaction_log_bytes_reserved] AS [Log Reserved],
   s_est.[text] AS [Last T-SQL Text],
   s_eqp.[query_plan] AS [Last Query Plan]
FROM sys.dm_tran_database_transactions s_tdt
   JOIN sys.dm_tran_session_transactions s_tst
      ON s_tst.[transaction_id] = s_tdt.[transaction_id]
   JOIN sys.[dm_exec_sessions] s_es
      ON s_es.[session_id] = s_tst.[session_id]
   JOIN sys.dm_exec_connections s_ec
      ON s_ec.[session_id] = s_tst.[session_id]
   LEFT OUTER JOIN sys.dm_exec_requests s_er
      ON s_er.[session_id] = s_tst.[session_id]
   CROSS APPLY sys.dm_exec_sql_text (s_ec.[most_recent_sql_handle]) AS s_est
   OUTER APPLY sys.dm_exec_query_plan (s_er.[plan_handle]) AS s_eqp
ORDER BY [Begin Time] ASC;
GO
```


DMVs for troubleshooting locking and connections

```sql
SELECT resource_type, resource_associated_entity_id, 
    request_status, request_mode,request_session_id, 
    resource_description  
    FROM sys.dm_tran_locks
-- WHERE resource_type <> 'DATABASE';
```

This query will display lock information. The value for <dbid> should be replaced with the database_id from sys.databases.

```sql
SELECT resource_type, resource_associated_entity_id, 
    request_status, request_mode,request_session_id, 
    resource_description, resource_database_id 
    FROM sys.dm_tran_locks
    WHERE resource_database_id = <dbid>;
```

This query returns object information using resource_associated_entity_id from the previous query.

```sql
SELECT object_name(object_id), * 
    FROM pubs.sys.partitions 
    WHERE hobt_id=72057594038452224;
```

This query will show blocking information.

```sql
SELECT resource_type, resource_database_id, 
    resource_associated_entity_id, request_mode, 
    request_session_id, blocking_session_id 
    FROM sys.dm_tran_locks as t1 JOIN sys.dm_os_waiting_tasks as t2
     ON t1.lock_owner_address = t2.resource_address;
```

Similar to sysprocesses, without wait type info

```sql
SELECT * FROM sys.dm_exec_connections;
```

Shows security and session settings
exec_connections to exec_sessions is one-to-one

```sql
SELECT * FROM sys.dm_exec_sessions;
```

Wait type info is in another DMV

```sql
SELECT * FROM sys.dm_os_waiting_tasks;
```