"""Byte-budgeted LRU cache for thumbnail pixmaps.

Created for Sprint: Performance Optimizer.

The cache is intentionally QPixmap-aware. We approximate the per-pixmap
byte cost as ``width * height * 4`` (one 32-bit pixel). This is cheap
(O(1), no serialization) and tracks the dominant memory cost for the
rasterized image data that Qt allocates for QPixmap uploads.

The cache is thread-safe so worker threads can probe ``get()`` / write
``put()`` while the GUI thread is reading ``stats()`` for diagnostics.
"""

from __future__ import annotations

import threading
from collections import OrderedDict
from typing import Optional

from PySide6.QtGui import QPixmap

from utils.logger import get_logger

logger = get_logger(__name__)


class ThumbnailLRUCache:
    """LRU cache sized in approximate bytes, thread-safe."""

    def __init__(self, max_bytes: int = 64 * 1024 * 1024) -> None:
        self._max_bytes = int(max_bytes)
        self._current_bytes = 0
        self._cache: "OrderedDict[str, QPixmap]" = OrderedDict()
        self._lock = threading.Lock()
        self._hits = 0
        self._misses = 0

    # ── Public API ───────────────────────────────────────────────────────────

    def get(self, key: str) -> Optional[QPixmap]:
        """Return a cached pixmap, marking it most-recently-used, or None."""
        with self._lock:
            pix = self._cache.get(key)
            if pix is not None:
                self._cache.move_to_end(key)
                self._hits += 1
                return pix
            self._misses += 1
            return None

    def put(self, key: str, pixmap: QPixmap) -> None:
        """Insert (or replace) a cached pixmap, evicting older entries."""
        if pixmap is None or pixmap.isNull():
            return
        size = self._estimate_bytes(pixmap)
        if size <= 0:
            return
        if size > self._max_bytes:
            # Larger than the whole cache; not worth keeping.
            return
        with self._lock:
            existing = self._cache.pop(key, None)
            if existing is not None:
                self._current_bytes -= self._estimate_bytes(existing)
            self._cache[key] = pixmap
            self._current_bytes += size
            self._cache.move_to_end(key)
            self._evict_until_within_budget()

    def remove(self, key: str) -> None:
        with self._lock:
            pix = self._cache.pop(key, None)
            if pix is not None:
                self._current_bytes -= self._estimate_bytes(pix)

    def clear(self) -> None:
        with self._lock:
            self._cache.clear()
            self._current_bytes = 0

    def contains(self, key: str) -> bool:
        with self._lock:
            return key in self._cache

    def stats(self) -> dict:
        with self._lock:
            total = self._hits + self._misses
            hit_rate = (self._hits / total) if total else 0.0
            return {
                "entries": len(self._cache),
                "bytes": int(self._current_bytes),
                "max_bytes": int(self._max_bytes),
                "hits": self._hits,
                "misses": self._misses,
                "hit_rate": float(hit_rate),
            }

    @property
    def max_bytes(self) -> int:
        return self._max_bytes

    # ── Internal ─────────────────────────────────────────────────────────────

    def _evict_until_within_budget(self) -> None:
        while self._current_bytes > self._max_bytes and self._cache:
            _, victim = self._cache.popitem(last=False)
            self._current_bytes -= self._estimate_bytes(victim)

    @staticmethod
    def _estimate_bytes(pixmap: QPixmap) -> int:
        try:
            return int(pixmap.width()) * int(pixmap.height()) * 4
        except Exception:  # noqa: BLE001
            return 0
