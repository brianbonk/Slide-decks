# Partitions and indexes

## Setup

```sql
USE AdventureWorks2012;
GO
--DROP TABLE Sales.SalesOrderDetail2
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE [Sales].[SalesOrderDetail2](
	[SalesOrderID] [int] NOT NULL,
	[SalesOrderDetailID] [int] NOT NULL,
	[CarrierTrackingNumber] [nvarchar](25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[OrderQty] [smallint] NOT NULL,
	[ProductID] [int] NOT NULL,
	[SpecialOfferID] [int] NOT NULL,
	[UnitPrice] [money] NOT NULL,
	[UnitPriceDiscount] [money] NOT NULL ,
 CONSTRAINT [PK_SalesOrderDetail2_SalesOrderID_SalesOrderDetailID] PRIMARY KEY CLUSTERED 
(
	[SalesOrderID] ASC,
	[SalesOrderDetailID] ASC
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY];
GO

ALTER TABLE [Sales].[SalesOrderDetail2]  WITH CHECK ADD  CONSTRAINT [FK_SalesOrderDetail2_SalesOrderHeader_SalesOrderID] FOREIGN KEY([SalesOrderID])
REFERENCES [Sales].[SalesOrderHeader] ([SalesOrderID])
ON DELETE CASCADE;
GO

INSERT INTO Sales.SalesOrderDetail2
SELECT [SalesOrderID]
      ,[SalesOrderDetailID]
      ,[CarrierTrackingNumber]
      ,[OrderQty]
      ,[ProductID]
      ,[SpecialOfferID]
      ,[UnitPrice]
      ,[UnitPriceDiscount]

  FROM AdventureWorks2012.Sales.SalesOrderDetail;
```

## Partitions

Create a partition function, a partition scheme, a table and a clustered index

Then look at the allocation information metadata for the table

Note that you can only create a partitioned table or index if you are using SQL Server Enterprise or Developer Edition

```sql
USE AdventureWorks2012;
GO
IF object_id('Employees') IS NOT NULL
	DROP TABLE Employees;
GO
IF object_id('Employees2') IS NOT NULL
	DROP TABLE Employees2;
GO
IF object_id('Employees3') IS NOT NULL
	DROP TABLE Employees3;
GO
IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'test_ps')
	DROP PARTITION SCHEME test_ps;
GO
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'test_fn')
	DROP PARTITION FUNCTION test_fn;
GO
```

Create a partition function defining 5 partitions

```sql
CREATE PARTITION FUNCTION test_fn (int) 
	AS RANGE LEFT FOR VALUES (-1,10, 20, 30)
```

Verify the function boundaries

```sql
SELECT $PARTITION.test_fn(10)
GO
```

The same number of filegroups must be specified, order is important

```sql
CREATE PARTITION SCHEME test_ps
  AS PARTITION test_fn  
		ALL TO ([Primary])
GO
```

Create a table using the test_ps partition scheme

```sql
CREATE TABLE Employees 
(EmpId int identity(-10,1), EmpName char(500)) 
   ON test_ps(EmpId);
```

Populate the table, copying data from a table in AdventureWorks

```sql
INSERT INTO Employees
  SELECT TOP 60 FirstName
  FROM AdventureWorks2012.Person.Person
GO
SELECT $PARTITION.test_fn(EmpID) as Partition, * 
FROM Employees;
GO
```

Look at metadata for partition storage

This is the same query that we used for 'hugerows'

```sql
SELECT object_name(i.object_id) AS object_name, p.object_id, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
    allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page, root_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
ORDER by object_name, partition_number;
GO
CREATE UNIQUE CLUSTERED INDEX Employees_PK on Employees(EmpID)
GO
```

Look at metadata for partition storage after building a clustered index

```sql
SELECT object_name(i.object_id) AS object_name, p.object_id, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
    allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page, root_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
ORDER by object_name, partition_number;
GO
```

### Switching a partition

This script assumes you have already run the Basic Partitioning

After creating a second partitioned table and SWITCHING a partition from one table to another, we can use the included metadata script to verify that the data itself has not moved. The starting page number for the allocation unit containing the partition's data is the same page.

