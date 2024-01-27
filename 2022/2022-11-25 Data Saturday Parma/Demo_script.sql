
--- the raw parquet files from NYC taxi
select count_big(*) from nyctaxi.allparquet
-- exectution time - aprox: 01.853 sec

--- the computed external table
select count_big(*) from nyctaxi.externaltableallparquet
-- exectution time - aprox: 00.995 sec

--- just to compare using CSV files from the serverless SQL endpoint
--- this does not finish...
select count_big(*) from nyctaxi.allcsv



























-- filter predicate
--- the raw parquet files from NYC taxi
select count_big(*) from nyctaxi.allparquet
where 1=1
    and passenger_count = 1
-- exectution time - aprox: 23.015 sec

--- the computed external table
select count_big(*) from nyctaxi.externaltableallparquet
where 1=1
    and passenger_count = 1
-- exectution time - aprox: 19.694 sec




























-- what sql server are we getting from
-- Synapse serverless SQL?
select @@version






















-- lets look at the serverproperties
select 
serverproperty('ProductVersion') as [version]
,serverproperty('Edition') as [edition]
,serverproperty('EngineEdition') as [engine edition]























-- what about the recovery model and compatibility levels?
select [name], [compatibility_level], [recovery_model_desc] from [sys].[databases] where [name] = 'Chester'

















-- what about the data files?
-- look at the max size
select [file_id], [file_guid], [type], [type_desc], [data_space_id], [name], [physical_name], [size], [max_size], [growth] from [sys].[database_files]



-----------------------------------------
--------- BACK TO THE SLIDES ------------
-----------------------------------------




















-- do we have a tempdb?
select * from tempdb.information_schema.tables

































-- look at the temp db files
SELECT
[file_id], [file_guid], [type], [type_desc], [data_space_id], [name], [physical_name], [max_size]*8/1024/1024 as [max_size_gb], [growth]
FROM [tempdb].[sys].[database_files]



--- the same query as before - can we query the tempdb database
--- the raw parquet files from NYC taxi
select count_big(*) from nyctaxi.allparquet
where 1=1
    and passenger_count = 1
-- exectution time - aprox: 23.015 sec

--- run this in another query window
select * from tempdb.information_schema.tables

select * from tempdb.dbo.[tablename]







-----------------------------------------
--------- BACK TO THE SLIDES ------------
-----------------------------------------




