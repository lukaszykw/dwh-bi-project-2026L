# Jak wykonac testy

1. Uruchom pelny proces:

```powershell
python run_etl.py
```

2. W SSMS otworz i wykonaj:

```text
sql/verification_km3.sql
```

3. Do raportu finalnego dodaj:

- zrzut ekranu z konsoli po `python run_etl.py`,
- wynik sekcji `01_ROW_COUNTS`,
- wynik sekcji `02_DUPLICATE_GRAIN_CHECKS`,
- wynik sekcji `03_VALUE_RANGE_CHECKS`,
- wynik sekcji `04_FOREIGN_KEY_COVERAGE`,
- przykladowy wynik sekcji `09_END_TO_END_ANALYTIC_QUERY`,
- zrzut ekranu z odswiezenia Power BI.

Opis testow funkcjonalnych znajduje sie w `tests/functional_tests.md`.