```sql
USE AdventureWorks2012;
GO
IF object_id('Employees2') IS NOT NULL
	DROP TABLE Employees2;
GO
CREATE TABLE Employees2 
(EmpId int identity(-10,1), EmpName char(500)) 
   ON test_ps(EmpId);
GO
```

```sql
CREATE UNIQUE CLUSTERED INDEX Employees2_PK on Employees2(EmpID);
GO
```

Note the first_page and root_page from Partition 1 in Employees

Note also that there is no space used by any of the partitions in Employees2 yet

```sql
SELECT object_name(i.object_id) AS object_name, p.object_id, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
    allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page, root_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
   or i.object_id=object_id('Employees2')
ORDER by object_name, partition_number;
GO
```

Reassign the data from Partition 1 of Employees to Partition 1 of Employees2; this is a metadata ONLY operation

The data stays in the same pages and the allocation units containing those pages is associated with a new table

```sql
ALTER TABLE Employees SWITCH Partition 1 to Employees2 Partition 1;
GO
```

Switch back the other way

```sql
ALTER TABLE Employees2 SWITCH Partition 1 to Employees Partition 1;
GO
```

Note the first_page and root_page from Partition 1 in Employees2

```sql
SELECT object_name(i.object_id) AS object_name, p.object_id, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
    allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page, root_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
   or i.object_id=object_id('Employees2')
ORDER by object_name, partition_number,index_name;
GO
```

Now create a third table without partitioning

```sql
IF object_id('Employees3') IS NOT NULL
	DROP TABLE Employees3;
GO
CREATE TABLE Employees3 
(EmpId int identity(-10,1), EmpName char(500)) 
GO
CREATE UNIQUE CLUSTERED INDEX Employees3_PK on Employees3(EmpID);
GO
```

Switch a partition into a standalone table

```sql
ALTER TABLE Employees SWITCH Partition 1 to Employees3;
GO
```

You can't switch it back!

```sql
ALTER TABLE Employees3 SWITCH to Employees  Partition 1;
GO
```

Add a constraint to guarantee the data fits in the range for partition 1

```sql
ALTER TABLE Employees3 ADD CONSTRAINT ck_part1 CHECK (EmpID <= -1)
GO
```

Try again to switch back

```sql
ALTER TABLE Employees3 SWITCH to Employees  Partition 1;
GO
```

Create a nonclustered index on Employees

```sql
CREATE INDEX Employees_Name_Index on Employees(EmpName);
GO
SELECT object_name(i.object_id) AS object_name, p.object_id, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
    allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page, root_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
   or i.object_id=object_id('Employees2')
ORDER by object_name, partition_number, index_name desc;
GO
```

Switch a partition into a partition of a table with no nc index

```sql
ALTER TABLE Employees SWITCH Partition 1 to Employees2 Partition 1;
GO
```

You can't switch it back!
If target has nc index, the source must have one, but the reverse isn't true

```sql
ALTER TABLE Employees2 SWITCH Partition 1  to Employees Partition 1;
GO

CREATE INDEX Employees2_NameIndex on Employees2(EmpName);
```

Now try to switch back the other way

```sql
ALTER TABLE Employees2 SWITCH Partition 1 to Employees Partition 1;
GO
```

### Split and merge partitions
These operations apply to a partition function, and affect all tables based on the function

Recreate the Employees table

```sql
IF object_id('Employees') IS NOT NULL
	DROP TABLE Employees;
GO
CREATE TABLE Employees 
(EmpId int identity(-10,1), EmpName char(500)) 
   ON test_ps(EmpId);
GO
```

Populate the table, copying data from a table in AdventureWorks

```sql
INSERT INTO Employees
  SELECT TOP 60 FirstName
  FROM AdventureWorks2012.Person.Person;
GO
```

Splitting a range in the middle creates a new partition and one or more new allocation units

The new partition includes the set of rows containing the new boundary point

Inspect the metadata and note that partitions are renumbered

```sql
ALTER PARTITION FUNCTION test_fn() SPLIT RANGE(25);
GO
```

The partition number that contains the new boundary point will be the new one; 

```sql
SELECT $PARTITION.test_fn(25)
```

Splitting at the high end adds a new partition, but no rows are moved and no existing partitions are renumbered

