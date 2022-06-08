# Query tuning

## SARG

Use of Search Arguments (SARGS)

A SARG is a condition in the WHERE clause which compares a column of a table to an expression, using any of the comparison operators: >, <, <=, >=, <>


Just because there is a SARG doesn't mean an index on the column will be used. It only means the optimizer will consider using the index and will investigate the cost of using it.

If there is no SARG, the index will not be evaluated for a SEEK operation.

```sql
USE CREDIT

CREATE INDEX member_fname ON member(firstname);
GO
```

These queries have SARGs, and a nonclustered index seek on firstname will be used in all cases; Examine the query plans:

```sql
SELECT * FROM member
WHERE  firstname < 'ABX';
GO
```

```sql
SELECT * FROM member
WHERE  firstname = substring('HABXALSFJA', 2,3);
GO
```

```sql
SELECT * FROM member
WHERE  firstname = 'AB' + 'X';
GO
```

A column used as an argument to a function cannot be part of a SARG

In some cases, you can rewrite your query to turn a non-SARG into a SARG; 

For example, you can rewrite the following substring query into the LIKE query that follows it.

```sql
SET STATISTICS IO ON;
SELECT * FROM member
WHERE substring(firstname, 1,3) = 'ABX';
GO
```

```sql
SELECT * FROM member
WHERE firstname LIKE  'ABX%';
GO
```

```sql
SET STATISTICS IO OFF;
```

Variables are a special case

```sql
DECLARE @name  char(3)
SET @name = 'ABX'
SELECT * FROM member
WHERE  firstname < @name;
```

Not all functions can be used in SARGs.

```sql
SELECT * FROM charge  
WHERE  charge_amt < 2*1;
GO
```

```sql
SELECT * FROM charge  
WHERE  charge_amt < sqrt(4);
GO 
```

Compare the above queries to ones using = instead of <. With =, the optimizer can use the density information to come up with a good row estimate, even if it’s not going to actually perform the function’s calculations.

## Plan guides

```sql
USE AdventureWorks2012;
GO
```

### Object Plan Guide

For plan to be optimized for a particular parameter

```sql
IF EXISTS (SELECT 1
FROM sys.plan_guides
WHERE name = 'plan_US_PersonCountry') 
   EXEC sp_control_plan_guide @operation = N'DROP', @name = 'plan_US_PersonCountry';
GO
```

```sql
IF object_id('Person.GetPersonByCountry') IS NOT NULL
    DROP PROC Person.GetPersonByCountry;
GO
```

```sql
CREATE PROCEDURE  Person.GetPersonByCountry(@Country nchar(2))
AS
SELECT Title, FirstName, LastName, City, CountryRegionCode
           FROM Person.Person as p
           INNER JOIN Person.BusinessEntityAddress AS ea
              ON p.BusinessEntityID = ea.BusinessEntityID
           INNER JOIN Person.Address AS a
              ON ea.AddressID = a.AddressID
           INNER JOIN Person.StateProvince as sp
              ON a.StateProvinceID = sp.StateProvinceID
           WHERE sp.CountryRegionCode = @Country;
RETURN
GO
```

```sql
dbcc freeproccache;
```

```sql
SET STATISTICS IO ON;
GO

EXEC Person.GetPersonByCountry 'FI';
EXEC Person.GetPersonByCountry 'US';
```

```sql
EXEC sp_create_plan_guide @name = 'plan_US_PersonCountry', 
  @stmt = N'SELECT Title, FirstName, LastName, City, CountryRegionCode
           FROM Person.Person as p
           INNER JOIN Person.BusinessEntityAddress AS ea
              ON p.BusinessEntityID = ea.BusinessEntityID
           INNER JOIN Person.Address AS a
              ON ea.AddressID = a.AddressID
           INNER JOIN Person.StateProvince as sp
              ON a.StateProvinceID = sp.StateProvinceID
           WHERE sp.CountryRegionCode = @Country', 
  @type = N'OBJECT', @module_or_batch = N'[Person].[GetPersonByCountry]', 
  @hints = N'OPTION (OPTIMIZE FOR (@Country = N''US''))';
GO
```

