from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = ROOT_DIR / "config" / "etl_config.json"
EXAMPLE_CONFIG_PATH = ROOT_DIR / "config" / "etl_config.example.json"


def load_config(path: str | Path | None = None) -> dict[str, Any]:
    config_path = Path(path) if path else DEFAULT_CONFIG_PATH
    if not config_path.exists():
        config_path = EXAMPLE_CONFIG_PATH

    with config_path.open("r", encoding="utf-8") as f:
        config = json.load(f)

    config["_root_dir"] = str(ROOT_DIR)
    config["_config_path"] = str(config_path)
    return config


def resolve_path(config: dict[str, Any], value: str | None) -> Path | None:
    if not value:
        return None

    path = Path(value)
    if path.is_absolute():
        return path
    return Path(config["_root_dir"]) / path
