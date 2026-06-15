# Climate, Economy and Mental Health DW/BI

Projekt hurtowni danych dla analizy zaleznosci pomiedzy klimatem, ekonomia i wskaznikami zdrowia psychicznego w Europie w latach 2000-2010.

## Zakres systemu

- SQL Server jako hurtownia danych.
- Python jako warstwa ETL/ELT.
- Tabele stagingowe `staging.STG_*`.
- Model hurtowni w schemacie `dw`.
- Widoki agregujace pogode do poziomu miesiecznego, rocznego i sezonowego.
- SQL-e weryfikacyjne i testy funkcjonalne pod KM3.

## Najwazniejsze pliki

- `dw_climate_mental_health_DDL-3.sql` - definicja modelu hurtowni danych.
- `run_etl.py` - uruchomienie procesu ETL/ELT.
- `etl/` - kod Pythona do ekstrakcji danych i ladowania stagingu.
- `sql/load_dw_from_staging.sql` - transformacje SQL ze stagingu do hurtowni.
- `sql/verification_km3.sql` - zapytania weryfikacyjne i testowe.
- `tests/functional_tests.md` - opis testow funkcjonalnych.
- `ETL_README.md` - szczegolowa instrukcja konfiguracji i uruchomienia ETL.

## Uruchomienie

1. Utworz baze danych w SQL Server.
2. Uruchom `dw_climate_mental_health_DDL-3.sql` w SSMS.
3. Skopiuj konfiguracje:

```powershell
Copy-Item config\etl_config.example.json config\etl_config.json
```

4. Ustaw w `config/etl_config.json` nazwe serwera i bazy.
5. Zainstaluj zaleznosci:

```powershell
python -m pip install -r requirements.txt
```

6. Uruchom ETL:

```powershell
python run_etl.py
```

7. W SSMS wykonaj:

```text
sql/verification_km3.sql
```

## Dane źródłowe

Repozytorium zawiera lokalne pliki CSV używane w finalnym ETL:

```text
data/raw/FactEconomyYearly.csv
data/raw/FactMentalHealthYearly.csv
```

Cache odpowiedzi Open-Meteo nie jest wersjonowany. Przy uruchomieniu ETL dane pogodowe zostana pobrane z API albo odczytane z lokalnego cache, jesli uzytkownik posiada katalog `data/cache/weather`.

Szczegoly mapowania danych sa opisane w `ETL_README.md`, a finalne mapowanie source-to-target znajduje sie w `STTM.xlsx`.
