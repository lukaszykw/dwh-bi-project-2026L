# ETL/ELT dla projektu Climate, Economy and Mental Health

## Cel

Ta warstwa realizuje proces ETL/ELT wymagany w KM3:

1. pobiera dane z wielu zrodel,
2. zapisuje je do tabel `staging`,
3. uruchamia transformacje SQL z warstwy staging do hurtowni `dw`,
4. wykonuje zapytania kontrolne jakosci danych.

Docelowy przeplyw:

```text
Open-Meteo / World Bank / OWID CSV
        -> Python ETL
        -> staging.STG_*
        -> SQL ELT
        -> dw.FACT_* + widoki agregujace
        -> SSAS / Power BI
```

## Pliki

- `run_etl.py` - glowny punkt uruchomienia.
- `etl/sources.py` - pobieranie danych z API i CSV.
- `etl/load_staging.py` - zapis do tabel stagingowych.
- `etl/db.py` - polaczenie z SQL Serverem i uruchamianie skryptow SQL.
- `sql/truncate_staging.sql` - czyszczenie stagingu.
- `sql/load_dw_from_staging.sql` - transformacje staging -> hurtownia.
- `sql/data_quality_checks.sql` - testy kontrolne jakosci danych.
- `config/etl_config.example.json` - przykladowa konfiguracja.
- `config/countries_europe.json` - lista krajow zgodna z modelem DW.
- `data/templates/mental_health_template.csv` - minimalny szablon lokalnego CSV dla danych zdrowia psychicznego.

## Konfiguracja

Skopiuj:

```powershell
Copy-Item config\etl_config.example.json config\etl_config.json
```

Nastepnie ustaw w `config/etl_config.json`:

```json
{
  "database": {
    "driver": "ODBC Driver 17 for SQL Server",
    "server": "NAZWA_SERWERA",
    "database": "NAZWA_BAZY",
    "trusted_connection": true,
    "username": "",
    "password": ""
  }
}
```

Przyklady wartosci `server`:

- `localhost`
- `localhost\\SQLEXPRESS`
- `(localdb)\\MSSQLLocalDB`
- nazwa instancji widoczna w SSMS.

`database` ustaw na baze, w ktorej uruchomiles `dw_climate_mental_health_DDL-3.sql`.

## Lokalne pliki CSV z repo projektu

ETL moze korzystac z gotowych plikow CSV przygotowanych w repo projektu:

```text
data/raw/FactEconomyYearly.csv
data/raw/FactMentalHealthYearly.csv
```

`FactEconomyYearly.csv` jest mapowany do `staging.STG_ECONOMY`:

- `code` ISO3 -> `COUNTRY_CODE` ISO2,
- `year` -> `YEAR`,
- `GDP` -> `GDP_PER_CAPITA_USD`,
- `HealthExpenditure` -> `HEALTH_EXP_PER_CAPITA_USD`,
- `alkohol_consumption` -> `ALCOHOL_LITERS_PER_CAPITA`,
- `unemployment` -> `UNEMPLOYMENT_PCT`.

`FactMentalHealthYearly.csv` jest mapowany do `staging.STG_MENTAL_HEALTH`.
Szczegolowe zaburzenia sa agregowane do kategorii zgodnych z `dw.DIM_DISORDER`, np.:

- `Major depressive disorder` + `Persistent depressive disorder` -> `Depressive disorders`,
- `Generalized anxiety disorder` + `Panic disorder` + `Social anxiety disorder` -> `Anxiety disorders`,
- `Alcohol abuse` + `Alcohol dependence` -> `Alcohol use disorders`.

ETL odfiltrowuje kraje, ktorych nie ma w aktualnym modelu hurtowni.

## Dane mental health w formacie szerokim

Alternatywnie mozna uzyc oryginalnego CSV z kolumnami zaburzen, np.:

```text
Entity,Code,Year,Prevalence - Depressive disorders - Sex: Both - Age: Age-standardized (Percent)
Poland,POL,2000,3.12
```

Parser rozpoznaje kraje po `Code`/`Entity`, lata po `Year` i zaburzenia po nazwach zgodnych z `dw.DIM_DISORDER`.

## Uruchomienie

Instalacja zaleznosci:

```powershell
python -m pip install -r requirements.txt
```

Pelny proces ETL/ELT:

```powershell
python run_etl.py
```

Tylko transformacja ze staging do hurtowni:

```powershell
python run_etl.py --skip-extract
```

## Co pokazac w raporcie KM3

Jako dowody dzialania dodaj:

- zrzut ekranu z uruchomienia `python run_etl.py`,
- wyniki zapytan z `sql/data_quality_checks.sql`,
- liczbe rekordow w tabelach `staging` i `dw`,
- opis scenariusza inicjalnego ladowania,
- opis scenariusza kolejnego ladowania: proces kasuje i wstawia dane po ziarnie faktow, wiec ponowne uruchomienie nie powinno dublowac rekordow.

## Uwagi

Dane pogodowe sa dzienne, a dane ekonomiczne i zdrowia psychicznego sa roczne. Z tego powodu w hurtowni istnieja widoki agregujace pogode do poziomu miesiecznego, rocznego i sezonowego.
