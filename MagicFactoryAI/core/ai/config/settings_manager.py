"""Settings manager."""

from __future__ import annotations

import json
from pathlib import Path

from core.config.ai_settings import AISettings


class SettingsManager:

    def __init__(self) -> None:

        self._config_dir = Path.home() / ".magicfactory"

        self._config_dir.mkdir(exist_ok=True)

        self._config_file = self._config_dir / "settings.json"

    def load(self) -> AISettings:

        if not self._config_file.exists():

            settings = AISettings()

            self.save(settings)

            return settings

        data = json.loads(
            self._config_file.read_text(
                encoding="utf-8"
            )
        )

        return AISettings(**data)

    def save(
        self,
        settings: AISettings,
    ) -> None:

        self._config_file.write_text(

            json.dumps(
                settings.__dict__,
                indent=4,
            ),

            encoding="utf-8",
        )