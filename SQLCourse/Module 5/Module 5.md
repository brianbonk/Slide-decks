# Query Processing

## Types of joins

```sql
USE CREDIT;
GO
```

```sql
IF object_id('charge2') IS NOT NULL
	DROP TABLE charge2;
GO
```

```sql
SELECT *
INTO charge2
FROM charge;
```

```sql
IF object_id('member2') IS NOT NULL
	DROP TABLE member2;
GO
```

```sql
SELECT * INTO member2
FROM member;
GO
```

```sql
CREATE CLUSTERED INDEX member_index on member2(member_no);
GO
```

```sql
SELECT *
FROM charge2  c2 JOIN member2 m2 
 ON c2.member_no = m2.member_no
WHERE charge_no < 50;
```

Observe the query plan for the above query
Observe the plan without the WHERE filter

```sql
CREATE  CLUSTERED INDEX charge_member_no on charge2(member_no);
GO
```

```sql
SELECT *
FROM charge2  c2 JOIN member2 m2 
 ON c2.member_no = m2.member_no;
```

Observe the query plan for the above query

Even with clustered indexes on both join columns, a merge join is not used

Recreate one of the indexes as unique

```sql
CREATE UNIQUE CLUSTERED INDEX member_index on member2(member_no)
WITH DROP_EXISTING;
GO
```

```sql
SELECT *
FROM charge2  c2 JOIN member2 m2 
 ON c2.member_no = m2.member_no;
```

Observe the query plan for the above query

## Basic plan icons

When the comment references the executution plan, it means you don't need to actually execute the query

```sql
USE credit
GO

IF object_id('charge2') IS NOT NULL
	DROP TABLE charge2;
GO
```

Copy the charge table

```sql
SELECT * 
INTO charge2
FROM  charge
GO
```


Execution plan will show table scan

```sql
SELECT * FROM charge2
WHERE charge_amt < 2
GO
```

```sql
CREATE INDEX charge2_charge_amt ON charge2(charge_amt)
GO
```

Execution plan will show nonclustered index seek

```sql
SELECT * FROM charge2
WHERE charge_amt < 2
GO
```

Execution plan will show nonclustered index scan

```sql
SELECT avg(charge_amt)
FROM charge2
GO
```

```sql
CREATE UNIQUE CLUSTERED INDEX charge_ident ON charge2(charge_no)
GO
```

Execution plan will show clustered index scan

```sql
SELECT * FROM charge2
WHERE provider_no = 301
GO
```

## Types on union

```sql
USE credit;
GO
```

```sql
IF object_id('newcharge') IS NOT NULL
   DROP TABLE newcharge;
GO
```

```sql
SELECT * INTO newcharge FROM charge;
GO
```

Concat + Sort

Change to UNION ALL to get Concat with no sort

```sql
SELECT * FROM newcharge
WHERE charge_amt between 200 and 205
UNION -- ALL
SELECT * FROM newcharge
WHERE provider_no = 184
```

CONCAT + Hash

```sql
SELECT * FROM newcharge
WHERE charge_amt < 200
UNION
SELECT * FROM newcharge
WHERE provider_no < 478
GO
```

## Bitmap Filters with Star Joins

```sql
USE AdventureWorksDW2012;
GO
```

```sql
SELECT * INTO FactInternetSalesNew
FROM FactInternetSales;
GO
```

```sql
INSERT INTO FactInternetSalesNew
SELECT * FROM FactInternetSales;
GO 3
```

Examine the execution plan for this query and try to tell to your self what is happening

```sql
SELECT * 
FROM dbo.FactInternetSalesNew AS F
INNER JOIN dbo.DimProduct AS D1 ON F.ProductKey = D1.ProductKey
INNER JOIN dbo.DimCustomer AS D2 ON F.CustomerKey = D2.CustomerKey
WHERE D1.StandardCost <= 0.9 AND D2.YearlyIncome <= 10000;
```

## Grouping aggregations

```sql
USE Northwind;
GO
```

In this first query, a nonclustered index will be used to retrieve the data in already sorted sequence, so a stream aggregate can be done. 

Examine the execution plan for this query

```sql
SELECT  employeeID, count(*)
FROM orders
GROUP BY employeeid;
GO
```

