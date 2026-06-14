# Testy funkcjonalne KM3

## Zakres

Testy potwierdzaja dzialanie procesu od lokalnych/API zrodel danych, przez staging i hurtownie danych, do warstwy raportowej. Wyniki testow nalezy udokumentowac zrzutami ekranu z konsoli, SSMS i Power BI.

## TF-01: Uruchomienie polaczenia z baza danych

Cel: potwierdzenie, ze modul ETL laczy sie z baza SQL Server, w ktorej utworzono model hurtowni.

Kroki:

1. Ustaw `server`, `database` i `trusted_connection` w `config/etl_config.json`.
2. Uruchom `python run_etl.py --skip-extract`.

Oczekiwany wynik: skrypt laczy sie z baza i uruchamia SQL ELT bez bledu logowania.

Potwierdzenie: zrzut ekranu z konsoli albo komunikat bledu/braku bledu.

## TF-02: Ladowanie danych do staging

Cel: potwierdzenie, ze ETL zasila tabele `staging.STG_COUNTRY`, `staging.STG_WEATHER`, `staging.STG_ECONOMY` i `staging.STG_MENTAL_HEALTH`.

Kroki:

1. Uruchom `python run_etl.py`.
2. Po zakonczeniu wykonaj sekcje `01_ROW_COUNTS` z `sql/verification_km3.sql`.

Oczekiwany wynik: tabele stagingowe maja niezerowa liczbe rekordow.

Potwierdzenie: wynik zapytania SQL z liczba rekordow.

## TF-03: Ladowanie inicjalne hurtowni

Cel: potwierdzenie, ze dane ze stagingu sa transformowane do faktow hurtowni.

Kroki:

1. Uruchom pelny ETL.
2. Sprawdz liczbe rekordow w `dw.FACT_WEATHER`, `dw.FACT_ECONOMY` i `dw.FACT_MENTAL_HEALTH`.

Oczekiwany wynik: wszystkie trzy tabele faktow maja rekordy, a klucze obce wskazuja na wymiary.

Potwierdzenie: wynik sekcji `01_ROW_COUNTS` i `04_FOREIGN_KEY_COVERAGE`.

## TF-04: Ponowne ladowanie bez duplikatow

Cel: potwierdzenie scenariusza kolejnej iteracji ladowania.

Kroki:

1. Zapisz liczbe rekordow w tabelach faktow.
2. Uruchom ponownie `python run_etl.py`.
3. Ponownie sprawdz liczbe rekordow i duplikaty po ziarnie faktow.

Oczekiwany wynik: liczba rekordow pozostaje stabilna dla tego samego zakresu danych, a testy duplikatow zwracaja `0`.

Potwierdzenie: wyniki sekcji `02_DUPLICATE_GRAIN_CHECKS`.

## TF-05: Poprawnosc transformacji pogody

Cel: potwierdzenie konwersji danych pogodowych ze stagingu do faktu dziennego.

Kroki:

1. Porownaj `staging.STG_WEATHER.SUNSHINE_S` z `dw.FACT_WEATHER.SUNSHINE_H`.
2. Sprawdz zakresy temperatur, opadow, zachmurzenia i wiatru.

Oczekiwany wynik: naslonecznienie w fakcie jest w godzinach, a wartosci pogodowe mieszcza sie w realistycznych zakresach.

Potwierdzenie: wyniki sekcji `03_VALUE_RANGE_CHECKS` i probka danych z `07_SAMPLE_BUSINESS_DATA`.

## TF-06: Poprawnosc transformacji ekonomii

Cel: potwierdzenie mapowania lokalnego CSV ekonomicznego do `dw.FACT_ECONOMY`.

Kroki:

1. Sprawdz, czy lata mieszcza sie w zakresie 2000-2010.
2. Sprawdz, czy nie ma ujemnego PKB, wydatkow zdrowotnych, alkoholu ani bezrobocia poza zakresem 0-100%.

Oczekiwany wynik: zakres lat jest zgodny z projektem, a test wartosci skrajnych zwraca `0`.

Potwierdzenie: wyniki sekcji `03_VALUE_RANGE_CHECKS` i `06_DATE_RANGE_COVERAGE`.

## TF-07: Poprawnosc transformacji zdrowia psychicznego

Cel: potwierdzenie agregacji szczegolowych zaburzen do kategorii zgodnych z `dw.DIM_DISORDER`.

Kroki:

1. Sprawdz, czy `dw.FACT_MENTAL_HEALTH` laczy sie z `dw.DIM_DISORDER`.
2. Sprawdz liczbe rekordow wedlug zaburzenia.

Oczekiwany wynik: brak rekordow bez wymiaru zaburzenia; wystepuja glownie kategorie `Depressive disorders`, `Anxiety disorders`, `Alcohol use disorders`, `Drug use disorders`, `Eating disorders`, `Bipolar disorder`, `Schizophrenia`.

Potwierdzenie: wyniki sekcji `04_FOREIGN_KEY_COVERAGE` i `05_BUSINESS_DISTRIBUTIONS`.

## TF-08: Agregaty pogodowe

Cel: potwierdzenie dzialania widokow agregujacych pogode.

Kroki:

1. Wykonaj zapytania z sekcji `08_AGGREGATE_VIEWS`.
2. Sprawdz liczbe rekordow w widokach miesiecznych, rocznych i sezonowych.

Oczekiwany wynik: widoki zwracaja dane i moga byc uzyte w Power BI.

Potwierdzenie: wyniki SQL z `dw.AGG_WEATHER_MONTHLY`, `dw.AGG_WEATHER_ANNUAL`, `dw.AGG_WEATHER_SEASONAL`.

## TF-09: Raport Power BI

Cel: potwierdzenie dostepu raportu do danych hurtowni.

Kroki:

1. Podlacz Power BI do SQL Servera.
2. Zaladuj tabele `dw` i widoki agregujace.
3. Odswiez model.

Oczekiwany wynik: model odswieza sie bez bledow, a wizualizacje pokazuja dane dla krajow i lat 2000-2010.

Potwierdzenie: zrzut ekranu z Power BI po odswiezeniu.

## TF-10: Test end-to-end

Cel: potwierdzenie calosciowego dzialania systemu.

Kroki:

1. Uruchom `python run_etl.py`.
2. Wykonaj `sql/verification_km3.sql`.
3. Odswiez raport Power BI.
4. Wyeksportuj przykladowy raport do PDF.

Oczekiwany wynik: dane przechodza od zrodel przez staging i hurtownie do raportu koncowego.

Potwierdzenie: log z ETL, wyniki SQL, zrzut raportu i wygenerowany PDF.
