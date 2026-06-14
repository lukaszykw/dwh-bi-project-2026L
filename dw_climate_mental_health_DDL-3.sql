-- 0. CZYSZCZENIE 
if object_id('dw.AGG_WEATHER_SEASONAL', 'V') is not null  drop view dw.AGG_WEATHER_SEASONAL;
if object_id('dw.AGG_WEATHER_ANNUAL',   'V') is not null  drop view dw.AGG_WEATHER_ANNUAL;
if object_id('dw.AGG_WEATHER_MONTHLY',  'V') is not null  drop view dw.AGG_WEATHER_MONTHLY;
go
-- tabele faktowe 
if object_id('dw.FACT_WEATHER',       'U') is not null  drop table dw.FACT_WEATHER;
if object_id('dw.FACT_MENTAL_HEALTH', 'U') is not null  drop table dw.FACT_MENTAL_HEALTH;
if object_id('dw.FACT_ECONOMY',       'U') is not null  drop table dw.FACT_ECONOMY;
go
-- wymiary 
if object_id('dw.DIM_COUNTRY',  'U') is not null  drop table dw.DIM_COUNTRY;
if object_id('dw.DIM_DISORDER', 'U') is not null  drop table dw.DIM_DISORDER;
if object_id('dw.DIM_DATE',     'U') is not null  drop table dw.DIM_DATE;
if object_id('dw.DIM_YEAR',     'U') is not null  drop table dw.DIM_YEAR;
if object_id('dw.DIM_MONTH',    'U') is not null  drop table dw.DIM_MONTH;
go
-- staging
if object_id('staging.STG_WEATHER',       'U') is not null  drop table staging.STG_WEATHER;
if object_id('staging.STG_ECONOMY',       'U') is not null  drop table staging.STG_ECONOMY;
if object_id('staging.STG_MENTAL_HEALTH', 'U') is not null  drop table staging.STG_MENTAL_HEALTH;
if object_id('staging.STG_COUNTRY',       'U') is not null  drop table staging.STG_COUNTRY;
go


-- HURTOWNIA DANYCH: Climate, Economy and Mental Health in Europe (2000-2010)
-- Liwia Jankowska, Wiktoria Kawa, Wojciech Lukaszyk
-- KM2 | Schemat konstelacji 


-- SCHEMATY
if not exists (select 1 from sys.schemas where name = 'staging')
    exec('CREATE SCHEMA staging');
go
if not exists (select 1 from sys.schemas where name = 'dw')
    exec('CREATE SCHEMA dw');
go


-- 1. WARSTWA STAGING
-- Tabele posrednie przechowujace surowe dane przed transformacja

-- 1.1 dane pogodowe (Open-Meteo Historical API)
if object_id('staging.STG_WEATHER', 'U') is not null
    drop table staging.STG_WEATHER;
go
create table staging.STG_WEATHER (
    STG_WEATHER_ID  int           identity(1,1) not null primary key,
    COUNTRY_CODE    char(2)       not null,
    OBS_DATE        date          not null,
    TEMP_AVG_C      float         null,
    TEMP_MIN_C      float         null,
    TEMP_MAX_C      float         null,
    PRECIP_MM       float         null,
    SUNSHINE_S      float         null,   
    CLOUD_COVER_PCT float         null,
    WIND_SPEED_KMH  float         null,
    LOAD_DATE       datetime2     not null default getdate()
);
go

-- 1.2 dane ekonomiczne (World Bank API + WHO GHED + OWID)
if object_id('staging.STG_ECONOMY', 'U') is not null
    drop table staging.STG_ECONOMY;
go
create table staging.STG_ECONOMY (
    STG_ECONOMY_ID              int           identity(1,1) not null primary key,
    COUNTRY_CODE                char(2)       not null,
    YEAR                        smallint      not null,
    GDP_PER_CAPITA_USD          float         null,
    HEALTH_EXP_PER_CAPITA_USD   float         null,
    HEALTH_EXP_PCT_GDP          float         null,
    ALCOHOL_LITERS_PER_CAPITA   float         null,
    UNEMPLOYMENT_PCT            float         null,
    LOAD_DATE                   datetime2     not null default getdate()
);
go

-- 1.3 dane zdrowia psychicznego (OWID/IHME GBD CSV)
if object_id('staging.STG_MENTAL_HEALTH', 'U') is not null
    drop table staging.STG_MENTAL_HEALTH;
