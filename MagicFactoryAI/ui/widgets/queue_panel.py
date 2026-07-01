"""Sprint: Batch Queue Manager PRO — Queue panel widget.

This is the main UI for the PRO queue. Embedded inside AIGeneratorTab.

Design:
* A long-lived ``QueueWorker`` (QObject on its own QThread) pumps the
  BatchController queue one item at a time. Items are processed via
  ``BatchController.execute_next`` (existing path, no refactor).
* The panel is purely a view/controller wiring layer: it asks the
  BatchController for a queue snapshot, renders rows in a table,
  and forwards user actions (Pause / Cancel / Move / Retry / Clear)
  back to BatchController.
* ETA uses a simple moving average of the last 10 finished jobs;
  the panel re-renders only on signal-driven updates so the GUI
  stays responsive at hundreds of jobs.
* State mapping: see ``_ui_state_for``.
"""

from __future__ import annotations

import time as _time
from collections import deque
from dataclasses import dataclass
from datetime import datetime
from typing import Deque, Dict, List, Optional

from PySide6.QtCore import (
    QMetaObject,
    QObject,
    QThread,
    Qt,
    Signal,
    Slot,
)
from PySide6.QtGui import QBrush, QColor
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSizePolicy,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from core.theme.colors import Colors
from engine.generator.batch_generator import BatchState


# Sprint: rendering constants — keep the same look as the rest of the app.
_TABLE_FONT_MONO = "Consolas, 'Courier New', monospace"
_TABLE_HEADER_STYLE = (
    f"QHeaderView::section {{ background-color: {Colors.SURFACE};"
    f" color: {Colors.TEXT_SECONDARY}; padding: 6px;"
    f" border: 0; border-bottom: 1px solid {Colors.BORDER};"
    f" font-weight: 600; }}"
)


_STATE_STYLES: Dict[str, Dict[str, str]] = {
    "Waiting": {"fg": Colors.TEXT_SECONDARY, "bg": Colors.SURFACE_LIGHT},
    "Preparing": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.INFO},
    "Running": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.PRIMARY},
    "Paused": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.WARNING},
    "Completed": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.SUCCESS},
    "Failed": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.ERROR},
    "Cancelled": {"fg": Colors.TEXT_ON_PRIMARY, "bg": Colors.SURFACE_HOVER},
}


def _fmt_seconds(seconds: float) -> str:
    """Format seconds into a friendly HH:MM:SS or M:SS string."""
    seconds = max(0, int(seconds))
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m {seconds % 60:02d}s"
    h, rem = divmod(seconds, 3600)
    return f"{h}h {rem // 60:02d}m"


def _fmt_created_at(iso: str) -> str:
    if not iso:
        return ""
    try:
        dt = datetime.fromisoformat(iso)
        return dt.strftime("%H:%M:%S")
    except (ValueError, TypeError):
        return iso or ""


@dataclass
class _DispatchRecord:
    """Per-job timing record kept in a sliding window for ETA."""

    final_state: str  # "Completed" / "Failed" / "Cancelled"
    duration_s: float


# ── Worker ────────────────────────────────────────────────────────────────


