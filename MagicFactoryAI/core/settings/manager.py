"""Persistent application settings with JSON storage."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any, Optional

from utils.logger import get_logger
from utils.paths import get_config_dir, get_data_dir

logger = get_logger(__name__)


class SettingsManager:
    """Loads defaults from config/, merges user overrides from data/."""

    _instance: Optional[SettingsManager] = None

    def __init__(self) -> None:
        self._defaults_path = get_config_dir() / "default_settings.json"
        self._user_path = get_data_dir() / "user_settings.json"
        self._settings: dict[str, Any] = {}
        self._load()

    @classmethod
    def instance(cls) -> SettingsManager:
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _load(self) -> None:
        defaults: dict[str, Any] = {}
        if self._defaults_path.exists():
            with open(self._defaults_path, encoding="utf-8") as f:
                defaults = json.load(f)

        user_overrides: dict[str, Any] = {}
        if self._user_path.exists():
            with open(self._user_path, encoding="utf-8") as f:
                user_overrides = json.load(f)

        self._settings = self._deep_merge(defaults, user_overrides)
        logger.info("Settings loaded from %s", self._defaults_path)

    def _deep_merge(self, base: dict, override: dict) -> dict:
        result = copy.deepcopy(base)
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = copy.deepcopy(value)
        return result

    def save(self) -> None:
        self._user_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self._user_path, "w", encoding="utf-8") as f:
            json.dump(self._settings, f, indent=2)
        logger.info("Settings saved to %s", self._user_path)

    def get(self, key_path: str, default: Any = None) -> Any:
        """Get a nested setting using dot notation, e.g. 'app.window_width'."""
        keys = key_path.split(".")
        value: Any = self._settings
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        return value

    def set(self, key_path: str, value: Any, persist: bool = True) -> None:
        """Set a nested setting using dot notation."""
        keys = key_path.split(".")
        target = self._settings
        for key in keys[:-1]:
            target = target.setdefault(key, {})
        target[keys[-1]] = value
        if persist:
            self.save()

    @property
    def all(self) -> dict[str, Any]:
        return copy.deepcopy(self._settings)

    @property
    def app_name(self) -> str:
        return str(self.get("app.name", "Magic Factory AI"))

    @property
    def window_size(self) -> tuple[int, int]:
        return (
            int(self.get("app.window_width", 1400)),
            int(self.get("app.window_height", 900)),
        )

    @property
    def sidebar_width(self) -> int:
        return int(self.get("app.sidebar_width", 260))

    @property
    def log_level(self) -> str:
        return str(self.get("logging.level", "INFO"))