go
create table staging.STG_MENTAL_HEALTH (
    STG_MENTAL_ID   int             identity(1,1) not null primary key,
    COUNTRY_CODE    char(2)         not null,
    YEAR            smallint        not null,
    DISORDER_NAME   nvarchar(100)   not null,
    PREVALENCE_PCT  float           null,
    DALYS_PER_100K  float           null,
    LOAD_DATE       datetime2       not null default getdate()
);
go

-- 1.4 metadane krajow (World Bank API)
if object_id('staging.STG_COUNTRY', 'U') is not null
    drop table staging.STG_COUNTRY;
go
create table staging.STG_COUNTRY (
    STG_COUNTRY_ID  int             identity(1,1) not null primary key,
    COUNTRY_CODE    char(2)         not null,
    NAME            nvarchar(100)   not null,
    REGION          nvarchar(60)    null,
    INCOME_GROUP    nvarchar(40)    null,
    CAPITAL_CITY    nvarchar(60)    null,
    LATITUDE        decimal(8,4)    null,
    LONGITUDE       decimal(8,4)    null,
    LOAD_DATE       datetime2       not null default getdate()
);
go


-- 2. WYMIARY (DIMENSIONS)

-- 2.1 DIM_DATE — pelna hierarchia dat (SCD Typ 0)
-- Generowana jednorazowo dla zakresu 2000-01-01 do 2010-12-31
if object_id('dw.DIM_DATE', 'U') is not null
    drop table dw.DIM_DATE;
go
create table dw.DIM_DATE (
    DATE_KEY        int         not null primary key,   -- format yyyyMMdd
    FULL_DATE       date        not null,
    DAY             tinyint     not null,
    MONTH           tinyint     not null,
    YEAR            smallint    not null,
    QUARTER         tinyint     not null,
    NAME            nvarchar(20) not null,
    DAY_OF_WEEK     tinyint     not null,               -- ISO: 1=pn, 7=nd
    IS_WEEKEND      bit         not null default 0
);
go

-- Populacja DIM_DATE 
with dates as (
    select cast('2000-01-01' as date) as d
    union all
    select dateadd(DAY, 1, d) from dates where d < '2010-12-31'
)
insert into dw.DIM_DATE (DATE_KEY, FULL_DATE, DAY, MONTH, YEAR, QUARTER, NAME, DAY_OF_WEEK, IS_WEEKEND)
select
    cast(format(d, 'yyyyMMdd') as int)  as DATE_KEY,
    d                                   as FULL_DATE,
    day(d)                              as DAY,
    month(d)                            as MONTH,
    year(d)                             as YEAR,
    datepart(QUARTER, d)                as QUARTER,
    datename(MONTH, d)                  as NAME,
    case datepart(WEEKDAY, d)
        when 1 then 7
        else datepart(WEEKDAY, d) - 1
    end                                 as DAY_OF_WEEK,
    case when datepart(WEEKDAY, d) in (1, 7) then 1 else 0 end as IS_WEEKEND
from dates
option (maxrecursion 0);
go

-- 2.2 DIM_YEAR — wymiar roku (SCD Typ 0)
-- 11 rekordow: 2000-2010
if object_id('dw.DIM_YEAR', 'U') is not null
    drop table dw.DIM_YEAR;
go
create table dw.DIM_YEAR (
    YEAR_KEY    int         identity(1,1) not null primary key,
    YEAR        smallint    not null unique,
    DECADE      smallint    not null       
);
go

insert into dw.DIM_YEAR (YEAR, DECADE) values
(2000, 2000),(2001, 2000),(2002, 2000),(2003, 2000),(2004, 2000),
(2005, 2000),(2006, 2000),(2007, 2000),(2008, 2000),(2009, 2000),
(2010, 2010);
go

-- 2.3 DIM_MONTH — wymiar miesiaca (SCD Typ 0)
-- uzywany przez AGG_WEATHER_MONTHLY
if object_id('dw.DIM_MONTH', 'U') is not null
    drop table dw.DIM_MONTH;
go
create table dw.DIM_MONTH (
    MONTH_KEY   int         not null primary key,   -- format yyyyMM, np. 200503
    YEAR        smallint    not null,
    MONTH       tinyint     not null,
    QUARTER     tinyint     not null,
    NAME        nvarchar(20) not null
);
go

