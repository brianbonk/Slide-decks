# Module 1 - Architecture and metadata

## Configuration settings

By default, sp_configure doesn't show ALL configuration options
```sql
EXEC sp_configure;
```

There is a metadata view that does show all

It also shows which options are advanced and which are dynamic

```sql
SELECT * FROM sys.configurations;
```

To CHANGE options, you must use sp_configure

To use sp_configure to see or change advanced options, you must set 'show advanced options' to 1

```sql
EXEC sp_configure 'advanced', 1; RECONFIGURE

EXEC sp_configure;
```

SQL Server Management Studio does not show all the options

## Dynamic Management Objects

Views and Functions
DM objects are visible in all databases

```sql
USE master
SELECT * FROM sys.all_objects
WHERE name LIKE 'dm_%'
ORDER BY name;
GO
USE AdventureWorks2012;
SELECT * FROM sys.all_objects
WHERE name LIKE 'dm_%'
ORDER BY name;
GO
```

You can also see all the DM objects using the Object Explorer under Views | System Views in all databases

Not all the DM objects are documented in BOL, but they all are listed in the metadata definitions are available, don't help us much

```sql
SELECT object_definition (object_id('sys.dm_tran_version_store'));
GO

```

The Resource Database does not show up in sys.databases

```sql
SELECT name FROM sys.databases;
```

You can see its files using Windows Explorer in SQL Server's Binn directory

You can see reference to it in some of the metadata

```sql
SELECT * FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%databases%'
ORDER BY instance_name;
```

You can see the above information using PerfMon directly

The ID of the resource database is observable in other metadata

```sql
SELECT * FROM sys.dm_os_buffer_descriptors
ORDER BY database_id DESC;
```
## Memory 

The sys.dm_os_memory_clerks view returns one row per memory clerk that is currently active in the instance of SQL Server. 

You can think of a clerk as an accounting unit. 

Each store described above is a clerk, but there are also clerks that are not stores, such as those for the CLR and for fulltext search. 

The following query returns a list of all the types of clerks:

```sql
SELECT DISTINCT type FROM sys.dm_os_memory_clerks;

SELECT SUM (pages_in_bytes)/8192 as 'Pages Used', type 
FROM sys.dm_os_memory_objects
GROUP BY type 
ORDER BY 1 DESC;

```

## Buffer counts by object & index.sql
Break down buffers by object (table, index)

Note that object names are only available in the current database. Switch to a different database to see object names for that database 

```sql
SELECT b.database_id, database_name = 
                CASE  b.database_id WHEN 32767 THEN 'Resource'
									ELSE db_name(b.database_id) END 
		,p.object_id
		,Object_Name = 
             CASE database_id WHEN db_id() THEN object_name(p.object_id) 
							  ELSE 'unavailable' END
		,p.index_id
		,buffer_count=count(*)
FROM  sys.allocation_units a  
		JOIN sys.dm_os_buffer_descriptors b 
			ON a.allocation_unit_id = b.allocation_unit_id
		JOIN sys.partitions p
			ON a.container_id = p.hobt_id
WHERE object_id > 99 
GROUP BY  b.database_id,p.object_id, p.index_id
ORDER BY  buffer_count DESC;
```

## Metadata
Compatability and Catalog Views

```sql
USE master;

```
Compatibity views allow you to use same code as in previous versions

```sql
SELECT * FROM sysdatabases;
```
Catalog views contain more detailed information requiring less need for property functions

```sql
SELECT * FROM sys.databases;
```

In master, sysobjects  contains everything in both sys.objects and sys.system_objects

Objects in sys.objects are considered 'not system objects'
The catalog view that shows all objects in ALL databases is sys.all_objects

```sql
USE master;
SELECT * FROM sysobjects;
SELECT * FROM sys.objects;
SELECT * FROM sys.system_objects;
SELECT * FROM sys.all_objects;
```

In all other databases, sysobjects  contains only the non-system objects

In ALL databases,  sys.system_objects contains the same 1756 rows

