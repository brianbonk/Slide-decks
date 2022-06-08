# Module 2 - File Page and Row Structures

## Metadata for storage

Get start page numbers for each allocation unit

sys.partitions contains object_id and number of rows

```sql
USE pubs
GO

SELECT OBJECT_ID, Rows, Partition_ID 
FROM sys.partitions;

SELECT OBJECT_NAME(OBJECT_ID), Rows, Partition_ID
FROM sys.partitions
WHERE OBJECT_NAME(OBJECT_ID) = 'authors'
	AND index_id  < 2;
```

sys.allocation_units contains a container_id to join with partition_id, and also page counts

```sql
SELECT * FROM sys.allocation_units;
GO

SELECT  OBJECT_NAME(OBJECT_ID), Rows, total_pages
FROM sys.partitions p JOIN sys.allocation_units a
	ON p.partition_id = a.container_id
WHERE OBJECT_NAME(OBJECT_ID) = 'authors'
	AND index_id  < 2;
```

sys.system_internals_allocation_units contains the same data as sys.allocation_units, plus 3 page numbers

```sql
SELECT * FROM sys.system_internals_allocation_units;
GO

SELECT  OBJECT_NAME(OBJECT_ID), Rows, total_pages, first_page, root_page, first_iam_page
FROM sys.partitions p JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE OBJECT_NAME(OBJECT_ID) = 'authors'
	AND index_id  < 2;
```

## Pages

We'll look at a simple page from the pubs database authors table

First take a look at the data

```sql
USE pubs
GO

SELECT * FROM pubs..authors;

DBCC TRACEON(3604);
```

Examine Buffer and Page Header

```sql
DBCC PAGE(pubs, 1, 266, 0);
```

Examine header plus each row
```sql
DBCC PAGE(pubs, 1, 266, 1);
```

Dump the page

```sql
DBCC PAGE(pubs, 1, 266, 2);
```

Examine header plus full details for each row

```sql
DBCC PAGE(pubs, 1, 266, 3);
```

## Getting page numbers

A small table will only return a few rows

```sql
USE pubs;
GO

SELECT * FROM sys.dm_db_database_page_allocations(db_id('pubs'), null, null, null, 'DETAILED');
GO

SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('authors'), null, null, 'DETAILED');
GO

DBCC IND (pubs, authors, -1);
GO
```

A large table will return LOTS of rows, one row for every page of every index, and one row for each page of special storage formats

```sql
USE AdventureWorks2012;
GO

SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID,
	   allocation_unit_type_desc as AU_type, page_type as PageType, 
	   index_id, page_level
FROM sys.dm_db_database_page_allocations(db_id('AdventureWorks2012'), object_id('Sales.SalesOrderHeader'), null, null, 'DETAILED');
GO

DBCC IND (AdventureWorks2012, 'Sales.SalesOrderHeader', -1);
GO
```

For earlier versions:

It's hard to visually scan almost 1000 rows of output to find the information of interest

Create a table to hold the output of DBCC IND

```sql
USE master

IF exists (SELECT 1 FROM sys.tables WHERE name = 'sp_pages')
    DROP TABLE sp_pages
GO

CREATE TABLE sp_pages
(PageFID  tinyint, 
  PagePID int,   
  IAMFID   tinyint, 
  IAMPID  int, 
  ObjectID  int,
  IndexID  tinyint,
  PartitionNumber tinyint,
  PartitionID bigint,
  iam_chain_type  varchar(30),    
  PageType  tinyint, 
  IndexLevel  tinyint,
  NextPageFID  tinyint,
  NextPagePID  int,
  PrevPageFID  tinyint,
  PrevPagePID int, 
  Primary Key (PageFID, PagePID))
```

Examples of use:

Look at small table in pubs

```sql
USE pubs
DECLARE @dbid int
DECLARE @tabid int
DECLARE @indid int
SELECT @dbid = db_id('pubs'), @tabid = object_id('authors'), @indid = -1

 INSERT INTO sp_pages
    EXEC ('DBCC IND ( ' + @dbid + ' , ' + @tabid + ' , '  + @indid + ')'  )
GO

SELECT * FROM sp_pages
GO
```

