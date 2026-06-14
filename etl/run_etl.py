from __future__ import annotations

import argparse
from pathlib import Path

from .config import ROOT_DIR, load_config
from .db import connect, execute_sql_script
from .load_staging import load_all


def main() -> None:
    parser = argparse.ArgumentParser(description="Climate/Mental Health DW ETL/ELT")
    parser.add_argument("--config", default=None, help="Sciezka do pliku konfiguracji JSON.")
    parser.add_argument(
        "--skip-extract",
        action="store_true",
        help="Pomin pobieranie danych i uruchom tylko ELT ze staging do DW.",
    )
    args = parser.parse_args()

    config = load_config(args.config)

    if not args.skip_extract:
        load_all(args.config)

    with connect(config["database"]) as conn:
        cursor = conn.cursor()
        execute_sql_script(cursor, ROOT_DIR / "sql" / "load_dw_from_staging.sql")
        execute_sql_script(cursor, ROOT_DIR / "sql" / "data_quality_checks.sql")
        conn.commit()

    print("ETL/ELT finished successfully.")


if __name__ == "__main__":
    main()
