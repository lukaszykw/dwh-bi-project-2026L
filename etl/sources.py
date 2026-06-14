from __future__ import annotations

import csv
import json
import time
from io import StringIO
from pathlib import Path
from typing import Any, Iterator

import pandas as pd
import requests

from .config import resolve_path


WORLD_BANK_INDICATORS = {
    "GDP_PER_CAPITA_USD": "NY.GDP.PCAP.CD",
    "HEALTH_EXP_PER_CAPITA_USD": "SH.XPD.CHEX.PC.CD",
    "HEALTH_EXP_PCT_GDP": "SH.XPD.CHEX.GD.ZS",
    "UNEMPLOYMENT_PCT": "SL.UEM.TOTL.ZS",
}

COUNTRY_CODE_OVERRIDES = {
    "CZ": "CZ",
}

MENTAL_HEALTH_DISORDER_MAP = {
    "Schizophrenia": "Schizophrenia",
    "Bipolar disorder": "Bipolar disorder",
    "Anorexia": "Eating disorders",
    "Bulimia": "Eating disorders",
    "Binge eating disorder": "Eating disorders",
    "Eating disorders": "Eating disorders",
    "Generalized anxiety disorder": "Anxiety disorders",
    "Panic disorder": "Anxiety disorders",
    "Social anxiety disorder": "Anxiety disorders",
    "Anxiety disorders": "Anxiety disorders",
    "Opioid use disorder": "Drug use disorders",
    "Cannabis use disorder": "Drug use disorders",
    "Stimulant use disorder": "Drug use disorders",
    "Drug use disorders": "Drug use disorders",
    "Major depressive disorder": "Depressive disorders",
    "Persistent depressive disorder": "Depressive disorders",
    "Depression": "Depressive disorders",
    "Depressive disorders": "Depressive disorders",
    "Alcohol dependence": "Alcohol use disorders",
    "Alcohol abuse": "Alcohol use disorders",
    "Alcohol use disorders": "Alcohol use disorders",
}

DISORDER_NAMES = [
    "Depressive disorders",
    "Anxiety disorders",
    "Bipolar disorder",
    "Schizophrenia",
    "Eating disorders",
    "Alcohol use disorders",
    "Drug use disorders",
    "Autism spectrum disorders",
    "Attention-deficit disorders",
    "Conduct disorders",
    "Intellectual disabilities",
]


def load_countries(config: dict[str, Any]) -> list[dict[str, Any]]:
    path = resolve_path(config, config["etl"]["countries_path"])
    if path is None:
        raise ValueError("Brak sciezki countries_path w konfiguracji.")
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def extract_countries(config: dict[str, Any]) -> list[tuple]:
    countries = load_countries(config)
    return [
        (
            c["iso2"],
            c["name"],
            c.get("region"),
            c.get("income_group"),
            c.get("capital_city"),
            c.get("latitude"),
            c.get("longitude"),
        )
        for c in countries
    ]


def extract_weather(config: dict[str, Any]) -> Iterator[tuple]:
    countries = load_countries(config)
    start_date = config["etl"]["weather_start_date"]
    end_date = config["etl"]["weather_end_date"]
    cache_dir = resolve_path(config, config["etl"].get("weather_cache_dir"))
    if cache_dir:
        cache_dir.mkdir(parents=True, exist_ok=True)

    for country in countries:
        try:
            daily = _get_weather_daily(config, country, start_date, end_date, cache_dir)
        except requests.HTTPError as exc:
            if config["etl"].get("weather_skip_failed_countries", True):
                print(f"Skipping weather for {country['iso2']} after API error: {exc}")
                continue
            raise

        if daily is None:
            print(f"Skipping weather for {country['iso2']}: no cache file and cache-only mode is enabled.")
            continue

        for idx, obs_date in enumerate(daily["time"]):
            yield (
                country["iso2"],
                obs_date,
                _value_at(daily, "temperature_2m_mean", idx),
                _value_at(daily, "temperature_2m_min", idx),
                _value_at(daily, "temperature_2m_max", idx),
                _value_at(daily, "precipitation_sum", idx),
                _value_at(daily, "sunshine_duration", idx),
                _value_at(daily, "cloud_cover_mean", idx),
                _value_at(daily, "wind_speed_10m_max", idx),
            )


