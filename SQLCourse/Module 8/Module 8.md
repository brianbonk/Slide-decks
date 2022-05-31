# Index tuning

## Index with included columns

Demonstrate the value of indexes with Included Columns

Run each section between comment lines separately

```sql
USE AdventureWorks2012;
```

Set the database to bulk_logged recovery prior to copying tables

```sql
ALTER DATABASE AdventureWorks2012
	SET RECOVERY bulk_logged;
```

```sql
IF ( OBJECT_ID('Person.Address1') is not null)
	DROP TABLE Person.Address1;
```

```sql
IF ( OBJECT_ID('Person.Address2') is not null)
	DROP TABLE Person.Address2;
```

```sql
IF ( OBJECT_ID('Person.Address3') is not null)
	DROP TABLE Person.Address3;
```

```sql
IF ( OBJECT_ID('Person.Address4') is not null)
	DROP TABLE Person.Address4;
```

Create four copies of the Person.Address table

```sql
SELECT * INTO Person.Address1 
	FROM Person.Address;
```

Create an index with two included columns

```sql
CREATE INDEX IX_Address_City 
	on [Person].[Address1] (City, StateProvinceID)
    INCLUDE(AddressLine1, AddressLine2);
GO
```

```sql
SELECT * INTO Person.Address2 
	FROM Person.Address;
```

Create a 'regular' index with no included columns;

All four columns are keys, and included at all index levels

```sql
CREATE INDEX IX_Address_City 
	on [Person].[Address2] 
		(City, StateProvinceID, AddressLine1, AddressLine2);
GO
```

```sql
SELECT * INTO Person.Address3 
	FROM Person.Address;
```

```sql
ALTER TABLE Person.Address3 
	ALTER COLUMN AddressLine2 nchar(350);
```

Create an index with two included columns

```sql
CREATE INDEX IX_Address_City 
	on [Person].[Address3] (City, StateProvinceID)
    INCLUDE(AddressLine1, AddressLine2);
GO
```

```sql
SELECT * INTO Person.Address4 
	FROM Person.Address;
```

```sql
ALTER TABLE Person.Address4 
	ALTER COLUMN AddressLine2 nchar(350);
GO
```

Create an index with no included columns and wide keys;

All four columns are keys, and included at all index levels

```sql
CREATE INDEX IX_Address_City 
	on [Person].[Address4] 
		(City, StateProvinceID, AddressLine1, AddressLine2);
```

Note that the space used for the Address2 index is only slightly more than for the index on Address1, because it contains all 4 keys in all levels of the index. After the column for AddressLine2 is increased to be very wide, the difference in index size between the tables Address3 and Address4 is much greater

```sql
EXEC sp_spaceused 'Person.Address1';
EXEC sp_spaceused 'Person.Address2';

EXEC sp_spaceused 'Person.Address3';
EXEC sp_spaceused 'Person.Address4';
```

A separate script creates this view


```sql
SELECT * FROM  get_index_columns 
WHERE object_name = 'Address1';

SELECT * FROM  get_index_columns 
WHERE object_name = 'Address2';

SELECT * FROM  get_index_columns 
WHERE object_name = 'Address3';

SELECT * FROM  get_index_columns 
WHERE object_name = 'Address4';
```


A separate script creates this procedure

```sql
EXEC sp_helpindex2 'Person.Address1';
```

## Which column should come first in a composite index?

```sql
USE credit;
GO
```

```sql
DBCC SHOW_STATISTICS(charge, charge_charge_amt);
GO
```

```sql
IF object_id('newmember') IS NOT NULL
	DROP TABLE newmember;
GO
SELECT * INTO newmember
  FROM member;
GO
```

The member table has lots of duplication for lastname but firstname is almost unique

Run these queries to see the distribution of names, and to choose a specific lastname and firstname value to use in the subsequent examples

```sql
--SELECT a firstname from the results
SELECT firstname, COUNT(*)
FROM newmember
GROUP BY firstname;
GO
``` 

```sql
-- SELECT a lastname from the results
SELECT lastname, COUNT(*)
FROM newmember
GROUP BY lastname;
GO
```