However, you must make sure there is a new filegroup to hold the new partition

Below query does not work:

```sql
ALTER PARTITION FUNCTION test_fn() SPLIT RANGE(50);
GO
```

But after you change the partition scheme, it will:

```sql
ALTER PARTITION SCHEME test_ps
NEXT USED [PRIMARY];
GO
ALTER PARTITION FUNCTION test_fn() SPLIT RANGE(50);
GO
```

```sql
SELECT $PARTITION.test_fn(50);
```

```sql
ALTER PARTITION SCHEME test_ps
NEXT USED [PRIMARY];
GO
```

Splitting to add a new boundary point at the low end will not move rows, but will renumber ALL the partitions

```sql
ALTER PARTITION FUNCTION test_fn() SPLIT RANGE(-11);
GO
```

Merging an empty partition causes no data movement

```sql
ALTER PARTITION FUNCTION test_fn() MERGE RANGE(50);
GO

ALTER PARTITION FUNCTION test_fn() MERGE RANGE(-11);
GO
```

Check metadata 

```sql
SELECT object_name(i.object_id) AS object_name, i.name as index_name, 
    partition_id, partition_number as p_num, rows, 
   -- allocation_unit_id AS au_id, container_id,a.type_desc as page_type_desc,
    total_pages AS pages, first_page
FROM sys.indexes i JOIN sys.partitions p  
	ON i.object_id = p.object_id AND i.index_id = p.index_id
	JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE i.object_id=object_id('Employees')
  AND i.index_id < 2
ORDER by object_name, partition_number;
```

### Partitioning metadata

```sql
SELECT * FROM sys.partition_schemes;

SELECT * FROM sys.data_spaces;

SELECT * FROM sys.destination_data_spaces;

SELECT * FROM sys.partition_functions;

SELECT * FROM sys.filegroups;

SELECT * FROM sys.partitions;

SELECT * FROM sys.partition_range_values;

SELECT * FROM sys.partition_parameters;

select * from sys.dm_db_partition_stats;


select partition_id, object_id, object_name(object_id), row_count
 from sys.dm_db_partition_stats;

select * from sys.partitions
where object_id = object_id('Employees');
```


```sql
DROP PARTITION FUNCTION RangePF1;

CREATE PARTITION FUNCTION RangePF1 ( int )
AS RANGE FOR VALUES (10, 100, 1000) ;
GO
SELECT $PARTITION.RangePF1 (11) ;
GO
```

'$PARTITION Returns the partition number into which a set of partitioning column values would be mapped for any specified partition function. 

```sql
SELECT * FROM sys.partitions
WHERE object_id = object_id('Employees');

SELECT * FROM sys.indexes
WHERE object_id = object_id('Employees');

SELECT object_name(object_id), * FROM sys.partitions p JOIN sys.allocation_units a
	ON p.hobt_id = a.container_id
WHERE object_id = object_id('Employees')
ORDER BY partition_id;
```

### Full query to get partitioning metadata

Create a view to return details about a partitioned table or index

First run the script to create the function index_name()

```sql 
IF OBJECT_ID('dbo.index_name') IS NOT NULL
	DROP FUNCTION dbo.index_name;
GO

CREATE FUNCTION dbo.index_name (@object_id int, @index_id smallint)
RETURNS sysname
AS
BEGIN
  DECLARE @index_name sysname
  SELECT @index_name = name FROM sys.indexes
     WHERE object_id = @object_id and index_id = @index_id
  RETURN(@index_name)
END;
```