def _get_weather_daily(
    config: dict[str, Any],
    country: dict[str, Any],
    start_date: str,
    end_date: str,
    cache_dir: Path | None,
) -> dict[str, list] | None:
    cache_path = None
    if cache_dir:
        cache_path = cache_dir / f"{country['iso2']}_{start_date}_{end_date}.json"
        if cache_path.exists():
            with cache_path.open("r", encoding="utf-8") as f:
                return json.load(f)["daily"]

    if config["etl"].get("weather_use_cache_only", False):
        return None

    params = {
        "latitude": country["latitude"],
        "longitude": country["longitude"],
        "start_date": start_date,
        "end_date": end_date,
        "daily": ",".join(
            [
                "temperature_2m_mean",
                "temperature_2m_min",
                "temperature_2m_max",
                "precipitation_sum",
                "sunshine_duration",
                "cloud_cover_mean",
                "wind_speed_10m_max",
            ]
        ),
        "timezone": "UTC",
    }

    payload = _request_json_with_retry(
        config["sources"]["open_meteo_archive_url"],
        params=params,
        max_retries=int(config["etl"].get("weather_max_retries", 6)),
    )
    delay = float(config["etl"].get("weather_request_delay_seconds", 2))
    if delay > 0:
        time.sleep(delay)

    if cache_path:
        with cache_path.open("w", encoding="utf-8") as f:
            json.dump(payload, f)
    return payload["daily"]


def _request_json_with_retry(url: str, params: dict[str, Any], max_retries: int) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(1, max_retries + 1):
        response = requests.get(url, params=params, timeout=60)
        if response.status_code == 429:
            if attempt >= max_retries:
                response.raise_for_status()
            wait_seconds = min(120, 10 * (2 ** attempt))
            retry_after = response.headers.get("Retry-After")
            if retry_after and retry_after.isdigit():
                wait_seconds = max(wait_seconds, int(retry_after))
            print(f"Open-Meteo 429, waiting {wait_seconds}s before retry {attempt + 1}/{max_retries}...")
            time.sleep(wait_seconds)
            continue

        try:
            response.raise_for_status()
            return response.json()
        except requests.RequestException as exc:
            last_error = exc
            if attempt >= max_retries:
                raise
            wait_seconds = min(60, 5 * (2 ** attempt))
            print(f"Open-Meteo request failed, waiting {wait_seconds}s before retry {attempt + 1}/{max_retries}...")
            time.sleep(wait_seconds)

    if last_error:
        raise last_error
    raise RuntimeError("Open-Meteo request failed after retries.")


def extract_economy(config: dict[str, Any]) -> list[tuple]:
    csv_path = resolve_path(config, config["sources"].get("economy_csv_path"))
    if csv_path and csv_path.exists():
        return extract_economy_from_csv(config, csv_path)

    countries = load_countries(config)
    start_year = int(config["etl"]["start_year"])
    end_year = int(config["etl"]["end_year"])
    url_template = config["sources"]["world_bank_indicator_url"]
    rows: dict[tuple[str, int], dict[str, Any]] = {}

    for country in countries:
        for target_column, indicator in WORLD_BANK_INDICATORS.items():
            url = url_template.format(country_code=country["iso2"], indicator=indicator)
            params = {"format": "json", "date": f"{start_year}:{end_year}", "per_page": 20000}
            response = requests.get(url, params=params, timeout=60)
            response.raise_for_status()
            payload = response.json()
            observations = payload[1] if isinstance(payload, list) and len(payload) > 1 else []

            for item in observations:
                if item.get("value") is None:
                    continue
                year = int(item["date"])
                key = (country["iso2"], year)
                rows.setdefault(key, {"COUNTRY_CODE": country["iso2"], "YEAR": year})
                rows[key][target_column] = item["value"]

    result = []
    for _, values in sorted(rows.items()):
        result.append(
            (
                values["COUNTRY_CODE"],
                values["YEAR"],
                values.get("GDP_PER_CAPITA_USD"),
                values.get("HEALTH_EXP_PER_CAPITA_USD"),
                values.get("HEALTH_EXP_PCT_GDP"),
                None,
                values.get("UNEMPLOYMENT_PCT"),
            )
        )
    return result


def extract_economy_from_csv(config: dict[str, Any], csv_path: Path) -> list[tuple]:
    df = pd.read_csv(csv_path)
    countries = load_countries(config)
    iso3_to_iso2 = {c["iso3"]: c["iso2"] for c in countries}
    valid_iso2 = {c["iso2"] for c in countries}
    start_year = int(config["etl"]["start_year"])
    end_year = int(config["etl"]["end_year"])

    rows: list[tuple] = []
    for _, record in df.iterrows():
        year = int(record["year"])
        if year < start_year or year > end_year:
            continue

        raw_code = str(record["code"])
        country_code = COUNTRY_CODE_OVERRIDES.get(raw_code, iso3_to_iso2.get(raw_code))
        if country_code not in valid_iso2:
            continue

        rows.append(
            (
                country_code,
                year,
                _to_float(record.get("GDP")),
                _to_float(record.get("HealthExpenditure")),
                None,
                _to_float(record.get("alkohol_consumption")),
                _to_float(record.get("unemployment")),
            )
        )
    return rows


