set nocount on;
go

-- COUNTRY: SCD2 dla zmiany INCOME_GROUP oraz insert brakujacych krajow.
update dc
set
    VALID_TO = cast(getdate() as date),
    IS_CURRENT = 0
from dw.DIM_COUNTRY dc
join (
    select
        COUNTRY_CODE,
        max(NAME) as NAME,
        max(REGION) as REGION,
        max(INCOME_GROUP) as INCOME_GROUP,
        max(CAPITAL_CITY) as CAPITAL_CITY,
        max(LATITUDE) as LATITUDE,
        max(LONGITUDE) as LONGITUDE
    from staging.STG_COUNTRY
    group by COUNTRY_CODE
) stg on stg.COUNTRY_CODE = dc.COUNTRY_CODE
where dc.IS_CURRENT = 1
  and isnull(dc.INCOME_GROUP, '') <> isnull(stg.INCOME_GROUP, '');
go

insert into dw.DIM_COUNTRY
    (COUNTRY_CODE, NAME, REGION, INCOME_GROUP, CLIMATE_TYPE, CAPITAL_CITY, LATITUDE, LONGITUDE, VALID_FROM, VALID_TO, IS_CURRENT)
select
    stg.COUNTRY_CODE,
    stg.NAME,
    stg.REGION,
    stg.INCOME_GROUP,
    old.CLIMATE_TYPE,
    stg.CAPITAL_CITY,
    stg.LATITUDE,
    stg.LONGITUDE,
    cast(getdate() as date),
    null,
    1
from (
    select
        COUNTRY_CODE,
        max(NAME) as NAME,
        max(REGION) as REGION,
        max(INCOME_GROUP) as INCOME_GROUP,
        max(CAPITAL_CITY) as CAPITAL_CITY,
        max(LATITUDE) as LATITUDE,
        max(LONGITUDE) as LONGITUDE
    from staging.STG_COUNTRY
    group by COUNTRY_CODE
) stg
outer apply (
    select top 1 CLIMATE_TYPE
    from dw.DIM_COUNTRY dc
    where dc.COUNTRY_CODE = stg.COUNTRY_CODE
    order by dc.COUNTRY_KEY desc
) old
where not exists (
    select 1
    from dw.DIM_COUNTRY dc
    where dc.COUNTRY_CODE = stg.COUNTRY_CODE
      and dc.IS_CURRENT = 1
);
go

-- WEATHER: ladowanie idempotentne po ziarnie kraj x dzien.
delete fw
from dw.FACT_WEATHER fw
join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fw.COUNTRY_KEY
join dw.DIM_DATE dd on dd.DATE_KEY = fw.DATE_KEY
where dc.IS_CURRENT = 1
  and exists (
      select 1
      from staging.STG_WEATHER stg
      where stg.COUNTRY_CODE = dc.COUNTRY_CODE
        and stg.OBS_DATE = dd.FULL_DATE
  );
go

insert into dw.FACT_WEATHER
    (DATE_KEY, YEAR_KEY, COUNTRY_KEY, TEMP_AVG, TEMP_MIN, TEMP_MAX, PRECIP_MM, SUNSHINE_H, CLOUD_COVER, WIND_SPEED)
select
    dd.DATE_KEY,
    dy.YEAR_KEY,
    dc.COUNTRY_KEY,
    cast(avg(stg.TEMP_AVG_C) as decimal(5,2)) as TEMP_AVG,
    cast(min(stg.TEMP_MIN_C) as decimal(5,2)) as TEMP_MIN,
    cast(max(stg.TEMP_MAX_C) as decimal(5,2)) as TEMP_MAX,
    cast(sum(stg.PRECIP_MM) as decimal(6,2)) as PRECIP_MM,
    cast(avg(stg.SUNSHINE_S) / 3600.0 as decimal(5,2)) as SUNSHINE_H,
    cast(avg(stg.CLOUD_COVER_PCT) as decimal(4,1)) as CLOUD_COVER,
    cast(avg(stg.WIND_SPEED_KMH) as decimal(5,2)) as WIND_SPEED
