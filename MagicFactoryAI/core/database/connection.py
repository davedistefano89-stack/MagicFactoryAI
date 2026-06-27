"""SQLite database connection and schema management."""

from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional

from core.database.schema import SCHEMA_VERSION, get_schema_sql
from utils.logger import get_logger
from utils.paths import get_data_dir

logger = get_logger(__name__)


class DatabaseConnection:
    """Thread-safe SQLite connection manager with schema migrations."""

    _instance: Optional[DatabaseConnection] = None

    def __init__(self, db_path: Optional[Path] = None) -> None:
        self._db_path = db_path or (get_data_dir() / "magic_factory.db")
        self._connection: Optional[sqlite3.Connection] = None

    @classmethod
    def instance(cls, db_path: Optional[Path] = None) -> DatabaseConnection:
        if cls._instance is None:
            cls._instance = cls(db_path)
        return cls._instance

    @property
    def path(self) -> Path:
        return self._db_path

    def connect(self) -> sqlite3.Connection:
        if self._connection is None:
            self._db_path.parent.mkdir(parents=True, exist_ok=True)
            self._connection = sqlite3.connect(str(self._db_path), check_same_thread=False)
            self._connection.row_factory = sqlite3.Row
            self._connection.execute("PRAGMA foreign_keys = ON")
            self._connection.execute("PRAGMA journal_mode = WAL")
            logger.info("Connected to database: %s", self._db_path)
        return self._connection

    def initialize(self) -> None:
        conn = self.connect()
        conn.executescript(get_schema_sql())
        conn.commit()
        logger.info("Database schema initialized (version %d)", SCHEMA_VERSION)

    @contextmanager
    def transaction(self) -> Generator[sqlite3.Connection, None, None]:
        conn = self.connect()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise

    def close(self) -> None:
        if self._connection is not None:
            self._connection.close()
            self._connection = None
            logger.info("Database connection closed")

    @classmethod
    def reset_instance(cls) -> None:
        if cls._instance is not None:
            cls._instance.close()
            cls._instance = None
