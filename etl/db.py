from __future__ import annotations

from pathlib import Path
from typing import Iterable, Sequence


def _import_pyodbc():
    try:
        import pyodbc  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "Brakuje biblioteki pyodbc. Zainstaluj zaleznosci poleceniem: "
            "python -m pip install -r requirements.txt"
        ) from exc
    return pyodbc


def build_connection_string(database_config: dict) -> str:
    parts = [
        f"DRIVER={{{database_config['driver']}}}",
        f"SERVER={database_config['server']}",
        f"DATABASE={database_config['database']}",
    ]

    if database_config.get("trusted_connection", True):
        parts.append("Trusted_Connection=yes")
    else:
        parts.append(f"UID={database_config['username']}")
        parts.append(f"PWD={database_config['password']}")

    parts.append("TrustServerCertificate=yes")
    return ";".join(parts)


def connect(database_config: dict):
    pyodbc = _import_pyodbc()
    return pyodbc.connect(build_connection_string(database_config))


def executemany(cursor, sql: str, rows: Iterable[Sequence], batch_size: int = 1000) -> int:
    cursor.fast_executemany = True
    total = 0
    batch: list[Sequence] = []
    for row in rows:
        batch.append(row)
        if len(batch) >= batch_size:
            cursor.executemany(sql, batch)
            total += len(batch)
            batch.clear()
    if batch:
        cursor.executemany(sql, batch)
        total += len(batch)
    return total


def execute_sql_script(cursor, script_path: str | Path) -> None:
    script = Path(script_path).read_text(encoding="utf-8")
    batch: list[str] = []

    for line in script.splitlines():
        if line.strip().lower() == "go":
            statement = "\n".join(batch).strip()
            if statement:
                cursor.execute(statement)
            batch.clear()
        else:
            batch.append(line)

    statement = "\n".join(batch).strip()
    if statement:
        cursor.execute(statement)