class QueueWorker(QObject):
    """Long-lived QObject worker (runs on its own QThread) that pumps
    BatchController.queue.

    State machine:
      IDLE → emit item_started → run_ai → emit item_finished → repeat
      while not paused and queue not empty.
    """

    item_started = Signal(str)            # uid
    item_progress = Signal(str, int)      # uid, percent (0..100)
    item_finished = Signal(str, float)    # uid, duration_s (>= 0)
    queue_state_changed = Signal()
    queue_finished = Signal(bool)         # has_failures

    def __init__(self, batch_controller) -> None:
        super().__init__()
        self._ctrl = batch_controller
        self._current_uid: Optional[str] = None
        self._should_stop: bool = False
        self._times_by_uid: Dict[str, float] = {}
        # Used to ignore duplicate ``pump`` calls while we are busy.
        self._busy: bool = False

    @Slot()
    def stop(self) -> None:
        """Request the dispatcher to stop running (called from teardown)."""
        self._should_stop = True

    @Slot()
    def pump(self) -> None:
        """Public entry: pull and execute one item if the queue is ready."""
        if self._should_stop:
            return
        if self._busy:
            return
        if self._ctrl.is_paused:
            self.queue_state_changed.emit()
            return
        if len(self._ctrl.queue) == 0:
            self.queue_state_changed.emit()
            return
        self._execute_one()

    def _execute_one(self) -> None:
        """Run one batch synchronously on the worker thread.

        Track the in-flight uid so ETA calculation sees real durations.
        Worker exceptions are caught so the GUI can never crash on
        a single bad job.
        """
        self._busy = True
        any_failure = False
        current_uid: Optional[str] = None
        try:
            # Snapshot the uid of the batch we're about to run.
            head = self._ctrl.queue.peek()
            current_uid = (
                self._ctrl.queue.get_uid(head) if head is not None else None
            )
            self._current_uid = current_uid
            if current_uid is not None:
                self._times_by_uid[current_uid] = _time.monotonic()

            job = self._ctrl.execute_next(
                on_result=lambda req, res, task: None,
                on_progress=self._on_progress_for_current,
            )
            if job is None:
                self.queue_state_changed.emit()
                self.queue_finished.emit(False)
                return

            # Compute real duration for the EMA window.
            dur = 0.0
            if current_uid is not None:
                start = self._times_by_uid.get(current_uid)
                if start is not None:
                    dur = _time.monotonic() - start
                self._finishing_durations.append(dur)
                # Keep map size bounded (never grow across hundreds of
                # jobs — sprint required support for hundreds).
                if len(self._times_by_uid) > 64:
                    self._times_by_uid.pop(next(iter(self._times_by_uid)))

            # Failure detection: job.failed_items > 0 OR job.status
            # explicitly "failed" / "cancelled" after the run.
            try:
                if job is not None and (
                    int(getattr(job, "failed_items", 0) or 0) > 0
                    or str(getattr(job, "status", "")) in ("failed", "cancelled")
                ):
                    any_failure = True
            except Exception:  # noqa: BLE001
                any_failure = True

            self._current_uid = None
            # Emit (uid, duration_so_far); the panel uses duration to
            # update the ETA sliding window. The UI state itself is
            # derived by the panel from BatchController.get_queue_view().
            self.item_finished.emit(current_uid or "", dur)
        except Exception as exc:  # noqa: BLE001
            any_failure = True
            self.item_finished.emit(self._current_uid or "", 0.0)
        finally:
            self._busy = False

        self.queue_state_changed.emit()

        if (
            len(self._ctrl.queue) == 0
            and self._ctrl.queue.current is None
        ):
            self.queue_finished.emit(any_failure)
            return

        # Re-kick from the worker thread so the GUI never has to do
        # it. We use ``QMetaObject.invokeMethod`` with a queued
        # connection instead of ``QTimer.singleShot``. The latter
        # calls ``QObject::startTimer`` internally, which produces
        # the warning ``QObject::startTimer: current thread's event
        # dispatcher has already been destroyed`` whenever the timer
        # is created on a worker thread whose dispatcher is mid-
        # teardown — and can subsequently crash with an access
        # violation if Qt fires the timer after the thread cleanup.
        # ``QMetaObject.invokeMethod`` posts a QMetaCallEvent straight
        # to the worker's event queue without ever touching startTimer.
        if not self._should_stop and not self._ctrl.is_paused:
            QMetaObject.invokeMethod(
                self, "pump", Qt.ConnectionType.QueuedConnection
            )

    def _on_progress_for_current(self, tracker) -> None:
        # Forward the percentage into the GUI (auto-queued because the
        # receiver lives in another thread).
        uid = self._current_uid or ""
        try:
            pct = int(tracker.percentage)
        except Exception:  # noqa: BLE001
            pct = 0
        self.item_progress.emit(uid, pct)

    def elapsed_for(self, uid: str) -> float:
        start = self._times_by_uid.get(uid)
        if start is None:
            return 0.0
        return _time.monotonic() - start


# ── Panel widget ──────────────────────────────────────────────────────────


