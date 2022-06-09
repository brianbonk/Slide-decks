# Recompilations

## Stored Procedures and Recompile

### SETUP install sp_cacheobjects

Create a view to show most of the same information as SQL Server 2000's syscacheobjects

```sql
USE master
GO
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'sp_cacheobjects')
	DROP VIEW sp_cacheobjects;
GO
-- You may want to add other filters in the WHERE clause to remove system operations 
--    on your own SQL Server
CREATE VIEW sp_cacheobjects (bucketid, cacheobjtype, objtype, objid, dbid, dbidexec, uid, refcounts, 

                        usecounts, pagesused, setopts, langid, dateformat, status, lasttime, maxexectime, avgexectime, lastreads,

                        lastwrites, sqlbytes, sql, plan_handle) 
AS

            SELECT            pvt.bucketid, CONVERT(nvarchar(18), pvt.cacheobjtype) as cacheobjtype, pvt.objtype, 

                                    CONVERT(int, pvt.objectid)as object_id, CONVERT(smallint, pvt.dbid) as dbid,

                                    CONVERT(smallint, pvt.dbid_execute) as execute_dbid, CONVERT(smallint, pvt.user_id) as user_id,

                                    pvt.refcounts, pvt.usecounts, pvt.size_in_bytes / 8192 as size_in_bytes,

                                    CONVERT(int, pvt.set_options) as setopts, CONVERT(smallint, pvt.language_id) as langid,

                                    CONVERT(smallint, pvt.date_format) as date_format, CONVERT(int, pvt.status) as status,

                                    CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), 

                                    CONVERT(int, LEN(CONVERT(nvarchar(max), fgs.text)) * 2), CONVERT(nvarchar(3900), fgs.text), plan_handle

            FROM (SELECT ecp.*, epa.attribute, epa.value

                        FROM sys.dm_exec_cached_plans ecp OUTER APPLY sys.dm_exec_plan_attributes(ecp.plan_handle) epa) as ecpa

            PIVOT (MAX(ecpa.value) for ecpa.attribute IN ("set_options", "objectid", "dbid", "dbid_execute", "user_id", "language_id", "date_format", "status")) as pvt

            OUTER APPLY sys.dm_exec_sql_text(pvt.plan_handle) fgs
    WHERE cacheobjtype like 'Compiled%'
    AND pvt.dbid > 4 and pvt.dbid < 32767
    AND text not like '%filetable%'
    AND text not like '%fulltext%';
```



Take the query previous and make a stored procedure

```sql
--EXEC sp_executesql 
--		  EXEC sp_executesql 
--          N'SELECT * FROM dbo.newsales WHERE SalesOrderID < @num',
--          N'@num int',
--          @num = 43700;
GO
```
 
```sql
USE AdventureWorks2012;
GO
```

```sql
IF EXISTS (SELECT 1 FROM sys.procedures
			  WHERE name = 'get_sales_range')
  DROP PROC get_sales_range;
 
GO
```

```sql
CREATE PROC get_sales_range
   @num int
AS
    SELECT * FROM dbo.newsales 
    WHERE SalesOrderID < @num
GO
```

```sql
DBCC FREEPROCCACHE
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SET statistics io ON
GO
```

```sql
EXEC get_sales_range 43700;
GO
```

```sql
SELECT * FROM sp_cacheobjects;;
GO
```

Note the same plan is used which is inappropriate for the new parameter. A small value should use the index but the larger value should not.

This is a behavior that is referred to as 'parameter sniffing'

SQL Server 'sniffs' the parameter the first time the procedure is executed, generates a plan from the original parameter, and continues to use that plan even though the parameter is different

```sql
EXEC get_sales_range 55555;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

When a procedure is executed WITH RECOMPILE, the plan is not saved

```sql
SET statistics io ON
GO
```

```sql
EXEC  get_sales_range 55555 WITH RECOMPILE;
GO
```
 
```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
ALTER PROC get_sales_range
   @num int
   WITH RECOMPILE
AS
    SELECT * FROM dbo.newsales 
    WHERE SalesOrderID < @num
GO
```

When a procedure is created WITH RECOMPILE, a plan is never saved

```sql
EXEC get_sales_range 43700;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
EXEC get_sales_range 66666;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SET statistics io OFF
GO
```

So is parameter sniffing a good thing or a bad thing?

## XQUERY

```sql
USE CREDIT
GO
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'LookForPhysicalOps')
    DROP PROCEDURE LookForPhysicalOps