Run the queries with the plan guide enabled:

```sql
EXEC Person.GetPersonByCountry 'FI';
EXEC Person.GetPersonByCountry 'US';
```

Disable the plan guide.

```sql
EXEC sp_control_plan_guide N'DISABLE', N'plan_US_PersonCountry';
GO
```

Run the queries without the plan guide

```sql
EXEC Person.GetPersonByCountry 'FI';
EXEC Person.GetPersonByCountry 'US';
```

Enable the plan guide.

```sql
EXEC sp_control_plan_guide N'ENABLE', N'plan_US_PersonCountry';

EXEC Person.GetPersonByCountry 'FI';
EXEC Person.GetPersonByCountry 'US';
```

SQL Plan Guide to Force Parallelism

Force Hint to Limit Parallelization
```sql
DBCC FREEPROCCACHE
GO
```

```sql
USE credit
```

Look at the query plan and note the parallelism

```sql
SELECT * FROM charge ORDER BY charge_amt;
GO
```

```sql
IF EXISTS (SELECT 1
FROM sys.plan_guides
WHERE name = 'plan_1Proc') 
   EXEC sp_control_plan_guide @operation = N'DROP', @name = 'plan_1Proc';
GO
EXEC sp_create_plan_guide 
    @name = N'plan_1Proc', 
    @stmt = N'SELECT * FROM charge ORDER BY charge_amt;', 
    @type = N'SQL',
    @module_or_batch = NULL, 
    @params = NULL, 
    @hints = N'OPTION (MAXDOP 1)';

GO
```

Look at the query plan and note the lack of parallelism
Do NOT include the comment

```sql
SELECT * FROM charge ORDER BY charge_amt;
GO
   
-- Disable the PLAN GUIDE
EXEC sp_control_plan_guide N'DISABLE', N'plan_1Proc';
```

Look at the query plan and note the parallelism

```sql
SELECT * FROM charge ORDER BY charge_amt;
GO
```

Enable the PLAN GUIDE

```sql
EXEC sp_control_plan_guide N'ENABLE', N'plan_1Proc';
```

Look at the query plan and note the lack of parallelism

```sql
SELECT * FROM charge ORDER BY charge_amt;
GO
```

## Multiple NULLS in unique index

Q. How can I have a unique index that allows multiple NULL values?

A: In general, you can't. For the purposes of indexes, all NULLs are considered equal.

However, there are workarounds.
 
In SQL Server you can create a view that contains only the non-null values, and build a unique index on the view. So all non-null values are constrained by the index on the view, but null values have no such constraint.

```sql
USE tempdb;
```

```sql
CREATE TABLE multinulls
(a int null, b char(5) default 'hello' );
GO
```

```sql
CREATE VIEW  v_multinulls
WITH SCHEMABINDING
	AS SELECT a FROM dbo.multinulls
	WHERE a IS NOT null;
GO
```

```sql
CREATE UNIQUE CLUSTERED INDEX  idx1 ON v_multinulls(a);
GO
```

Test the view by inserting into the base table

```sql
INSERT INTO multinulls(a) SELECT 1;
```

```sql
INSERT INTO multinulls(a) SELECT 1; -- error because of duplicate!
```

```sql
INSERT INTO multinulls(a) SELECT 2;
```

```sql
INSERT INTO multinulls(a) SELECT 3;
```

```sql
INSERT INTO multinulls(a) SELECT null;
```

```sql
INSERT INTO multinulls(a) SELECT null; -- no error
```

```sql
INSERT INTO multinulls(a) SELECT null; -- no error
```

```sql
SELECT * FROM multinulls;
GO
```

Updating a NULL will also check the uniqueness

```sql
INSERT INTO multinulls(a,b) SELECT null, 'green';
GO
UPDATE multinulls
 SET a = 2 WHERE b = 'green';
GO
```

in SQL Server, you can create a filtered index

```sql
DROP VIEW v_multinulls;
GO
```

```sql
CREATE UNIQUE INDEX idx2 on multinulls(a)
WHERE a IS NOT NULL;
GO
```