with mths as (
    select cast('2000-01-01' as date) as m
    union all
    select dateadd(MONTH, 1, m) from mths where m < '2010-12-01'
)
insert into dw.DIM_MONTH (MONTH_KEY, YEAR, MONTH, QUARTER, NAME)
select
    cast(format(m, 'yyyyMM') as int)    as MONTH_KEY,
    year(m)                             as YEAR,
    month(m)                            as MONTH,
    datepart(QUARTER, m)                as QUARTER,
    datename(MONTH, m)                  as NAME
from mths
option (maxrecursion 200);
go

-- 2.4 DIM_COUNTRY — wymiar kraju (SCD Typ 2)
-- World Bank API + reczna tabela Koppen 
-- INCOME_GROUP podlega SCD2, CLIMATE_TYPE statyczny (SCD0)
if object_id('dw.DIM_COUNTRY', 'U') is not null
    drop table dw.DIM_COUNTRY;
go
create table dw.DIM_COUNTRY (
    COUNTRY_KEY     int             identity(1,1) not null primary key,
    COUNTRY_CODE    char(2)         not null,
    NAME            nvarchar(100)   not null,
    REGION          nvarchar(60)    null,
    INCOME_GROUP    nvarchar(40)    null,   -- SCD2 - zmiana tworzy nowy rekord
    CLIMATE_TYPE    nvarchar(30)    null,   -- Klasyfikacja Koppen (stala)
    CAPITAL_CITY    nvarchar(60)    null,
    LATITUDE        decimal(8,4)    null,   -- wspolrzedne stolicy (do Open-Meteo)
    LONGITUDE       decimal(8,4)    null,
    VALID_FROM      date            not null default cast(getdate() as date),
    VALID_TO        date            null,   -- null to rekord aktualny
    IS_CURRENT      bit             not null default 1
);
go

create nonclustered index IX_DIM_COUNTRY_CODE_CURRENT
    on dw.DIM_COUNTRY (COUNTRY_CODE, IS_CURRENT);
go

-- Populacja: 40 krajow europejskich + klasyfikacja Koppen
-- (ladowane przez dbt z World Bank API + koppen_europe.csv)
-- Przykladowe rekordy inicjalizacyjne wygenerowane przez AI:
insert into dw.DIM_COUNTRY
    (COUNTRY_CODE, NAME, REGION, INCOME_GROUP, CLIMATE_TYPE, CAPITAL_CITY, LATITUDE, LONGITUDE)