```sql
IF EXISTS (SELECT * FROM sys.views WHERE name = 'Partition_Info')
    DROP VIEW partition_info;
GO

CREATE VIEW Partition_Info AS
  SELECT OBJECT_NAME(i.object_id) as Object_Name, dbo.INDEX_NAME(i.object_id,i.index_id) AS Index_Name, 
    p.partition_number, fg.name AS Filegroup_Name, rows, 
    au.total_pages, first_page,
    CASE boundary_value_on_right 
        WHEN 1 THEN 'less than' 
        ELSE 'less than or equal to' 
    END as 'comparison'
    , rv.value,
    CASE WHEN ISNULL(rv.value, rv2.value) IS NULL THEN 'N/A'
    ELSE 
      CASE 
        WHEN boundary_value_on_right = 0 AND rv2.value IS NULL  
           THEN 'Greater than or equal to'
        WHEN boundary_value_on_right = 0 
           THEN 'Greater than' 
        ELSE 'Greater than or equal to' END + ' ' +
           ISNULL(CONVERT(varchar(20), rv2.value), 'Min Value') 
                + ' ' +
                + 
           CASE boundary_value_on_right 
             WHEN 1 THEN 'and less than' 
               ELSE 'and less than or equal to' 
               END + ' ' +
                + ISNULL(CONVERT(varchar(20), rv.value), 
                           'Max Value')
        END as 'TextComparison'
  FROM sys.partitions p 
    JOIN sys.indexes i 
      ON p.object_id = i.object_id and p.index_id = i.index_id
    LEFT JOIN sys.partition_schemes ps 
      ON ps.data_space_id = i.data_space_id
    LEFT JOIN sys.partition_functions f 
      ON f.function_id = ps.function_id
    LEFT JOIN sys.partition_range_values rv 
      ON f.function_id = rv.function_id 
          AND p.partition_number = rv.boundary_id     
    LEFT JOIN sys.partition_range_values rv2 
      ON f.function_id = rv2.function_id 
          AND p.partition_number - 1= rv2.boundary_id
    LEFT JOIN sys.destination_data_spaces dds
      ON dds.partition_scheme_id = ps.data_space_id 
          AND dds.destination_id = p.partition_number 
    LEFT JOIN sys.filegroups fg 
      ON dds.data_space_id = fg.data_space_id
    JOIN sys.system_internals_allocation_units au
      ON au.container_id = p.partition_id 
WHERE i.index_id <2 AND au.type =1;
```

Example of use:

```sql
SELECT * FROM Partition_Info 
WHERE Object_Name = 'Employees'
ORDER BY Object_Name, partition_number;
```

--------------------------
--------------------------
--------------------------

## Indexes

Create a columnstore index based on a table in the AdventureWorksDW2012 database

```sql
USE AdventureWorksDW2012;
GO
```

You might need to adjust resource governor, to allow queries in the default resource group have more than 25% of available memory

```sql
ALTER WORKLOAD GROUP [DEFAULT] WITH (REQUEST_MAX_MEMORY_GRANT_PERCENT=75);
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
```

```sql
IF  object_id('dbo.FactInternetSalesBig') IS NOT NULL
     DROP TABLE dbo.FactInternetSalesBig;
GO
```

Create the table, and first just copy data from the original table

```sql
CREATE TABLE dbo.FactInternetSalesBig (
	ProductKey int NOT NULL,
	OrderDateKey int NOT NULL,
	DueDateKey int NOT NULL,
	ShipDateKey int NOT NULL,
	CustomerKey int NOT NULL,
	PromotionKey int NOT NULL,
	CurrencyKey int NOT NULL,
	SalesTerritoryKey int NOT NULL,
	SalesOrderNumber nvarchar(20) NOT NULL,
	SalesOrderLineNumber tinyint NOT NULL,
	RevisionNumber tinyint NOT NULL,
	OrderQuantity smallint NOT NULL,
	UnitPrice money NOT NULL,
	ExtendedAmount money NOT NULL,
	UnitPriceDiscountPct float NOT NULL,
	DiscountAmount float NOT NULL,
	ProductStandardCost money NOT NULL,
	TotalProductCost money NOT NULL,
	SalesAmount money NOT NULL,
	TaxAmt money NOT NULL,
	Freight money NOT NULL,
	CarrierTrackingNumber nvarchar(25) NULL,
	CustomerPONumber nvarchar(25) NULL,
	OrderDate datetime NULL,
	DueDate datetime NULL,
	ShipDate datetime NULL
)
GO

INSERT INTO dbo.FactInternetSalesBig
SELECT * FROM dbo.FactInternetSales;
GO
```

To make sure rows are unique, we will change the revision number each time, and keep track of the value in a tiny table

```sql
IF  object_id('dbo.RevisionNumberValue') IS NOT NULL
     DROP TABLE dbo.RevisionNumberValue;
GO
CREATE TABLE RevisionNumberValue (RevisionNumber tinyint);
INSERT INTO RevisionNumberValue SELECT 1;
GO
```