class QueuePanel(QWidget):
    """Queue Manager PRO UI embedded into the Generator tab."""

    queue_finished_notify = Signal(bool)  # has_failures (used by host tab)
    _kick_signal = Signal()  # class-scope so Qt's meta-object wires connect/emit

    COLUMNS = [
        ("Prompt", 220),
        ("Provider", 80),
        ("Model", 100),
        ("Resolution", 90),
        ("Preset", 110),
        ("Status", 110),
        ("Progress", 110),
        ("ETA", 80),
        ("Created", 90),
    ]

    def __init__(self, controller, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self.controller = controller
        self._workspace = controller.workspace
        self._batch_controller = controller.batch_controller
        self._dispatch_stopping: bool = False
        self._finishing_durations: Deque[float] = deque(maxlen=10)
        self._known_states: Dict[str, str] = {}
        self._known_uids: set = set()

        self._build_ui()
        self._install_workers()
        self._refresh_view()

    # ── UI construction ────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(8)

        # Toolbar (left: queue ops, right: counters + global progress).
        bar = QFrame()
        bar.setStyleSheet(
            f"QFrame {{ background: {Colors.SURFACE}; border: 1px solid"
            f" {Colors.BORDER}; border-radius: 10px; }}"
        )
        bar_layout = QHBoxLayout(bar)
        bar_layout.setContentsMargins(10, 6, 10, 6)
        bar_layout.setSpacing(6)

        title = QLabel("Batch Queue")
        title.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-weight: 700; font-size: 13px;"
        )
        bar_layout.addWidget(title)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.VLine)
        sep.setStyleSheet(f"color: {Colors.BORDER};")
        bar_layout.addWidget(sep)

        # Action buttons. Stored for auto-enable / disable.
        self._btn_pause = self._mk_btn("⏸ Pause", self._on_pause)
        self._btn_resume = self._mk_btn("▶ Resume", self._on_resume)
        self._btn_cancel_selected = self._mk_btn(
            "✖ Cancel Job", self._on_cancel_selected
        )
        self._btn_cancel_waiting = self._mk_btn(
            "✖ Cancel Waiting", self._on_cancel_waiting
        )
        self._btn_retry_selected = self._mk_btn(
            "↻ Retry Job", self._on_retry_selected
        )
        self._btn_retry_failed = self._mk_btn(
            "↻ Retry All Failed", self._on_retry_failed
        )
        self._btn_move_up = self._mk_btn("▲ Up", self._on_move_up)
        self._btn_move_down = self._mk_btn("▼ Down", self._on_move_down)
        self._btn_clear_completed = self._mk_btn(
            "🧹 Clear Completed", self._on_clear_completed
        )
        self._btn_clear_failed = self._mk_btn(
            "🧹 Clear Failed", self._on_clear_failed
        )
        for btn in (
            self._btn_pause,
            self._btn_resume,
            self._btn_cancel_selected,
            self._btn_cancel_waiting,
            self._btn_retry_selected,
            self._btn_retry_failed,
            self._btn_move_up,
            self._btn_move_down,
            self._btn_clear_completed,
            self._btn_clear_failed,
        ):
            bar_layout.addWidget(btn)

        bar_layout.addStretch()

        # Right side: counters + overall progress bar.
        self._count_label = QLabel("0 / 0")
        self._count_label.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
        )
        bar_layout.addWidget(self._count_label)

        self._progress = QProgressBar()
        self._progress.setRange(0, 100)
        self._progress.setValue(0)
        self._progress.setFixedHeight(8)
        self._progress.setTextVisible(False)
        self._progress.setFixedWidth(180)
        self._progress.setStyleSheet(
            f"QProgressBar {{ background: {Colors.SURFACE_LIGHT};"
            f" border: none; border-radius: 4px; }}"
            f"QProgressBar::chunk {{ background: {Colors.PRIMARY};"
            f" border-radius: 4px; }}"
        )
        bar_layout.addWidget(self._progress)

        outer.addWidget(bar)

        # Queue table.
        self._table = QTableWidget(0, len(self.COLUMNS))
        self._table.setHorizontalHeaderLabels([c[0] for c in self.COLUMNS])
        self._table.verticalHeader().setVisible(False)
        self._table.setSelectionBehavior(
            QTableWidget.SelectionBehavior.SelectRows
        )
        self._table.setSelectionMode(
            QTableWidget.SelectionMode.ExtendedSelection
        )
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.setAlternatingRowColors(True)
        self._table.setStyleSheet(
            f"QTableWidget {{ background-color: {Colors.SURFACE};"
            f" color: {Colors.TEXT_PRIMARY}; gridline-color: {Colors.BORDER};"
            f" alternate-background-color: {Colors.SURFACE_LIGHT}; }}"
            f"QHeaderView::section {{ background-color: {Colors.SURFACE};"
            f" color: {Colors.TEXT_SECONDARY}; padding: 6px;"
            f" border: 0; border-bottom: 1px solid {Colors.BORDER};"
            f" font-weight: 600; }}"
            f"QTableWidget::item:selected {{ background-color: {Colors.PRIMARY}55;"
            f" color: {Colors.TEXT_PRIMARY}; }}"
        )
        header = self._table.horizontalHeader()
        for i, (_, w) in enumerate(self.COLUMNS):
            self._table.setColumnWidth(i, w)
        header.setStretchLastSection(True)
        header.setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
        outer.addWidget(self._table, stretch=1)

        # Footer summary.
        footer = QFrame()
        footer.setStyleSheet(
            f"QFrame {{ background: {Colors.SURFACE}; border: 1px solid"
            f" {Colors.BORDER}; border-radius: 10px; }}"
        )
        footer_layout = QHBoxLayout(footer)
        footer_layout.setContentsMargins(10, 4, 10, 4)
        footer_layout.setSpacing(16)

        self._running_label = QLabel("Running: —")
        self._remaining_label = QLabel("Remaining: 0")
        self._eta_label = QLabel("ETA: —")
        self._completed_label = QLabel("Completed: 0")
        self._failed_label = QLabel("Failed: 0")
        self._cancelled_label = QLabel("Cancelled: 0")

        for lbl in (
            self._running_label,
            self._remaining_label,
            self._eta_label,
            self._completed_label,
            self._failed_label,
            self._cancelled_label,
        ):
            lbl.setStyleSheet(
                f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
            )
            footer_layout.addWidget(lbl)
        footer_layout.addStretch()
        outer.addWidget(footer)

    # ── Helper factories ───────────────────────────────────────────────────

    def _mk_btn(self, text: str, slot) -> QPushButton:
        btn = QPushButton(text)
        btn.setProperty("cssClass", "ghost")
        btn.setFixedHeight(28)
        btn.clicked.connect(slot)
        return btn

    # ── Worker installation ────────────────────────────────────────────────

    def _install_workers(self) -> None:
        """Wire up a long-lived dispatcher thread for the queue."""
        self._dispatch_thread = QThread()
        self._dispatch_thread.setObjectName("queue-dispatcher")
        self._dispatch_worker = QueueWorker(self._batch_controller)
        self._dispatch_worker.moveToThread(self._dispatch_thread)

        # Cross-thread signals from worker to GUI:
        self._dispatch_worker.item_progress.connect(
            self._on_item_progress, Qt.ConnectionType.QueuedConnection
        )
        self._dispatch_worker.item_finished.connect(
            self._on_item_finished, Qt.ConnectionType.QueuedConnection
        )
        self._dispatch_worker.queue_state_changed.connect(
            self._refresh_view, Qt.ConnectionType.QueuedConnection
        )
        self._dispatch_worker.queue_finished.connect(
            self._on_queue_finished, Qt.ConnectionType.QueuedConnection
        )

        # GUI -> worker (queued). The Signal is class-scope so Qt's
        # meta-object machinery wires ``connect``. An instance-scope
        # Signal object would have no ``connect`` attribute.
        self._kick_signal.connect(
            self._dispatch_worker.pump, Qt.ConnectionType.QueuedConnection
        )

        self._dispatch_thread.start()
        # Sprint QA PRO #1 — schedule worker deletion once the thread
        # loop has fully terminated to avoid orphaned worker objects.
        self._dispatch_thread.finished.connect(self._dispatch_worker.deleteLater)

        # Reliable teardown on every destruction path.
        self.destroyed.connect(self._stop_dispatcher)
        app = QApplication.instance()
        if app is not None:
            app.aboutToQuit.connect(self._stop_dispatcher)

    # ── Public hook used by AIGeneratorTab ─────────────────────────────────

    def enqueue_request(self, request_dict: dict, preset_name: str = "") -> int:
        """Enqueue ``count`` jobs derived from ``request_dict``.

        Returns the number of items actually enqueued. Each row
        carries the original ``subject`` / ``provider`` / ``model`` /
        ``resolution`` / ``preset`` so the UI can show it without an
        extra DB round-trip.
        """
        from core.ai.models import AIRequest
        from utils.paths import get_library_dir

        if not self._workspace.project_id:
            return 0

        count = max(1, int(request_dict.get("count", 1)))
        subject = request_dict["subject"]
        provider = request_dict.get("provider", "openai")
        model = request_dict.get("model", "gpt-image-1")
        size_text = request_dict.get("size", "1024x1024")
        try:
            w_str, h_str = size_text.lower().split("x")
            width, height = int(w_str), int(h_str)
        except (ValueError, AttributeError):
            width, height = 1024, 1024

        out_dir = get_library_dir()
        queued = 0
        for i in range(count):
            prompt_text = (
                f"Category: {request_dict.get('category','')}\n"
                f"Subject: {subject}\n"
                f"Age: {request_dict.get('age','')}\n"
                f"Complexity: {request_dict.get('complexity','')}"
            )
            ai_request = AIRequest(
                image_path=out_dir,
                prompt=prompt_text,
                provider=provider.lower(),
                model=model,
                width=width,
                height=height,
                quality=request_dict.get("quality", "high"),
                output_format="png",
                category=request_dict.get("category", ""),
            )
            task = self._batch_controller.create_task(
                name=f"{subject} #{i + 1}",
                request=ai_request,
                project_id=self._workspace.project_id,
                output_directory=out_dir,
                category_id=self._workspace.category_id,
                prompt_id=request_dict.get("prompt_id"),
                request_meta={
                    "subject": subject,
                    "preset": preset_name,
                    "provider": provider,
                    "model": model,
                    "resolution": f"{width}x{height}",
                },
            )
            uid = self._batch_controller.enqueue(task, task._queue_display)
            self._known_states[uid] = "Waiting"
            self._known_uids.add(uid)
            # Stash pending UID on the dispatcher so the next pump can
            # know what's currently in flight.
            queued += 1

        self._refresh_view()
        self._dispatch_worker.set_current_uid("")  # reset before pump
        self._kick_signal.emit()
        return queued

    # ── Refresh ────────────────────────────────────────────────────────────

    @Slot()
    def _refresh_view(self) -> None:
        rows = self._batch_controller.get_queue_view()
        current_uids = {r["uid"] for r in rows if r["uid"]}

        # Capture selection (UIDs) BEFORE rebuilding the table so the
        # spec's "Selection is preserved whenever possible" holds.
        previously_selected = self._selected_uids()

        # Track uids that have disappeared (cleared / completed / failed).
        gone = [uid for uid in list(self._known_uids) if uid not in current_uids]
        for uid in gone:
            self._known_uids.discard(uid)
            self._known_states.pop(uid, None)

        # Rebuild table. For hundreds of rows this is acceptable; the
        # SPEC explicitly asked us to avoid unnecessary refreshes, so
        # we only repaint from a single source-of-truth pass.
        self._table.setRowCount(len(rows))
        for r_idx, row in enumerate(rows):
            uid = row["uid"]
            self._known_uids.add(uid)
            state = row["state"] or "Waiting"
            prev_state = self._known_states.get(uid)
            self._known_states[uid] = state

            cells = (
                self._fit(row["prompt"], 80),
                str(row["provider"]),
                str(row["model"]),
                str(row["resolution"]),
                str(row["preset"]),
                state,
                f"{row['progress']}%",
                self._eta_for_row(row),
                _fmt_created_at(row["created_at"]),
            )
            for c_idx, text in enumerate(cells):
                item = QTableWidgetItem(text)
                if c_idx == 0:
                    # UID hidden in the prompt column so the panel can
                    # map row → uid without a parallel QTableWidget map.
                    item.setData(Qt.ItemDataRole.UserRole, uid)
                if c_idx == 5:  # status
                    style = _STATE_STYLES.get(state, {})
                    fg = style.get("fg")
                    bg = style.get("bg")
                    if fg:
                        item.setForeground(QBrush(QColor(fg)))
                    if bg:
                        item.setBackground(QBrush(QColor(bg)))
                self._table.setItem(r_idx, c_idx, item)

            # Track completion transitions so we can keep an ETA window.
            if (
                prev_state in ("Running", "Preparing", "Waiting")
                and state in ("Completed", "Failed", "Cancelled")
            ):
                # Use the dispatcher's elapsed time if known.
                d = self._dispatch_worker.elapsed_for(uid)
                self._finishing_durations.append(d)

        self._update_footer(rows)

        # Restore the selection by uid mapping.
        if previously_selected:
            from PySide6.QtCore import QItemSelection, QItemSelectionModel
            sel = QItemSelection()
            for r_idx in range(self._table.rowCount()):
                item = self._table.item(r_idx, 0)
                if item is None:
                    continue
                uid = item.data(Qt.ItemDataRole.UserRole)
                if uid in previously_selected:
                    sel.select(
                        self._table.model().index(r_idx, 0),
                        self._table.model().index(
                            r_idx, self._table.columnCount() - 1
                        ),
                        QItemSelectionModel.SelectionFlag.Select
                        | QItemSelectionModel.SelectionFlag.Rows,
                    )
            if not sel.isEmpty():
                self._table.selectionModel().select(
                    sel,
                    QItemSelectionModel.SelectionFlag.Select
                    | QItemSelectionModel.SelectionFlag.Rows,
                )

    @Slot(str, int)
    def _on_item_progress(self, uid: str, percent: int) -> None:
        if not uid:
            return
        row_idx = self._find_row_for_uid(uid)
        if row_idx < 0:
            return
        item = self._table.item(row_idx, 6)
        if item is not None:
            item.setText(f"{percent}%")

    @Slot(str, float)
    def _on_item_finished(self, uid: str, duration_s: float) -> None:
        # Append a real duration so ETA updates.
        if duration_s > 0:
            self._finishing_durations.append(duration_s)
        # Force a full refresh so the row shows the final state.
        self._refresh_view()
        # The worker auto-rekicks via QTimer.singleShot(0, self.pump),
        # so we don't have to kick again from here.

    @Slot(bool)
    def _on_queue_finished(self, has_failures: bool) -> None:
        self._refresh_view()
        self._show_completion_notification(has_failures)
        self.queue_finished_notify.emit(has_failures)

    # ── Footer / counters ──────────────────────────────────────────────────

    def _update_footer(self, rows: List[dict]) -> None:
        total = len(rows)
        completed = sum(1 for r in rows if r["state"] == "Completed")
        failed = sum(1 for r in rows if r["state"] == "Failed")
        cancelled = sum(1 for r in rows if r["state"] == "Cancelled")
        running = next(
            (r for r in rows if r["state"] in ("Running", "Preparing")),
            None,
        )
        waiting = sum(1 for r in rows if r["state"] == "Waiting")
        remaining = total - completed - failed - cancelled
        if remaining < 0:
            remaining = 0

        if running is not None:
            self._running_label.setText(
                f"Running: {running['name'] or running['prompt'][:24]}"
            )
        else:
            self._running_label.setText("Running: —")

        self._remaining_label.setText(f"Remaining: {remaining}")
        self._completed_label.setText(f"Completed: {completed}")
        self._failed_label.setText(f"Failed: {failed}")
        self._cancelled_label.setText(f"Cancelled: {cancelled}")

        if total == 0:
            self._count_label.setText("0 / 0")
            self._progress.setValue(0)
        else:
            done = completed + failed + cancelled
            self._count_label.setText(f"{done} / {total}")
            self._progress.setValue(int((done / total) * 100))

        # ETA.
        if remaining > 0 and self._finishing_durations:
            avg = sum(self._finishing_durations) / max(
                1, len(self._finishing_durations)
            )
            eta_seconds = avg * remaining
            self._eta_label.setText(f"ETA: {_fmt_seconds(eta_seconds)}")
        elif remaining > 0:
            self._eta_label.setText("ETA: estimating…")
        else:
            self._eta_label.setText("ETA: —")

        self._update_button_states(rows)

    # ── Auto-enable / disable buttons ──────────────────────────────────────

    def _update_button_states(self, rows: List[dict]) -> None:
        has_running = any(r["state"] in ("Running", "Preparing", "Paused") for r in rows)
        has_waiting = any(r["state"] == "Waiting" for r in rows)
        has_failed = any(r["state"] == "Failed" for r in rows)
        has_completed = any(r["state"] == "Completed" for r in rows)
        selected = self._selected_uids()
        selected_states = [r["state"] for r in rows if r["uid"] in selected]

        self._btn_pause.setEnabled(has_running or has_waiting)
        self._btn_resume.setEnabled(self._batch_controller.is_paused)
        self._btn_cancel_selected.setEnabled(
            bool(selected_states) and all(
                s in ("Waiting", "Running", "Preparing", "Paused")
                for s in selected_states
            )
        )
        self._btn_cancel_waiting.setEnabled(has_waiting)
        self._btn_retry_selected.setEnabled(
            bool(selected_states)
            and all(s in ("Failed", "Cancelled") for s in selected_states)
        )
        self._btn_retry_failed.setEnabled(has_failed)
        self._btn_move_up.setEnabled(
            len(selected) == 1 and "Waiting" in selected_states
        )
        self._btn_move_down.setEnabled(
            len(selected) == 1 and "Waiting" in selected_states
        )
        self._btn_clear_completed.setEnabled(has_completed)
        self._btn_clear_failed.setEnabled(has_failed)

    def _selected_uids(self) -> set:
        uids: set = set()
        for idx in self._table.selectionModel().selectedRows():
            item = self._table.item(idx.row(), 0)
            if item is not None:
                uid = item.data(Qt.ItemDataRole.UserRole)
                if uid:
                    uids.add(uid)
        return uids

    # ── Action handlers ────────────────────────────────────────────────────

    def _on_pause(self) -> None:
        self._batch_controller.pause_queue()
        self._refresh_view()

    def _on_resume(self) -> None:
        self._batch_controller.resume_queue()
        self._refresh_view()
        self._kick_signal.emit()

    def _on_cancel_selected(self) -> None:
        uids = self._selected_uids()
        for uid in uids:
            self._batch_controller.cancel_item(uid)
        self._refresh_view()

    def _on_cancel_waiting(self) -> None:
        self._batch_controller.cancel_waiting()
        self._refresh_view()

    def _on_retry_selected(self) -> None:
        for uid in self._selected_uids():
            self._batch_controller.retry_item(uid)
        self._refresh_view()
        self._kick_signal.emit()

    def _on_retry_failed(self) -> None:
        self._batch_controller.retry_all_failed()
        self._refresh_view()
        self._kick_signal.emit()

    def _on_move_up(self) -> None:
        uids = list(self._selected_uids())
        if len(uids) != 1:
            return
        pre_state = [
            r["uid"]
            for r in self._batch_controller.get_queue_view()
            if r["state"] == "Waiting"
        ]
        self._batch_controller.move_up(uids[0])
        post_state = [
            r["uid"]
            for r in self._batch_controller.get_queue_view()
            if r["state"] == "Waiting"
        ]
        if pre_state != post_state:
            self._record_queue_move(
                uid=uids[0],
                direction="up",
                before=pre_state,
                after=post_state,
            )
        self._refresh_view()

    def _on_move_down(self) -> None:
        uids = list(self._selected_uids())
        if len(uids) != 1:
            return
        pre_state = [
            r["uid"]
            for r in self._batch_controller.get_queue_view()
            if r["state"] == "Waiting"
        ]
        self._batch_controller.move_down(uids[0])
        post_state = [
            r["uid"]
            for r in self._batch_controller.get_queue_view()
            if r["state"] == "Waiting"
        ]
        if pre_state != post_state:
            self._record_queue_move(
                uid=uids[0],
                direction="down",
                before=pre_state,
                after=post_state,
            )
        self._refresh_view()

    def _record_queue_move(
        self,
        uid: str,
        direction: str,
        before: list,
        after: list,
    ) -> None:
        """Snapshot a queue reorder so undo restores prior ordering.

        We store both pre and post UID lists; undo applies move_up/down
        deltas in reverse to walk the ordering back. In practice we just
        emit a synthetic record whose undo/redo re-apply the same move
        op via BatchController so we never duplicate queue logic here.
        """
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None or not uid:
            return
        ctrl = self._batch_controller
        # If a move has no effect (already at the boundary), the call
        # short-circuits inside BatchController and we have nothing to
        # undo. The pre != post guard above catches that case.
        if before == after:
            return

        opp_direction = "down" if direction == "up" else "up"

        def _undo() -> None:
            try:
                if opp_direction == "up":
                    ctrl.move_up(uid)
                else:
                    ctrl.move_down(uid)
            except Exception:
                pass

        def _redo() -> None:
            try:
                if direction == "up":
                    ctrl.move_up(uid)
                else:
                    ctrl.move_down(uid)
            except Exception:
                pass

        manager.record(
            "Reorder queue",
            undo=_undo,
            redo=_redo,
            context=f"{direction} ({uid[:8]}…)",
        )

    def _on_clear_completed(self) -> None:
        self._batch_controller.clear_completed()
        self._refresh_view()

    def _on_clear_failed(self) -> None:
        self._batch_controller.clear_failed()
        self._refresh_view()

    # ── Notifications ──────────────────────────────────────────────────────

    def _show_completion_notification(self, has_failures: bool) -> None:
        # PySide6 has no native "toast" widget; we use a non-modal
        # QMessageBox so the user sees the result without breaking
        # the queue workflow. Worker exceptions are never allowed to
        # bubble up here — they all resolve to a Failed row already.
        if has_failures:
            QMessageBox.warning(
                self,
                "Batch Queue",
                "Generation completed with warnings.",
                QMessageBox.StandardButton.Ok,
            )
        else:
            QMessageBox.information(
                self,
                "Batch Queue",
                "Batch generation completed.",
                QMessageBox.StandardButton.Ok,
            )

    # ── Helpers ────────────────────────────────────────────────────────────

    def _find_row_for_uid(self, uid: str) -> int:
        for r in range(self._table.rowCount()):
            item = self._table.item(r, 0)
            if item is None:
                continue
            if item.data(Qt.ItemDataRole.UserRole) == uid:
                return r
        return -1

    @staticmethod
    def _fit(text: str, max_len: int) -> str:
        if not text:
            return ""
        text = text.replace("\n", " ").strip()
        return text if len(text) <= max_len else text[: max_len - 1] + "…"

    @staticmethod
    def _eta_for_row(row: dict) -> str:
        # Per-row ETA is approximate; for ongoing "Running" jobs we
        # don't track individual speed — we show "—". This keeps the
        # column updateable cheaply.
        return "—"

    # ── Teardown ───────────────────────────────────────────────────────────


    def _stop_dispatcher(self) -> None:
        if getattr(self, "_dispatch_stopping", False):
            return
        self._dispatch_stopping = True

        worker = getattr(self, "_dispatch_worker", None)
        thread = getattr(self, "_dispatch_thread", None)

        try:
            self._kick_signal.disconnect()
        except Exception:  # noqa: BLE001
            pass
        try:
            if worker is not None:
                try:
                    worker.item_progress.disconnect(self._on_item_progress)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.item_finished.disconnect(self._on_item_finished)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.queue_state_changed.disconnect(self._refresh_view)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.queue_finished.disconnect(self._on_queue_finished)
                except Exception:  # noqa: BLE001
                    pass
                worker.stop()
        except Exception:  # noqa: BLE001
            pass
        try:
            if worker is not None and thread is not None and thread.isRunning():
                worker.deleteLater()
            # NOTE: do NOT clear self._dispatch_worker here. The queue
            # worker has no QObject parent, so PySide6 ties its C++
            # lifetime to the last Python reference. Dropping the
            # attribute while the dispatcher thread is still alive lets
            # Python's GC re-enter the C++ destructor before the thread's
            # event dispatcher is gone, producing the native
            # "QObject::startTimer" warning and Windows access
            # violation. Drop the reference AFTER wait().
        except Exception:  # noqa: BLE001
            pass
        try:
            if thread is not None and thread.isRunning():
                thread.quit()
        except Exception:  # noqa: BLE001
            pass
        try:
            if thread is not None:
                thread.wait(2000)
                self._dispatch_thread = None
                # Safe to drop the Python reference now that the
                # dispatcher thread has fully stopped.
                self._dispatch_worker = None
        except Exception:  # noqa: BLE001
            pass