values
('AL','Albania','Southern Europe','Upper-middle','BSk','Tirana',41.3317,19.8317),
('AT','Austria','Western Europe','High','Cfb','Vienna',48.2092,16.3728),
('BE','Belgium','Western Europe','High','Cfb','Brussels',50.8503,4.3517),
('BG','Bulgaria','Eastern Europe','Upper-middle','Dfb','Sofia',42.6975,23.3242),
('BY','Belarus','Eastern Europe','Upper-middle','Dfb','Minsk',53.9045,27.5615),
('CH','Switzerland','Western Europe','High','Cfb','Bern',46.9480,7.4474),
('CY','Cyprus','Southern Europe','High','Csa','Nicosia',35.1667,33.3667),
('CZ','Czechia','Central Europe','High','Dfb','Prague',50.0880,14.4208),
('DE','Germany','Western Europe','High','Cfb','Berlin',52.5235,13.4115),
('DK','Denmark','Northern Europe','High','Cfb','Copenhagen',55.6763,12.5681),
('EE','Estonia','Northern Europe','High','Dfb','Tallinn',59.4370,24.7536),
('ES','Spain','Southern Europe','High','Csa','Madrid',40.4167,3.7033),
('FI','Finland','Northern Europe','High','Dfc','Helsinki',60.1699,24.9384),
('FR','France','Western Europe','High','Cfb','Paris',48.8566,2.3522),
('GB','United Kingdom','Western Europe','High','Cfb','London',51.5074,-0.1278),
('GR','Greece','Southern Europe','High','Csa','Athens',37.9792,23.7166),
('HR','Croatia','Southern Europe','High','Cfb','Zagreb',45.8150,15.9819),
('HU','Hungary','Central Europe','High','Dfb','Budapest',47.4979,19.0402),
('IE','Ireland','Western Europe','High','Cfb','Dublin',53.3441,-6.2675),
('IS','Iceland','Northern Europe','High','ET','Reykjavik',64.1353,-21.8952),
('IT','Italy','Southern Europe','High','Csa','Rome',41.8955,12.4823),
('LT','Lithuania','Northern Europe','High','Dfb','Vilnius',54.6896,25.2799),
('LU','Luxembourg','Western Europe','High','Cfb','Luxembourg',49.6117,6.1300),
('LV','Latvia','Northern Europe','High','Dfb','Riga',56.9460,24.1059),
('MD','Moldova','Eastern Europe','Lower-middle','Dfb','Chisinau',47.0105,28.8638),
('ME','Montenegro','Southern Europe','Upper-middle','Cfb','Podgorica',42.4415,19.2636),
('MK','North Macedonia','Southern Europe','Upper-middle','Cfb','Skopje',41.9833,21.4333),
('MT','Malta','Southern Europe','High','Csa','Valletta',35.8978,14.5125),
('NL','Netherlands','Western Europe','High','Cfb','Amsterdam',52.3791,4.9003),
('NO','Norway','Northern Europe','High','Dfc','Oslo',59.9127,10.7461),
('PL','Poland','Central Europe','High','Dfb','Warsaw',52.2298,21.0118),
('PT','Portugal','Southern Europe','High','Csa','Lisbon',38.7223,-9.1393),
('RO','Romania','Eastern Europe','Upper-middle','Dfb','Bucharest',44.4368,26.1024),
('RS','Serbia','Southern Europe','Upper-middle','Dfb','Belgrade',44.8048,20.4781),
('RU','Russia','Eastern Europe','Upper-middle','Dfc','Moscow',55.7558,37.6176),
('SE','Sweden','Northern Europe','High','Dfc','Stockholm',59.3328,18.0645),
('SI','Slovenia','Central Europe','High','Cfb','Ljubljana',46.0511,14.5051),
('SK','Slovakia','Central Europe','High','Dfb','Bratislava',48.1439,17.1097),
('TR','Turkey','Southern Europe','Upper-middle','Csa','Ankara',39.9334,32.8597),
('UA','Ukraine','Eastern Europe','Lower-middle','Dfb','Kyiv',50.4501,30.5234);
go

-- 2.5 DIM_DISORDER — wymiar zaburzenia psychicznego (SCD Typ 1)
-- Zrodlo: OWID/IHME CSV + dane syntetyczne (ICD10_CODE, IS_SEASONAL, TREATMENT_TYPE)
if object_id('dw.DIM_DISORDER', 'U') is not null
    drop table dw.DIM_DISORDER;
go
create table dw.DIM_DISORDER (
    DISORDER_KEY    int             identity(1,1) not null primary key,
    NAME            nvarchar(100)   not null unique,
    CATEGORY        nvarchar(60)    not null,   -- np. "Mood disorders", "Anxiety disorders"
    ICD10_CODE      char(4)         null,       -- dane syntetyczne
    IS_SEASONAL     bit             not null default 0,  -- 1 = SAD i podobne
    TREATMENT_TYPE  nvarchar(60)    null        -- dane syntetyczne
);
go

insert into dw.DIM_DISORDER (NAME, CATEGORY, ICD10_CODE, IS_SEASONAL, TREATMENT_TYPE)
values
('Depressive disorders',             'Mood disorders',       'F32', 0, 'Psychotherapy / SSRI'),
('Anxiety disorders',                'Anxiety disorders',    'F41', 0, 'Psychotherapy / SSRI'),
('Bipolar disorder',                 'Mood disorders',       'F31', 0, 'Mood stabilizers'),
('Schizophrenia',                    'Psychotic disorders',  'F20', 0, 'Antipsychotics'),
('Eating disorders',                 'Eating disorders',     'F50', 0, 'Psychotherapy / CBT'),
('Alcohol use disorders',            'Substance use',        'F10', 0, 'Rehabilitation'),
('Drug use disorders',               'Substance use',        'F19', 0, 'Rehabilitation'),
('Autism spectrum disorders',        'Neurodevelopmental',   'F84', 0, 'Behavioral therapy'),
('Attention-deficit disorders',      'Neurodevelopmental',   'F90', 0, 'Behavioral therapy / Medication'),
('Conduct disorders',                'Neurodevelopmental',   'F91', 0, 'Behavioral therapy'),
('Intellectual disabilities',        'Neurodevelopmental',   'F70', 0, 'Educational support'),
('Seasonal affective disorder',      'Mood disorders',       'F33', 1, 'Light therapy / SSRI');
go


