"""Job model."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class Job:
    id: int | None = None

    project_id: int = 0
    category_id: int | None = None

    type: str = "generation"

    status: str = "pending"

    total_items: int = 0
    completed_items: int = 0
    failed_items: int = 0

    progress: float = 0.0

    created_at: str = ""
    started_at: str | None = None
    finished_at: str | None = None

    @classmethod
    def create(
        cls,
        project_id: int,
        category_id: int | None,
        job_type: str,
        total_items: int,
    ) -> "Job":
        return cls(
            project_id=project_id,
            category_id=category_id,
            type=job_type,
            total_items=total_items,
            created_at=datetime.utcnow().isoformat(),
        )

    @property
    def is_finished(self) -> bool:
        return self.status in (
            "completed",
            "failed",
            "cancelled",
        )

    @property
    def percentage(self) -> int:
        if self.total_items == 0:
            return 0

        return int(
            (self.completed_items / self.total_items) * 100
        )

    def start(self) -> None:
        self.status = "running"
        self.started_at = datetime.utcnow().isoformat()

    def complete(self) -> None:
        self.status = "completed"
        self.progress = 100
        self.completed_items = self.total_items
        self.finished_at = datetime.utcnow().isoformat()

    def fail(self) -> None:
        self.status = "failed"
        self.finished_at = datetime.utcnow().isoformat()

    def update_progress(
        self,
        completed: int,
        failed: int = 0,
    ) -> None:
        self.completed_items = completed
        self.failed_items = failed

        if self.total_items:
            self.progress = (
                completed / self.total_items
            ) * 100