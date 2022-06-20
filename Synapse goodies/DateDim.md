# Date dimension
Based on Microsoft AdventureWorks sample database.
Reference: https://docs.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver16&tabs=ssms
## Create Table

```python
%%sql
/* Modified version of install script for [dbo].[DimDate] */
CREATE TABLE IF NOT EXISTS dim_date
(
    DateKey int NOT NULL,
    FullDateAlternateKey date NOT NULL,
    DayNumberOfWeek tinyint NOT NULL,
    EnglishDayNameOfWeek varchar(10) NOT NULL,
    SpanishDayNameOfWeek varchar(10) NOT NULL,
    FrenchDayNameOfWeek varchar(10) NOT NULL,
    DayNumberOfMonth tinyint NOT NULL,
    DayNumberOfYear smallint NOT NULL,
    WeekNumberOfYear tinyint NOT NULL,
    EnglishMonthName varchar(10) NOT NULL,
    SpanishMonthName varchar(10) NOT NULL,
    FrenchMonthName varchar(10) NOT NULL,
    MonthNumberOfYear tinyint NOT NULL,
    CalendarQuarter tinyint NOT NULL,
    CalendarYear smallint NOT NULL,
    CalendarSemester tinyint NOT NULL,
    FiscalQuarter tinyint NOT NULL,
    FiscalYear smallint NOT NULL,
    FiscalSemester tinyint NOT NULL
)
USING PARQUET;

```
## Define Date Range
Use date range to create a list from which we "calculate" additional columns using a temporary view

```python
%%pyspark
from pyspark.sql.functions import sequence, to_date, explode, col
df = spark.sql("select sequence(to_date('2020-01-01'), to_date('2049-12-31'), interval 1 day) as date").withColumn("date", explode(col("date")))
df.createOrReplaceTempView("datelist")
```
## Populate Date Dimension
Adapted source material to use in Spark Data lake.
Reference: https://sqldusty.com/2014/07/17/script-to-populate-adventureworksdw-dimdate/
Spark datetime patterns.
Reference: https://spark.apache.org/docs/latest/sql-ref-datetime-pattern.html
Reference: https://dwgeek.com/spark-sql-date-and-timestamp-functions-and-examples.html/

```python
insert into dim_date
(
    DateKey, 
    FullDateAlternateKey, 
    DayNumberOfWeek, 
    EnglishDayNameOfWeek, 
    SpanishDayNameOfWeek, 
    FrenchDayNameOfWeek, 
    DayNumberOfMonth, 
    DayNumberOfYear, 
    WeekNumberOfYear, 
    EnglishMonthName, 
    SpanishMonthName, 
    FrenchMonthName, 
    MonthNumberOfYear, 
    CalendarQuarter, 
    CalendarYear, 
    CalendarSemester, 
    FiscalQuarter, 
    FiscalYear, 
    FiscalSemester
)
select
    year(date) * 10000 + month(date) * 100 + dayofmonth(date) as DateKey
    ,date as FullDate
    ,((dayofweek(date)+5)%7)+1 AS DayNumberOfWeek  /* Monday = 1 as first day of week. Reference: https://stackoverflow.com/questions/38928919/how-to-get-the-weekday-from-day-of-month-using-pyspark */
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'EEEE', 'locale', 'EN'))) AS EnglishDayNameOfWeek
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'EEEE', 'locale', 'ES'))) AS SpanishDayNameOfWeek
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'EEEE', 'locale', 'FR'))) AS FrenchDayNameOfWeek
    ,dayofmonth(date) AS DayNumberOfMonth
    ,dayofyear(date) AS DayNumberOfYear
    ,weekofyear(date) as WeekNumberOfYear
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'MMMM', 'locale', 'EN'))) AS EnglishMonthName
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'MMMM', 'locale', 'ES'))) AS SpanishDayNameOfWeek
    ,initcap(to_csv(named_struct('date', date), map('dateFormat', 'MMMM', 'locale', 'FR'))) AS FrenchDayNameOfWeek
    ,month(date) AS MonthNumberOfYear
    ,quarter(date) AS CalendarQuarter
    ,year(date) AS CalendarYear
    ,case when quarter(date) > 2 then 2 else 1 end AS CalendarSemester
    ,null as FiscalQuarter
    ,null as FiscalYear
    ,null as FiscalSemester
from datelist
where 1=1
    and not exists (select 1 from dim_date where FullDateAlternateKey = datelist.date)
```