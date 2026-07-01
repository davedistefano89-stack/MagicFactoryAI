"""AI Generator workspace tab."""

from __future__ import annotations

import traceback
from pathlib import Path

from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QDoubleSpinBox,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSizePolicy,
    QSpinBox,
    QTextEdit,
    QVBoxLayout,
)
from PySide6.QtCore import QThread, Qt, Signal, Slot, QObject

from core.ai.models import AIRequest
from engine.generator.progress_tracker import ProgressTracker
from models.generation_task import GenerationTask
from core.theme.colors import Colors
from services.preset_manager import PresetManager
from ui.widgets.page_header import PageHeader
from ui.widgets.queue_panel import QueuePanel
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


class _PresetsManagerDialog(QDialog):
    """Rename, duplicate, delete and set-default operations on presets."""

    def __init__(self, mgr: PresetManager, parent=None) -> None:
        super().__init__(parent)
        self._mgr = mgr
        self.setWindowTitle("Manage Presets")
        self.setMinimumSize(420, 360)
        self.setModal(True)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(10)

        layout.addWidget(QLabel("Presets  (⭐ = default):"))

        self._list = QListWidget()
        self._list.setSelectionMode(QListWidget.SelectionMode.SingleSelection)
        layout.addWidget(self._list, stretch=1)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)

        rename_btn = QPushButton("✏️ Rename")
        rename_btn.setProperty("cssClass", "ghost")
        rename_btn.clicked.connect(self._on_rename)

        dup_btn = QPushButton("⧉ Duplicate")
        dup_btn.setProperty("cssClass", "ghost")
        dup_btn.clicked.connect(self._on_duplicate)

        default_btn = QPushButton("⭐ Set Default")
        default_btn.setProperty("cssClass", "ghost")
        default_btn.clicked.connect(self._on_set_default)

        del_btn = QPushButton("🗑 Delete")
        del_btn.setProperty("cssClass", "danger")
        del_btn.clicked.connect(self._on_delete)

        btn_row.addWidget(rename_btn)
        btn_row.addWidget(dup_btn)
        btn_row.addWidget(default_btn)
        btn_row.addStretch()
        btn_row.addWidget(del_btn)
        layout.addLayout(btn_row)

        close_btn = QPushButton("Close")
        close_btn.setFixedWidth(100)
        close_btn.clicked.connect(self.accept)
        layout.addWidget(close_btn, alignment=Qt.AlignmentFlag.AlignRight)

        self._populate()

    def _populate(self) -> None:
        self._list.clear()
        default = self._mgr.get_default()
        for name in self._mgr.get_sorted_names():
            label = f"⭐  {name}" if name == default else f"    {name}"
            item = QListWidgetItem(label)
            item.setData(Qt.ItemDataRole.UserRole, name)
            self._list.addItem(item)

    def _selected_name(self):
        items = self._list.selectedItems()
        return items[0].data(Qt.ItemDataRole.UserRole) if items else None

    def _on_rename(self) -> None:
        name = self._selected_name()
        if not name:
            return
        new_name, ok = QInputDialog.getText(
            self, "Rename Preset", "New name:", text=name
        )
        if ok and new_name.strip() and new_name.strip() != name:
            self._mgr.rename(name, new_name.strip())
            self._populate()

    def _on_duplicate(self) -> None:
        name = self._selected_name()
        if not name:
            return
        new_name, ok = QInputDialog.getText(
            self, "Duplicate Preset", "New preset name:", text=f"{name} Copy"
        )
        if ok and new_name.strip():
            self._mgr.duplicate(name, new_name.strip())
            self._populate()

    def _on_set_default(self) -> None:
        name = self._selected_name()
        if name:
            self._mgr.set_default(name)
            self._populate()

    def _on_delete(self) -> None:
        name = self._selected_name()
        if not name:
            return
        if name == self._mgr.get_default():
            QMessageBox.warning(
                self, "Delete Preset", "Cannot delete the default preset."
            )
            return
        reply = QMessageBox.question(
            self,
            "Delete Preset",
            f"Delete preset '{name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._mgr.delete(name)
            self._populate()


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

        self._preset_mgr = PresetManager()
        self._preset_mgr.ensure_default()

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
        # Preset selector
        # -------------------------------------------------

        preset_row = QHBoxLayout()
        preset_row.setContentsMargins(0, 0, 0, 0)
        preset_row.setSpacing(8)

        self._preset_combo = QComboBox()
        self._preset_combo.setMinimumWidth(180)
        self._preset_combo.currentTextChanged.connect(self._on_preset_changed)
        preset_row.addWidget(self._preset_combo, stretch=1)

        _save_preset_btn = QPushButton("💾 Save Preset")
        _save_preset_btn.setProperty("cssClass", "ghost")
        _save_preset_btn.setFixedHeight(30)
        _save_preset_btn.clicked.connect(self._on_save_preset)
        preset_row.addWidget(_save_preset_btn)

        _manage_preset_btn = QPushButton("⚙ Manage")
        _manage_preset_btn.setProperty("cssClass", "ghost")
        _manage_preset_btn.setFixedHeight(30)
        _manage_preset_btn.clicked.connect(self._on_manage_presets)
        preset_row.addWidget(_manage_preset_btn)

        _preset_row_widget = QFrame()
        _preset_row_widget.setLayout(preset_row)
        form.addRow("Preset", _preset_row_widget)

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

        # -------------------------------------------------
        # Steps
        # -------------------------------------------------

        self._steps = QSpinBox()
        self._steps.setRange(1, 150)
        self._steps.setValue(20)
        form.addRow("Steps", self._steps)

        # -------------------------------------------------
        # Guidance Scale
        # -------------------------------------------------

        self._guidance = QDoubleSpinBox()
        self._guidance.setRange(1.0, 20.0)
        self._guidance.setSingleStep(0.5)
        self._guidance.setDecimals(1)
        self._guidance.setValue(7.5)
        form.addRow("Guidance Scale", self._guidance)

        # -------------------------------------------------
        # Seed Mode
        # -------------------------------------------------

        self._seed_mode = QComboBox()
        self._seed_mode.addItems(["Random", "Fixed"])
        form.addRow("Seed Mode", self._seed_mode)

        # -------------------------------------------------
        # Negative Prompt
        # -------------------------------------------------

        self._neg_prompt = QLineEdit()
        self._neg_prompt.setPlaceholderText("e.g. blurry, low quality, watermark…")
        form.addRow("Negative Prompt", self._neg_prompt)

        # -------------------------------------------------
        # Prompt Prefix
        # -------------------------------------------------

        self._prompt_prefix = QLineEdit()
        self._prompt_prefix.setPlaceholderText("Added before every prompt")
        form.addRow("Prompt Prefix", self._prompt_prefix)

        # -------------------------------------------------
        # Prompt Suffix
        # -------------------------------------------------

        self._prompt_suffix = QLineEdit()
        self._prompt_suffix.setPlaceholderText("Added after every prompt")
        form.addRow("Prompt Suffix", self._prompt_suffix)

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

        # Sprint: Batch Queue Manager PRO — dedicated queue panel
        # integrated below the form. All generation requests now go
        # through this queue (single and batch share the same path)
        # so the user has unified visibility / control.
        self._queue_panel = QueuePanel(self.controller, self)
        self._queue_panel.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Expanding,
        )
        self._layout.addWidget(self._queue_panel, stretch=1)

        self._layout.addStretch()

        # Worker/thread placeholders
        self._worker_thread: QThread | None = None
        self._worker: object | None = None

        # Load presets into selector and apply the default
        self._load_preset_selector()
        # Trigger silently — combo already set to index 0 by _load_preset_selector
        self._on_preset_changed(self._preset_combo.currentText())

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
            "steps": self._steps.value(),
            "guidance_scale": self._guidance.value(),
            "seed_mode": self._seed_mode.currentText().lower(),
            "negative_prompt": self._neg_prompt.text().strip(),
            "prompt_prefix": self._prompt_prefix.text().strip(),
            "prompt_suffix": self._prompt_suffix.text().strip(),
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
            self._preset_combo,
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
            self._steps,
            self._guidance,
            self._seed_mode,
            self._neg_prompt,
            self._prompt_prefix,
            self._prompt_suffix,
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

        # Ensure the request includes workspace context.
        request["project_id"] = self.workspace.project_id
        request["category_id"] = self.workspace.category_id
        request["prompt_id"] = None

        # Sprint: Batch Queue Manager PRO — single source of truth.
        # All jobs (count == 1 OR count > 1) are routed through the
        # QueuePanel dispatcher. The queue panel owns its own progress
        # UI; we keep ``self._set_busy`` on the form fields so the
        # user cannot trigger duplicate jobs while one is queued.
        self._set_busy(True)
        self._update_progress(
            5,
            "Adding to queue...",
        )

        try:
            self._queue_panel.enqueue_request(
                request,
                preset_name=self._preset_combo.currentText(),
            )
            self._update_progress(
                10,
                f"Queued {request['count']} job(s).",
            )
        except Exception as exc:
            self._generation_failed(str(exc))
            return

        # Re-enable the form immediately — the queue panel drives
        # the rest of the lifecycle and signals completion via
        # ``_queue_panel.queue_finished_notify``.
        self._set_busy(False)
        self.workspace.workspace_refresh.emit()

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
        """Request cancellation of the running worker / queue item.

        Sprint: All generation now flows through the QueuePanel, so
        cancellation goes via ``BatchController.cancel_running``
        which calls ``cancel()`` on the in-flight BatchGenerator.
        """
        try:
            self.controller.batch_controller.cancel_running()
        except Exception:  # noqa: BLE001
            pass
        try:
            self.controller.batch_controller.cancel_waiting()
        except Exception:  # noqa: BLE001
            pass
        # Fallback: legacy inline worker.
        if self._worker is not None and hasattr(self._worker, "cancel"):
            try:
                self._worker.cancel()
            except Exception:  # noqa: BLE001
                pass
        self._update_progress(self._progress.value(), "Cancellation requested...")

    # ---------------------------------------------------------
    # Refresh
    # ---------------------------------------------------------

    def refresh(self) -> None:

        self._set_busy(False)

        self._progress.setValue(0)

        self._status.setText("Ready")

    # ---------------------------------------------------------
    # Preset management
    # ---------------------------------------------------------

    def _load_preset_selector(self) -> None:
        """Repopulate the preset combo from the manager."""
        self._preset_combo.blockSignals(True)
        current = self._preset_combo.currentText()
        self._preset_combo.clear()
        for name in self._preset_mgr.get_sorted_names():
            self._preset_combo.addItem(name)
        # Restore previous selection or fall back to default
        idx = self._preset_combo.findText(current)
        if idx < 0:
            idx = self._preset_combo.findText(self._preset_mgr.get_default())
        if idx >= 0:
            self._preset_combo.setCurrentIndex(idx)
        self._preset_combo.blockSignals(False)

    def _on_preset_changed(self, name: str = "") -> None:
        """Apply a preset's values to all form controls."""
        if not name:
            name = self._preset_combo.currentText()
        data = self._preset_mgr.get(name)
        if not data:
            return
        self._provider.setCurrentText(data.get("provider", "OpenAI"))
        self._model.setCurrentText(data.get("model", "gpt-image-1"))
        self._size.setCurrentText(data.get("size", "1024x1024"))
        self._quality.setCurrentText(data.get("quality", "high"))
        self._seed.setValue(int(data.get("seed", 0)))
        self._steps.setValue(int(data.get("steps", 20)))
        self._guidance.setValue(float(data.get("guidance_scale", 7.5)))
        seed_mode = data.get("seed_mode", "Random").capitalize()
        idx = self._seed_mode.findText(seed_mode)
        if idx >= 0:
            self._seed_mode.setCurrentIndex(idx)
        self._neg_prompt.setText(data.get("negative_prompt", ""))
        self._prompt_prefix.setText(data.get("prompt_prefix", ""))
        self._prompt_suffix.setText(data.get("prompt_suffix", ""))

    def _on_save_preset(self) -> None:
        """Save current form values as a named preset."""
        current_name = self._preset_combo.currentText()
        name, ok = QInputDialog.getText(
            self, "Save Preset", "Preset name:", text=current_name
        )
        if not ok or not name.strip():
            return
        name = name.strip()
        data = {
            "provider": self._provider.currentText(),
            "model": self._model.currentText(),
            "size": self._size.currentText(),
            "quality": self._quality.currentText(),
            "seed": self._seed.value(),
            "seed_mode": self._seed_mode.currentText(),
            "steps": self._steps.value(),
            "guidance_scale": self._guidance.value(),
            "negative_prompt": self._neg_prompt.text().strip(),
            "prompt_prefix": self._prompt_prefix.text().strip(),
            "prompt_suffix": self._prompt_suffix.text().strip(),
        }
        self._preset_mgr.save(name, data)
        self.workspace.mark_dirty()
        self._load_preset_selector()
        # Select the freshly saved preset
        idx = self._preset_combo.findText(name)
        if idx >= 0:
            self._preset_combo.blockSignals(True)
            self._preset_combo.setCurrentIndex(idx)
            self._preset_combo.blockSignals(False)

    def _on_manage_presets(self) -> None:
        """Open the Manage Presets dialog."""
        dlg = _PresetsManagerDialog(self._preset_mgr, parent=self)
        dlg.exec()
        self.workspace.mark_dirty()
        self._load_preset_selector()
        self._on_preset_changed(self._preset_combo.currentText())
