from __future__ import annotations

from collections import deque
from typing import Any


class QueueManager:
    """
    Simple FIFO queue used by the batch generator.
    """

    def __init__(self) -> None:
        self._queue: deque[Any] = deque()
        self._current: Any | None = None

    def enqueue(self, item: Any) -> None:
        self._queue.append(item)

    def next(self) -> Any | None:
        if self._current is None and self._queue:
            self._current = self._queue.popleft()

        return self._current

    def finish_current(self) -> None:
        self._current = None

    def clear(self) -> None:
        self._queue.clear()
        self._current = None

    def __len__(self) -> int:
        return len(self._queue)

    @property
    def current(self) -> Any | None:
        return self._current

    @property
    def is_empty(self) -> bool:
        return len(self._queue) == 0