Copy the new big table into itself 9 times - this takes a while: 8:38 on my machine

```sql
DECLARE @RevisionNumber tinyint;
SELECT @RevisionNumber = RevisionNumber + 1 FROM RevisionNumberValue;
SELECT @RevisionNumber as RevisionNumber;
INSERT INTO dbo.FactInternetSalesBig WITH (TABLOCK)
SELECT ProductKey
,OrderDateKey
,DueDateKey
,ShipDateKey
,CustomerKey
,PromotionKey
,CurrencyKey
,SalesTerritoryKey
,SalesOrderNumber + cast(@RevisionNumber as nvarchar(4))
,SalesOrderLineNumber
,@RevisionNumber
,OrderQuantity
,UnitPrice
,ExtendedAmount
,UnitPriceDiscountPct
,DiscountAmount
,ProductStandardCost
,TotalProductCost
,SalesAmount
,TaxAmt
,Freight
,CarrierTrackingNumber
,CustomerPONumber 
,OrderDate
,DueDate
,ShipDate
FROM dbo.FactInternetSalesBig;
UPDATE RevisionNumberValue SET RevisionNumber = RevisionNumber + 1;
GO 9
```

How many rows do we have?

```sql
SELECT COUNT(*) FROM FactInternetSalesBig;
GO
```

Create a columnstore index on all the columns, this also takes a while: 3:09 on my machine

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX csi_FactInternetSalesBig 
ON dbo.FactInternetSalesBig (
	ProductKey,
	OrderDateKey,
	DueDateKey,
	ShipDateKey,
	CustomerKey,
	PromotionKey,
	CurrencyKey,
	SalesTerritoryKey,
	SalesOrderNumber,
	SalesOrderLineNumber,
	RevisionNumber,
	OrderQuantity,
	UnitPrice,
	ExtendedAmount,
	UnitPriceDiscountPct,
	DiscountAmount,
	ProductStandardCost,
	TotalProductCost,
	SalesAmount,
	TaxAmt,
	Freight,
	CarrierTrackingNumber,
	CustomerPONumber,
    OrderDate,
	DueDate,
	ShipDate
); 
GO
```

## Columnstore metadata

Explore the metadata for the columnstore index

All columnstore index pages are stored in a LOB allocation unit

```sql
SELECT index_id, rows, data_compression_desc, type_desc, total_pages, partition_number
FROM sys.partitions p
   JOIN sys.allocation_units au
      ON p.partition_id = au.container_id
WHERE OBJECT_NAME(object_id) = 'FactInternetSalesBig';
GO
```

How many segments do we have for our columnstore index?

```sql
SELECT s.column_id,  col_name(ic.object_id, ic.column_id) as column_name,  
       count(*) as segment_count
FROM sys.column_store_segments s join sys.partitions p 
       ON s.partition_id = p.partition_id 
  LEFT JOIN sys.index_columns ic 
       ON p.object_id = ic.object_id AND p.index_id = ic.index_id
              AND s.column_id = ic.index_column_id
WHERE object_name(p.object_id) = 'FactInternetSalesBig'
GROUP BY s.column_id,  col_name(ic.object_id, ic.column_id)
ORDER by s.column_id; 
GO
```

How many rows are in each segment? All columns have the same number, so I only need to look at one:

```sql
SELECT  segment_id, sum(row_count)  
FROM sys.column_store_segments s join sys.partitions p 
       ON  s.partition_id = p.partition_id 
   JOIN sys.index_columns ic 
       ON p.object_id = ic.object_id AND p.index_id = ic.index_id
           AND s.column_id = ic.index_column_id
WHERE object_name(p.object_id) = 'FactInternetSalesBig' and index_column_id = 1
GROUP BY  segment_id;
GO
```

sys.column_store_segments stores info on the min and max value in each segment

```sql
SELECT  segment_id, min_data_id, max_data_id
FROM sys.column_store_segments s join sys.partitions p 
       ON s.partition_id = p.partition_id 
  LEFT JOIN sys.index_columns ic 
       ON p.object_id = ic.object_id AND p.index_id = ic.index_id
           AND s.column_id = ic.index_column_id