Look at bigger table in AdventureWorks2012

```sql
USE AdventureWorks2012
GO

TRUNCATE TABLE sp_pages
GO
INSERT INTO sp_pages
    exec ('DBCC IND (''AdventureWorks2012'', ''Sales.SalesOrderHeader'', -1) ')
GO
```

Find first data page

```sql
SELECT  * from sp_pages
where pagetype = 1 and prevpagePID = 0 and prevpageFID = 0
```

How many pages of each type

```sql
SELECT PageType, number = count(*)
FROM sp_pages
GROUP BY PageType
```

How many pages for each index 
You must be in the AdventureWorks database to get the index name

```sql
USE AdventureWorks2012

SELECT Index_ID, name,  number = count(*)
FROM sp_pages join sys.indexes 
	ON IndexID = Index_ID and ObjectID = Object_ID
GROUP BY Index_ID, name
ORDER BY Index_ID
```

fn_physLocFormatter

```sql
USE pubs;
GO

SELECT sys.fn_physLocFormatter (%%physloc%%), *
FROM authors;
GO
```

sys.system_internals_allocation_units

```sql
SELECT  OBJECT_NAME(OBJECT_ID), Rows, total_pages, first_page, root_page, first_iam_page
FROM sys.partitions p JOIN sys.system_internals_allocation_units a
	ON p.partition_id = a.container_id
WHERE OBJECT_NAME(OBJECT_ID) = 'authors'
	AND index_id  < 2;
```

Example: 

0x0A0100000100	-- use the value you get for first_page

Separate into bytes, 2 digits each:  0A 01 00 00 01 00

Reverse bytes: 00 01 00 00 01 0A

First two bytes are file number: 00 01 = File 1

Last four bytes are page number: 0000010A = Page 266

## Extend allocations

```sql
USE pubs
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'bigrows')
   DROP TABLE bigrows;
GO

CREATE TABLE bigrows
(col1 int identity, col2 char(8000) default 'hello');
GO
```

Rows are so big, that each row takes a whole page

```sql
EXEC sp_spaceused bigrows, @updateusage = true;
GO

INSERT INTO bigrows DEFAULT VALUES
EXEC sp_spaceused bigrows, @updateusage = true
GO
```

execute above batch multiple times

first 8 executions reserved one new page each time

after 8 pages, SQL Server allocates 8 pages at a time

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType, 
	   extent_file_id, extent_page_id, is_mixed_page_allocation
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO

CREATE CLUSTERED INDEX col1_indx ON bigrows(col1);
GO

SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType, 
	   extent_file_id, extent_page_id, is_mixed_page_allocation
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO
```

What if we build a clustered index on a bigger table?

```sql
USE pubs;
GO

set nocount on;

IF object_id('bigrows') IS NOT NULL
   DROP TABLE bigrows;
GO

CREATE TABLE bigrows
(col1 int identity, col2 char(8000) default 'default');
GO


INSERT INTO bigrows DEFAULT VALUES
GO 24

SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType, 
	   extent_file_id, extent_page_id, is_mixed_page_allocation
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO

CREATE CLUSTERED INDEX alloc_index on bigrows(col1);
GO

SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType, 
	   extent_file_id, extent_page_id, is_mixed_page_allocation
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO
```

Note that with 24 pages, building the clustered index leaves the initial 8 pages on shared extents

Rerun the script to insert 25 rows, and notice that now all the data pages are in uniform extents, but there is now one page for the index that and one page for the IAM that are in mixed extents

Earlier versions

```sql
DBCC EXTENTINFO ('pubs', 'bigrows')
GO
```

## Sparse columns

Sparse columns are ordinary columns that have an optimized storage for null values. Sparse columns reduce the space requirements for null values at the cost of more overhead to retrieve non-NULL values. Consider using sparse columns when the space saved is at least 20 percent to 40 percent. Sparse columns and column sets are defined by using the CREATE TABLE or ALTER TABLE statements.

Sparse columns can be used with column sets and filtered indexes:

- Column sets
  - INSERT, UPDATE, and DELETE statements can reference the sparse columns by name. However, you can also view and work with all the sparse columns of a table that are combined into a single XML column. This column is called a column set. For more information about column sets, see Use Column Sets.

- Filtered indexes
  - Because sparse columns have many null-valued rows, they are especially appropriate for filtered indexes. A filtered index on a sparse column can index only the rows that have populated values. This creates a smaller and more efficient index. For more information, see Create Filtered Indexes.

Sparse columns and filtered indexes enable applications, such as Windows SharePoint Services, to efficiently store and access a large number of user-defined properties by using SQL Server.

```sql
USE pubs
GO