Which is better? (lastname, firstname)  or (firstname, lastname)

See which what indexes are used in the following situations

```sql
CREATE INDEX nameindex on newmember(firstname, lastname);
GO
```

```sql
DBCC SHOW_STATISTICS(newmember, nameindex);
```

Look at the plans

```sql
SELECT * FROM newmember
WHERE lastname = 'CHEN';  -- substitute the lastname you chose
```

```sql
SELECT * FROM newmember
WHERE firstname = 'VJAY'; -- substitute the firstname you chose
```

Now reverse the index

```sql
CREATE INDEX nameindex on newmember(lastname, firstname)  WITH DROP_EXISTING;
GO
```

```sql
DBCC SHOW_STATISTICS(newmember, nameindex);
GO
```

Look at the plans

```sql
SELECT * FROM newmember
WHERE lastname = 'CHEN';  -- substitute the lastname you chose
```

```sql
SELECT * FROM newmember
WHERE firstname = 'VJAY'; -- substitute the firstname you chose
```

## Helper queries - to use when you need them

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.

### sp_helpindex2.sql

So, what are the included columns?!

This is a MODIFIED sp_helpindex script that includes INCLUDED columns AND filtered index columns.

```sql
USE master;
GO

create procedure sp_helpindex2
	@objname nvarchar(776)		-- the table to check for indexes
AS

	SET NOCOUNT ON

	DECLARE @objid int,			-- the object id of the table
			@indid smallint,	-- the index id of an index
			@groupid int,  		-- the filegroup id of an index
			@indname sysname,
			@groupname sysname,
			@status int,
			@keys nvarchar(2126),	--Length (16*max_identifierLength)+(15*2)+(16*3)
			@inc_columns	nvarchar(max),
			@inc_Count		smallint,
			@loop_inc_Count		smallint,
			@dbname	sysname,
			@ignore_dup_key	bit,
			@is_unique		bit,
			@is_hypothetical	bit,
			@is_primary_key	bit,
			@is_unique_key 	bit,
			@auto_created	bit,
			@no_recompute	bit,
			@filter_definition	nvarchar(max);

	-- Check to see that the object names are local to the current database.
	SELECT @dbname = parsename(@objname,3)
	IF @dbname is null
		SELECT @dbname = db_name();
	ELSE IF @dbname <> db_name()
		BEGIN 
			RAISERROR(15250,-1,-1);
			RETURN (1);
		END 

	-- Check to see the the table exists and initialize @objid.
	SELECT @objid = object_id(@objname);
	IF @objid is NULL
	BEGIN 
		RAISERROR(15009,-1,-1,@objname,@dbname);
		RETURN (1);
	END 

	-- OPEN CURSOR OVER INDEXES  
	DECLARE ms_crs_ind CURSOR LOCAL STATIC FOR
		SELECT i.index_id, i.data_space_id, i.name,
			i.ignore_dup_key, i.is_unique, i.is_hypothetical, i.is_primary_key, i.is_unique_constraint,
			s.auto_created, s.no_recompute, i.filter_definition
		FROM sys.indexes i join sys.stats s
			on i.object_id = s.object_id and i.index_id = s.stats_id
		WHERE i.object_id = @objid;
	OPEN ms_crs_ind;
	FETCH ms_crs_ind into @indid, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition;

	-- IF NO INDEX, QUIT
	IF @@fetch_status < 0
	BEGIN 
		DEALLOCATE ms_crs_ind;
		RAISERROR(15472,-1,-1,@objname); -- Object does not have any indexes.
		RETURN (0);
	END 

	-- create temp tables
	CREATE TABLE #spindtab
	(
		index_name			sysname	collate database_default NOT NULL,
		index_id			int,
		ignore_dup_key		bit,
		is_unique			bit,
		is_hypothetical		bit,
		is_primary_key		bit,
		is_unique_key		bit,
		auto_created		bit,
		no_recompute		bit,
		groupname			sysname collate database_default NULL,
		index_keys			nvarchar(2126)	collate database_default NOT NULL, -- see @keys above for length descr
		filter_definition	nvarchar(max),
		inc_Count			smallint,
		inc_columns			nvarchar(max)
	);

	CREATE TABLE #IncludedColumns
	(	RowNumber	smallint,
		[Name]	nvarchar(128)
	);

	-- Now check out each index, figure out its type and keys and
	--	save the info in a temporary table that we'll print out at the end.
	while @@fetch_status >= 0
	BEGIN 
		-- First we'll figure out what the keys are.
		DECLARE @i int, @thiskey nvarchar(131); -- 128+3

		SELECT @keys = index_col(@objname, @indid, 1), @i = 2;
		IF (indexkey_property(@objid, @indid, 1, 'isdescending') = 1)
			SELECT @keys = @keys  + '(-)';

		SELECT @thiskey = index_col(@objname, @indid, @i);
		IF ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1))
			SELECT @thiskey = @thiskey + '(-)';

		while (@thiskey is not null )
		BEGIN 
			SELECT @keys = @keys + ', ' + @thiskey, @i = @i + 1;
			SELECT @thiskey = index_col(@objname, @indid, @i);
			IF ((@thiskey is not null) and (indexkey_property(@objid, @indid, @i, 'isdescending') = 1)) 
				SELECT @thiskey = @thiskey + '(-)';
		END 

		-- Second, we'll figure out what the included columns are.
		SELECT @inc_Count = count(*)
		FROM
		sys.tables AS tbl
		INNER JOIN sys.indexes AS si 
			ON (si.index_id > 0 
				AND si.is_hypothetical = 0) 
				AND (si.object_id=tbl.object_id)
		INNER JOIN sys.index_columns AS ic 
			ON (ic.column_id > 0 
				AND (ic.key_ordinal > 0 or ic.partition_ordinal = 0 or ic.is_included_column != 0)) 
				AND (ic.index_id=CAST(si.index_id AS int) AND ic.object_id=si.object_id)
		INNER JOIN sys.columns AS clmns 
			ON clmns.object_id = ic.object_id 
			AND clmns.column_id = ic.column_id
		WHERE ic.is_included_column = 1 and
			(si.index_id = @indid) and 
			(tbl.object_id= @objid);

		IF @inc_Count > 0
		BEGIN 
			DELETE FROM #IncludedColumns;
			INSERT #IncludedColumns
				SELECT ROW_NUMBER() OVER (ORDER BY clmns.column_id) 
				, clmns.name 
			FROM
			sys.tables AS tbl
			INNER JOIN sys.indexes AS si 
				ON (si.index_id > 0 
					AND si.is_hypothetical = 0) 
					AND (si.object_id=tbl.object_id)
			INNER JOIN sys.index_columns AS ic 
				ON (ic.column_id > 0 
					AND (ic.key_ordinal > 0 or ic.partition_ordinal = 0 or ic.is_included_column != 0)) 
					AND (ic.index_id=CAST(si.index_id AS int) AND ic.object_id=si.object_id)
			INNER JOIN sys.columns AS clmns 
				ON clmns.object_id = ic.object_id 
				AND clmns.column_id = ic.column_id
			WHERE ic.is_included_column = 1 and
				(si.index_id = @indid) and 
				(tbl.object_id= @objid);
			
			SELECT @inc_columns = [Name] FROM #IncludedColumns WHERE RowNumber = 1;

			SET @loop_inc_Count = 1;

			WHILE @loop_inc_Count < @inc_Count
			BEGIN 
				SELECT @inc_columns = @inc_columns + ', ' + [Name] 
					FROM #IncludedColumns WHERE RowNumber = @loop_inc_Count + 1;
				SET @loop_inc_Count = @loop_inc_Count + 1;
			END
		END
	
		SELECT @groupname = null;
		SELECT @groupname = name FROM sys.data_spaces WHERE data_space_id = @groupid;

		-- INSERT ROW FOR INDEX
		INSERT INTO #spindtab values (@indname, @indid, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @groupname, @keys, @filter_definition, @inc_Count, @inc_columns);

		-- Next index
		FETCH ms_crs_ind into @indid, @groupid, @indname, @ignore_dup_key, @is_unique, @is_hypothetical,
			@is_primary_key, @is_unique_key, @auto_created, @no_recompute, @filter_definition;
	END
	DEALLOCATE ms_crs_ind;

	-- DISPLAY THE RESULTS
	SELECT
		'index_name' = index_name,
		'index_description' = convert(varchar(210), --bits 16 off, 1, 2, 16777216 on, located on group
				CASE WHEN index_id = 1 then 'clustered' ELSE 'nonclustered' END 
				+ CASE WHEN ignore_dup_key <>0 then ', ignore duplicate keys' ELSE '' END 
				+ CASE WHEN is_unique <>0 then ', unique' ELSE '' END 
				+ CASE WHEN is_hypothetical <>0 then ', hypothetical' ELSE '' END 
				+ CASE WHEN is_primary_key <>0 then ', primary key' ELSE '' END 
				+ CASE WHEN is_unique_key <>0 then ', unique key' ELSE '' END 
				+ CASE WHEN auto_created <>0 then ', auto create' ELSE '' END 
				+ CASE WHEN no_recompute <>0 then ', stats no recompute' ELSE '' END 
				+ ' located on ' + groupname),
		'index_keys' = index_keys,
		--'num_included_columns' = inc_Count,
		'included_columns' = inc_columns,
		'filter_definition' = filter_definition
	FROM #spindtab
	ORDER BY index_name;

	RETURN (0); -- sp_helpindex2
GO

EXEC sys.sp_MS_marksystemobject 'sp_helpindex2';
GO
```

