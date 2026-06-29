"""Generation pipeline task model."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime

from core.ai.models import AIRequest
from models.job import Job


@dataclass(slots=True)
class GenerationTask:
    """
    Represents one complete generation task.

    It contains everything required to execute a batch
    without passing dozens of parameters between classes.
    """

    # -------------------------------------------------
    # Identity
    # -------------------------------------------------

    name: str

    # -------------------------------------------------
    # AI
    # -------------------------------------------------

    request: AIRequest

    # -------------------------------------------------
    # Project
    # -------------------------------------------------

    project_id: int

    category_id: int | None = None

    prompt_id: int | None = None

    # -------------------------------------------------
    # Output
    # -------------------------------------------------

    output_directory: Path = Path()

    # -------------------------------------------------
    # Batch
    # -------------------------------------------------

    job: Job | None = None

    # -------------------------------------------------
    # Runtime
    # -------------------------------------------------

    created_at: datetime = field(default_factory=datetime.utcnow)

    started_at: datetime | None = None

    finished_at: datetime | None = None

    status: str = "pending"

    retries: int = 0

    max_retries: int = 3

    error: str = ""

    # -------------------------------------------------
    # Helpers
    # -------------------------------------------------

    @property
    def is_finished(self) -> bool:
        return self.status in (
            "completed",
            "failed",
            "cancelled",
        )

    @property
    def can_retry(self) -> bool:
        return self.retries < self.max_retries

    def start(self) -> None:
        self.started_at = datetime.utcnow()
        self.status = "running"

    def complete(self) -> None:
        self.finished_at = datetime.utcnow()
        self.status = "completed"

    def fail(self, message: str) -> None:
        self.finished_at = datetime.utcnow()
        self.status = "failed"
        self.error = message

    def retry(self) -> None:
        self.retries += 1
        self.status = "retrying"