GO
```

```sql
CREATE PROCEDURE LookForPhysicalOps (@op VARCHAR(30))
AS
SELECT sql.text, qs.EXECUTION_COUNT, qs.*, p.* 
    FROM sys.dm_exec_query_stats AS qs 
      CROSS APPLY sys.dm_exec_sql_text(sql_handle) sql
       CROSS APPLY sys.dm_exec_query_plan(plan_handle) p
WHERE query_plan.exist('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";
/ShowPlanXML/BatchSequence/Batch/Statements//RelOp/@PhysicalOp[. = sql:variable("@op")]  ') = 1
GO
```

Run some queries to generate different types of plan operators

```sql
USE credit
GO
```

Create the newcharge and newmem tables if they don't exist

```sql
IF object_id('newcharge') IS NOT NULL
    DROP TABLE newcharge;
GO
```

```sql
IF object_id('newmem') IS NOT NULL
    DROP TABLE newmem;
GO
```

```sql
SELECT * INTO newcharge FROM charge;
SELECT * INTO newmem FROM member;
```

```sql
SELECT *
FROM newcharge JOIN newmem
 ON newcharge.member_no = newmem.member_no;
GO
```

```sql
SELECT *
FROM newcharge JOIN newmem
 ON newcharge.member_no = newmem.member_no
WHERE charge_no < 50;
GO
```

```sql
EXECUTE LookForPhysicalOps 'Clustered Index Scan';
EXECUTE LookForPhysicalOps 'Hash Match';
EXECUTE LookForPhysicalOps 'Table Scan';
```

You may also search for plans containing certain values.

This example looks for plans containing a row estimate of more than 1000

```sql
SELECT 
    p.*, 
    q.*,
    cp.plan_handle
FROM 
    sys.dm_exec_cached_plans cp
    CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) p
    CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) as q
