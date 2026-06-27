"""Application path resolution."""

from __future__ import annotations

from pathlib import Path


def get_app_root() -> Path:
    """Return the MagicFactoryAI project root directory."""
    return Path(__file__).resolve().parent.parent


def get_data_dir() -> Path:
    """Return the writable application data directory."""
    data_dir = get_app_root() / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    return data_dir


def get_config_dir() -> Path:
    """Return the configuration directory."""
    config_dir = get_app_root() / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir


def get_logs_dir() -> Path:
    """Return the logs directory."""
    logs_dir = get_app_root() / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    return logs_dir


def get_assets_dir() -> Path:
    """Return the static assets directory."""
    assets_dir = get_app_root() / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    return assets_dir


def get_exports_dir() -> Path:
    """Return the default export output directory."""
    exports_dir = get_data_dir() / "exports"
    exports_dir.mkdir(parents=True, exist_ok=True)
    return exports_dir


def get_library_dir() -> Path:
    """Return the asset library storage directory."""
    library_dir = get_data_dir() / "library"
    library_dir.mkdir(parents=True, exist_ok=True)
    return library_dir
