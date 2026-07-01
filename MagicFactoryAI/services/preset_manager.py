"""Generation Preset manager — persists presets via SettingsManager."""

from __future__ import annotations

import copy
from typing import Dict, List, Optional

from core.settings.manager import SettingsManager

_SETTINGS_KEY = "generation_presets"
_DEFAULT_PRESET_NAME = "Default"

DEFAULT_PRESET: Dict = {
    "provider": "OpenAI",
    "model": "gpt-image-1",
    "size": "1024x1024",
    "quality": "high",
    "seed": 0,
    "seed_mode": "Random",
    "steps": 20,
    "guidance_scale": 7.5,
    "negative_prompt": "",
    "prompt_prefix": "",
    "prompt_suffix": "",
}


class PresetManager:
    """CRUD operations for generation presets stored in user settings."""

    def __init__(self) -> None:
        self._settings = SettingsManager.instance()

    # ── Storage helpers ───────────────────────────────────────────────────────

    def _load(self) -> dict:
        return self._settings.get(_SETTINGS_KEY, {})

    def _persist(self, block: dict) -> None:
        self._settings.set(_SETTINGS_KEY, copy.deepcopy(block))

    # ── Public API ────────────────────────────────────────────────────────────

    def ensure_default(self) -> None:
        """Create the built-in Default preset if no presets exist yet."""
        block = self._load()
        if not block.get("presets"):
            block["presets"] = {_DEFAULT_PRESET_NAME: copy.deepcopy(DEFAULT_PRESET)}
        if not block.get("default"):
            block["default"] = _DEFAULT_PRESET_NAME
        self._persist(block)

    def get_all(self) -> Dict[str, dict]:
        return dict(self._load().get("presets", {}))

    def get(self, name: str) -> Optional[dict]:
        return self._load().get("presets", {}).get(name)

    def save(self, name: str, data: dict) -> None:
        block = self._load()
        block.setdefault("presets", {})[name] = copy.deepcopy(data)
        if not block.get("default"):
            block["default"] = name
        self._persist(block)

    def delete(self, name: str) -> None:
        block = self._load()
        block.get("presets", {}).pop(name, None)
        self._persist(block)

    def rename(self, old: str, new: str) -> None:
        block = self._load()
        presets = block.get("presets", {})
        if old in presets:
            presets[new] = presets.pop(old)
        if block.get("default") == old:
            block["default"] = new
        self._persist(block)

    def duplicate(self, name: str, new_name: str) -> None:
        block = self._load()
        presets = block.get("presets", {})
        if name in presets:
            presets[new_name] = copy.deepcopy(presets[name])
        self._persist(block)

    def get_default(self) -> str:
        return self._load().get("default", _DEFAULT_PRESET_NAME)

    def set_default(self, name: str) -> None:
        block = self._load()
        block["default"] = name
        self._persist(block)

    def get_sorted_names(self) -> List[str]:
        """Return names sorted alphabetically, default preset listed first."""
        presets = self._load().get("presets", {})
        default = self.get_default()
        names = sorted(presets.keys(), key=str.lower)
        if default in names:
            names.remove(default)
            names.insert(0, default)
        return names
