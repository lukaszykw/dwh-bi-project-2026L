from __future__ import annotations

from . import sources
from .config import ROOT_DIR, load_config
from .db import connect, execute_sql_script, executemany


def load_all(config_path: str | None = None) -> None:
    config = load_config(config_path)
    batch_size = int(config["etl"].get("batch_size", 1000))

    with connect(config["database"]) as conn:
        cursor = conn.cursor()

        if config["etl"].get("truncate_staging_before_load", True):
            execute_sql_script(cursor, ROOT_DIR / "sql" / "truncate_staging.sql")
            conn.commit()

        countries = sources.extract_countries(config)
        count = executemany(
            cursor,
            """
            insert into staging.STG_COUNTRY
                (COUNTRY_CODE, NAME, REGION, INCOME_GROUP, CAPITAL_CITY, LATITUDE, LONGITUDE)
            values (?, ?, ?, ?, ?, ?, ?)
            """,
            countries,
            batch_size,
        )
        print(f"STG_COUNTRY: {count} rows")

        weather_count = executemany(
            cursor,
            """
            insert into staging.STG_WEATHER
                (COUNTRY_CODE, OBS_DATE, TEMP_AVG_C, TEMP_MIN_C, TEMP_MAX_C,
                 PRECIP_MM, SUNSHINE_S, CLOUD_COVER_PCT, WIND_SPEED_KMH)
            values (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            sources.extract_weather(config),
            batch_size,
        )
        print(f"STG_WEATHER: {weather_count} rows")

        economy = sources.extract_economy(config)
        economy_count = executemany(
            cursor,
            """
            insert into staging.STG_ECONOMY
                (COUNTRY_CODE, YEAR, GDP_PER_CAPITA_USD, HEALTH_EXP_PER_CAPITA_USD,
                 HEALTH_EXP_PCT_GDP, ALCOHOL_LITERS_PER_CAPITA, UNEMPLOYMENT_PCT)
            values (?, ?, ?, ?, ?, ?, ?)
            """,
            economy,
            batch_size,
        )
        print(f"STG_ECONOMY: {economy_count} rows")

        mental_health = sources.extract_mental_health(config)
        mental_count = executemany(
            cursor,
            """
            insert into staging.STG_MENTAL_HEALTH
                (COUNTRY_CODE, YEAR, DISORDER_NAME, PREVALENCE_PCT, DALYS_PER_100K)
            values (?, ?, ?, ?, ?)
            """,
            mental_health,
            batch_size,
        )
        print(f"STG_MENTAL_HEALTH: {mental_count} rows")

        conn.commit()


if __name__ == "__main__":
    load_all()
