set nocount on;
go

select 'STG_COUNTRY' as object_name, count(*) as row_count from staging.STG_COUNTRY
union all select 'STG_WEATHER', count(*) from staging.STG_WEATHER
union all select 'STG_ECONOMY', count(*) from staging.STG_ECONOMY
union all select 'STG_MENTAL_HEALTH', count(*) from staging.STG_MENTAL_HEALTH
union all select 'FACT_WEATHER', count(*) from dw.FACT_WEATHER
union all select 'FACT_ECONOMY', count(*) from dw.FACT_ECONOMY
union all select 'FACT_MENTAL_HEALTH', count(*) from dw.FACT_MENTAL_HEALTH;
go

select
    'WEATHER_DUPLICATE_GRAIN' as check_name,
    count(*) as issue_count
from (
    select COUNTRY_CODE, OBS_DATE
    from staging.STG_WEATHER
    group by COUNTRY_CODE, OBS_DATE
    having count(*) > 1
) d;
go

select
    'ECONOMY_DUPLICATE_GRAIN' as check_name,
    count(*) as issue_count
from (
    select COUNTRY_CODE, YEAR
    from staging.STG_ECONOMY
    group by COUNTRY_CODE, YEAR
    having count(*) > 1
) d;
go

select
    'MENTAL_HEALTH_DUPLICATE_GRAIN' as check_name,
    count(*) as issue_count
from (
    select COUNTRY_CODE, YEAR, DISORDER_NAME
    from staging.STG_MENTAL_HEALTH
    group by COUNTRY_CODE, YEAR, DISORDER_NAME
    having count(*) > 1
) d;
go

select
    'WEATHER_OUT_OF_RANGE' as check_name,
    count(*) as issue_count
from staging.STG_WEATHER
where TEMP_MIN_C < -80
   or TEMP_MAX_C > 60
   or PRECIP_MM < 0
   or CLOUD_COVER_PCT < 0
   or CLOUD_COVER_PCT > 100
   or WIND_SPEED_KMH < 0;
go

select
    'ECONOMY_OUT_OF_RANGE' as check_name,
    count(*) as issue_count
from staging.STG_ECONOMY
where GDP_PER_CAPITA_USD < 0
   or HEALTH_EXP_PER_CAPITA_USD < 0
   or HEALTH_EXP_PCT_GDP < 0
   or HEALTH_EXP_PCT_GDP > 100
   or ALCOHOL_LITERS_PER_CAPITA < 0
   or UNEMPLOYMENT_PCT < 0
   or UNEMPLOYMENT_PCT > 100;
go

select
    'MENTAL_HEALTH_OUT_OF_RANGE' as check_name,
    count(*) as issue_count
from staging.STG_MENTAL_HEALTH
where PREVALENCE_PCT < 0
   or PREVALENCE_PCT > 100
   or DALYS_PER_100K < 0;
go

select
    'FACT_WEATHER_MISSING_YEAR' as check_name,
    count(*) as issue_count
from dw.FACT_WEATHER fw
left join dw.DIM_YEAR dy on dy.YEAR_KEY = fw.YEAR_KEY
where dy.YEAR_KEY is null;
go