IF object_id('Products') IS NOT NULL
    DROP TABLE Products;
GO

CREATE TABLE Products(Id int
           , Type       nvarchar(32)
           , ZoomLength nvarchar(8) SPARSE
           , Resolution nvarchar(8) SPARSE
           , WaistSize  int SPARSE
           , Inseam     int SPARSE
           , ProductProperties XML COLUMN_SET FOR ALL_SPARSE_COLUMNS);
GO
```

Insert Product information using sparse columns explicitly just like any other column

```sql
INSERT INTO Products
(Id, Type, ZoomLength, Resolution, WaistSize, Inseam) VALUES
(1001, 'Camera', '3x','5 mb', NULL, NULL),
(1002, 'Camera', '5x','10 mb', NULL, NULL),
(1003, 'Camera', '2x','2 mb', NULL, NULL),
(2001, 'Trousers', NULL, NULL, 36, 34),
(2002, 'Trousers', NULL, NULL, 32, 30),
(2003, 'Trousers', NULL, NULL, 30, 34),
(1005, 'Camera', '2x','2 mb', NULL, NULL),
(1006, 'Camera', '2x','2 mb', NULL, NULL),
(1007, 'Camera', '2x','2 mb', NULL, NULL),
(1008, 'Camera', '2x','2 mb', NULL, NULL),
(2004, 'Trousers', NULL, NULL, 40, 34),
(2005, 'Trousers', NULL, NULL, 36, 34),
(2006, 'Trousers', NULL, NULL, 36, 30),
(2007, 'Trousers', NULL, NULL, 38, 36),
(2008, 'Trousers', NULL, NULL, 40, 34),
(2009, 'Trousers', NULL, NULL, 36, 32),
(2010, 'Trousers', NULL, NULL, 38, 34),
(2011, 'Trousers', NULL, NULL, 36, 32),
(2012, 'Trousers', NULL, NULL, 40, 34)
GO
```


Can Selet sparse columns explicitly just like any other columns

```sql
SELECT Id, Type, WaistSize, Inseam, ZoomLength, Resolution 
FROM Products
GO
```

Select * will return column_set XML

```sql
SELECT * FROM Products;
GO
```

Update a product property explicitly

```sql
UPDATE Products SET ZoomLength='12x' WHERE Id=1003;

SELECT Id, Type, ProductProperties 
FROM Products WHERE Id=1003
GO
```

INSERT PRODUCTS USING COLUMN_SET xml

```sql
INSERT INTO Products(Id, Type, ProductProperties) VALUES 
(1004, 'Camera', '<ZoomLength>10x</ZoomLength><Resolution>10 mb</Resolution>'),
(2050, 'Trousers', '<WaistSize>38</WaistSize><Inseam>32</Inseam>')
GO
```

Select with individual and column set

```sql
SELECT Id, Type,ZoomLength, WaistSize, ProductProperties 
FROM Products where Id in (1004, 2050); 
GO
```

Update using columnset

```sql
UPDATE Products 
SET ProductProperties = '<ZoomLength>20x</ZoomLength><Resolution>12 mb</Resolution>'
WHERE Id=1004;
GO
```

## Sparse and non sparse space used

Compare size of tables, sparse, nonsparse, null, not null

```sql			
USE pubs;
GO
SET NOCOUNT ON;
GO
IF object_id('sparse_nonulls_size') IS NOT NULL
		DROP TABLE sparse_nonulls_size;
