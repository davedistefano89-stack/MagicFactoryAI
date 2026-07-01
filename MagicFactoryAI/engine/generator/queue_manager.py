"""Queue manager used by the batch generator.

Sprint: Batch Queue Manager PRO — extend with move/remove and stable
uid stamping while keeping the original public API intact.
"""

from __future__ import annotations

from typing import Any, Callable, Iterator, List, Optional
from uuid import uuid4


class QueueManager:
    """FIFO queue with PRO move/remove support."""

    def __init__(self) -> None:
        # Sprint: deque -> list so the UI can reorder items in O(n).
        self._queue: List[Any] = []
        self._current: Any | None = None
        # uid -> list index, stable for the lifetime of the queue.
        self._index: dict[str, int] = {}

    # ── Original / backward-compatible API ──────────────────────────────

    def enqueue(self, item: Any) -> None:
        """Append ``item`` to the queue and stamp a stable uid on it."""
        uid = uuid4().hex
        try:
            item._queue_uid = uid  # type: ignore[attr-defined]
        except Exception:  # noqa: BLE001
            pass
        self._queue.append(item)
        self._reindex()

    def next(self) -> Any | None:
        if self._current is None and self._queue:
            self._current = self._queue.pop(0)
            self._reindex()
        return self._current

    def finish_current(self) -> None:
        self._current = None

    def clear(self) -> None:
        self._queue.clear()
        self._current = None
        self._index.clear()

    def __len__(self) -> int:
        return len(self._queue)

    @property
    def current(self) -> Any | None:
        return self._current

    @property
    def is_empty(self) -> bool:
        return len(self._queue) == 0

    # ── Sprint PRO additions ─────────────────────────────────────────────

    def iter_items(self) -> Iterator[Any]:
        return iter(self._queue)

    def items_snapshot(self) -> List[Any]:
        return list(self._queue)

    def peek(self) -> Any | None:
        """Return the next-to-run item without consuming it.

        Sprint PRO: lets the dispatcher read the head of the queue
        without popping it.
        """
        return self._queue[0] if self._queue else None

    def get_uid(self, item: Any) -> Optional[str]:
        return getattr(item, "_queue_uid", None)

    def index_of(self, uid: str) -> int:
        return self._index.get(uid, -1)

    def move_up(self, uid: str) -> bool:
        idx = self._index.get(uid, -1)
        if idx <= 0:
            return False
        self._queue[idx - 1], self._queue[idx] = (
            self._queue[idx],
            self._queue[idx - 1],
        )
        self._reindex()
        return True

    def move_down(self, uid: str) -> bool:
        idx = self._index.get(uid, -1)
        if idx < 0 or idx >= len(self._queue) - 1:
            return False
        self._queue[idx + 1], self._queue[idx] = (
            self._queue[idx],
            self._queue[idx + 1],
        )
        self._reindex()
        return True

    def remove_by_uid(self, uid: str) -> Any | None:
        idx = self._index.pop(uid, -1)
        if idx < 0:
            return None
        item = self._queue.pop(idx)
        self._reindex()
        try:
            delattr(item, "_queue_uid")
        except Exception:  # noqa: BLE001
            pass
        return item

    def remove_if(self, predicate: Callable[[Any], bool]) -> List[Any]:
        kept: List[Any] = []
        removed: List[Any] = []
        for item in self._queue:
            if predicate(item):
                try:
                    delattr(item, "_queue_uid")
                except Exception:  # noqa: BLE001
                    pass
                removed.append(item)
            else:
                kept.append(item)
        self._queue = kept
        self._reindex()
        return removed

    # ── Internal ─────────────────────────────────────────────────────────

    def _reindex(self) -> None:
        self._index = {
            getattr(it, "_queue_uid", ""): i
            for i, it in enumerate(self._queue)
            if getattr(it, "_queue_uid", "")
        }