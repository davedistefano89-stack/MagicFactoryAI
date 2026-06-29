from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class ProgressTracker:
    """
    Tracks batch generation progress.
    """

    total: int

    completed: int = 0
    failed: int = 0

    started_at: datetime | None = None
    finished_at: datetime | None = None

    def start(self) -> None:
        self.started_at = datetime.utcnow()

    def complete_item(self) -> None:
        self.completed += 1

    def fail_item(self) -> None:
        self.failed += 1

    @property
    def percentage(self) -> float:
        if self.total == 0:
            return 0.0

        return (self.completed / self.total) * 100

    @property
    def remaining(self) -> int:
        return self.total - self.completed - self.failed

    @property
    def is_finished(self) -> bool:
        return (self.completed + self.failed) >= self.total