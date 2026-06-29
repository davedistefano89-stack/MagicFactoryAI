"""Batch image generation engine."""

from __future__ import annotations

from collections.abc import Callable
from enum import Enum, auto
from typing import Any

from core.ai.ai_manager import AIManager
from core.ai.models import AIRequest, AIResult
from engine.generator.progress_tracker import ProgressTracker
from engine.generator.retry_manager import RetryManager
from models.generation_task import GenerationTask
from models.job import Job


class BatchState(Enum):
    """Batch execution state."""

    IDLE = auto()
    RUNNING = auto()
    PAUSED = auto()
    CANCELLED = auto()
    COMPLETED = auto()
    FAILED = auto()


class BatchGenerator:
    """
    Executes a batch of AI image generation requests.

    This class contains no UI code.
    It can therefore be reused from Desktop, CLI or future Web version.
    """

    def __init__(
        self,
        ai_manager: AIManager,
        job: Job,
        requests: list[AIRequest] | None = None,
        task: "GenerationTask" | None = None,
        retry_manager: RetryManager | None = None,
    ) -> None:

        self._ai = ai_manager
        self._job = job
        self._requests = requests or []
        self._task = task
        self._retry_manager = retry_manager or RetryManager()

        self._tracker = ProgressTracker(job.total_items)

        self._state = BatchState.IDLE

        self._cancel_requested = False
        self._pause_requested = False

    # --------------------------------------------------------
    # Properties
    # --------------------------------------------------------

    @property
    def state(self) -> BatchState:
        return self._state

    @property
    def tracker(self) -> ProgressTracker:
        return self._tracker

    @property
    def job(self) -> Job:
        return self._job

    @property
    def requests(self) -> list[AIRequest]:
        return self._requests

    @property
    def task(self) -> "GenerationTask" | None:
        return self._task

    # --------------------------------------------------------
    # Controls
    # --------------------------------------------------------

    def pause(self) -> None:
        self._pause_requested = True
        self._state = BatchState.PAUSED

    def resume(self) -> None:
        self._pause_requested = False
        self._state = BatchState.RUNNING

    def cancel(self) -> None:
        self._cancel_requested = True
        self._state = BatchState.CANCELLED

    # --------------------------------------------------------
    # Main execution
    # --------------------------------------------------------

    def run(
        self,
        requests: list[AIRequest],
        on_result: Callable[[AIRequest, AIResult, GenerationTask | None], Any] | None = None,
        on_progress: Callable[[ProgressTracker], Any] | None = None,
    ) -> Job:

        self._state = BatchState.RUNNING

        self._job.start()

        self._tracker.start()

        completed = 0
        failed = 0

        for request in requests:

            if self._cancel_requested:
                self._job.status = "cancelled"
                self._state = BatchState.CANCELLED
                return self._job

            if self._pause_requested:
                break

            retries = self._task.retries if self._task else 0
            final_result: AIResult | None = None

            while True:
                result = self._ai.generate(request)

                if result.success:
                    completed += 1
                    self._tracker.complete_item()
                    final_result = result
                    break

                retry_allowed = (
                    self._retry_manager is not None
                    and self._task is not None
                    and self._retry_manager.can_retry(retries)
                )

                if retry_allowed:
                    retries = self._retry_manager.next_retry(retries)
                    if self._task is not None:
                        self._task.retry()
                    continue

                failed += 1
                self._tracker.fail_item()
                final_result = result
                break

            self._job.update_progress(
                completed=completed,
                failed=failed,
            )

            if on_result and final_result is not None:
                on_result(request, final_result, self._task)

            if on_progress:
                on_progress(self._tracker)

        if self._cancel_requested:

            self._job.status = "cancelled"
            self._state = BatchState.CANCELLED

        elif failed:

            self._job.fail()
            self._state = BatchState.FAILED

        else:

            self._job.complete()
            self._state = BatchState.COMPLETED

        return self._job