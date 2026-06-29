"""AI Generator workspace tab."""

from __future__ import annotations

import traceback
from pathlib import Path

from PySide6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSpinBox,
    QTextEdit,
    QVBoxLayout,
)
from PySide6.QtCore import QThread, Qt, Signal, Slot, QObject

from core.ai.models import AIRequest
from engine.generator.progress_tracker import ProgressTracker
from models.generation_task import GenerationTask
from core.theme.colors import Colors
from ui.widgets.page_header import PageHeader
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase
from app.workers.ai_generation_worker import AIGenerationWorker
from utils.paths import get_library_dir



class _BatchExecutionWorker(QObject):

    started = Signal()
    progress = Signal(int)
    status = Signal(str)
    finished = Signal()
    error = Signal(str)

    def __init__(
        self,
        batch_controller,
        generator_controller,
        total_tasks: int,
    ) -> None:
        super().__init__()
        self._batch_controller = batch_controller
        self._generator_controller = generator_controller
        self._cancel_requested = False
        self._tracker = ProgressTracker(total_tasks)
        self._completed_tasks = 0
        self._total_tasks = total_tasks

    def cancel(self) -> None:
        self._cancel_requested = True

    @Slot(list)
    def run(self, tasks: list[GenerationTask]) -> None:
        self.started.emit()
        self.status.emit("Starting batch generation...")

        try:
            for task in tasks:
                if self._cancel_requested:
                    self.status.emit("Cancelled")
                    return

                self._batch_controller.execute(
                    task,
                    on_result=self._on_result,
                    on_progress=self._on_progress,
                )

            self.finished.emit()

        except Exception as exc:
            self.error.emit(str(exc))

    def _on_result(
        self,
        request: AIRequest,
        result,
        task: GenerationTask | None,
    ) -> None:
        if self._cancel_requested:
            return
        if result.success and result.image_bytes and task is not None:
            self._generator_controller.create_asset_from_bytes(
                category=task.request.category,
                subject=task.request.prompt,
                image_bytes=result.image_bytes,
                project_id=task.project_id,
                category_id=task.category_id,
                prompt_id=task.prompt_id,
                output_directory=task.output_directory,
                request=request,
                result=result,
            )
            self._tracker.complete_item()
            self._completed_tasks += 1
            self.progress.emit(int(self._tracker.percentage))
            self.status.emit(
                f"Completed {self._completed_tasks} of {self._total_tasks} tasks."
            )
        else:
            self._tracker.fail_item()
            self.progress.emit(int(self._tracker.percentage))
            self.status.emit(
                f"Task failed: {result.error or 'unknown error'}."
            )

    def _on_progress(self, tracker: ProgressTracker) -> None:
        self.progress.emit(int(tracker.percentage))


