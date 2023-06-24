-- create database
-- notice the collate part, this is decribed as best practice for reading csv files in UTF8 format
create database APACDemo COLLATE Latin1_General_100_BIN2_UTF8;

--use new database
use APACDemo;

--create schema
create schema nyctaxi

-- create master key
create master key encryption by password = 'StrongAndSecretPassword!123';

-- create credentials for containers in storage account
CREATE DATABASE SCOPED CREDENTIAL NYCDataAPACDemo
WITH IDENTITY='SHARED ACCESS SIGNATURE',  
SECRET = '<GET SECRET FROM AZURE>'
GO

-- create the external data source
CREATE EXTERNAL DATA SOURCE APACDemoDataSource WITH (
    LOCATION = 'https://<your storage account name>.dfs.core.windows.net',
    CREDENTIAL = NYCDataAPACDemo
);

-- create the external file format
CREATE EXTERNAL FILE FORMAT APACDemoSynapseParquetFormat
WITH ( 
        FORMAT_TYPE = PARQUET
     );

-- create nyctaxi.allparquet view
create or alter view nyctaxi.allparquet as
SELECT
    *
FROM
    OPENROWSET(
        BULK 'https://<your storage account name>.dfs.core.windows.net/nyctaxi/parquetsmalldataset/yellow_tripdata_*.parquet'
        ,FORMAT = 'PARQUET'
    ) AS [result]



-- create nyctaxi.externaltableallparquet
create external table nyctaxi.externaltableallparquet
with (
    LOCATION = 'nyctaxi/allparquetexternaltable/'
    ,DATA_SOURCE = APACDemoDataSource
    ,FILE_FORMAT = APACDemoSynapseParquetFormat
)
as

SELECT
    *
FROM
    OPENROWSET(
        BULK 'https://<your storage account name>.dfs.core.windows.net/nyctaxi/parquetsmalldataset/yellow_tripdata_*.parquet',
        FORMAT = 'PARQUET'
    ) AS [result]


-- create nyctaxi.allcsv view
create or alter view nyctaxi.allcsv as
SELECT
    *
FROM
    OPENROWSET(
        BULK 'https://<your storage account name>.dfs.core.windows.net/nyctaxi/csvsmalldataset/yellow_tripdata_*.csv'
        ,FORMAT = 'CSV'
        ,PARSER_VERSION = '2.0'
        ,FIRST_ROW = 2
    ) 
with (
    vendor_name	varchar(8000)
    ,Trip_Pickup_DateTime varchar(8000)
    ,Trip_Dropoff_DateTime	varchar(8000)
    ,Passenger_Count	bigint
    ,Trip_Distance	float	
    ,Start_Lon	float	
    ,Start_Lat	float	
    ,Rate_Code	float	
    ,store_and_forward	float	
    ,End_Lon	float	
    ,End_Lat	float	
    ,Payment_Type	varchar(8000)
    ,Fare_Amt	float	
    ,surcharge	float	
    ,mta_tax	float	
    ,Tip_Amt	float	
    ,Tolls_Amt	float	
    ,Total_Amt	float	
) AS [result]


use master
drop database APACDemo