-- 3. TABELE FAKTOW 
-- Periodic Snapshot dla wszystkich trzech tabel


-- 3.1 FACT_WEATHER — dzienna migawka pogodowa
-- Granulacja: kraj x dzien 
-- Open-Meteo Historical API (per stolica kraju)
if object_id('dw.FACT_WEATHER', 'U') is not null
    drop table dw.FACT_WEATHER;
go
create table dw.FACT_WEATHER (
    WEATHER_KEY     int             identity(1,1) not null primary key,
    DATE_KEY        int             not null,
    YEAR_KEY        int             not null,
    COUNTRY_KEY     int             not null,
    TEMP_AVG        decimal(5,2)    null,   -- srednia temperatura dzienna [C]
    TEMP_MIN        decimal(5,2)    null,   -- minimalna temperatura dzienna [C]
    TEMP_MAX        decimal(5,2)    null,   -- maksymalna temperatura dzienna [C]
    PRECIP_MM       decimal(6,2)    null,   -- suma opadow [mm]
    SUNSHINE_H      decimal(5,2)    null,   -- czas nasłonecznienia [h], API zwraca sekundy / 3600
    CLOUD_COVER     decimal(4,1)    null,   -- zachmurzenie [%]; zakres 0-100
    WIND_SPEED      decimal(5,2)    null,   -- predkosc wiatru [km/h]
    constraint FK_FW_DATE    foreign key (DATE_KEY)    references dw.DIM_DATE(DATE_KEY),
    constraint FK_FW_YEAR    foreign key (YEAR_KEY)    references dw.DIM_YEAR(YEAR_KEY),
    constraint FK_FW_COUNTRY foreign key (COUNTRY_KEY) references dw.DIM_COUNTRY(COUNTRY_KEY)
);
go

create nonclustered index IX_FW_COUNTRY_DATE
    on dw.FACT_WEATHER (COUNTRY_KEY, DATE_KEY);
go

-- 3.2 FACT_MENTAL_HEALTH — roczne wskazniki zdrowia psychicznego
-- Granulacja: kraj x rok x zaburzenie 
-- OWID/IHME GBD CSV (GitHub)
if object_id('dw.FACT_MENTAL_HEALTH', 'U') is not null
    drop table dw.FACT_MENTAL_HEALTH;
go
create table dw.FACT_MENTAL_HEALTH (
    MENTAL_HEALTH_KEY   int             identity(1,1) not null primary key,
    YEAR_KEY            int             not null,
    COUNTRY_KEY         int             not null,
    DISORDER_KEY        int             not null,
    PREVALENCE_PCT      decimal(6,4)    null,   -- wspolczynnik chorobowosci [% populacji]
    DALYS_PER_100K      decimal(8,2)    null,   -- lata zycia skorygowane niepenosprawnoscią / 100k, mówi nam to, przykład: jeśli Finlandia ma DALYS_PER_100K = 800 dla depresji, to na każde 100 000 Finów depresja zabiera 800 pełnych lat zdrowego życia rocznie
    constraint FK_FMH_YEAR     foreign key (YEAR_KEY)     references dw.DIM_YEAR(YEAR_KEY),
    constraint FK_FMH_COUNTRY  foreign key (COUNTRY_KEY)  references dw.DIM_COUNTRY(COUNTRY_KEY),
    constraint FK_FMH_DISORDER foreign key (DISORDER_KEY) references dw.DIM_DISORDER(DISORDER_KEY)
);
go

create nonclustered index IX_FMH_COUNTRY_YEAR_DISORDER
    on dw.FACT_MENTAL_HEALTH (COUNTRY_KEY, YEAR_KEY, DISORDER_KEY);
go

-- 3.3 FACT_ECONOMY — roczne wskazniki ekonomiczne
-- Granulacja: kraj x rok 
-- World Bank API (GDP, Unemployment), WHO GHED (Health Exp.), OWID (Alcohol)
if object_id('dw.FACT_ECONOMY', 'U') is not null
    drop table dw.FACT_ECONOMY;
