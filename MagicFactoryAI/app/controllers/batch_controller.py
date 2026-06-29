"""Batch generation controller."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import TYPE_CHECKING, Any

from core.ai.ai_manager import AIManager
from core.ai.models import AIRequest, AIResult
from engine.generator.batch_generator import BatchGenerator
from engine.generator.progress_tracker import ProgressTracker
from engine.generator.queue_manager import QueueManager
from engine.generator.retry_manager import RetryManager
from models.generation_task import GenerationTask
from models.job import Job

if TYPE_CHECKING:
    from app.controllers.app_controller import AppController


class BatchController:
    """
    Coordinates batch image generation.
    """

    def __init__(
        self,
        app: "AppController",
        ai_manager: AIManager,
    ) -> None:

        self._app = app
        self._ai = ai_manager
        self._queue = QueueManager()

    @property
    def queue(self) -> QueueManager:
        return self._queue

    def create_task(
        self,
        *,
        name: str,
        request: AIRequest,
        project_id: int,
        output_directory: Path,
        category_id: int | None = None,
        prompt_id: int | None = None,
    ) -> GenerationTask:

        job = Job.create(
            project_id=project_id,
            category_id=category_id,
            job_type="generation",
            total_items=1,
        )

        return GenerationTask(
            name=name,
            request=request,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
            output_directory=output_directory,
            job=job,
        )

    def enqueue(
        self,
        task: GenerationTask,
    ) -> None:

        batch = BatchGenerator(
            ai_manager=self._ai,
            job=task.job,
            requests=[task.request],
            task=task,
            retry_manager=RetryManager(),
        )

        self._queue.enqueue(batch)

    def execute(
        self,
        task: GenerationTask,
        on_result: Callable[[AIRequest, AIResult, GenerationTask | None], Any] | None = None,
        on_progress: Callable[[ProgressTracker], Any] | None = None,
    ) -> Job:
        """
        Execute a single task immediately.
        """

        batch = BatchGenerator(
            ai_manager=self._ai,
            job=task.job,
            task=task,
            retry_manager=RetryManager(),
            requests=[task.request],
        )

        batch.run(
            requests=[task.request],
            on_result=on_result,
            on_progress=on_progress,
        )

        return batch.job

    def execute_next(
        self,
        on_result: Callable[[AIRequest, AIResult, GenerationTask | None], Any] | None = None,
        on_progress: Callable[[ProgressTracker], Any] | None = None,
    ) -> Job | None:
        """
        Execute the next queued batch.
        """

        batch = self._queue.next()

        if batch is None:
            return None

        try:

            job = batch.job

            batch.run(
                requests=batch.requests,
                on_result=on_result,
                on_progress=on_progress,
            )

            return job

        finally:

            self._queue.finish_current()

    def clear(self) -> None:
        self._queue.clear()

    @property
    def queue_size(self) -> int:
        return len(self._queue)