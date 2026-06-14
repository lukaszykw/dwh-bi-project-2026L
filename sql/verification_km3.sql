set nocount on;
go

/* 01_ROW_COUNTS: liczba rekordow w kazdej warstwie */
select 'staging.STG_COUNTRY' as object_name, count(*) as row_count from staging.STG_COUNTRY
union all select 'staging.STG_WEATHER', count(*) from staging.STG_WEATHER
union all select 'staging.STG_ECONOMY', count(*) from staging.STG_ECONOMY
union all select 'staging.STG_MENTAL_HEALTH', count(*) from staging.STG_MENTAL_HEALTH
union all select 'dw.DIM_DATE', count(*) from dw.DIM_DATE
union all select 'dw.DIM_YEAR', count(*) from dw.DIM_YEAR
union all select 'dw.DIM_MONTH', count(*) from dw.DIM_MONTH
union all select 'dw.DIM_COUNTRY', count(*) from dw.DIM_COUNTRY
union all select 'dw.DIM_DISORDER', count(*) from dw.DIM_DISORDER
union all select 'dw.FACT_WEATHER', count(*) from dw.FACT_WEATHER
union all select 'dw.FACT_ECONOMY', count(*) from dw.FACT_ECONOMY
union all select 'dw.FACT_MENTAL_HEALTH', count(*) from dw.FACT_MENTAL_HEALTH;
go

/* 02_DUPLICATE_GRAIN_CHECKS: oczekiwany wynik issue_count = 0 */
select 'STG_WEATHER country-date duplicates' as check_name, count(*) as issue_count
from (
    select COUNTRY_CODE, OBS_DATE
    from staging.STG_WEATHER
    group by COUNTRY_CODE, OBS_DATE
    having count(*) > 1
) x
union all
select 'STG_ECONOMY country-year duplicates', count(*)
from (
    select COUNTRY_CODE, YEAR
    from staging.STG_ECONOMY
    group by COUNTRY_CODE, YEAR
    having count(*) > 1
) x
union all
select 'STG_MENTAL country-year-disorder duplicates', count(*)
from (
    select COUNTRY_CODE, YEAR, DISORDER_NAME
    from staging.STG_MENTAL_HEALTH
    group by COUNTRY_CODE, YEAR, DISORDER_NAME
    having count(*) > 1
) x
union all
select 'FACT_WEATHER country-date duplicates', count(*)
from (
    select COUNTRY_KEY, DATE_KEY
    from dw.FACT_WEATHER
    group by COUNTRY_KEY, DATE_KEY
    having count(*) > 1
) x
union all
select 'FACT_ECONOMY country-year duplicates', count(*)
from (
    select COUNTRY_KEY, YEAR_KEY
    from dw.FACT_ECONOMY
    group by COUNTRY_KEY, YEAR_KEY
    having count(*) > 1
) x
union all
select 'FACT_MENTAL country-year-disorder duplicates', count(*)
from (
    select COUNTRY_KEY, YEAR_KEY, DISORDER_KEY
    from dw.FACT_MENTAL_HEALTH
    group by COUNTRY_KEY, YEAR_KEY, DISORDER_KEY
    having count(*) > 1
) x;
go

/* 03_VALUE_RANGE_CHECKS: oczekiwany wynik issue_count = 0 */
select 'weather values out of range' as check_name, count(*) as issue_count
from staging.STG_WEATHER
where TEMP_MIN_C < -80
   or TEMP_MAX_C > 60
   or TEMP_MIN_C > TEMP_MAX_C
   or PRECIP_MM < 0
   or SUNSHINE_S < 0
   or CLOUD_COVER_PCT < 0
   or CLOUD_COVER_PCT > 100
   or WIND_SPEED_KMH < 0
union all
select 'economy values out of range', count(*)
from staging.STG_ECONOMY
where GDP_PER_CAPITA_USD < 0
   or HEALTH_EXP_PER_CAPITA_USD < 0
   or HEALTH_EXP_PCT_GDP < 0
   or HEALTH_EXP_PCT_GDP > 100
   or ALCOHOL_LITERS_PER_CAPITA < 0
   or UNEMPLOYMENT_PCT < 0
   or UNEMPLOYMENT_PCT > 100
union all
select 'mental health values out of range', count(*)
from staging.STG_MENTAL_HEALTH
where PREVALENCE_PCT < 0
   or PREVALENCE_PCT > 100
   or DALYS_PER_100K < 0;
go

