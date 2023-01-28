-- create database
create database <your own database>

--use new database
use <your own database>;

--create schema
create schema nyctaxi

-- create credentials for containers in storage account
CREATE DATABASE SCOPED CREDENTIAL NYCData
WITH IDENTITY='SHARED ACCESS SIGNATURE',  
SECRET = '<your own SAS'
GO

-- create the external data source
CREATE EXTERNAL DATA SOURCE ChesterDataSource WITH (
    LOCATION = '<your own blob storage>',
    CREDENTIAL = NYCData
);

-- create the external file format
CREATE EXTERNAL FILE FORMAT SynapseParquetFormat
WITH ( 
        FORMAT_TYPE = PARQUET
     );

-- create nyctaxi.allparquet view
create or alter view nyctaxi.allparquet as
SELECT
    *
FROM
    OPENROWSET(
        BULK '<your own blob storage>/nyctaxi/parquet/yellow_tripdata_*.parquet'
        ,FORMAT = 'PARQUET'
    ) AS [result]



-- create nyctaxi.externaltableallparquet
create external table nyctaxi.externaltableallparquet
with (
    LOCATION = 'nyctaxi/allparquetexternaltable/'
    ,DATA_SOURCE = ChesterDataSource
    ,FILE_FORMAT = SynapseParquetFormat
)
as

SELECT
    *
FROM
    OPENROWSET(
        BULK '<your own blob storage>//nyctaxi/parquet/yellow_tripdata_*.parquet',
        FORMAT = 'PARQUET'
    ) AS [result]


-- create nyctaxi.allcsv view
create or alter view nyctaxi.allcsv as
SELECT
    *
FROM
    OPENROWSET(
        BULK '<your own blob storage>/nyctaxi/csv/yellow_tripdata_*.csv'
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
