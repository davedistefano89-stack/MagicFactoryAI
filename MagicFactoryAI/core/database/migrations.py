"""Database migration utilities for future schema upgrades."""

from __future__ import annotations

from core.database.connection import DatabaseConnection
from core.database.schema import SCHEMA_VERSION
from utils.logger import get_logger

logger = get_logger(__name__)


def get_current_version(db: DatabaseConnection) -> int:
    conn = db.connect()
    try:
        row = conn.execute("SELECT version FROM schema_version LIMIT 1").fetchone()
        return int(row["version"]) if row else 0
    except Exception:
        return 0


def run_migrations(db: DatabaseConnection) -> None:
    """Apply pending schema migrations. Extend this as the schema evolves."""
    current = get_current_version(db)
    if current >= SCHEMA_VERSION:
        logger.info("Database schema is up to date (v%d)", current)
        return

    logger.info("Migrating database from v%d to v%d", current, SCHEMA_VERSION)
    db.initialize()
