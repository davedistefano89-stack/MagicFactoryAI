"""Batch generation controller.

Sprint: Batch Queue Manager PRO added per-item queue operations
alongside the original FIFO API while preserving all behavior so
existing callers (AIGeneratorTab, batch dispatchers, etc.) keep
working.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any, List, Optional

from core.ai.ai_manager import AIManager
from core.ai.models import AIRequest, AIResult
from engine.generator.batch_generator import BatchGenerator, BatchState
from engine.generator.progress_tracker import ProgressTracker
from engine.generator.queue_manager import QueueManager
from engine.generator.retry_manager import RetryManager
from models.generation_task import GenerationTask
from models.job import Job

if TYPE_CHECKING:
    from app.controllers.app_controller import AppController


# ── Sprint: per-job metadata snapshot for the queue UI ─────────────────
# This is intentionally a plain dict so we don't touch the GenerationTask
# slots model. Keys live for the lifetime of the GenerationTask in the
# queue; the queue panel reads them via ``BatchController.get_queue_view``.

JOB_META_KEY = "_queue_meta"  # attached at enqueue time


def _attach_meta(batch: BatchGenerator, meta: dict) -> None:
    setattr(batch, JOB_META_KEY, meta)


def _read_meta(batch: BatchGenerator) -> dict:
    return getattr(batch, JOB_META_KEY, {}) or {}


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

        # Sprint: global pause flag. When True the dispatcher should not
        # pull new items from the queue.
        self._paused: bool = False

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
        request_meta: Optional[dict] = None,
    ) -> GenerationTask:

        job = Job.create(
            project_id=project_id,
            category_id=category_id,
            job_type="generation",
            total_items=1,
        )

        task = GenerationTask(
            name=name,
            request=request,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
            output_directory=output_directory,
            job=job,
        )
        # Sprint: store the optional per-job display metadata on the
        # task itself so it survives any wrapper round-trip.
        if request_meta:
            try:
                task._queue_display = dict(request_meta)  # type: ignore[attr-defined]
            except Exception:  # noqa: BLE001
                pass
        return task

    def enqueue(
        self,
        task: GenerationTask,
        display_meta: Optional[dict] = None,
    ) -> str:
        """Wrap ``task`` in a BatchGenerator, attach metadata and enqueue.

        Returns the queue uid stamped on the BatchGenerator so the UI
        can address the item immediately after enqueue.
        """
        batch = BatchGenerator(
            ai_manager=self._ai,
            job=task.job,
            requests=[task.request],
            task=task,
            retry_manager=RetryManager(),
        )

        meta = dict(display_meta or {})
        meta.setdefault("name", task.name)
        meta.setdefault("prompt", getattr(task.request, "prompt", ""))
        meta.setdefault(
            "provider",
            getattr(task.request, "provider", "") or "openai",
        )
        meta.setdefault(
            "model", getattr(task.request, "model", "") or ""
        )
        meta.setdefault(
            "resolution",
            f"{getattr(task.request, 'width', '?')}x"
            f"{getattr(task.request, 'height', '?')}",
        )
        meta.setdefault("created_at", datetime.utcnow().isoformat())
        _attach_meta(batch, meta)
        try:
            task._queue_display = dict(meta)  # type: ignore[attr-defined]
        except Exception:  # noqa: BLE001
            pass

        self._queue.enqueue(batch)
        return self._queue.get_uid(batch) or ""

    def execute(
        self,
        task: GenerationTask,
        on_result: Callable[[AIRequest, AIResult, GenerationTask | None], Any] | None = None,
        on_progress: Callable[[ProgressTracker], Any] | None = None,
    ) -> Job:
        """Execute a single task immediately (unchanged)."""

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
        """Execute the next queued batch (unchanged)."""

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

    # ── Sprint: Batch Queue Manager PRO ───────────────────────────────────

    @property
    def is_paused(self) -> bool:
        return self._paused

    def pause_queue(self) -> None:
        """Suspend the dispatcher. Currently running items finish first."""
        self._paused = True

    def resume_queue(self) -> None:
        """Lift the suspension so the dispatcher starts pulling again."""
        self._paused = False

    def cancel_item(self, uid: str) -> bool:
        """Cancel one waiting item. Running items must be cancelled
        through the active BatchGenerator (the dispatcher picks it up).

        Returns True if a waiting item was removed.
        """
        item = self._queue.remove_by_uid(uid)
        return item is not None

    def cancel_waiting(self) -> int:
        """Drop every queued BatchGenerator that hasn't started yet."""
        removed = self._queue.remove_if(
            lambda batch: batch.state in (BatchState.IDLE,)
        )
        return len(removed)

    def cancel_running(self) -> int:
        """Cancel the currently running BatchGenerator via its own cancel()."""
        current = self._queue.current
        count = 0
        if current is not None and current.state in (BatchState.RUNNING, BatchState.PAUSED):
            current.cancel()
            count = 1
        return count

    def retry_item(self, uid: str) -> bool:
        """Re-create the failed/cancelled task identified by ``uid``.

        ``task`` outlives the BatchGenerator so we can rebuild a new
        batch from its stored ``_queue_display`` + ``request``.
        """
        item = self._queue.remove_by_uid(uid)
        if item is None:
            return False
        task = getattr(item, "task", None)
        if task is None:
            return False
        meta = _read_meta(item)
        # Reset lifecycle fields so the rebuilt task starts fresh.
        task.retries = 0
        task.error = ""
        task.started_at = None
        task.finished_at = None
        if task.job is not None:
            task.job.status = "pending"
            task.job.started_at = None
            task.job.finished_at = None
            task.job.completed_items = 0
            task.job.failed_items = 0
            task.job.progress = 0.0
        return bool(self.enqueue(task, meta))

    def retry_all_failed(self) -> int:
        """Re-enqueue every failed batch currently in the queue."""
        failed_uids: List[str] = []
        for batch in self._queue.items_snapshot():
            if batch.state == BatchState.FAILED:
                uid = self._queue.get_uid(batch)
                if uid:
                    failed_uids.append(uid)
        for uid in failed_uids:
            self.retry_item(uid)
        return len(failed_uids)

    def move_up(self, uid: str) -> bool:
        return self._queue.move_up(uid)

    def move_down(self, uid: str) -> bool:
        return self._queue.move_down(uid)

    def clear_completed(self) -> int:
        return len(
            self._queue.remove_if(
                lambda batch: batch.state == BatchState.COMPLETED
            )
        )

    def clear_failed(self) -> int:
        return len(
            self._queue.remove_if(
                lambda batch: batch.state == BatchState.FAILED
            )
        )

    def clear_cancelled(self) -> int:
        return len(
            self._queue.remove_if(
                lambda batch: batch.state == BatchState.CANCELLED
            )
        )

    # ── Sprint: queue view snapshot for the UI ──────────────────────────────

    def get_queue_view(self) -> List[dict]:
        """Return a dict-per-row snapshot suitable for the queue panel.

        Each row as_dict() is plain-Python so the UI can render without
        touching model internals.
        """
        view: List[dict] = []
        uid_for: dict[int, str] = {
            id(b): self._queue.get_uid(b) or "" for b in self._queue.items_snapshot()
        }
        for batch in self._queue.items_snapshot():
            uid = uid_for.get(id(batch), "")
            meta = _read_meta(batch)
            task = getattr(batch, "task", None)
            job = batch.job
            state = self._ui_state_for(batch, task, job)
            view.append(
                {
                    "uid": uid,
                    "name": meta.get("name") or (task.name if task else ""),
                    "prompt": meta.get("prompt", ""),
                    "provider": meta.get("provider", ""),
                    "model": meta.get("model", ""),
                    "resolution": meta.get("resolution", ""),
                    "preset": meta.get("preset", ""),
                    "state": state,
                    "raw_state": batch.state.name,
                    "progress": int(getattr(job, "progress", 0) or 0) if job else 0,
                    "completed": int(getattr(job, "completed_items", 0) or 0) if job else 0,
                    "failed": int(getattr(job, "failed_items", 0) or 0) if job else 0,
                    "total": int(getattr(job, "total_items", 1) or 1) if job else 1,
                    "created_at": meta.get("created_at", ""),
                    "started_at": getattr(job, "started_at", None) if job else None,
                    "finished_at": getattr(job, "finished_at", None) if job else None,
                    "task": task,
                    "batch": batch,
                    "error": getattr(task, "error", "") if task else "",
                }
            )
        return view

    @staticmethod
    def _ui_state_for(
        batch: BatchGenerator,
        task: Optional[GenerationTask],
        job: Optional[Job],
    ) -> str:
        """Map BatchGenerator/Job states onto the 7 user-facing states.

        Sprint: Returning a stable string per state so the UI can render
        a chip / color. ``Preparing`` is derived empirically from a
        RUNNING batch whose job has not yet started or grown.
        """
        bs = batch.state
        if bs == BatchState.IDLE:
            return "Waiting"
        if bs == BatchState.RUNNING:
            # Heuristic: ``started_at is None`` OR no completed_items
            # yet -> we're still in the AI provider's first call.
            try:
                started = getattr(job, "started_at", None) if job else None
                done = int(getattr(job, "completed_items", 0) or 0) if job else 0
            except Exception:  # noqa: BLE001
                started, done = None, 0
            if started is None and done == 0:
                return "Preparing"
            return "Running"
        if bs == BatchState.PAUSED:
            return "Paused"
        if bs == BatchState.CANCELLED:
            return "Cancelled"
        if bs == BatchState.COMPLETED:
            return "Completed"
        if bs == BatchState.FAILED:
            return "Failed"
        return bs.name