WHERE 
    cp.cacheobjtype = 'Compiled Plan' and
    p.query_plan.value('declare namespace p="http://schemas.microsoft.com/sqlserver/2004/07/showplan";
        max(//p:RelOp/@EstimateRows)', 'float') > 1000;
```

Find what queries use a specific index:

```sql
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
DECLARE @IndexName AS NVARCHAR(128) = 'charge2_charge_amt'; 
-- Make sure the name passed is appropriately quoted 
IF (LEFT(@IndexName, 1) <> '[' AND RIGHT(@IndexName, 1) <> ']') SET @IndexName = QUOTENAME(@IndexName); 
--Handle the case where the left or right was quoted manually but not the opposite side 
IF LEFT(@IndexName, 1) <> '[' SET @IndexName = '['+@IndexName; 
IF RIGHT(@IndexName, 1) <> ']' SET @IndexName = @IndexName + ']'; 

----------------------------------------------------------------
-- Dig into the plan cache and find all plans using this index 
----------------------------------------------------------------

;WITH XMLNAMESPACES 
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')    
SELECT 
stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Text, 
obj.value('(@Database)[1]', 'varchar(128)') AS DatabaseName, 
obj.value('(@Schema)[1]', 'varchar(128)') AS SchemaName, 
obj.value('(@Table)[1]', 'varchar(128)') AS TableName, 
obj.value('(@Index)[1]', 'varchar(128)') AS IndexName, 
obj.value('(@IndexKind)[1]', 'varchar(128)') AS IndexKind, 
cp.plan_handle, 
query_plan 
FROM sys.dm_exec_cached_plans AS cp 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
CROSS APPLY stmt.nodes('.//IndexScan/Object[@Index=sql:variable("@IndexName")]') AS idx(obj) 
OPTION(MAXDOP 1, RECOMPILE); 
GO
```

Clear the cache

```sql
DBCC FREEPROCCACHE
```

Look at the Estimatet Executionplan thorugh SSMS, do so without executing the actual below query.

```sql
SELECT * FROM charge2
WHERE charge_amt < 2;
GO
```

Run XQUERY query above; note that just getting an estimated plan will not cache the plan

Now EXECUTE the query

```sql
SELECT * FROM charge2
WHERE charge_amt < 2;
GO
```

Run XQUERY query above to see plan returned

## Autoparameterized queries
...or prepared Queries

Can be either autoparameterized or user parameterized

This script will look at autoparameterized queries, which can use either SIMPLE parameterization or FORCED parameterization SIMPLE is the default

```sql
SELECT name, is_parameterization_forced FROM sys.databases
WHERE name = 'AdventureWorks2012';
```

```sql
USE AdventureWorks2012;
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55555; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 44444;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 66666;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

Previous query was safe and simple

Following query is safe but not simple, it is not parameterized under SIMPLE

```sql
SELECT * FROM dbo.newsales s JOIN Sales.SalesOrderDetail d
    ON s.SalesOrderID = d.SalesOrderID
WHERE s.SalesOrderID = 55555;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales s JOIN Sales.SalesOrderDetail d
    ON s.SalesOrderID = d.SalesOrderID
WHERE s.SalesOrderID = 44444;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Set database to FORCED parameterization; cache is cleared for this db

```sql
ALTER DATABASE AdventureWorks2012 SET parameterization FORCED;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Previous example is now parameterized

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM dbo.newsales s JOIN Sales.SalesOrderDetail d
    ON s.SalesOrderID = d.SalesOrderID
WHERE s.SalesOrderID = 55555;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales s JOIN Sales.SalesOrderDetail d
    ON s.SalesOrderID = d.SalesOrderID
WHERE s.SalesOrderID = 44444;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

With FORCED parameterization, even UNSAFE plans are parameterized!


```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID < 43700;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SET STATISTICS IO ON;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID < 43700;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID < 77777;
GO
```

How many I/O's for a table scan?

```sql
SELECT * FROM dbo.newsales;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
ALTER DATABASE AdventureWorks2012 SET parameterization SIMPLE;
GO
```

Different data types create a new plan:

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 555; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55555; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

What if we start with the INT?

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55555; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 555; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55; 
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

## Forced parameterization

Simulate SQLPrepare/SQLExec  with sp_executesql

```sql
USE AdventureWorks2012;
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

Notice the performance of these two queries if the optimizer is allowed to choose the plan

```sql
SET statistics io ON
GO
```

```sql
SELECT * FROM dbo.newsales 
WHERE SalesOrderID < 43700;
GO
```

```sql
SELECT * FROM dbo.newsales 
WHERE SalesOrderID < 77777;
GO
```

Run the same query as previously, using explicit parameterization

```sql
EXEC sp_executesql 
          N'SELECT * FROM dbo.newsales WHERE SalesOrderID < @num',
          N'@num int',
          @num = 43700;
GO
```

Notice there is no shell query

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Force SQL Server to use the same cached plan, even though the parameter is no longer selective

```sql
EXEC sp_executesql 
          N'SELECT * FROM dbo.newsales WHERE SalesOrderID < @num',
          N'@num int',
          @num = 77777;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

Now execute the queries in the other order, with the non-selective value first


```sql
EXEC sp_executesql 
          N'SELECT * FROM dbo.newsales WHERE SalesOrderID < @num',
          N'@num int',
          @num = 77777;
GO
```

```sql
EXEC sp_executesql 
          N'SELECT * FROM dbo.newsales WHERE SalesOrderID < @num',
          N'@num int',
          @num = 43700;
GO
```

```sql
SET statistics io OFF;
GO
```

## Observing Plan Cache
Adhoc Plans

```sql
USE AdventureWorks2012;
GO
```

```sql
IF object_id('newsales') IS NOT NULL
	DROP TABLE newsales;
GO
```

Make a copy of the Sales.SalesOrderHeader table

```sql
SELECT * INTO dbo.newsales
FROM Sales.SalesOrderHeader;
GO
```

```sql
UPDATE dbo.newsales
SET SubTotal = cast(cast(SubTotal as int) as money);
GO
```

```sql
CREATE UNIQUE index newsales_ident 
	ON newsales(SalesOrderID);
GO
```

```sql
CREATE INDEX IX_Sales_SubTotal on newsales(SubTotal);
GO
```

Adhoc query plan reuse

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Adhoc query

```sql
SELECT * FROM dbo.newsales
WHERE SubTotal = 4;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Adhoc query; a different plan is used

```sql
SELECT * FROM dbo.newsales
WHERE SubTotal = 5;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

Adhoc queries must be textually EXACT to reuse plan without the comment it's a different query

```sql
-- Include this comment when running the query
SELECT * FROM dbo.newsales
WHERE SubTotal = 4;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

This time the query has all lower case keywords

```sql
select * from dbo.newsales
where SubTotal = 4;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

 Rerun above examples with new 2008 option enabled

```sql
EXEC sp_configure 'Optimize for Ad hoc workloads', 1; RECONFIGURE;
GO
```

```sql
EXEC sp_configure 'Optimize for Ad hoc workloads', 0; RECONFIGURE; 
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

Why is this NOT an adhoc query?

```sql
SELECT * FROM dbo.newsales
where SalesOrderID = 55555;
GO
```

```sql
SELECT * FROM sp_cacheobjects;
GO
```

## Extracting info fromplan cache

Cached plan metadata

```sql
USE AdventureWorks2012;
GO
```

```sql
CREATE NONCLUSTERED INDEX IX_newsales_SalesPersonID ON dbo.newsales(SalesPersonID);
GO
```

```sql
DBCC FREEPROCCACHE;
GO
```

```sql
SELECT * FROM dbo.newsales
WHERE SalesPersonID = 277;
SELECT * FROM dbo.newsales
WHERE SalesPersonID = 287;
GO
```

These objects are views, and can be selected from directly:

```sql
SELECT * FROM sys.dm_exec_query_stats;
```

```sql
SELECT * FROM sys.dm_exec_cached_plans
	WHERE cacheobjtype like 'Compiled %';
```

Why is there only one plan in this view:

```sql
SELECT * FROM sys.dm_exec_requests
	WHERE sql_handle IS NOT NULL;
```

These objects are Table Valued Functions, and must be passed a parameter

```sql
SELECT * FROM sys.dm_exec_query_plan (<get plan_handle from one of the views above>)
```

```sql
SELECT * FROM  sys.dm_exec_sql_text (<get sql_handle or plan_handle from one of the views above> )
```

TVFs can be called with a value from each row of a table or view by 'joining' to the TVF; this is done using the 

Operator CROSS APPLY

```sql
SELECT text, usecounts, cacheobjtype, objtype, db_name(txt.dbid) as [database], object_name(txt.objectid, txt.dbid) as [object], query_plan
    FROM SYS.DM_EXEC_CACHED_PLANS
		CROSS APPLY SYS.DM_EXEC_SQL_TEXT(PLAN_HANDLE) AS TXT
		CROSS APPLY 
			SYS.DM_EXEC_QUERY_PLAN(PLAN_HANDLE)AS PLN
GO
```

## Last thing

Create a view to show most of the same information as SQL Server's syscacheobjects

```sql
USE master
GO
```

```sql
IF EXISTS (SELECT 1 FROM sys.views WHERE name = 'sp_cacheobjects')
	DROP VIEW sp_cacheobjects;
GO
```

You may want to add other filters in the WHERE clause to remove system operations on your own SQL Server

```sql
CREATE VIEW sp_cacheobjects (bucketid, cacheobjtype, objtype, objid, dbid, dbidexec, uid, refcounts, 

                        usecounts, pagesused, setopts, langid, dateformat, status, lasttime, maxexectime, avgexectime, lastreads,

                        lastwrites, sqlbytes, sql, plan_handle) 
AS

            SELECT            pvt.bucketid, CONVERT(nvarchar(18), pvt.cacheobjtype) as cacheobjtype, pvt.objtype, 

                                    CONVERT(int, pvt.objectid)as object_id, CONVERT(smallint, pvt.dbid) as dbid,

                                    CONVERT(smallint, pvt.dbid_execute) as execute_dbid, CONVERT(smallint, pvt.user_id) as user_id,

                                    pvt.refcounts, pvt.usecounts, pvt.size_in_bytes / 8192 as size_in_bytes,

                                    CONVERT(int, pvt.set_options) as setopts, CONVERT(smallint, pvt.language_id) as langid,

                                    CONVERT(smallint, pvt.date_format) as date_format, CONVERT(int, pvt.status) as status,

                                    CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), CONVERT(bigint, 0), 

                                    CONVERT(int, LEN(CONVERT(nvarchar(max), fgs.text)) * 2), CONVERT(nvarchar(3900), fgs.text), plan_handle

            FROM (SELECT ecp.*, epa.attribute, epa.value

                        FROM sys.dm_exec_cached_plans ecp OUTER APPLY sys.dm_exec_plan_attributes(ecp.plan_handle) epa) as ecpa

            PIVOT (MAX(ecpa.value) for ecpa.attribute IN ("set_options", "objectid", "dbid", "dbid_execute", "user_id", "language_id", "date_format", "status")) as pvt

            OUTER APPLY sys.dm_exec_sql_text(pvt.plan_handle) fgs
    WHERE cacheobjtype like 'Compiled%'
    AND pvt.dbid > 4 and pvt.dbid < 32767
    AND text not like '%filetable%'
    AND text not like '%fulltext%';
```