go
create table dw.FACT_ECONOMY (
    ECONOMY_KEY                 int             identity(1,1) not null primary key,
    YEAR_KEY                    int             not null,
    COUNTRY_KEY                 int             not null,
    GDP_PER_CAPITA_USD          decimal(12,2)   null,   -- PKB per capita [USD biezace]; WB: NY.GDP.PCAP.CD
    HEALTH_EXP_PER_CAPITA_USD   decimal(10,2)   null,   -- wydatki na zdrowie per capita [USD]; WB: SH.XPD.CHEX.PC.CD
    HEALTH_EXP_PCT_GDP          decimal(5,2)    null,   -- wydatki na zdrowie [% PKB]; zakres 0-100
    ALCOHOL_LITERS_PER_CAPITA   decimal(5,2)    null,   -- spozyce alkoholu [l czystego alkoholu/os/rok]; OWID
    UNEMPLOYMENT_PCT            decimal(5,2)    null,   -- stopa bezrobocia [% siły roboczej]; WB: SL.UEM.TOTL.ZS
    constraint FK_FE_YEAR    foreign key (YEAR_KEY)    references dw.DIM_YEAR(YEAR_KEY),
    constraint FK_FE_COUNTRY foreign key (COUNTRY_KEY) references dw.DIM_COUNTRY(COUNTRY_KEY)
);
go

create nonclustered index IX_FE_COUNTRY_YEAR
    on dw.FACT_ECONOMY (COUNTRY_KEY, YEAR_KEY);
go


-- 4. AGREGATY POGODOWE (VIEWS)
-- Rozwiazanie problemu granulacji: FACT_WEATHER (dzienna)
-- vs FACT_ECONOMY / FACT_MENTAL_HEALTH (roczna)
-- Agregaty eliminuja live-agregacje w Power BI

-- 4.1 AGG_WEATHER_MONTHLY — agregat miesieczny 
-- Cel: drill-down trendow, analiza sezonowosci miesiecznej w Power BI
-- JOIN z: DIM_MONTH dla wizualizacji trendow
if object_id('dw.AGG_WEATHER_MONTHLY', 'V') is not null
    drop view dw.AGG_WEATHER_MONTHLY;
go
create view dw.AGG_WEATHER_MONTHLY as
select
    dm.MONTH_KEY,
    fw.COUNTRY_KEY,
    dm.YEAR,
    dm.MONTH,
    dm.QUARTER,
    dm.NAME,
    avg(fw.TEMP_AVG)        as AVG_TEMP,
    min(fw.TEMP_MIN)        as MIN_TEMP,
    max(fw.TEMP_MAX)        as MAX_TEMP,
    sum(fw.PRECIP_MM)       as SUM_PRECIP_MM,
    avg(fw.SUNSHINE_H)      as AVG_SUNSHINE_H,
    avg(fw.CLOUD_COVER)     as AVG_CLOUD_COVER,
    avg(fw.WIND_SPEED)      as AVG_WIND_SPEED,
    count(*)                as ROW_COUNT         -- kontrola kompletnosci danych
from dw.FACT_WEATHER fw
join dw.DIM_DATE dd   on fw.DATE_KEY    = dd.DATE_KEY
join dw.DIM_MONTH dm  on dm.YEAR = dd.YEAR and dm.MONTH = dd.MONTH
group by
    dm.MONTH_KEY, fw.COUNTRY_KEY,
    dm.YEAR, dm.MONTH, dm.QUARTER, dm.NAME;
go

-- 4.2 AGG_WEATHER_ANNUAL — agregat roczny 
-- Cel: korelacja roczna pogody z FACT_ECONOMY i FACT_MENTAL_HEALTH
-- JOIN z: FACT_ECONOMY, FACT_MENTAL_HEALTH po YEAR_KEY + COUNTRY_KEY
if object_id('dw.AGG_WEATHER_ANNUAL', 'V') is not null
    drop view dw.AGG_WEATHER_ANNUAL;
go
create view dw.AGG_WEATHER_ANNUAL as
select
    dy.YEAR_KEY,
    fw.COUNTRY_KEY,
    dy.YEAR,
    avg(fw.TEMP_AVG)        as AVG_TEMP,
    min(fw.TEMP_MIN)        as MIN_TEMP,
    max(fw.TEMP_MAX)        as MAX_TEMP,
    sum(fw.PRECIP_MM)       as SUM_PRECIP_MM,
    avg(fw.SUNSHINE_H)      as AVG_SUNSHINE_H,    -- roczna srednia nasłonecznienia [h/dzien]
    avg(fw.CLOUD_COVER)     as AVG_CLOUD_COVER,
    avg(fw.WIND_SPEED)      as AVG_WIND_SPEED,
    count(*)                as ROW_COUNT