### Get Index columns

This view will list all the index columns for a given index on a given table in the current database. 

You can add additional filters to just look for indexes on one particular table

For each column in each index, the procedure indicates whether the column is a regular key column or an included column

Disclaimer: This script, is provided for informational purposes only and or the author of this script makes no warranties, either express or implied.

This view will list all the index columns for a given index on a given table in the AdventureWorks database. 

If the table name is omitted, all columns for ALL indexes will be returned.

For each column, the procedure indicates whether the column is a regular key column or an included column

```sql
USE AdventureWorks2012;
GO
IF object_id('get_index_columns') IS NOT NULL
	DROP VIEW get_index_columns;
GO

CREATE  VIEW get_index_columns
AS
SELECT object_name(ic.object_id) as object_name , 
       index_name = i.name, 'column' = c.name, 
       'column usage' = CASE ic.is_included_column
			WHEN 0 then 'KEY'
			ELSE 'INCLUDED' 
          END
 FROM sys.index_columns ic JOIN sys.columns  c
			ON ic.object_id = c.object_id
			AND ic.column_id = c.column_id
        JOIN sys.indexes i
			ON i.object_id = ic.object_id
		    AND i.index_id = ic.index_id;
GO
```

### sp_indexinfo


```sql
USE master 
GO 
IF OBJECT_ID('sp_indexinfo') IS NOT NULL DROP PROC sp_indexinfo 
GO 

CREATE PROCEDURE sp_IndexInfo 
 @tblPat sysname = '%' 
,@missing_ix tinyint = 0 
AS 

WITH key_columns AS 
( 
SELECT 
 c.OBJECT_ID 
,c.name AS column_name 
,ic.key_ordinal 
,ic.is_included_column 
,ic.index_id 
,ic.is_descending_key 
FROM sys.columns AS c 
 INNER JOIN sys.index_columns AS ic ON c.OBJECT_ID = ic.OBJECT_ID AND ic.column_id = c.column_id 
) 
, physical_info AS 
( 
SELECT p.OBJECT_ID, p.index_id, ds.name AS location, SUM(p.rows) AS rows, SUM(a.total_pages) AS pages 
FROM sys.partitions AS p 
 INNER JOIN sys.allocation_units AS a ON p.hobt_id = a.container_id 
 INNER JOIN sys.data_spaces AS ds ON a.data_space_id = ds.data_space_id 
GROUP BY OBJECT_ID, index_id, ds.name 
) 
SELECT 
 OBJECT_SCHEMA_NAME(i.OBJECT_ID) AS schema_name 
,OBJECT_NAME(i.OBJECT_ID) AS table_name 
,i.name AS index_name 
,CASE i.type 
  WHEN 0 THEN 'heap' 
  WHEN 1 THEN 'cl' 
  WHEN 2 THEN 'nc' 
  WHEN 3 THEN 'xml' 
  ELSE CAST(i.type AS VARCHAR(2)) 
 END 
 AS type 
,i.is_unique 
,CASE 
  WHEN is_primary_key = 0 AND is_unique_constraint = 0 THEN 'no' 
  WHEN is_primary_key = 1 AND is_unique_constraint = 0 THEN 'PK' 
  WHEN is_primary_key = 0 AND is_unique_constraint = 1 THEN 'UQ' 
 END 
 AS cnstr 
,STUFF((SELECT CAST(', ' + kc.column_name + CASE kc.is_descending_key 
                                             WHEN 0 THEN ''  
                                             ELSE ' DESC'  
                                             END 
               AS VARCHAR(MAX)) 
 AS [text()]  
FROM key_columns AS kc 
WHERE i.OBJECT_ID = kc.OBJECT_ID AND i.index_id = kc.index_id AND kc.is_included_column = 0 
ORDER BY key_ordinal  
FOR XML PATH('')  
 ), 1, 2, '') AS key_columns 
,STUFF((SELECT CAST(', ' + column_name AS VARCHAR(MAX)) AS [text()] 
  FROM key_columns AS kc 
  WHERE i.OBJECT_ID = kc.OBJECT_ID AND i.index_id = kc.index_id AND kc.is_included_column = 1 
  ORDER BY key_ordinal 
  FOR XML PATH('') 
 ), 1, 2, '') AS included_columns 
--,i.filter_definition -- 2008 
,p.location 
,p.rows 
,p.pages 
,CAST((p.pages * 8.00) / 1024 AS decimal(9,2)) AS MB 
,s.user_seeks 
,s.user_scans 
,s.user_lookups 
,s.user_updates 
FROM sys.indexes AS i 
 LEFT OUTER JOIN physical_info AS p 
  ON i.OBJECT_ID = p.OBJECT_ID AND i.index_id = p.index_id 
 LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s 
  ON s.OBJECT_ID = i.OBJECT_ID AND s.index_id = i.index_id AND s.database_id = DB_ID() 
WHERE OBJECTPROPERTY(i.OBJECT_ID, 'IsMsShipped') = 0 
 AND OBJECTPROPERTY(i.OBJECT_ID, 'IsTableFunction') = 0 
 AND OBJECT_NAME(i.OBJECT_ID) LIKE @tblPat 
ORDER BY table_name, index_name;  

IF @missing_ix = 1 
BEGIN 
SELECT 
 OBJECT_SCHEMA_NAME(d.OBJECT_ID) AS schema_name   
,OBJECT_NAME(d.OBJECT_ID) AS table_name   
,'CREATE INDEX <IndexName> ON ' + OBJECT_SCHEMA_NAME(d.OBJECT_ID) + '.' + OBJECT_NAME(d.OBJECT_ID) + ' '   
 + '(' + COALESCE(d.equality_columns + COALESCE(', ' + d.inequality_columns, ''), d.inequality_columns) + ')'   
 + COALESCE(' INCLUDE(' + d.included_columns + ')', '') 
 AS ddl 
,s.user_seeks 
,s.user_scans 
,s.avg_user_impact 
FROM sys.dm_db_missing_index_details AS d 
 INNER JOIN  sys.dm_db_missing_index_groups AS g 
  ON d.index_handle = g.index_handle 
 INNER JOIN sys.dm_db_missing_index_group_stats AS s 
  ON g.index_group_handle = s.group_handle 
WHERE OBJECT_NAME(d.OBJECT_ID) LIKE @tblPat 
AND d.database_id = DB_ID() 
ORDER BY avg_user_impact DESC ;
END 
GO  

EXEC sp_MS_Marksystemobject 'sp_IndexInfo';
```