WHERE object_name(p.object_id) = 'FactInternetSalesBig' 
      AND col_name(ic.object_id, ic.column_id) = 'OrderDateKey'
ORDER by segment_id;
GO
```

Observe dm_db_index_physical_stats with various parameters

```sql
USE AdventureWorks2012;
GO
```

The following returns rows for all levels of all indexes on all partitions plus other allocation units for all partitions, for the AdventureWorks2012 database

```sql
SELECT *
FROM sys.dm_db_index_physical_stats 
(DB_ID(N'AdventureWorks2012'), null,  null, null,  'DETAILED');
```

The output can be filtered even after the params are specified

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), null,  null, null,  'DETAILED')
where index_type_desc = 'heap';
```

```sql
USE pubs
```

For the following, the fact that we're in pubs is irrelevant, we still get heap info from the AdventureWorks2012 database

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), null,  null, null,  'DETAILED')
where index_type_desc = 'heap';
```

```sql
USE AdventureWorks2012
```

Look for one particular object in the AW database

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), object_id('DatabaseLog'),  null, null,  'DETAILED');
where index_type_desc = 'heap';
```

The following may seem to generate incorrect results, but it really doesn't

We are in the AW database when SQL Server tries to find the object_id for 'authors'. There is none, so NULL is returned.

The function then returns info for ALL objects in pubs, not just one table

```sql
SELECT /* object_name(object_id) as Object, */ *
FROM sys.dm_db_index_physical_stats (DB_ID(N'pubs'), object_id('authors'),  null, null,  'DETAILED')

```

Recommended use of this function is to verify the db and object IDs prior  to calling the function

```sql
DECLARE @db_id SMALLINT;
DECLARE @object_id INT;

SET @db_id = DB_ID(N'pubs');
SET @object_id = OBJECT_ID(N'pubs.dbo.authors');

IF @db_id IS NULL
BEGIN;
    PRINT N'Invalid database';
END;
ELSE IF @object_id IS NULL
BEGIN;
    PRINT N'Invalid object';
END;
ELSE
SELECT * FROM sys.dm_db_index_physical_stats (@db_id, @object_id, NULL, NULL,  'detailed');
GO
```

## Reorganise indexes

Demo to illustrate use of the Index Reorganize feature

```sql
USE AdventureWorks2012;
GO
```

Look at the fragmentation data for the SalesOrderDetail2 table.

Note the avg_fragmentation_in_percent value

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), object_id('Sales.SalesOrderDetail2'),  null, null,  'DETAILED');
```

Add a new fixed width column and note that this is a metadata only change

The data pages are not modified

There is no change in the fragmentation

```sql
ALTER TABLE Sales.SalesOrderDetail2
ADD notes CHAR(100);
GO
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), object_id('Sales.SalesOrderDetail2'),  null, null,  'DETAILED');
GO
```

The data pages are not affected until we run the following update.

Every row on every page has an additional 100 bytes in the notes field added to it 

```sql
UPDATE Sales.SalesOrderDetail2
SET notes = 'notes';
GO
```

Note the new fragmentation value

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), object_id('Sales.SalesOrderDetail2'),  null, null,  'DETAILED');
GO
```

Prior to running the ALTER INDEX, determine the @@spid value of the current session

```sql
SELECT @@spid
GO
```

Copy and paste the following SELECT to another window after determining the @@spid and using that value in the code below, and be prepared to start running this immediately after starting the ALTER INDEX

The sys.dm_exec_requests DMV will show the process of the REORGANIZE operation

Run this SELECT repeatedly to see the progress; 

```sql
SELECT percent_complete, estimated_completion_time, * 
FROM sys.dm_exec_requests 
WHERE session_id = @@spid;
GO
```

Use the ALTER INDEX command to REORGANIZE the table and remove the fragmentatino

```sql
ALTER INDEX PK_SalesOrderDetail2_SalesOrderID_SalesOrderDetailID 
	ON Sales.SalesOrderDetail2 
   REORGANIZE;
GO
```

Look at the fragmentation now, in the leaf level of the clustered index