from dw.FACT_WEATHER fw
join dw.DIM_DATE dd  on fw.DATE_KEY = dd.DATE_KEY
join dw.DIM_YEAR dy  on dy.YEAR = dd.YEAR
group by
    dy.YEAR_KEY, fw.COUNTRY_KEY, dy.YEAR;
go

-- 4.3 AGG_WEATHER_SEASONAL — agregat sezonowy 
-- Cel: badanie czy ciemna zima to wieksza prevalencja depresji"
-- Sezon WINTER (Grudzien-Luty) jako kluczowy filtr analityczny
-- JOIN z: FACT_MENTAL_HEALTH filtrem SEASON='Winter' po YEAR_KEY + COUNTRY_KEY
if object_id('dw.AGG_WEATHER_SEASONAL', 'V') is not null
    drop view dw.AGG_WEATHER_SEASONAL;
go
create view dw.AGG_WEATHER_SEASONAL as
select
    dy.YEAR_KEY,
    fw.COUNTRY_KEY,
    dy.YEAR,
    case
        when dd.MONTH in (12, 1, 2) then 'Winter'
        when dd.MONTH in (3, 4, 5)  then 'Spring'
        when dd.MONTH in (6, 7, 8)  then 'Summer'
        when dd.MONTH in (9,10,11)  then 'Autumn'
    end                             as SEASON,
    case
        when dd.MONTH in (12, 1, 2) then 1
        when dd.MONTH in (3, 4, 5)  then 2
        when dd.MONTH in (6, 7, 8)  then 3
        when dd.MONTH in (9,10,11)  then 4
    end                             as SEASON_ORDER,
    avg(fw.TEMP_AVG)                as AVG_TEMP,
    min(fw.TEMP_MIN)                as MIN_TEMP,
    max(fw.TEMP_MAX)                as MAX_TEMP,
    sum(fw.PRECIP_MM)               as SUM_PRECIP_MM,
    avg(fw.SUNSHINE_H)              as AVG_SUNSHINE_H,  -- KLUCZOWE: srednie nasłonecznienie zimowe
    avg(fw.CLOUD_COVER)             as AVG_CLOUD_COVER,
    avg(fw.WIND_SPEED)              as AVG_WIND_SPEED,
    count(*)                        as ROW_COUNT
from dw.FACT_WEATHER fw
join dw.DIM_DATE dd  on fw.DATE_KEY = dd.DATE_KEY
join dw.DIM_YEAR dy  on dy.YEAR = dd.YEAR
group by
    dy.YEAR_KEY, fw.COUNTRY_KEY, dy.YEAR,
    case
        when dd.MONTH in (12, 1, 2) then 'Winter'
        when dd.MONTH in (3, 4, 5)  then 'Spring'
        when dd.MONTH in (6, 7, 8)  then 'Summer'
        when dd.MONTH in (9,10,11)  then 'Autumn'
    end,
    case
        when dd.MONTH in (12, 1, 2) then 1
        when dd.MONTH in (3, 4, 5)  then 2
        when dd.MONTH in (6, 7, 8)  then 3
        when dd.MONTH in (9,10,11)  then 4
    end;
go



-- 5. INDEKSY POMOCNICZE


-- Przyspieszenie lookupow wymiarow
create nonclustered index IX_DIM_YEAR_YEAR
    on dw.DIM_YEAR (YEAR);
go

create nonclustered index IX_DIM_DATE_YEAR_MONTH
    on dw.DIM_DATE (YEAR, MONTH);
go



-- 6. WERYFIKACJA MODELU
select 'DIM_DATE'         as tabela, count(*) as wiersze from dw.DIM_DATE
union all
select 'DIM_YEAR',                   count(*) from dw.DIM_YEAR
union all
select 'DIM_MONTH',                  count(*) from dw.DIM_MONTH
union all
select 'DIM_COUNTRY',                count(*) from dw.DIM_COUNTRY
union all
select 'DIM_DISORDER',               count(*) from dw.DIM_DISORDER;
go