class AIGeneratorTab(WorkspaceTabBase):
    """
    AI image generation workspace.

    This tab collects generation parameters and delegates
    execution to the AI generation pipeline.
    """

    # ---------------------------------------------------------
    # UI
    # ---------------------------------------------------------

    # Signal used to request generation in the worker thread.
    generation_requested = Signal(dict)
    batch_requested = Signal(list)

    def _build_ui(self) -> None:

        self._layout.addWidget(
            PageHeader(
                "AI Generator",
                "Generate printable coloring pages using Artificial Intelligence.",
            )
        )

        card = QFrame()

        card.setStyleSheet(
            f"""
            QFrame {{
                background: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
            """
        )

        layout = QVBoxLayout(card)

        layout.setContentsMargins(
            24,
            24,
            24,
            24,
        )

        layout.setSpacing(18)

        form = QFormLayout()
        form.setSpacing(12)

        # -------------------------------------------------
        # Provider
        # -------------------------------------------------

        self._provider = QComboBox()

        self._provider.addItems(
            [
                "OpenAI",
                "Gemini",
                "Ollama",
                "Stability AI",
            ]
        )

        form.addRow(
            "Provider",
            self._provider,
        )

        # -------------------------------------------------
        # Model
        # -------------------------------------------------

        self._model = QComboBox()

        self._model.addItems(
            [
                "gpt-image-1",
            ]
        )

        form.addRow(
            "Model",
            self._model,
        )

        # -------------------------------------------------
        # Category
        # -------------------------------------------------

        self._category = QComboBox()

        self._category.addItems(
            [
                "Princess",
                "Animals",
                "Unicorn",
                "Vehicles",
                "Dinosaurs",
                "Fantasy",
            ]
        )

        form.addRow(
            "Category",
            self._category,
        )

        # -------------------------------------------------
        # Subject
        # -------------------------------------------------

        self._subject = QLineEdit()

        self._subject.setPlaceholderText(
            "Example: Princess riding a unicorn"
        )

        form.addRow(
            "Subject",
            self._subject,
        )

        # -------------------------------------------------
        # Age
        # -------------------------------------------------

        self._age = QComboBox()

        self._age.addItems(
            [
                "2-4",
                "3-6",
                "5-8",
                "8-12",
            ]
        )

        form.addRow(
            "Target Age",
            self._age,
        )

        # -------------------------------------------------
        # Complexity
        # -------------------------------------------------

        self._complexity = QComboBox()

        self._complexity.addItems(
            [
                "Simple",
                "Medium",
                "Advanced",
            ]
        )

        form.addRow(
            "Complexity",
            self._complexity,
        )

        # -------------------------------------------------
        # Image Size
        # -------------------------------------------------

        self._size = QComboBox()

        self._size.addItems(
            [
                "1024x1024",
                "1024x1536",
                "1536x1024",
            ]
        )

        form.addRow(
            "Image Size",
            self._size,
        )

        # -------------------------------------------------
        # Quality
        # -------------------------------------------------

        self._quality = QComboBox()

        self._quality.addItems(
            [
                "high",
                "medium",
                "low",
            ]
        )

        self._quality.setCurrentText("high")

        form.addRow(
            "Quality",
            self._quality,
        )

        # -------------------------------------------------
        # Seed
        # -------------------------------------------------

        self._seed = QSpinBox()

        self._seed.setRange(
            0,
            999999999,
        )

        self._seed.setSpecialValueText(
            "Random"
        )

        form.addRow(
            "Seed",
            self._seed,
        )

        # -------------------------------------------------
        # Images
        # -------------------------------------------------

        self._count = QSpinBox()

        self._count.setRange(
            1,
            500,
        )

        self._count.setValue(10)

        form.addRow(
            "Images",
            self._count,
        )

        # -------------------------------------------------
        # Notes
        # -------------------------------------------------

        self._notes = QTextEdit()

        self._notes.setMaximumHeight(90)

        self._notes.setPlaceholderText(
            "Optional notes..."
        )

        form.addRow(
            "Notes",
            self._notes,
        )

        layout.addLayout(form)

        # -------------------------------------------------
        # Progress
        # -------------------------------------------------

        self._progress = QProgressBar()

        self._progress.setRange(
            0,
            100,
        )

        self._progress.setValue(0)

        layout.addWidget(
            self._progress,
        )

        self._status = QLabel("Ready")

        self._status.setStyleSheet(
            f"color:{Colors.TEXT_SECONDARY};"
        )

        layout.addWidget(
            self._status,
        )

        # -------------------------------------------------
        # Buttons
        # -------------------------------------------------

        buttons = QHBoxLayout()

        buttons.addStretch()

        self._generate = QPushButton(
            "Generate"
        )

        self._generate.setProperty(
            "cssClass",
            "primary",
        )

        self._generate.clicked.connect(
            self._on_generate,
        )

        self._cancel = QPushButton(
            "Cancel"
        )

        self._cancel.setEnabled(False)
        # Connect cancel action
        self._cancel.clicked.connect(self._on_cancel)

        buttons.addWidget(
            self._generate,
        )

        buttons.addWidget(
            self._cancel,
        )

        layout.addLayout(
            buttons,
        )

        self._layout.addWidget(
            card,
        )

        self._layout.addStretch()

        # Worker/thread placeholders
        self._worker_thread: QThread | None = None
        self._worker: object | None = None

    # ---------------------------------------------------------
    # Helpers
    # ---------------------------------------------------------

    def _validate(self) -> bool:
        """
        Validate user input before generation.
        """

        if not self.workspace.project_id:

            QMessageBox.warning(
                self,
                "Project",
                "Open a project first.",
            )

            return False

        if not self._subject.text().strip():

            QMessageBox.warning(
                self,
                "Validation",
                "Subject is required.",
            )

            return False

        return True

    def _collect_request(self) -> dict:
        """
        Collect generation settings from the UI.
        """

        return {
            "provider": self._provider.currentText(),
            "model": self._model.currentText(),
            "category": self._category.currentText(),
            "subject": self._subject.text().strip(),
            "age": self._age.currentText(),
            "complexity": self._complexity.currentText(),
            "size": self._size.currentText(),
            "quality": self._quality.currentText(),
            "seed": self._seed.value(),
            "count": self._count.value(),
            "notes": self._notes.toPlainText().strip(),
        }

    def _set_busy(
        self,
        busy: bool,
    ) -> None:
        """
        Enable/disable the interface while generating.
        """

        self._generate.setEnabled(not busy)
        self._cancel.setEnabled(busy)

        widgets = [
            self._provider,
            self._model,
            self._category,
            self._subject,
            self._age,
            self._complexity,
            self._size,
            self._quality,
            self._seed,
            self._count,
            self._notes,
        ]

        for widget in widgets:
            widget.setEnabled(not busy)

    def _update_progress(
        self,
        value: int,
        message: str,
    ) -> None:
        """
        Update progress bar and status text.
        """

        self._progress.setValue(value)
        self._status.setText(message)

    def _generation_completed(self) -> None:
        """
        Restore UI after successful generation.
        """

        self._set_busy(False)

        self._update_progress(
            100,
            "Generation completed.",
        )

        self.workspace.workspace_refresh.emit()

    def _generation_failed(
        self,
        error: str,
    ) -> None:
        """
        Restore UI after a failed generation.
        """

        self._set_busy(False)

        self._update_progress(
            0,
            "Generation failed.",
        )

        QMessageBox.critical(
            self,
            "AI Generation",
            error,
        )

    # ---------------------------------------------------------
    # Actions
    # ---------------------------------------------------------

    def _on_generate(self) -> None:

        if not self._validate():
            return

        request = self._collect_request()

        self._set_busy(True)

        self._update_progress(
            5,
            "Preparing AI generation...",
        )

        # Ensure the request includes workspace context.
        request["project_id"] = self.workspace.project_id
        request["category_id"] = self.workspace.category_id
        request["prompt_id"] = None

        if request["count"] > 1:
            self._start_batch_generation(request)
            return

        # Single-image generation uses legacy worker path.
        try:
            self._start_single_generation(request)
        except Exception as exc:
            self._generation_failed(str(exc))

    def _create_ai_request(self, request: dict) -> AIRequest:
        return AIRequest(
            image_path=get_library_dir(),
            prompt=request["subject"],
            provider=request["provider"].lower(),
            model=request["model"],
            width=int(request["size"].split("x")[0]),
            height=int(request["size"].split("x")[1]),
            quality=request["quality"],
            output_format="png",
            category=request["category"],
        )

    def _build_batch_tasks(self, request: dict) -> list[GenerationTask]:
        tasks: list[GenerationTask] = []
        output_dir = get_library_dir()

        for index in range(request["count"]):
            ai_request = self._create_ai_request(request)
            task_name = f"{request['subject']} #{index + 1}"
            task = self.controller.batch_controller.create_task(
                name=task_name,
                request=ai_request,
                project_id=self.workspace.project_id,
                output_directory=output_dir,
                category_id=self.workspace.category_id,
                prompt_id=request.get("prompt_id"),
            )
            tasks.append(task)

        return tasks

    def _start_batch_generation(self, request: dict) -> None:
        try:
            tasks = self._build_batch_tasks(request)

            self._worker_thread = QThread()
            self._worker = _BatchExecutionWorker(
                self.controller.batch_controller,
                self.controller.ai_generator,
                total_tasks=len(tasks),
            )

            self._worker.moveToThread(self._worker_thread)
            self._worker.started.connect(lambda: self._update_progress(5, "Starting batch generation..."))
            self._worker.progress.connect(lambda v: self._update_progress(v, f"Progress: {v}%"))
            self._worker.status.connect(lambda s: self._update_progress(self._progress.value(), s))
            self._worker.finished.connect(self._on_batch_finished)
            self._worker.error.connect(self._on_worker_error)
            self._worker.finished.connect(self._worker_thread.quit)

            self._worker_thread.started.connect(lambda: self._worker.run(tasks))

            self._worker_thread.start()

        except Exception as exc:
            self._generation_failed(str(exc))

    def _start_single_generation(self, request: dict) -> None:
        self._worker_thread = QThread()
        self._worker = AIGenerationWorker(self.controller.ai_generator)

        self._worker.moveToThread(self._worker_thread)

        self._worker.started.connect(lambda: self._update_progress(5, "Starting generation..."))
        self._worker.progress.connect(lambda v: self._update_progress(v, f"Progress: {v}%"))
        self._worker.status.connect(lambda s: self._update_progress(self._progress.value(), s))
        self._worker.finished.connect(self._on_worker_finished)
        self._worker.error.connect(self._on_worker_error)

        self.generation_requested.connect(self._worker.generate, Qt.QueuedConnection)
        self._worker_thread.started.connect(lambda: self.generation_requested.emit(request))

        self._worker.finished.connect(self._worker_thread.quit)
        self._worker.finished.connect(self._worker.deleteLater)
        self._worker_thread.finished.connect(self._worker_thread.deleteLater)
        self._worker_thread.finished.connect(self._clear_worker_refs)

        self._worker_thread.start()

    def _on_batch_finished(self) -> None:
        self._update_progress(100, "Batch generation completed.")
        self._generation_completed()

        QMessageBox.information(
            self,
            "Batch Generation Completed",
            "All batch images have been generated and added to the Library.",
        )

    # ---------------------------------------------------------
    # Worker callbacks
    # ---------------------------------------------------------

    def _on_worker_finished(self, asset) -> None:
        self._update_progress(100, "Generation completed.")
        self._generation_completed()

        QMessageBox.information(
            self,
            "Generation Completed",
            (
                f"'{asset.name}' generated successfully.\n\n"
                "The image has been added to the Library."
            ),
        )

    def _on_worker_error(self, error: str) -> None:
        self._generation_failed(error)

    def _clear_worker_refs(self) -> None:
        """Clear references to the worker and thread after they have finished."""
        self._worker = None
        self._worker_thread = None

    def _on_cancel(self) -> None:
        """Request cancellation of the running worker."""
        if self._worker:
            self._worker.cancel()
            self._update_progress(self._progress.value(), "Cancellation requested...")

    # ---------------------------------------------------------
    # Refresh
    # ---------------------------------------------------------

    def refresh(self) -> None:

        self._set_busy(False)

        self._progress.setValue(0)

        self._status.setText("Ready")