GO

CREATE TABLE sparse_nonulls_size
(col1 int IDENTITY,
 col2 datetime SPARSE,
 col3 char(10) SPARSE
 );
GO

IF object_id('nonsparse_nonulls_size') IS NOT NULL
		DROP TABLE nonsparse_nonulls_size;
GO

CREATE TABLE nonsparse_nonulls_size
(col1 int IDENTITY,
 col2 datetime,
 col3 char(10)
 );
GO

IF object_id('sparse_nulls_size') IS NOT NULL
		DROP TABLE sparse_nulls_size;
GO

CREATE TABLE sparse_nulls_size
(col1 int IDENTITY,
 col2 datetime SPARSE,
 col3 char(10) SPARSE
 );
GO

IF object_id('nonsparse_nulls_size') IS NOT NULL
		DROP TABLE nonsparse_nulls_size;
GO

CREATE TABLE nonsparse_nulls_size
(col1 int IDENTITY,
 col2 datetime,
 col3 char(10)
 );
GO
```			

```sql
DECLARE @num int
SET @num = 1
WHILE @num < 200001
BEGIN
  INSERT INTO sparse_nonulls_size
	SELECT GETDATE(), 'my message';
  INSERT INTO nonsparse_nonulls_size
	SELECT GETDATE(), 'my message';
  INSERT INTO sparse_nulls_size
	SELECT NULL, NULL;
  INSERT INTO nonsparse_nulls_size
	SELECT NULL, NULL;
  SET @num = @num + 1;
END;
GO

SELECT object_name(object_id) as 'table_name', rows, data_pages
FROM sys.allocation_units au 
    JOIN sys.partitions p
       ON p.partition_id = au.container_id
WHERE object_name(object_id) LIKE '%sparse%size';
GO
```			

## Pages for special storage formats

```sql
USE pubs 
GO

IF object_id('hugerows') IS NOT NULL
   DROP TABLE hugerows;
GO

CREATE TABLE hugerows 
   (a char(1000),  
    b varchar(8000),
    c text );
GO

INSERT INTO hugerows 
     SELECT REPLICATE('a', 1000), REPLICATE('b', 1000),
	      REPLICATE('c', 50);
go
```

Notice that even a very small amount of data in a text column will
still use LOB pages

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

Now insert a row that will cause row-overflow

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('a', 1000), REPLICATE('b', 8000),
	      REPLICATE('c', 50);
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('a', 1000), REPLICATE('b', 1000),
	      REPLICATE('c', 10000);
```

Replicate into a text column cannot insert more than 8000 bytes

```sql
SELECT datalength(a), datalength(b), datalength(c) FROM hugerows
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

Create a table with a fixed length column, a varchar(8000) column and a varchar(max) column

```sql
IF OBJECT_ID('hugerows') IS NOT NULL
   DROP TABLE hugerows;
GO

CREATE TABLE hugerows
   (a char(1000),
    B varchar(8000),
    c varchar(max) );
GO
```

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('a', 1000), REPLICATE('b', 1000),
	      REPLICATE(CAST ('c' as varchar(max)), 50);
GO
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

After the first insert, I only see the regular data page 
and its IAM, because the 50 byte column is treated 
as a regular varchar. However, after the second insert, 

It will have LOB data pages. 
There will one page for the LOB IAM, and 4 LOB pages 
to hold the 30000 bytes of LOB data and the root structure.  

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('g', 1000), REPLICATE('h', 1000),
	      REPLICATE(CAST('i' as varchar(max)), 30000);
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

Now add a row that will have both row-overflow and LOB data

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('g', 1000), REPLICATE('h', 8000),
	      REPLICATE(CAST('i' as varchar(max)), 30000);
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```

A varchar(MAX) column that is less than 8000 bytes, but that won't fit 
within the row is stored on LOB pages, not row-overflow

```sql
INSERT INTO hugerows 
     SELECT REPLICATE('g', 1000), REPLICATE('h', 8000),
	      REPLICATE(CAST('i' as varchar(max)), 8000);
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('hugerows'), null, null, 'DETAILED');
GO
```