```sql
USE pubs
SELECT * FROM sysobjects;
SELECT * FROM sys.objects;
SELECT * FROM sys.system_objects;
SELECT * FROM sys.all_objects;

USE master;
GO
SELECT * FROM sysobjects
   WHERE  name NOT IN (SELECT NAME FROM sys.objects)
order by 1;
```

The compatibility views can be referenced in several ways

```sql
SELECT * FROM sysobjects;
SELECT * FROM sys.sysobjects;
SELECT * FROM dbo.sysobjects;
```

The catalog views must have the schema specified

```sql
SELECT * FROM objects;

```

Not all catalog views have compatibility view counterparts

```sql
SELECT * FROM sys.partitions;
SELECT * FROM syspartitions;
```

Catalog view use inheritance model

```sql
USE AdventureWorks2012;
GO
SELECT * FROM sys.objects;
SELECT * FROM sys.tables;
SELECT * FROM sys.views;
SELECT * FROM sys.procedures;

```

Definition of metadata objects is available:

```sql
SELECT object_definition (object_id('sys.databases'));
```

Compatibility view definitions are built on catalog views

Undo all the work done to show separate property values

```sql
USE master
GO
SELECT object_definition (object_id('sysdatabases'));

```
Find  catalog views

```sql
SELECT * FROM sys.system_objects
WHERE type = 'V'
AND schema_id =4  -- eliminate INFORMATION_SCHEMA views
AND name not like 'dm%' -- eliminate DMVs
AND name not like 'sys%'; -- eliminate compatability views
```

Find compatability views

```sql
SELECT * FROM sys.system_objects
WHERE type = 'V'
AND name  like 'sys%'
AND name not like 'system%';  
```

## Processor and Scheduler Metadata

Here is the main scheduler DMV:

```sql
SELECT * FROM sys.dm_os_schedulers;

```

You can use the following query to list all the schedulers and look at the number of runnable tasks.

```sql
SELECT 
    scheduler_id,
    current_tasks_count,
    runnable_tasks_count
FROM  
    sys.dm_os_schedulers
WHERE  
    scheduler_id < 255;

```

Several DM objects are needed to replace sysprocesses

These are the main two:

```sql
SELECT * FROM sys.dm_exec_sessions;
SELECT * FROM sys.dm_exec_requests;
```

Requests includes all running sessions, plus some system tasks

Connections is only USER connections, and holds information about client/server communications

```sql
SELECT * FROM sys.dm_exec_connections;

SELECT * FROM sys.dm_os_tasks;
```

You can use the following query to find currently pending I/O requests. 

You can execute this query periodically to check the health of I/O subsystem and to isolate physical disk(s) that are involved in the I/O bottlenecks.

```sql
SELECT 
    database_id, 
    file_id, 
    io_stall,
    io_pending_ms_ticks,
    scheduler_address 
FROM	sys.dm_io_virtual_file_stats(NULL, NULL)t1 JOIN 
        sys.dm_io_pending_io_requests as t2
 ON	t1.file_handle = t2.io_handle;

```
From Slava Ok's web log
http://blogs.msdn.com/slavao/archive/2006/08/22/713357.aspx

```
Q: How many sockets does my machine have?

A: SELECT cpu_count/hyperthread_ratio AS sockets
FROM sys.dm_os_sys_info
```
```
Q: Is my machine hyper threaded? 

A: Unfortunately you can’t derive this information using this DMV today though there is a column called hyperthread_ratio. On the other hand this column can tell you: 
```
```
Q: How many either cores or logical CPU share the same socket?

A:
SELECT *, hyperthread_ratio AS cores_or_logical_cpus_per_socket
FROM sys.dm_os_sys_info
```

```
Q: How many threads/workers SQL Server would use if the default value in sp_configure for max worker threads is zero:

A:
sql
SELECT max_workers_count
FROM   sys.dm_os_sys_info
```

Every NUMA node has its own Resource Monitor, which can be thought of as a hidden scheduler. 

The Resource Monitor has its own spid, which you can see by querying the sys.dm_exec and sys.dm_os_workers DMVs as shown:

```sql
SELECT *, session_id,  
    CONVERT (varchar(10), r.status) AS status,  
    CONVERT (varchar(20),  r.command) AS command, 
    CONVERT (varchar(15),  w.state) AS worker_state
FROM sys.dm_exec_requests AS r JOIN sys.dm_os_workers AS w
ON  w.task_address = r.task_address
WHERE command = 'RESOURCE MONITOR'
```

Additional examples
Some of these depend on DM Objects that won't be covered until a later lession
Some of these don't return any interesting data on a single user test system (like mine)

Check for Long Waits in Runnable List

```sql
SELECT '%signal' = 100.0 * sum(signal_wait_time_ms) / sum (wait_time_ms)
FROM sys.dm_os_wait_stats
```

Look at Currently Executing Statements

```sql
SELECT r.session_id,
	status,
	substring(qt.text,r.statement_start_offset/2, 
	   (CASE WHEN r.statement_end_offset = -1 
		  THEN len(convert(nvarchar(max), qt.text)) * 2 
		  ELSE r.statement_end_offset END -	
		  r.statement_start_offset)/2) AS query,    
	  qt.dbid, qt.objectid, r.cpu_time, 
       r.total_elapsed_time,
		r.reads,  r.writes,  r.logical_reads
		,r.scheduler_id
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(sql_handle) as qt
ORDER BY r.scheduler_id, r.status, r.session_id
```

Look at Top CPU Using Procs and Batches 

```sql
SELECT TOP 50 
SUM(qs.total_worker_time) as total_cpu_time, 
    SUM(qs.execution_count) as total_execution_count,
    count(*) AS  '#_statements',
    qt.dbid, qt.objectid, qs.sql_handle, qt.[text]
FROM sys.dm_exec_query_stats as qs
CROSS apply sys.dm_exec_sql_text (qs.sql_handle) as qt
GROUP BY qt.dbid,qt.objectid, qs.sql_handle,qt.[text]
ORDER BY SUM(qs.total_worker_time) DESC,qs.sql_handle
```

Look at TOP CPU Usage 
top 50 statements by Avg CPU Time

```sql
SELECT TOP 50
  qs.total_worker_time/qs.execution_count AS [Avg CPU Time],
  SUBSTRING(qt.text,qs.statement_start_offset/2, 
	 (CASE WHEN qs.statement_end_offset = -1 
	   THEN len(convert(nvarchar(max), qt.text)) * 2 
		ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) 
		AS query_text,
		qt.dbid, qt.objectid 
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
ORDER BY  [Avg CPU Time] DESC
```

CPU - What’s running in parallel 

```sql
SELECT r.session_id,
	r.request_id,
	max(isnull(exec_context_id, 0)) as num_workers,
	r.sql_handle,
	r.statement_start_offset, statement_end_offset,
	r.plan_handle
FROM sys.dm_exec_requests r
	JOIN sys.dm_os_tasks t    ON r.session_id = t.session_id
	JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
WHERE s.is_user_process = 0x1
GROUP BY  r.session_id, r.request_id, r.sql_handle, r.plan_handle, 
r.statement_start_offset, r.statement_end_offset
HAVING  max(isnull(exec_context_id, 0)) > 0
```

## Using and tracking the DAC
Although sys.objects shows us SYSTEM_TABLE objects, we cannot access the data 

```sql
SELECT * FROM sys.objects;
SELECT schema_name(4);
SELECT * FROM sys.sysrowsets;
```

Connect using the DAC by prefacing your server name with ADMIN:

```sql
SELECT * FROM sys.sysrowsets;
```

Only one session at a time can use the DAC.

Try opening up another Query Window, by default it will use the same credentials

Is there a DAC?

You can check whether or not a DAC is in use by running the following query. 
If there is an active DAC, the query will return the session ID (spid) for the DAC, otherwise, it will return no rows.  

```sql
SELECT t2.session_id
FROM sys.tcp_endpoints as t1 JOIN sys.dm_exec_sessions as t2 
   ON t1.endpoint_id = t2.endpoint_id 
WHERE t1.name='Dedicated Admin Connection';
```

Any sysadmin session can kill the DAC

```sql
SELECT name, sysadmin, sid from sys.syslogins
WHERE sysadmin = 1;
```