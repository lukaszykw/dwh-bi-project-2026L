# Manifest repozytorium i paczki KM3

## Pliki, ktore powinny trafic do repozytorium

- `README.md` - opis projektu i instrukcja uruchomienia.
- `ETL_README.md` - szczegoly procesu ETL/ELT.
- `requirements.txt` - zaleznosci Pythona.
- `run_etl.py` oraz katalog `etl/` - kod zrodlowy ETL.
- `dw_climate_mental_health_DDL-3.sql` - skrypt modelu hurtowni.
- `sql/` - skrypty ELT i weryfikacyjne.
- `config/etl_config.example.json` - przykladowa konfiguracja bez lokalnych danych logowania.
- `config/countries_europe.json` - metadane krajow wykorzystywane przez ETL.
- `data/templates/` - szablony danych wejsciowych.
- `tests/` - opis testow funkcjonalnych.
- `scripts/generate_km3_documents.py` - generator raportu i prezentacji.

## Pliki do oddania jako zalaczniki

- `KM3_Raport_Finalny.docx` lub wyeksportowany z niego PDF.
- `KM3_Prezentacja.pptx`, jesli zespół zdecyduje sie prezentowac ze slajdow.
- `Power_BI_Raport.pdf` - eksport raportow Power BI.
- Plik `.pbix` z Power BI, jesli zostal zapisany lokalnie.
- `STTM_KM2-1.xlsx`, najlepiej po aktualizacji do finalnego ETL.

## Pliki lokalne, ktorych nie wrzucac do repozytorium

- `config/etl_config.json` - lokalna konfiguracja polaczenia z baza.
- `data/cache/` - cache Open-Meteo.
- `data/raw/` - lokalne pliki zrodlowe CSV.
- `.vs/` - pliki Visual Studio.
- `github_DWH-project/` - pomocniczo sklonowane repo.
- `__pycache__/`, `*.pyc`, `~$*` - artefakty narzedzi.

## Uwaga o danych zrodlowych

Repozytorium nie zawiera lokalnych danych `data/raw/`, bo sa traktowane jako dane wejsciowe. Do uruchomienia pelnego ETL nalezy dostarczyc:

```text
data/raw/FactEconomyYearly.csv
data/raw/FactMentalHealthYearly.csv
```

Szczegoly mapowania tych plikow opisuje `ETL_README.md`.
