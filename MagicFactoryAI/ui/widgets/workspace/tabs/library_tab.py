"""Library tab within the project workspace.

Sprint: Performance Optimizer #2.

This module is the user-facing library browser. The sprint refactor
adds:

* **Virtual scrolling** for the asset list. ``QTableWidget.setRowCount``
  only reserves row slots (no per-cell allocation). Cells are populated
  lazily for the rows in the viewport buffer.
* **Debounced search.** ``self._search_timer`` debounces text-input
  changes to a configurable delay (default 250 ms).
* **Incremental loading.** Assets are fetched in pages of
  ``library_page_size``; subsequent pages are appended as the user
  scrolls near the loaded range.
* **Background thumbnail loading.** Decoding happens on a dedicated
  ``QThread`` with a ``ThumbnailWorker``. ``QImage`` is decoded off-thread
  (Qt forbids ``QPixmap`` off-thread); the GUI converts to ``QPixmap``
  in the receiver slot.
* **Cancellation.** The worker keeps a thread-safe ``_visible_keys``
  set fed by the tab on every scroll/resize. Decoded images for keys
  that are no longer visible are dropped silently.
* **LRU thumbnail cache.** ``ThumbnailLRUCache`` evicts by approximate
  byte budget so memory stays bounded even with 10k+ entries.
* **Diagnostics panel.** Dev-mode-only floating overlay in the corner
  showing visible rows, cached thumbnails, cache memory, running jobs.

Backward compatibility:

* Existing controller methods (approve / reject / delete / collections
  / tag chips / status filter / double-click inspector) keep working.
* Undo / Redo integration is unchanged — undo calls still target
  ``asset_id``, not row positions.
* Recovery snapshots still see the same widgets.
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional, Set

from PySide6.QtCore import QObject, Qt, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QPixmap, QImage
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from app.workers.thumbnail_worker import ThumbnailWorker
from core.settings.manager import SettingsManager
from core.theme.colors import Colors
from models.asset import Asset, AssetStatus
from services.thumbnail_cache import ThumbnailLRUCache
from ui.widgets.asset_inspector_dialog import AssetInspectorDialog
from ui.widgets.tag_utils import (
    collect_all_collections,
    collect_all_tags,
    get_collections,
    get_tags,
    set_collections,
)
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase

_FILTER_CHIP_STYLE = (
    "QPushButton { background-color: #1E293B; border: 1px solid #334155;"
    " border-radius: 12px; padding: 3px 10px; font-size: 12px; color: #94A3B8; }"
    " QPushButton:checked { background-color: #6366F1; border-color: #6366F1; color: #FFFFFF; }"
    " QPushButton:hover:!checked { border-color: #6366F1; color: #818CF8; }"
)

_COLLECTION_BTN_STYLE = (
    "QPushButton { background-color: transparent; border: none; border-radius: 6px;"
    " padding: 3px 8px; font-size: 12px; color: #94A3B8; text-align: left; }"
    " QPushButton:checked { background-color: #6366F122; color: #818CF8;"
    " font-weight: 600; }"
    " QPushButton:hover:!checked { background-color: #334155; color: #F8FAFC; }"
)

_STATUS_CHOICES = ["All", "Pending", "Generated", "Approved", "Rejected", "Exported"]

# Index of the "thumbnail" column when it is shown.
_THUMB_COL = 0
# Number of rows we render outside the viewport to avoid jitter on tiny scrolls.
_VIEW_BUFFER_ROWS = 20
# Minimal height of the row in the table.
_ROW_HEIGHT = 40
# Tight cell padding for the thumbnail column.
_THUMB_CELL_FIXED_HEIGHT = 44
# Hard cap on the size of the actions-widget pool so memory stays bounded
# even after a user scrolls through tens of thousands of rows. 256 keeps
# roughly 1k QPushButtons (3 per widget) which is a few MB at most.
_ACTIONS_POOL_MAX = 256


class LibraryTab(WorkspaceTabBase):
    """Browse and manage assets scoped to the current project/category."""

    # Sprint Performance Optimizer: class-level Signal declaration so Qt's
    # meta-object machinery binds ``connect`` / ``emit`` correctly. Signals
    # declared inside a method body do NOT get this wiring and raise
    # ``AttributeError: 'PySide6.QtCore.Signal' object has no attribute 'connect'``.
    dispatch_thumbnail = Signal(int, str, str, int, int)

    # ── Diagnostics: surfaced via the floating overlay widget only.
    # Direct ``_diag_lines[key].setText`` from ``_emit_diagnostics``;
    # no extra signal needed.

    def _build_ui(self) -> None:
        # ── Settings (cached) ─────────────────────────────────────────────
        settings = SettingsManager.instance()
        self._page_size: int = int(
            settings.get("performance.library_page_size", 200)
        )
        self._prefetch_rows: int = int(
            settings.get("performance.library_prefetch_rows", 50)
        )
        max_mb = int(settings.get("performance.thumbnail_cache_mb", 64))
        self._thumb_max_size: int = int(
            settings.get("performance.thumbnail_max_size", 192)
        )
        self._search_debounce_ms: int = int(
            settings.get("performance.search_debounce_ms", 250)
        )
        self._dev_mode: bool = bool(settings.get("dev.enabled", False))
        self._show_diagnostics: bool = bool(
            settings.get("dev.show_diagnostics", self._dev_mode)
        )

        # ── State ────────────────────────────────────────────────────────
        self._asset_ctrl = AssetController(self.controller)
        self._all_assets: List[Asset] = []          # for sidebar / tag chips
        self._assets: List[Asset] = []              # paginated table data
        self._selected_tags: set = set()
        self._selected_collection: Optional[str] = None
        self._known_collections: List[str] = []

        self._current_query: str = ""
        self._current_status: str = "All"
        self._current_collection: Optional[str] = None
        self._current_tags: Set[str] = set()

        # Server-side paginated state.
        self._server_total: int = 0
        self._server_loaded: int = 0
        self._loading: bool = False

        # LRU thumbnail cache shared across this tab's lifetime.
        self._thumb_cache = ThumbnailLRUCache(
            max_bytes=max_mb * 1024 * 1024
        )

        # Per-asset version counters (incremented to cancel in-flight loads).
        self._thumb_versions: Dict[int, int] = {}
        # Decoded-state per asset for diagnostics.
        self._thumb_state: Dict[int, str] = {}      # "pending"|"ready"|"failed"
        self._thumb_worker_stopping: bool = False

        # ── Search debounce timer ─────────────────────────────────────────
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(self._search_debounce_ms)
        self._search_timer.timeout.connect(self._on_search_debounced)

        # ── Thumbnail worker thread ──────────────────────────────────────
        # ``self.dispatch_thumbnail`` is declared at class scope above
        # so Qt's meta-object machinery wires ``connect`` / ``emit``.
        # Below we connect the tab signal to the worker slot through
        # a queued connection so the decoder runs on the worker thread.
        self._thumb_thread = QThread()
        self._thumb_thread.setObjectName("library-thumb-loader")
        self._thumb_worker = ThumbnailWorker()
        self._thumb_worker.moveToThread(self._thumb_thread)
        self.dispatch_thumbnail.connect(
            self._thumb_worker.decode, Qt.ConnectionType.QueuedConnection
        )
        self._thumb_worker.thumbnail_ready.connect(
            self._on_thumb_ready, Qt.ConnectionType.QueuedConnection
        )
        self._thumb_worker.thumbnail_failed.connect(
            self._on_thumb_failed, Qt.ConnectionType.QueuedConnection
        )
        self._thumb_thread.start()

        # Reliable teardown regardless of which destruction path Qt
        # triggers (tab removed from QTabWidget, app shutdown, etc).
        # Qt emits ``destroyed`` on every destruction path.
        # NOTE: we intentionally do NOT connect
        # ``self._thumb_thread.finished.connect(self._thumb_worker.deleteLater)``
        # — ``finished`` fires AFTER the worker thread's event loop is
        # already dead, so any ``deleteLater`` posted there is lost and
        # Python GC eventually has to reclaim the QObject on the wrong
        # thread, producing the QObject::startTimer warning + Windows
        # access violation at shutdown. ``_stop_thumb_worker`` does the
        # cleanup explicitly with the correct ordering.
        self.destroyed.connect(self._stop_thumb_worker)
        app = QApplication.instance()
        if app is not None:
            app.aboutToQuit.connect(self._stop_thumb_worker)

        # ── Layout ───────────────────────────────────────────────────────
        main_row = QHBoxLayout()
        main_row.setContentsMargins(0, 0, 0, 0)
        main_row.setSpacing(12)
        main_row.addWidget(self._build_collections_sidebar())

        right = QWidget()
        right.setStyleSheet("background: transparent;")
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(8)

        header_row = QHBoxLayout()
        header_row.setSpacing(10)

        self._search_edit = QLineEdit()
        self._search_edit.setPlaceholderText("🔍  Search by name, tag or collection…")
        self._search_edit.setClearButtonEnabled(True)
        self._search_edit.textChanged.connect(self._on_search_changed)
        header_row.addWidget(self._search_edit, 1)

        status_lbl = QLabel("Status:")
        status_lbl.setAlignment(
            Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter
        )
        header_row.addWidget(status_lbl)

        self._status_combo = QComboBox()
        self._status_combo.addItems(_STATUS_CHOICES)
        self._status_combo.setFixedWidth(130)
        self._status_combo.currentIndexChanged.connect(self._on_status_changed)
        header_row.addWidget(self._status_combo)

        assign_btn = QPushButton("📁  Assign to Collection")
        assign_btn.setProperty("cssClass", "ghost")
        assign_btn.clicked.connect(self._on_assign_to_collection)
        header_row.addWidget(assign_btn)

        import_btn = QPushButton("+ Import Asset")
        import_btn.setProperty("cssClass", "primary")
        import_btn.clicked.connect(self._on_import)
        header_row.addWidget(import_btn)
        right_layout.addLayout(header_row)

        # Tag row (kept for backward compat with prior sprint)
        tag_row = QHBoxLayout()
        tag_row.setSpacing(8)
        tags_lbl = QLabel("Tags:")
        tags_lbl.setFixedWidth(38)
        tag_row.addWidget(tags_lbl)

        self._tag_scroll = QScrollArea()
        self._tag_scroll.setWidgetResizable(True)
        self._tag_scroll.setFixedHeight(36)
        self._tag_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self._tag_scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self._tag_scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )

        self._tag_chips_container = QWidget()
        self._tag_chips_layout = QHBoxLayout(self._tag_chips_container)
        self._tag_chips_layout.setContentsMargins(0, 2, 0, 2)
        self._tag_chips_layout.setSpacing(6)
        self._tag_chips_layout.addStretch()
        self._tag_scroll.setWidget(self._tag_chips_container)

        tag_row.addWidget(self._tag_scroll, 1)
        self._tag_row_widget = QWidget()
        self._tag_row_widget.setLayout(tag_row)
        self._tag_row_widget.hide()
        right_layout.addWidget(self._tag_row_widget)

        # ── Asset table (virtual scrolling lives in here) ────────────────
        self._table = QTableWidget()
        self._show_thumbs = True
        cols = ["Thumb", "Name", "Status", "Size", "File", "Actions"]
        self._table.setColumnCount(len(cols))
        self._table.setHorizontalHeaderLabels(cols)
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setSelectionMode(QTableWidget.SelectionMode.ExtendedSelection)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._table.verticalHeader().setDefaultSectionSize(_ROW_HEIGHT)
        # Sizing policy: Thumbnail column gets a fixed width;
        # uniform row height comes from verticalHeader() default
        # above (QTableWidget.setRowHeight takes (row, height) and
        # isn't valid with a single arg).
        self._table.setColumnWidth(_THUMB_COL, 56)
        # Track which rows currently have cell widgets attached. Used
        # by the lazy populator to clean up off-screen rows.
        self._populated_rows: Set[int] = set()
        self._table.cellDoubleClicked.connect(self._on_row_double_clicked)
        right_layout.addWidget(self._table)

        main_row.addWidget(right, stretch=1)
        self._layout.addLayout(main_row, stretch=1)

        # Scrollbar → visibility / pagination triggers
        self._table.verticalScrollBar().valueChanged.connect(
            self._on_scroll_changed
        )
        self._table.verticalScrollBar().rangeChanged.connect(
            self._on_scroll_range_changed
        )

        # ── Diagnostics overlay (dev only) ───────────────────────────────
        self._diagnostics: Optional[QFrame] = None
        if self._show_diagnostics:
            self._diagnostics = self._build_diagnostics_overlay()
            self._diagnostics.setParent(self)
            self._diagnostics.show()

    # ── Search debouncing ───────────────────────────────────────────────────

    def _on_search_changed(self, _text: str) -> None:
        # Restart the timer on every keystroke; only the last value fires.
        self._search_timer.start()

    def _on_search_debounced(self) -> None:
        self._current_query = self._search_edit.text().lower().strip()
        # Search also changes the data set; reset pagination.
        self._apply_filters(initial=True)

    # ── Filter & pagination state changes ───────────────────────────────────

    def _on_status_changed(self, _index: int) -> None:
        # Status dropdown is an explicit user action → immediate apply.
        self._current_status = self._status_combo.currentText()
        self._apply_filters(initial=True)

    def _on_tag_filter_toggled(self, tag: str, checked: bool) -> None:
        if checked:
            self._current_tags.add(tag.lower())
            self._selected_tags.add(tag.lower())
        else:
            self._current_tags.discard(tag.lower())
            self._selected_tags.discard(tag.lower())
        # Filter chip clicks are also immediate.
        self._apply_filters(initial=True)

    def _select_collection(self, name: Optional[str]) -> None:
        self._selected_collection = name
        self._current_collection = name
        self._col_all_btn.setChecked(name is None)
        for i in range(self._col_list_layout.count()):
            item = self._col_list_layout.itemAt(i)
            if item and item.widget() and isinstance(item.widget(), QPushButton):
                btn = item.widget()
                btn.setChecked(
                    name is not None and btn.text().lower() == name.lower()
                )
        self._apply_filters(initial=True)

    # ── Apply filters (server-side where possible) ──────────────────────────

    def _apply_filters(self, initial: bool = False) -> None:
        if not self.workspace.project_id:
            self._all_assets = []
            self._assets = []
            self._server_loaded = 0
            self._table.setRowCount(0)
            self._clear_all_cell_widgets()
            self._rebuild_tag_chips()
            self._rebuild_collection_sidebar()
            return

        kwargs = self._server_kwargs()

        if initial:
            # Reset pagination
            self._server_loaded = 0
            self._server_total = self._asset_ctrl.count(**kwargs)
            self._assets = []
            # Sidebar index is built from the FULL metadata pass;
            # tag chips and collection sidebar must remain accurate
            # regardless of pagination (we did this lazily: only the
            # JSON strings are walked, never the full pixmap).
            try:
                self._all_assets = self._asset_ctrl.get_all(**kwargs)
            except Exception:
                self._all_assets = []
            self._clear_all_cell_widgets()
            self._rebuild_tag_chips()
            self._rebuild_collection_sidebar()

            # CRITICAL: prune per-asset state dictionaries so they
            # don't grow unbounded across many filter switches.
            valid_ids = {a.id for a in self._all_assets if a.id is not None}
            self._thumb_versions = {
                k: v for k, v in self._thumb_versions.items() if k in valid_ids
            }
            self._thumb_state = {
                k: v for k, v in self._thumb_state.items() if k in valid_ids
            }
            # Cryptic: invalidate any in-flight decode for assets that
            # are no longer in scope by bumping their per-asset version.
            # The worker checks the version after decode completes.
            for aid in list(self._thumb_versions.keys()):
                self._thumb_versions[aid] += 1

        self._maybe_fetch_more_rows()

        # Sync the QTableWidget row count to the loaded window so the
        # scrollbar accurately reflects what's available.
        self._table.setRowCount(len(self._assets))
        # Render the visible subset right away.
        self._populate_visible_rows()

        # If the on-disk dataset ended within the displayed window and
        # there are unfetched rows because of filtering, fetch them now.
        if self._server_loaded < self._server_total:
            self._schedule_prefetch()

    def _server_kwargs(self) -> dict:
        kwargs: dict = {"project_id": self.workspace.project_id}
        if self.workspace.category_id is not None:
            kwargs["category_id"] = self.workspace.category_id
        if self._current_status != "All":
            try:
                kwargs["status"] = AssetStatus(self._current_status.lower())
            except ValueError:
                pass
        return kwargs

    def _maybe_fetch_more_rows(self) -> None:
        if self._loading:
            return
        if self._assets and (self._server_loaded >= self._server_total):
            return
        if self._server_loaded >= self._server_total:
            return
        self._fetch_next_page()

    def _fetch_next_page(self) -> None:
        if self._loading:
            return
        if not self.workspace.project_id:
            return
        self._loading = True
        try:
            kwargs = self._server_kwargs()
            batch = self._asset_ctrl.get_page(
                limit=self._page_size,
                offset=self._server_loaded,
                **kwargs,
            )
        except Exception as exc:  # noqa: BLE001
            self._loading = False
            return
        if not batch:
            self._loading = False
            # We've reached the end — clamp the total so future
            # "fetch more" attempts become no-ops.
            self._server_total = self._server_loaded
            return

        # Apply client-side filtering on the fetched page:
        # - search query (name / tag / collection substring)
        # - selected tag subset
        # - selected collection
        # Status filter is server-side; the others stay client-side for
        # backward compatibility with the previous behaviour.
        filtered: List[Asset] = []
        query = self._current_query
        tags_lower = set(self._current_tags)
        col_lower = self._current_collection.lower() if self._current_collection else None

        for asset in batch:
            tags = get_tags(asset)
            cols = get_collections(asset)

            if query:
                col_str = " ".join(c.lower() for c in cols)
                searchable = (
                    asset.name.lower()
                    + " "
                    + " ".join(t.lower() for t in tags)
                    + " "
                    + col_str
                )
                if query not in searchable:
                    continue

            if tags_lower:
                asset_tags_lower = {t.lower() for t in tags}
                if not tags_lower.issubset(asset_tags_lower):
                    continue
            if col_lower:
                if col_lower not in {c.lower() for c in cols}:
                    continue
            filtered.append(asset)

        if filtered:
            self._assets.extend(filtered)
        self._server_loaded += len(batch)
        # If a non-empty page returned zero matches, fetch again immediately
        # so the visible window doesn't empty out — but bound recursion.
        if not filtered and batch:
            self._loading = False
            if self._server_loaded < self._server_total:
                self._schedule_prefetch()
            return
        self._loading = False

    def _schedule_prefetch(self) -> None:
        QTimer.singleShot(0, self._fetch_next_page)

    # ── Lazy row population (virtual scrolling) ─────────────────────────────

    def _on_scroll_changed(self, _value: int) -> None:
        self._populate_visible_rows()
        self._maybe_prefetch_near_end()

    def _on_scroll_range_changed(
        self, _min: int, _max: int
    ) -> None:
        # Fires when the row count changes (initial load / new batch).
        self._populate_visible_rows()
        self._maybe_prefetch_near_end()

    def _maybe_prefetch_near_end(self) -> None:
        if self._loading:
            return
        if self._server_loaded >= self._server_total:
            return
        if not self._assets:
            return
        scroll = self._table.verticalScrollBar().value()
        page_step = self._table.verticalScrollBar().pageStep()
        maximum = self._table.verticalScrollBar().maximum()
        # If the user is within prefetch_rows of the loaded end, fetch more.
        if maximum > 0 and (scroll + page_step + self._prefetch_rows) >= maximum:
            self._fetch_next_page()

    def _visible_row_range(self) -> tuple[int, int]:
        if not self._assets:
            return (-1, -1)
        scroll = self._table.verticalScrollBar().value()
        page_step = self._table.verticalScrollBar().pageStep()
        first = max(0, scroll - _VIEW_BUFFER_ROWS)
        last = min(
            len(self._assets) - 1,
            scroll + page_step + _VIEW_BUFFER_ROWS,
        )
        return (first, last)

    def _populate_visible_rows(self) -> None:
        """Populate cells for visible rows; release resources for the rest."""
        first, last = self._visible_row_range()
        if first < 0:
            return

        target_rows: Set[int] = set(range(first, last + 1))

        # Tear down widgets for rows that scrolled out of view.
        for row in list(self._populated_rows):
            if row not in target_rows:
                self._clear_row_widgets(row)
                self._populated_rows.discard(row)

        # (Re)populate rows now in view.
        for row in target_rows:
            if (
                0 <= row < len(self._assets)
                and row not in self._populated_rows
            ):
                self._populate_row(row, fallback_thumb=True)
                self._populated_rows.add(row)

        # Tell the worker which cache_keys are currently visible so it
        # can drop decode work for items that scrolled away.
        self._update_visibility_feed()

    def _clear_all_cell_widgets(self) -> None:
        for row in list(self._populated_rows):
            self._clear_row_widgets(row)
        self._populated_rows.clear()

    def _clear_row_widgets(self, row: int) -> None:
        # CRITICAL fix: QTableWidget.removeCellWidget does NOT delete
        # the previously-attached widget (per Qt docs). Without explicit
        # cleanup we leak hundreds of QPushButtons per second when
        # scrolling fast through thousands of rows.
        for col in range(self._table.columnCount()):
            try:
                widget = self._table.cellWidget(row, col)
            except Exception:  # noqa: BLE001
                widget = None
            if widget is not None:
                try:
                    self._table.removeCellWidget(row, col)
                except Exception:  # noqa: BLE001
                    pass
                # Action widgets are pooled by _action_widget_for so we
                # only delete the per-row transient widgets (thumbs).
                if col == _THUMB_COL:
                    widget.setParent(None)
                    widget.deleteLater()
            try:
                self._table.takeItem(row, col)
            except Exception:  # noqa: BLE001
                pass

    def _populate_row(self, row: int, fallback_thumb: bool = False) -> None:
        try:
            asset = self._assets[row]
        except IndexError:
            return


        # Thumb column (col 0): placeholder until background load emits.
        thumb_cell_widget = QWidget()
        thumb_cell_widget.setFixedHeight(_THUMB_CELL_FIXED_HEIGHT)
        tlayout = QHBoxLayout(thumb_cell_widget)
        tlayout.setContentsMargins(4, 4, 4, 4)
        tlayout.setSpacing(0)
        thumb_lbl = QLabel()
        thumb_lbl.setAlignment(
            Qt.AlignmentFlag.AlignCenter
        )
        thumb_lbl.setFixedSize(48, _THUMB_CELL_FIXED_HEIGHT - 8)
        thumb_lbl.setStyleSheet(
            f"background-color: {Colors.SURFACE_LIGHT};"
            f" border: 1px solid {Colors.BORDER};"
            f" border-radius: 6px;"
        )
        tlayout.addWidget(thumb_lbl)
        # Drop any previous widget for the cell.
        try:
            self._table.removeCellWidget(row, _THUMB_COL)
        except Exception:  # noqa: BLE001
            pass
        self._table.setCellWidget(row, _THUMB_COL, thumb_cell_widget)

        # Try cache first; if hit we paint without an async request.
        cache_key = self._thumb_cache_key(asset)
        cached = self._thumb_cache.get(cache_key)
        if cached is not None:
            thumb_lbl.setPixmap(
                cached.scaled(
                    48,
                    _THUMB_CELL_FIXED_HEIGHT - 8,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
            )
            self._thumb_state[asset.id] = "ready"
        else:
            thumb_lbl.setText("…")
            thumb_lbl.setStyleSheet(
                f"background-color: {Colors.SURFACE_LIGHT};"
                f" border: 1px solid {Colors.BORDER};"
                f" border-radius: 6px;"
                f" color: {Colors.TEXT_MUTED};"
                f" font-size: 11px;"
            )
            # Bump version for cancellation safety and dispatch.
            v = self._thumb_versions.get(asset.id, 0) + 1
            self._thumb_versions[asset.id] = v
            self._thumb_state[asset.id] = "pending"
            path = asset.thumbnail_path or asset.file_path
            if path and Path(path).exists():
                # Queued signal: routes to the worker thread via the
                # connection we wired in __init__. Decoding happens
                # off-thread; result comes back through thumbnail_ready.
                self.dispatch_thumbnail.emit(
                    asset.id,
                    cache_key,
                    str(path),
                    v,
                    self._thumb_max_size,
                )

        # Name (col 1)
        name_item = QTableWidgetItem(asset.name)
        self._table.setItem(row, 1, name_item)

        # Status (col 2)
        status_item = QTableWidgetItem(
            asset.status.value.title() if asset.status else "—"
        )
        status_item.setForeground(Qt.GlobalColor.white)
        self._table.setItem(row, 2, status_item)

        # Size (col 3)
        size_text = (
            f"{asset.width}×{asset.height}" if asset.width else "—"
        )
        self._table.setItem(row, 3, QTableWidgetItem(size_text))

        # File (col 4)
        file_text = (
            Path(asset.file_path).name if asset.file_path else "—"
        )
        self._table.setItem(row, 4, QTableWidgetItem(file_text))

        # Actions (col 5) — pooled per asset to avoid reconstructing
        # 3 QPushButtons on every scroll / re-populate.
        actions = self._action_widget_for(asset)
        try:
            self._table.setCellWidget(row, 5, actions)
        except Exception:  # noqa: BLE001
            pass

    def _action_widget_for(self, asset: Asset) -> QWidget:
        """Return a cached actions widget for ``asset``.

        The cache is keyed by ``(id, status, name)`` so an Approve /
        Reject / Delete invalidates correctly when the underlying
        asset changes. We also LRU-trim the pool so it never balloons
        past ``_ACTIONS_POOL_MAX`` entries — this keeps memory bounded
        even after a user scrolls through thousands of assets.
        """
        cache = getattr(self, "_actions_pool", None)
        if cache is None:
            cache = {}
            self._actions_pool = cache
        cache_key = (
            asset.id if asset.id is not None else id(asset),
            asset.status.value if asset.status else "",
            asset.name,
        )
        existing = cache.get(cache_key)
        if existing is not None:
            # Touch — Mark as most-recently used (re-insert with same key).
            # Ordered semantics would be nicer; here we keep insertion
            # order by Pop/Set.
            cache.pop(cache_key, None)
            cache[cache_key] = existing
            return existing
        widget = self._build_actions_cell(asset)
        cache[cache_key] = widget
        # Bound the pool to avoid 30k cached buttons after a deep scroll.
        while len(cache) > _ACTIONS_POOL_MAX:
            oldest_key, oldest_widget = next(iter(cache.items()))
            cache.pop(oldest_key, None)
            oldest_widget.setParent(None)
            oldest_widget.deleteLater()
        return widget

    def _build_actions_cell(self, asset: Asset) -> QWidget:
        actions = QWidget()
        actions_layout = QHBoxLayout(actions)
        actions_layout.setContentsMargins(4, 2, 4, 2)
        actions_layout.setSpacing(4)

        if asset.status != AssetStatus.APPROVED:
            approve_btn = QPushButton("Approve")
            approve_btn.setProperty("cssClass", "primary")
            approve_btn.setFixedHeight(26)
            approve_btn.setFixedWidth(70)
            aid = asset.id
            approve_btn.clicked.connect(lambda _: self._on_approve(aid))
            actions_layout.addWidget(approve_btn)

        reject_btn = QPushButton("Reject")
        reject_btn.setFixedHeight(26)
        reject_btn.setFixedWidth(60)
        aid = asset.id
        reject_btn.clicked.connect(lambda _: self._on_reject(aid))
        actions_layout.addWidget(reject_btn)

        delete_btn = QPushButton("Delete")
        delete_btn.setProperty("cssClass", "danger")
        delete_btn.setFixedHeight(26)
        delete_btn.setFixedWidth(60)
        aid = asset.id
        nm = asset.name
        delete_btn.clicked.connect(lambda _, a=aid, n=nm: self._on_delete(a, n))
        actions_layout.addWidget(delete_btn)
        return actions

    # ── Thumb worker callbacks (GUI thread) ─────────────────────────────────

    @Slot(int, str, QImage)
    def _on_thumb_ready(
        self, asset_id: int, cache_key: str, qimage
    ) -> None:
        # Sprint CRITICAL BUG FIX: the receiver Slot now types its
        # third argument as QImage, matching the worker's typed
        # ``Signal(int, str, QImage)`` declaration. PySide6 marshals
        # QImage arguments across thread boundaries via Qt's meta-type
        # system, which performs an internal detach of the implicit
        # shared buffer and keeps the GUI-side instance safe even if
        # the worker thread is terminated. The previous ``object``
        # typing left both sides pointing at the same C++ QImage —
        # the worker's lifecycle would crash the GUI with a native
        # access violation as soon as ``QPixmap.fromImage(qimage)``
        # dereferenced the invalid pointer.
        # Validate that this result is still current.
        v = self._thumb_versions.get(asset_id)
        # Convert QImage → QPixmap on the GUI thread.
        pixmap = QPixmap.fromImage(qimage)
        if pixmap.isNull():
            self._thumb_state[asset_id] = "failed"
            return
        self._thumb_cache.put(cache_key, pixmap)
        self._thumb_state[asset_id] = "ready"

        # Find which row this asset is in and refresh that row's thumb.
        row = self._find_row_for_asset(asset_id)
        if row is None or row not in self._populated_rows:
            return
        # If version moved on while we were decoding (asset refiltered,
        # assignee scrolled away), keep it cancelled.
        if v is not None and v != self._thumb_versions.get(asset_id):
            return
        thumb_widget = self._table.cellWidget(row, _THUMB_COL)
        if thumb_widget is None:
            return
        labels = thumb_widget.findChildren(QLabel)
        if not labels:
            return
        thumb_lbl = labels[0]
        thumb_lbl.setText("")
        thumb_lbl.setPixmap(
            pixmap.scaled(
                48,
                _THUMB_CELL_FIXED_HEIGHT - 8,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )
        )
        self._emit_diagnostics()

    @Slot(int, str, str)
    def _on_thumb_failed(
        self, asset_id: int, cache_key: str, reason: str
    ) -> None:
        # Keep the placeholder "…" in place; just flag and report.
        self._thumb_state[asset_id] = "failed"
        self._emit_diagnostics()

    def _find_row_for_asset(self, asset_id: int) -> Optional[int]:
        for i, a in enumerate(self._assets):
            if a.id == asset_id:
                return i
        return None

    # ── Cancellation feed ───────────────────────────────────────────────────

    def _update_visibility_feed(self) -> None:
        visible_keys: Set[str] = set()
        for row in self._populated_rows:
            if 0 <= row < len(self._assets):
                asset = self._assets[row]
                if asset.id is not None:
                    visible_keys.add(self._thumb_cache_key(asset))
        # Bulk visibility update — single cross-thread call regardless
        # of scroll aggressiveness.
        try:
            self._thumb_worker.set_visible_keys(visible_keys)
        except Exception:  # noqa: BLE001
            pass

    @staticmethod
    def _thumb_cache_key(asset: Asset) -> str:
        # An asset's thumbnail content updates when its file path or
        # updated_at is touched — use both sides to defeat cache hits
        # when an asset is re-imported to the same path.
        return f"asset:{asset.id}:{asset.updated_at.isoformat()}"

    # ── Action handlers (unchanged from previous sprint) ─────────────────────

    def _on_row_double_clicked(self, row: int, _col: int) -> None:
        if 0 <= row < len(self._assets):
            dlg = AssetInspectorDialog(
                self._assets[row],
                self.controller,
                known_tags=collect_all_tags(self._all_assets),
                known_collections=collect_all_collections(self._all_assets),
                on_tags_changed=self.workspace.workspace_refresh.emit,
                parent=self,
            )
            dlg.exec()

    def _on_import(self) -> None:
        if not self.workspace.project_id:
            return
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Import Asset", "",
            "Images (*.png *.jpg *.jpeg *.webp *.bmp)",
        )
        if not file_path:
            return
        name, ok = QInputDialog.getText(
            self, "Asset Name", "Name for this asset:",
            text=Path(file_path).stem,
        )
        if ok and name.strip():
            try:
                self._asset_ctrl.import_asset(
                    Path(file_path),
                    name.strip(),
                    project_id=self.workspace.project_id,
                    category_id=self.workspace.category_id,
                )
                self.workspace.workspace_refresh.emit()
            except Exception as exc:
                QMessageBox.critical(self, "Import Failed", str(exc))

    def _on_approve(self, asset_id: int) -> None:
        self._change_asset_status(asset_id, AssetStatus.APPROVED, "Approve asset")

    def _on_reject(self, asset_id: int) -> None:
        self._change_asset_status(asset_id, AssetStatus.REJECTED, "Reject asset")

    def _change_asset_status(
        self, asset_id: int, new_status: AssetStatus, label: str
    ) -> None:
        asset = self.controller.assets.get_by_id(asset_id)
        if asset is None:
            return
        old_status = asset.status
        if old_status == new_status:
            return
        self._asset_ctrl.set_status(asset_id, new_status)
        self._record_asset_status(asset_id, old_status, new_status, label, asset.name)

    def _record_asset_status(
        self,
        asset_id: int,
        old_status: AssetStatus,
        new_status: AssetStatus,
        label: str,
        display_name: str,
    ) -> None:
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            self.workspace.workspace_refresh.emit()
            return
        ctrl = self._asset_ctrl
        manager.record(
            f"{label}",
            undo=lambda: ctrl.set_status(asset_id, old_status),
            redo=lambda: ctrl.set_status(asset_id, new_status),
            context=display_name,
        )
        self.workspace.workspace_refresh.emit()

    def _on_delete(self, asset_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self, "Delete Asset", f"Delete '{name}' permanently?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._asset_ctrl.delete_asset(asset_id)
            self.workspace.workspace_refresh.emit()

    # ── Sidebar / collection management (largely preserved) ────────────────

    def _rebuild_tag_chips(self) -> None:
        all_tags = collect_all_tags(self._all_assets)

        existing_lower = {t.lower() for t in all_tags}
        self._selected_tags = {t for t in self._selected_tags if t in existing_lower}
        self._current_tags = set(self._selected_tags)

        while self._tag_chips_layout.count() > 1:
            item = self._tag_chips_layout.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()

        if not all_tags:
            self._tag_row_widget.hide()
            return

        self._tag_row_widget.show()
        for tag in all_tags:
            chip = QPushButton(tag)
            chip.setCheckable(True)
            chip.setChecked(tag.lower() in self._selected_tags)
            chip.setFixedHeight(26)
            chip.setStyleSheet(_FILTER_CHIP_STYLE)
            chip.toggled.connect(
                lambda checked, t=tag: self._on_tag_filter_toggled(t, checked)
            )
            self._tag_chips_layout.insertWidget(
                self._tag_chips_layout.count() - 1, chip
            )

    def _build_collections_sidebar(self) -> QFrame:
        frame = QFrame()
        frame.setFixedWidth(164)
        frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(frame)
        layout.setContentsMargins(10, 14, 10, 14)
        layout.setSpacing(4)

        hdr = QHBoxLayout()
        hdr.setSpacing(4)
        title = QLabel("Collections")
        title.setStyleSheet(
            f"font-size: 12px; font-weight: 600; color: {Colors.TEXT_SECONDARY};"
        )
        hdr.addWidget(title)
        hdr.addStretch()

        new_btn = QPushButton("+")
        new_btn.setProperty("cssClass", "ghost")
        new_btn.setFixedSize(22, 22)
        new_btn.setToolTip("New Collection")
        new_btn.clicked.connect(self._on_new_collection)
        hdr.addWidget(new_btn)
        layout.addLayout(hdr)

        self._col_all_btn = QPushButton("All Assets")
        self._col_all_btn.setCheckable(True)
        self._col_all_btn.setChecked(True)
        self._col_all_btn.setFixedHeight(30)
        self._col_all_btn.setStyleSheet(_COLLECTION_BTN_STYLE)
        self._col_all_btn.clicked.connect(lambda: self._select_collection(None))
        layout.addWidget(self._col_all_btn)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet(f"color: {Colors.BORDER};")
        layout.addWidget(sep)

        col_scroll = QScrollArea()
        col_scroll.setWidgetResizable(True)
        col_scroll.setFrameShape(QFrame.Shape.NoFrame)
        col_scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )

        self._col_list_widget = QWidget()
        self._col_list_widget.setStyleSheet("background: transparent;")
        self._col_list_layout = QVBoxLayout(self._col_list_widget)
        self._col_list_layout.setContentsMargins(0, 0, 0, 0)
        self._col_list_layout.setSpacing(2)
        self._col_list_layout.addStretch()
        col_scroll.setWidget(self._col_list_widget)

        layout.addWidget(col_scroll, stretch=1)
        return frame

    def _rebuild_collection_sidebar(self) -> None:
        while self._col_list_layout.count() > 1:
            item = self._col_list_layout.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()

        from_assets = collect_all_collections(self._all_assets)
        merged = list(from_assets)
        for c in self._known_collections:
            if c.lower() not in {x.lower() for x in merged}:
                merged.append(c)
        merged.sort(key=str.lower)
        self._known_collections = merged

        self._col_all_btn.setChecked(self._selected_collection is None)

        for col in merged:
            btn = QPushButton(col)
            btn.setCheckable(True)
            btn.setChecked(
                self._selected_collection is not None
                and self._selected_collection.lower() == col.lower()
            )
            btn.setFixedHeight(28)
            btn.setStyleSheet(_COLLECTION_BTN_STYLE)
            btn.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
            btn.customContextMenuRequested.connect(
                lambda _pos, c=col, b=btn: self._collection_context_menu(c, b)
            )
            btn.clicked.connect(lambda _checked, c=col: self._select_collection(c))
            self._col_list_layout.insertWidget(
                self._col_list_layout.count() - 1, btn
            )

    def _collection_context_menu(self, col_name: str, btn: QPushButton) -> None:
        from PySide6.QtWidgets import QMenu
        menu = QMenu(self)
        rename_act = menu.addAction("✏️  Rename")
        delete_act = menu.addAction("🗑  Delete")
        action = menu.exec(btn.mapToGlobal(btn.rect().bottomLeft()))
        if action == rename_act:
            self._on_rename_collection(col_name)
        elif action == delete_act:
            self._on_delete_collection(col_name)

    def _on_new_collection(self) -> None:
        name, ok = QInputDialog.getText(
            self, "New Collection", "Collection name:"
        )
        if ok and name.strip():
            name = name.strip()
            if name.lower() not in {c.lower() for c in self._known_collections}:
                self._known_collections.append(name)
            self._rebuild_collection_sidebar()

    def _on_rename_collection(self, old_name: str) -> None:
        new_name, ok = QInputDialog.getText(
            self, "Rename Collection", "New name:", text=old_name
        )
        if not ok or not new_name.strip():
            return
        new_name = new_name.strip()
        if new_name.lower() == old_name.lower():
            return
        for asset in self._all_assets:
            cols = get_collections(asset)
            updated = [
                new_name if c.lower() == old_name.lower() else c for c in cols
            ]
            if updated != cols:
                set_collections(asset, updated)
                self._asset_ctrl.update_asset(asset)
        if (
            self._selected_collection
            and self._selected_collection.lower() == old_name.lower()
        ):
            self._selected_collection = new_name
            self._current_collection = new_name
        self.workspace.workspace_refresh.emit()

    def _on_delete_collection(self, name: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete Collection",
            f"Remove collection '{name}'?\n\nAssets will NOT be deleted.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        for asset in self._all_assets:
            cols = get_collections(asset)
            updated = [c for c in cols if c.lower() != name.lower()]
            if updated != cols:
                set_collections(asset, updated)
                self._asset_ctrl.update_asset(asset)
        if (
            self._selected_collection
            and self._selected_collection.lower() == name.lower()
        ):
            self._selected_collection = None
            self._current_collection = None
        self._known_collections = [
            c for c in self._known_collections if c.lower() != name.lower()
        ]
        self.workspace.workspace_refresh.emit()

    def _on_assign_to_collection(self) -> None:
        selected_rows = sorted(
            {idx.row() for idx in self._table.selectionModel().selectedRows()}
        )
        if not selected_rows:
            QMessageBox.information(
                self,
                "Assign to Collection",
                "Select one or more assets in the table first.",
            )
            return

        cols: List[str] = list(self._known_collections)
        for c in collect_all_collections(self._all_assets):
            if c.lower() not in {x.lower() for x in cols}:
                cols.append(c)
        cols.sort(key=str.lower)

        name, ok = QInputDialog.getItem(
            self,
            "Assign to Collection",
            f"Add {len(selected_rows)} asset(s) to collection:",
            cols,
            editable=True,
        )
        if not ok or not name.strip():
            return
        name = name.strip()

        # Sprint: Global Undo / Redo PRO #1 — snapshot every pre-state
        # of the selected assets so the bulk add can be reverted cleanly.
        snapshots: List[tuple[int, List[str]]] = []
        for row in selected_rows:
            if 0 <= row < len(self._assets):
                asset = self._assets[row]
                current = get_collections(asset)
                if name.lower() in {c.lower() for c in current}:
                    snapshots.append((asset.id, list(current)))
                    continue
                updated = list(current) + [name]
                snapshots.append((asset.id, list(current)))
                set_collections(asset, updated)
                self._asset_ctrl.update_asset(asset)

        if name.lower() not in {c.lower() for c in self._known_collections}:
            self._known_collections.append(name)

        # Record the bulk mutation for undo (only if anything actually
        # changed for at least one asset).
        affected = len([1 for aid, _ in snapshots if aid is not None])
        if affected:
            self._record_collection_bulk_assign(
                snapshots=snapshots,
                added_name=name,
            )

        self.workspace.workspace_refresh.emit()

    def _record_collection_bulk_assign(
        self,
        snapshots: List[tuple],
        added_name: str,
    ) -> None:
        """Push a bulk ``added_name`` collection-add onto undo/redo.

        ``snapshots`` is ``[(asset_id, old_collections_list), ...]``
        captured BEFORE the mutation. Undo restores the previous lists,
        redo applies the same ``added_name`` to every snapshot.
        """
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None or not snapshots:
            return
        ctrl = self._asset_ctrl
        affected = len([1 for aid, _ in snapshots if aid is not None])
        if affected == 0:
            return
        snap = [(aid, list(cols)) for aid, cols in snapshots if aid is not None]
        added = added_name

        def _undo() -> None:
            try:
                for aid, old_cols in snap:
                    inst = ctrl.get_by_id(aid)
                    if inst is None:
                        continue
                    set_collections(inst, list(old_cols))
                    ctrl.update_asset(inst)
            except Exception:
                pass

        def _redo() -> None:
            try:
                for aid, _old_cols in snap:
                    inst = ctrl.get_by_id(aid)
                    if inst is None:
                        continue
                    current = get_collections(inst)
                    if added.lower() in {c.lower() for c in current}:
                        continue
                    current.append(added)
                    set_collections(inst, current)
                    ctrl.update_asset(inst)
            except Exception:
                pass

        manager.record(
            f"Assign {affected} asset(s) to collection",
            undo=_undo,
            redo=_redo,
            context=added,
        )

    # ── Refresh hook ────────────────────────────────────────────────────────

    def refresh(self) -> None:
        self._apply_filters(initial=True)

    # ── Worker thread teardown ──────────────────────────────────────────────

    def _stop_thumb_worker(self) -> None:
        """Tear the thumbnail loader thread down cleanly.

        Wired to ``self.destroyed`` + ``app.aboutToQuit`` so it runs on
        every destruction path (QTabWidget tab removal, app shutdown,
        or deleteLater).

        Sprint CRITICAL BUG FIX (the three rules that make this safe):

        1. **Cooperative shutdown FIRST.** ``worker.request_shutdown()``
           flips a flag under the worker's own lock. Any ``decode``
           slot sitting in the worker's event-loop queue exits on its
           very next ``with self._lock`` block instead of waiting on a
           slow ``QImage(str(path))`` to finish. Without this, a
           backlog of pending decodes keeps the worker thread busy
           long enough that ``thread.wait(2000)`` will *time out*;
           we then drop the Python wrapper reference while the C++
           QObject is still alive on a still-running thread — and a
           later Python GC reclaims the QObject from the GUI thread
           while the worker is mid-slot. That's the cross-thread
           access violation the previous code path triggered.

        2. **``worker.deleteLater()`` BEFORE ``thread.quit()``.**
           Both post events into the worker's CURRENT event-loop
           queue. FIFO ordering guarantees the DeferredDelete runs
           first (destroying the C++ QObject on the worker's own
           thread while it's still alive), then the Quit event
           closes the loop. Issuing them the other way around
           (deleteLater after wait) posts into a dead event loop
           and crashes Qt on Windows.

        3. **Drop the Python reference LAST, but always drop it.**
           Even on a worst-case timeout, we *must* let the wrapper
           ref go so GC has a shot at reclaiming the worker.
           Because the C++ destruction was queued before ``wait``
           returned, the worker thread owns the actual deletion.
        """
        if getattr(self, "_thumb_worker_stopping", False):
            return
        self._thumb_worker_stopping = True

        worker = getattr(self, "_thumb_worker", None)
        thread = getattr(self, "_thumb_thread", None)

        # ── 1. Disconnect dispatch + result signals. Block any new
        #       work item from being delivered to a living slot.
        try:
            try:
                self.dispatch_thumbnail.disconnect()
            except Exception:  # noqa: BLE001
                pass
            if worker is not None:
                try:
                    worker.thumbnail_ready.disconnect(self._on_thumb_ready)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.thumbnail_failed.disconnect(self._on_thumb_failed)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.clear_visible()
                except Exception:  # noqa: BLE001
                    pass
                try:
                    worker.request_shutdown()
                except Exception:  # noqa: BLE001
                    pass
            pool = getattr(self, "_actions_pool", None)
            if pool:
                for w in pool.values():
                    w.setParent(None)
                    w.deleteLater()
                pool.clear()
        except Exception:  # noqa: BLE001
            pass

        # ── 2. deleteLater BEFORE quit. FIFO ordering on the
        #       worker's event-loop queue.
        try:
            if (
                worker is not None
                and thread is not None
                and thread.isRunning()
            ):
                worker.deleteLater()
        except Exception:  # noqa: BLE001
            pass

        # ── 3. Quit keeps the worker thread alive just long
        #       enough to drain the deferred delete then exit.
        try:
            if thread is not None and thread.isRunning():
                thread.quit()
        except Exception:  # noqa: BLE001
            pass

        # ── 4. Wait for the worker thread to actually exit. 5 s is
        #       comfortably larger than the worst slow-image decode
        #       observed in the dataset but still small enough that
        #       an unresponsive worker doesn't freeze the GUI when
        #       the user closes a tab.
        try:
            if thread is not None:
                thread.wait(5000)
        except Exception:  # noqa: BLE001
            pass

        # ── 5. Drop Python references last. The worker is back on
        #       its own thread (the C++ destruction was queued
        #       there in step 2) so handing the wrapper ref to GC
        #       is safe even on a worst-case wait() timeout.
        self._thumb_thread = None
        self._thumb_worker = None

    # ── Extra utilities ─────────────────────────────────────────────────────

    def resizeEvent(self, event) -> None:  # noqa: N802 (Qt naming)
        super().resizeEvent(event)
        if self._diagnostics is not None:
            margin = 12
            w = self._diagnostics.sizeHint().width()
            h = self._diagnostics.sizeHint().height()
            self._diagnostics.setGeometry(
                self.width() - w - margin,
                self.height() - h - margin,
                w, h,
            )

    # ── Diagnostics overlay ─────────────────────────────────────────────────

    def _build_diagnostics_overlay(self) -> QFrame:
        from core.theme.colors import Colors as _C
        box = QFrame(self)
        box.setObjectName("library-diagnostics")
        box.setStyleSheet(
            f"QFrame#library-diagnostics {{"
            f"  background-color: rgba(15, 23, 42, 230);"
            f"  border: 1px solid {_C.BORDER};"
            f"  border-radius: 8px;"
            f"}}"
            f"QLabel#library-diagnostics-line {{"
            f"  color: {_C.TEXT_SECONDARY};"
            f"  font-family: 'Consolas', 'Courier New', monospace;"
            f"  font-size: 11px;"
            f"  padding: 1px 6px;"
            f"}}"
            f"QLabel#library-diagnostics-title {{"
            f"  color: {_C.TEXT_PRIMARY};"
            f"  font-weight: 600;"
            f"  font-size: 11px;"
            f"  padding: 2px 6px;"
            f"}}"
        )
        v = QVBoxLayout(box)
        v.setContentsMargins(8, 6, 8, 6)
        v.setSpacing(1)

        title = QLabel("Perf Diagnostics")
        title.setObjectName("library-diagnostics-title")
        v.addWidget(title)

        self._diag_lines: Dict[str, QLabel] = {}
        for key in ("visible", "total", "cached", "cache_mb", "jobs", "prefetch"):
            lbl = QLabel(f"{key}: —")
            lbl.setObjectName("library-diagnostics-line")
            v.addWidget(lbl)
            self._diag_lines[key] = lbl
        return box

    def _emit_diagnostics(self) -> None:
        if self._diagnostics is None:
            return
        try:
            stats = self._thumb_cache.stats()
            visible_count = len(self._populated_rows)
            pending_jobs = self._thumb_worker.running_count()
            self._diag_lines["visible"].setText(
                f"visible  : {visible_count:5d}"
            )
            self._diag_lines["total"].setText(
                f"loaded   : {len(self._assets):5d} / {self._server_total:5d}"
            )
            self._diag_lines["cached"].setText(
                f"cached   : {stats['entries']:5d}  (hit {stats['hit_rate']*100:.0f}%)"
            )
            self._diag_lines["cache_mb"].setText(
                f"cache MB : {stats['bytes'] / (1024 * 1024):.2f} / "
                f"{stats['max_bytes'] / (1024 * 1024):.0f}"
            )
            self._diag_lines["jobs"].setText(
                f"bg jobs  : {pending_jobs:5d}"
            )
            self._diag_lines["prefetch"].setText(
                f"prefetch : 'within {self._prefetch_rows}'"
            )
        except Exception:  # noqa: BLE001
            pass