from staging.STG_WEATHER stg
join dw.DIM_DATE dd on dd.FULL_DATE = stg.OBS_DATE
join dw.DIM_YEAR dy on dy.YEAR = dd.YEAR
join dw.DIM_COUNTRY dc on dc.COUNTRY_CODE = stg.COUNTRY_CODE and dc.IS_CURRENT = 1
group by dd.DATE_KEY, dy.YEAR_KEY, dc.COUNTRY_KEY;
go

-- ECONOMY: ladowanie idempotentne po ziarnie kraj x rok.
delete fe
from dw.FACT_ECONOMY fe
join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fe.COUNTRY_KEY
join dw.DIM_YEAR dy on dy.YEAR_KEY = fe.YEAR_KEY
where dc.IS_CURRENT = 1
  and exists (
      select 1
      from staging.STG_ECONOMY stg
      where stg.COUNTRY_CODE = dc.COUNTRY_CODE
        and stg.YEAR = dy.YEAR
  );
go

insert into dw.FACT_ECONOMY
    (YEAR_KEY, COUNTRY_KEY, GDP_PER_CAPITA_USD, HEALTH_EXP_PER_CAPITA_USD,
     HEALTH_EXP_PCT_GDP, ALCOHOL_LITERS_PER_CAPITA, UNEMPLOYMENT_PCT)
select
    dy.YEAR_KEY,
    dc.COUNTRY_KEY,
    cast(avg(stg.GDP_PER_CAPITA_USD) as decimal(12,2)),
    cast(avg(stg.HEALTH_EXP_PER_CAPITA_USD) as decimal(10,2)),
    cast(avg(stg.HEALTH_EXP_PCT_GDP) as decimal(5,2)),
    cast(avg(stg.ALCOHOL_LITERS_PER_CAPITA) as decimal(5,2)),
    cast(avg(stg.UNEMPLOYMENT_PCT) as decimal(5,2))
from staging.STG_ECONOMY stg
join dw.DIM_YEAR dy on dy.YEAR = stg.YEAR
join dw.DIM_COUNTRY dc on dc.COUNTRY_CODE = stg.COUNTRY_CODE and dc.IS_CURRENT = 1
group by dy.YEAR_KEY, dc.COUNTRY_KEY;
go

-- MENTAL HEALTH: ladowanie idempotentne po ziarnie kraj x rok x zaburzenie.
delete fmh
from dw.FACT_MENTAL_HEALTH fmh
join dw.DIM_COUNTRY dc on dc.COUNTRY_KEY = fmh.COUNTRY_KEY
join dw.DIM_YEAR dy on dy.YEAR_KEY = fmh.YEAR_KEY
join dw.DIM_DISORDER dis on dis.DISORDER_KEY = fmh.DISORDER_KEY
where dc.IS_CURRENT = 1
  and exists (
      select 1
      from staging.STG_MENTAL_HEALTH stg
      where stg.COUNTRY_CODE = dc.COUNTRY_CODE
        and stg.YEAR = dy.YEAR
        and stg.DISORDER_NAME = dis.NAME
  );
go

insert into dw.FACT_MENTAL_HEALTH
    (YEAR_KEY, COUNTRY_KEY, DISORDER_KEY, PREVALENCE_PCT, DALYS_PER_100K)
select
    dy.YEAR_KEY,
    dc.COUNTRY_KEY,
    dis.DISORDER_KEY,
    cast(avg(stg.PREVALENCE_PCT) as decimal(6,4)),
    cast(avg(stg.DALYS_PER_100K) as decimal(8,2))
from staging.STG_MENTAL_HEALTH stg
join dw.DIM_YEAR dy on dy.YEAR = stg.YEAR
join dw.DIM_COUNTRY dc on dc.COUNTRY_CODE = stg.COUNTRY_CODE and dc.IS_CURRENT = 1
join dw.DIM_DISORDER dis on dis.NAME = stg.DISORDER_NAME
group by dy.YEAR_KEY, dc.COUNTRY_KEY, dis.DISORDER_KEY;
go