def extract_mental_health(config: dict[str, Any]) -> list[tuple]:
    csv_path = resolve_path(config, config["sources"].get("mental_health_csv_path"))
    if csv_path and csv_path.exists():
        df = pd.read_csv(csv_path)
    elif config["sources"].get("mental_health_csv_url"):
        df = _read_remote_csv(config["sources"]["mental_health_csv_url"])
    else:
        expected_path = csv_path or Path("data/raw/mental_health_owid.csv")
        raise FileNotFoundError(
            "Brakuje pliku z danymi mental health. Umiesc CSV w "
            f"{expected_path} albo ustaw sources.mental_health_csv_url w konfiguracji."
        )

    if {"country", "year", "disorder", "value"}.issubset(set(df.columns)):
        return extract_mental_health_from_long_csv(config, df)

    countries = load_countries(config)
    iso3_to_iso2 = {c["iso3"]: c["iso2"] for c in countries}
    name_to_iso2 = {c["name"]: c["iso2"] for c in countries}
    start_year = int(config["etl"]["start_year"])
    end_year = int(config["etl"]["end_year"])

    code_col = _first_existing(df, ["Code", "code", "ISO3"])
    country_col = _first_existing(df, ["Entity", "Country", "country"])
    year_col = _first_existing(df, ["Year", "year"])
    if year_col is None:
        raise ValueError("Nie znaleziono kolumny roku w pliku mental health.")

    rows: list[tuple] = []
    for _, record in df.iterrows():
        year = int(record[year_col])
        if year < start_year or year > end_year:
            continue

        country_code = None
        if code_col and pd.notna(record.get(code_col)):
            country_code = iso3_to_iso2.get(str(record[code_col]))
        if not country_code and country_col and pd.notna(record.get(country_col)):
            country_code = name_to_iso2.get(str(record[country_col]))
        if not country_code:
            continue

        for disorder in DISORDER_NAMES:
            prevalence_col = _find_metric_column(df.columns, disorder, ["prevalence", "percent", "share"])
            if prevalence_col is None:
                prevalence_col = _find_wide_disorder_column(df.columns, disorder)
            if prevalence_col is None or pd.isna(record.get(prevalence_col)):
                continue
            dalys_col = _find_metric_column(df.columns, disorder, ["daly", "dalys"])
            rows.append(
                (
                    country_code,
                    year,
                    disorder,
                    _to_float(record[prevalence_col]),
                    None if dalys_col is None or pd.isna(record.get(dalys_col)) else _to_float(record[dalys_col]),
                )
            )
    return rows


def extract_mental_health_from_long_csv(config: dict[str, Any], df: pd.DataFrame) -> list[tuple]:
    countries = load_countries(config)
    name_to_iso2 = {c["name"]: c["iso2"] for c in countries}
    valid_iso2 = {c["iso2"] for c in countries}
    start_year = int(config["etl"]["start_year"])
    end_year = int(config["etl"]["end_year"])

    normalized: dict[tuple[str, int, str], float] = {}
    for _, record in df.iterrows():
        year = int(record["year"])
        if year < start_year or year > end_year:
            continue

        country_code = name_to_iso2.get(str(record["country"]))
        if country_code not in valid_iso2:
            continue

        disorder_name = MENTAL_HEALTH_DISORDER_MAP.get(str(record["disorder"]))
        if not disorder_name:
            continue

        key = (country_code, year, disorder_name)
        normalized[key] = normalized.get(key, 0.0) + float(record["value"])

    return [
        (country_code, year, disorder_name, prevalence_pct, None)
        for (country_code, year, disorder_name), prevalence_pct in sorted(normalized.items())
    ]


def write_csv(path: Path, header: list[str], rows: list[tuple]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)


def _value_at(daily: dict[str, list], key: str, idx: int):
    values = daily.get(key) or []
    if idx >= len(values):
        return None
    return values[idx]


def _first_existing(df: pd.DataFrame, names: list[str]) -> str | None:
    for name in names:
        if name in df.columns:
            return name
    return None


def _find_metric_column(columns, disorder: str, tokens: list[str]) -> str | None:
    disorder_key = disorder.lower().replace("-", " ")
    for column in columns:
        col = str(column).lower().replace("-", " ")
        if disorder_key in col and any(token in col for token in tokens):
            return str(column)
    return None


def _find_wide_disorder_column(columns, disorder: str) -> str | None:
    aliases = {
        "Depressive disorders": ["Depression (%)"],
        "Anxiety disorders": ["Anxiety disorders (%)"],
        "Bipolar disorder": ["Bipolar disorder (%)"],
        "Schizophrenia": ["Schizophrenia (%)"],
        "Eating disorders": ["Eating disorders (%)"],
        "Alcohol use disorders": ["Alcohol use disorders (%)"],
        "Drug use disorders": ["Drug use disorders (%)"],
    }
    for alias in aliases.get(disorder, []):
        if alias in columns:
            return alias
    return None


def _to_float(value):
    if pd.isna(value):
        return None
    if isinstance(value, str):
        value = value.replace(",", ".")
    return float(value)


def _read_remote_csv(url: str) -> pd.DataFrame:
    response = requests.get(
        url,
        timeout=60,
        headers={"User-Agent": "ClimateMentalHealthDW-ETL/1.0"},
    )
    response.raise_for_status()
    return pd.read_csv(StringIO(response.text))