In this second query, the optimizer chooses to do a hash aggregate, but when the ORDER BY is added, (remove the comment marker) the plan is changed to do a sort first, and then a stream aggregate.

Examine the execution plan for this query both with and without the ORDER BY

```sql
SELECT employeeID, avg(Freight)
FROM orders
GROUP BY  employeeid
-- ORDER BY employeeid
GO
```

In this third query , the optimizer chooses to do a hash group, but when the ORDER BY is added, the plan is changed to still do a hash aggregate, and do the sorting as the final step.

Examine the execution plan for this query both with and without the ORDER BY

```sql
SELECT productID, avg(quantity)
FROM [order details]
GROUP BY productID
-- ORDER BY productID
GO
```

## Row Mode and Batch Mode for Columnstore Index Processing 

```sql
USE AdventureWorksDW2012
GO
```

Build a columnstore index on a small table

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX csi_FactInternetSales 
ON dbo.FactInternetSales
(
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

The next query is joining the FactInternetSales fact table with the DimDate dimension table, grouping on MonthNumberOfYear and aggregating data on the SalesAmount column to get the total of sales by month for the calendar year 2005.

Look at the query plan

```sql
SELECT d.MonthNumberOfYear,
    SUM(SalesAmount) AS TotalSales
FROM dbo.FactInternetSales AS f
    JOIN dbo.DimDate AS d
    ON f.OrderDateKey = d.DateKey
WHERE CalendarYear = 2005
GROUP BY d.MonthNumberOfYear
```

Drop the columnstore index

```sql
DROP INDEX csi_FactInternetSales ON dbo.FactInternetSales;
GO
```

Now look at the plan for the same query running against the FactInternetSalesBig table in Module 4

```sql
SELECT d.MonthNumberOfYear,
    SUM(SalesAmount) AS TotalSales
FROM dbo.FactInternetSalesBig AS f
    JOIN dbo.DimDate AS d
    ON f.OrderDateKey = d.DateKey
WHERE CalendarYear = 2005
GROUP BY d.MonthNumberOfYear;
GO
```

## Clustered indexes avoid sorting

```sql
USE credit;
GO
```

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

```sql
CREATE CLUSTERED INDEX charge_ident ON charge2(charge_no  ) ;
GO
```

First, look at the query plan when no clustered index supports the sort; there is no index on charge_amt;

```sql
SELECT * FROM  charge2 
ORDER BY charge_amt;
GO
```

```sql
CREATE INDEX charge_amt_index ON charge2(charge_amt);
GO
```

Now look at query plan when a clustered index supports the sort; both ascending and descending

```sql
SELECT * FROM  charge2
ORDER BY charge_no;
GO
```

```sql
SELECT * FROM  charge2
ORDER BY charge_no DESC ;
GO
```

Rebuild the clustered index to be composite

```sql
CREATE CLUSTERED INDEX charge_ident 
      ON charge2(member_no, charge_no)
WITH DROP_EXISTING;
GO
```

Look at query plan

```sql
SELECT * FROM  charge2
ORDER BY member_no , charge_no desc;
GO
```

Look as query plan when the primary sort column is changed

```sql
SELECT * FROM  charge2
ORDER BY charge_no, member_no;
GO
```

Look as query plan when columns are sorted in opposite directions

```sql
SELECT * FROM  charge2
ORDER BY member_no, charge_no DESC;
GO
```

Rebuild the clustered index to be composite with columns sorted in opposite directions

```sql
CREATE CLUSTERED INDEX charge_ident ON charge2(member_no, charge_no DESC)
WITH DROP_EXISTING;
GO
```

Look as query plan when columns are sorted in opposite directions

```sql
SELECT * FROM  charge2
ORDER BY member_no, charge_no DESC;
GO
```

```sql
SELECT * FROM  charge2
ORDER BY member_no , charge_no;
GO
```

```sql
SELECT * FROM  charge2
ORDER BY charge_no, member_no;
GO
```

## Forwarded records

sys.dm_db_index_physical_stats will show FORWARDED/FORWARDING RECORDS
  
```sql
USE pubs
GO
```

```sql
IF object_id('bigrows') IS NOT NULL
	DROP TABLE bigrows;
GO
```

```sql
CREATE TABLE bigrows
(
    a int IDENTITY ,
    b varchar(1600),
    c varchar(1600));
GO
```

```sql
INSERT INTO bigrows VALUES 
	(REPLICATE('a', 1600), ''), 
        (REPLICATE('b', 1600), ''),
	(REPLICATE('c', 1600), ''),
	(REPLICATE('d', 1600), ''),
	(REPLICATE('e', 1600), '');
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO
```

```sql
DBCC TRACEON(3604);
DBCC PAGE(pubs, 1, 518, 1);
GO
```

```sql
UPDATE bigrows 
SET c = REPLICATE('x', 1600)
WHERE a = 3;
GO
```

```sql
DBCC PAGE(pubs, 1, 518, 1);
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('bigrows'), null, null, 'DETAILED');
GO
```

```sql
SELECT *
FROM sys.dm_db_index_physical_stats 
(DB_ID(N'PUBS'),object_id('bigrows'),  null, null,  'DETAILED');
GO
```

Get rid of forward pointers by rebuilding table

```sql
ALTER TABLE bigrows REBUILD;
GO
```

```sql
SELECT *
FROM sys.dm_db_index_physical_stats 
(DB_ID(N'PUBS'),object_id('bigrows'),  null, null,  'DETAILED');
GO
```

## Ghosts records

sys.dm_db_index_physical_stats will show GHOST RECORDS  

Note that GHOST records can be very TRANSIENT on a lightly used system

>You have to act quickly to see them

```sql
USE pubs
GO
```

```sql
IF object_id('smallrows') IS NOT NULL
	DROP TABLE smallrows;
GO
```

```sql
CREATE TABLE smallrows
(
    a int IDENTITY PRIMARY KEY,
    b char(10)
)
GO
```

```sql
INSERT INTO smallrows VALUES
	('row 1'),
        ('row 2'),
        ('row 3'),
        ('row 4'),
        ('row 5');
GO
```

```sql
SELECT * FROM smallrows;
GO
```

```sql
SELECT allocated_page_file_id as PageFID, allocated_page_page_id as PagePID, 
       object_id as ObjectID, partition_id AS PartitionID, 
	   allocation_unit_type_desc as AU_type, page_type as PageType
FROM sys.dm_db_database_page_allocations(db_id('pubs'), object_id('smallrows'), null, null, 'DETAILED');
GO
```

```sql
DBCC TRACEON(3604)
DBCC PAGE(pubs, 1, 516,  1)
```

```sql
DELETE FROM smallrows
WHERE a = 1
GO
```

```sql
DBCC PAGE(pubs, 1, 516,  1)
GO
```

Now delete a row inside a transaction

```sql
BEGIN TRAN
DELETE FROM smallrows
WHERE a = 3
GO
```

```sql
DBCC PAGE(pubs, 1, 516,  1)
GO
```

```sql
SELECT *
FROM sys.dm_db_index_physical_stats 
(DB_ID(N'PUBS'),object_id('smallrows'),  null, null,  'DETAILED')
```

```sql
ROLLBACK TRAN
DBCC PAGE(pubs, 1, 516,  1)
GO
```


TRUNCATE TABLE vs DELETE all rows

```sql
DELETE smallrows;
GO
```

```sql
INSERT INTO smallrows VALUES
	('row 1'),
        ('row 2'),
        ('row 3'),
        ('row 4'),
        ('row 5');
GO
```

```sql
SELECT * FROM smallrows;
GO
```

```sql
TRUNCATE TABLE smallrows;
GO
```

```sql
INSERT INTO smallrows VALUES
	    ('row 1'),
        ('row 2'),
        ('row 3'),
        ('row 4'),
        ('row 5');
GO
```

```sql
SELECT * FROM smallrows;
GO
```

TRUNCATE TABLE can be rolled back

```sql
BEGIN TRAN
GO
```

```sql
TRUNCATE TABLE smallrows;
GO
```

```sql
SELECT * FROM smallrows;
GO
```

```sql
ROLLBACK TRAN;
GO
```

```sql
SELECT * FROM smallrows;
GO
```

## Table level updates (row-at-a-time) vs Index level updates

```sql
USE AdventureWorks2012;
GO
```

```sql
IF object_id('SalesOrderHeader') IS NOT NULL
    DROP TABLE SalesOrderHeader;
GO
```

```sql
SELECT * INTO SalesOrderHeader
FROM Sales.SalesOrderHeader;
GO
```

```sql
SELECT count(*) FROM SalesOrderHeader;
GO
```

```sql
ALTER TABLE SalesOrderHeader  ADD  CONSTRAINT [PK_SalesOrderHeader_SalesOrderID] PRIMARY KEY CLUSTERED 
([SalesOrderID])
GO
```

```sql
CREATE NONCLUSTERED INDEX [IX_SalesOrderHeader_CustomerID] ON [SalesOrderHeader] 
([CustomerID])
GO
```

```sql
CREATE NONCLUSTERED INDEX [IX_SalesOrderHeader_SalesPersonID] ON [SalesOrderHeader] 
([SalesPersonID])
GO
```

```sql
CREATE NONCLUSTERED INDEX [IX_SalesOrderHeader2_CreditCardID] ON [SalesOrderHeader] 
([CreditCardID]);
GO
```

Look at the plan for this update:

```sql
UPDATE SalesOrderHeader
SET  CustomerID = CustomerID + 100000,
CreditCardID = CreditCardID + 100000,
SalesPersonID = SalesPersonID + 1000;
GO
```

Insert more rows:

```sql
INSERT INTO SalesOrderHeader
SELECT  [RevisionNumber]
      ,[OrderDate]
      ,[DueDate]
      ,[ShipDate]
      ,[Status]
      ,[OnlineOrderFlag]
      ,[SalesOrderNumber]
      ,[PurchaseOrderNumber]
      ,[AccountNumber]
      ,[CustomerID]
      ,[SalesPersonID]
      ,[TerritoryID]
      ,[BillToAddressID]
      ,[ShipToAddressID]
      ,[ShipMethodID]
      ,[CreditCardID]
      ,[CreditCardApprovalCode]
      ,[CurrencyRateID]
      ,[SubTotal]
      ,[TaxAmt]
      ,[Freight]
      ,[TotalDue]
      ,[Comment]
      ,[rowguid]
      ,[ModifiedDate]
  FROM [Sales].[SalesOrderHeader];
GO 20
```

```sql
SELECT count(*) FROM SalesOrderHeader;
GO
```

Look at the plan for this update again:

```sql
UPDATE SalesOrderHeader
SET  CustomerID = CustomerID + 100000,
CreditCardID = CreditCardID + 100000,
SalesPersonID = SalesPersonID + 1000;
GO
```

# Using the SHOWPLAN variations

Unless stated, execute each SET statement and each SELECT 

However, once a SET SHOWPLAN option is on, the queries will not actually be executed, but will just display the plan

```sql
USE credit
GO
```

```sql
SET showplan_text ON
GO 
```

```sql
SELECT  * FROM charge
WHERE  charge_amt < 2
GO
```

```sql
SET showplan_all ON
GO 
```

```sql
SELECT  * FROM charge
WHERE charge_amt < 2
GO 
```

```sql
SET showplan_text OFF 
GO
```

```sql
SET showplan_all ON
GO
```

```sql
SELECT  * FROM charge
WHERE charge_amt < 2
GO
```

```sql
SET statistics profile ON
GO
```

```sql
SELECT  * FROM charge
WHERE charge_amt < 2
GO
```

```sql
SET showplan_all OFF
GO
```

```sql
SET statistics profile ON
GO
```

```sql
SELECT  * FROM charge
WHERE charge_amt < 2
GO
```

```sql
SET statistics profile OFF
GO
```

```sql
SET showplan_XML ON
GO
```

```sql
SELECT  * FROM charge
WHERE charge_amt < 2
GO
```

NOTE: In SQL Server 2005, running graphical showplan will always turn any of the SET SHOWPLAN options OFF, and then you must explicity execute a text based SET SHOWPLAN  after running graphical showplan.

In SQL Server 2008 and forward (incl Azure), running graphical showplan will not display a plan when any of the SET SHOWPLAN options is ON