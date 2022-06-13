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