/* 04_FOREIGN_KEY_COVERAGE: oczekiwany wynik missing_rows = 0 */
select 'FACT_WEATHER missing date/year/country' as check_name, count(*) as missing_rows
from dw.FACT_WEATHER fw
left join dw.DIM_DATE dd on dd.DATE_KEY = fw.DATE_KEY
left join dw.DIM_YEAR dy on dy.YEAR_KEY = fw.YEAR_KEY
left join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fw.COUNTRY_KEY
where dd.DATE_KEY is null or dy.YEAR_KEY is null or dc.COUNTRY_KEY is null
union all
select 'FACT_ECONOMY missing year/country', count(*)
from dw.FACT_ECONOMY fe
left join dw.DIM_YEAR dy on dy.YEAR_KEY = fe.YEAR_KEY
left join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fe.COUNTRY_KEY
where dy.YEAR_KEY is null or dc.COUNTRY_KEY is null
union all
select 'FACT_MENTAL missing year/country/disorder', count(*)
from dw.FACT_MENTAL_HEALTH fmh
left join dw.DIM_YEAR dy on dy.YEAR_KEY = fmh.YEAR_KEY
left join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fmh.COUNTRY_KEY
left join dw.DIM_DISORDER dis on dis.DISORDER_KEY = fmh.DISORDER_KEY
where dy.YEAR_KEY is null or dc.COUNTRY_KEY is null or dis.DISORDER_KEY is null;
go

/* 05_BUSINESS_DISTRIBUTIONS: rozklady do raportu */
select
    dis.NAME as disorder_name,
    count(*) as row_count,
    cast(avg(fmh.PREVALENCE_PCT) as decimal(8,4)) as avg_prevalence_pct
from dw.FACT_MENTAL_HEALTH fmh
join dw.DIM_DISORDER dis on dis.DISORDER_KEY = fmh.DISORDER_KEY
group by dis.NAME
order by dis.NAME;
go

select
    dc.REGION,
    count(distinct dc.COUNTRY_CODE) as country_count
from dw.DIM_COUNTRY dc
where dc.IS_CURRENT = 1
group by dc.REGION
order by dc.REGION;
go

/* 06_DATE_RANGE_COVERAGE: zakres lat w faktach */
select 'FACT_WEATHER' as object_name, min(dd.YEAR) as min_year, max(dd.YEAR) as max_year, count(distinct dd.YEAR) as years_count
from dw.FACT_WEATHER fw
join dw.DIM_DATE dd on dd.DATE_KEY = fw.DATE_KEY
union all
select 'FACT_ECONOMY', min(dy.YEAR), max(dy.YEAR), count(distinct dy.YEAR)
from dw.FACT_ECONOMY fe
join dw.DIM_YEAR dy on dy.YEAR_KEY = fe.YEAR_KEY
union all
select 'FACT_MENTAL_HEALTH', min(dy.YEAR), max(dy.YEAR), count(distinct dy.YEAR)
from dw.FACT_MENTAL_HEALTH fmh
join dw.DIM_YEAR dy on dy.YEAR_KEY = fmh.YEAR_KEY;
go

/* 07_SAMPLE_BUSINESS_DATA: probka danych biznesowych */
select top 20
    dc.NAME as country_name,
    dy.YEAR,
    cast(awa.AVG_TEMP as decimal(6,2)) as avg_temp,
    cast(awa.AVG_SUNSHINE_H as decimal(6,2)) as avg_sunshine_h,
    fe.GDP_PER_CAPITA_USD,
    fe.UNEMPLOYMENT_PCT
from dw.AGG_WEATHER_ANNUAL awa
join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = awa.COUNTRY_KEY
join dw.DIM_YEAR dy on dy.YEAR_KEY = awa.YEAR_KEY
left join dw.FACT_ECONOMY fe on fe.COUNTRY_KEY = awa.COUNTRY_KEY and fe.YEAR_KEY = awa.YEAR_KEY
order by dc.NAME, dy.YEAR;
go

/* 08_AGGREGATE_VIEWS: widoki do BI */
select 'dw.AGG_WEATHER_MONTHLY' as view_name, count(*) as row_count from dw.AGG_WEATHER_MONTHLY
union all select 'dw.AGG_WEATHER_ANNUAL', count(*) from dw.AGG_WEATHER_ANNUAL
union all select 'dw.AGG_WEATHER_SEASONAL', count(*) from dw.AGG_WEATHER_SEASONAL;
go

/* 09_END_TO_END_ANALYTIC_QUERY: przykladowe zapytanie laczace obszary */
select top 30
    dc.NAME as country_name,
    dy.YEAR,
    dis.NAME as disorder_name,
    fmh.PREVALENCE_PCT,
    awa.AVG_TEMP,
    awa.AVG_SUNSHINE_H,
    fe.GDP_PER_CAPITA_USD,
    fe.UNEMPLOYMENT_PCT,
    fe.ALCOHOL_LITERS_PER_CAPITA
from dw.FACT_MENTAL_HEALTH fmh
join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fmh.COUNTRY_KEY
join dw.DIM_YEAR dy on dy.YEAR_KEY = fmh.YEAR_KEY
join dw.DIM_DISORDER dis on dis.DISORDER_KEY = fmh.DISORDER_KEY
left join dw.AGG_WEATHER_ANNUAL awa on awa.COUNTRY_KEY = fmh.COUNTRY_KEY and awa.YEAR_KEY = fmh.YEAR_KEY
left join dw.FACT_ECONOMY fe on fe.COUNTRY_KEY = fmh.COUNTRY_KEY and fe.YEAR_KEY = fmh.YEAR_KEY
where dis.NAME in ('Depressive disorders', 'Anxiety disorders', 'Alcohol use disorders')
order by dc.NAME, dy.YEAR, dis.NAME;
go