```sql
SELECT object_name(object_id) as Object, *
FROM sys.dm_db_index_physical_stats (DB_ID(N'AdventureWorks2012'), object_id('Sales.SalesOrderDetail2'),  null, null,  'DETAILED');
GO
```

## SYSINDEXES keys

```sql
USE credit
```

Examine the keycnt column for different types of indexes

Examine the sysindexes table

INDID is 0 for a table with no clustered index (a heap)

INDID is 1 for a table with a clustered index

INDID is 2 - 250 for nonclustered indexes

Drop the table if it already exists

```sql
IF object_id('charge2') IS NOT NULL
	DROP TABLE charge2;
GO
```

```sql
SELECT *
INTO charge2
FROM charge;
GO
```

The compatibility view sysindexes contains a columns called keycnt

```sql
SELECT * FROM sysindexes;
```

Where does keycnt come from?

```sql
SELECT OBJECT_DEFINITION(OBJECT_ID('sysindexes'));
GO
```

```sql
SELECT keycnt = indexproperty(object_id, name, 'keycnt80'), *
FROM sys.indexes
WHERE object_id = object_id('charge2')
GO 
```

```sql
CREATE  CLUSTERED INDEX charge_charge_no  
	on charge2(charge_no);
GO
```

```sql
SELECT keycnt = indexproperty(object_id, name, 'keycnt80'), *
FROM sys.indexes
WHERE object_id = object_id('charge2');
GO
```

```sql
CREATE UNIQUE CLUSTERED INDEX charge_charge_no  
	on charge2(charge_no) with drop_existing; 
GO
```

```sql
SELECT keycnt = indexproperty(object_id, name, 'keycnt80'), *
FROM sys.indexes
WHERE object_id = object_id('charge2');
GO
```

```sql
CREATE  INDEX charge_member_index 
on charge2(member_no);
GO
```

```sql
SELECT keycnt = indexproperty(object_id, name, 'keycnt80'), *
FROM sys.indexes
WHERE object_id = object_id('charge2');
GO
```

## Create function index name
Create a function to return the index name, given the object_id and the index_id
 
```sql
IF OBJECT_ID('dbo.index_name') IS NOT NULL
	DROP FUNCTION dbo.index_name;
GO
```

```sql
CREATE FUNCTION dbo.index_name (@object_id int, @index_id smallint)
RETURNS sysname
AS
BEGIN
  DECLARE @index_name sysname
  SELECT @index_name = name FROM sys.indexes
     WHERE object_id = @object_id and index_id = @index_id
  RETURN(@index_name)
END;
```

Sample usage:

```sql
SELECT dbo.INDEX_NAME(object_id, index_id) AS index_name, *
FROM sys.dm_db_partition_stats
WHERE object_id > 100;
```

## Other DMV (Dynamic management views) for indexes

Look at additional Dynamic Management Objects for indexes

```sql
USE AdventureWorks2012;
```

Usage stats is a VIEW

```sql
SELECT *
FROM sys.dm_db_index_usage_stats 
WHERE database_id = DB_ID(N'AdventureWorks2012')
AND object_id = object_id('Sales.SalesOrderDetail2');
GO
```

Run the following SELECT several times

```sql
SELECT count(notes) FROM Sales.SalesOrderDetail2;
GO
```

Examine usage_stats after running SELECTs

```sql
SELECT *
FROM sys.dm_db_index_usage_stats 
WHERE database_id = DB_ID(N'AdventureWorks2012')
AND object_id = object_id('Sales.SalesOrderDetail2');
GO
```

Now run this query a few times, and look at the view again

```sql
SELECT  * FROM Sales.SalesOrderDetail2
WHERE SalesOrderID = 43680 AND SalesOrderDetailID = 190;
GO
```

```sql
SELECT *
FROM sys.dm_db_index_usage_stats 
WHERE database_id = DB_ID(N'AdventureWorks2012')
AND object_id = object_id('Sales.SalesOrderDetail2');
GO
```

Operational stats is a FUNCTION, and shows low level operations on the specified index(es)

```sql
SELECT *  
FROM sys.dm_db_index_operational_stats (DB_ID(N'AdventureWorks2012'),  object_id('Sales.SalesOrderDetail2'),  null, null) ;
GO
```
