"""Library tab v2 — clean rewrite, zero-thread, synchronous thumbnails.

Architecture
============
Three focused classes collaborate to display the asset library:

    _CollectionsSidebar   — virtual-folder navigation + CRUD
    _TagBar               — horizontal scrolling tag-filter chip strip
    LibraryTab            — coordinator: data loading, table, actions

Design goals
============
* Zero native crashes — no QThread, no worker objects, no queued signals.
* Correctness first — thumbnails are loaded synchronously via QPixmap.
* Simple refresh — calling refresh() reloads from the DB with no hidden
  state to unwind (no version counters, no cancellation sets, no pools).
* Maintainability — every responsibility lives in one clearly named
  section; new features slot in without touching unrelated code.

Data flow
=========
    refresh()
        └─ _reload()
               ├─ _load_all_assets()     DB query (server-side status filter)
               ├─ _apply_client_filters() name / tag / collection predicates
               ├─ _sidebar.rebuild()
               ├─ _tag_bar.rebuild()
               └─ _populate_table()
                      └─ _populate_row()   per-row: thumb + items + actions
"""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional, Set

from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtGui import QPixmap
from PySide6.QtWidgets import (
    QComboBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMenu,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import Asset, AssetStatus
from ui.widgets.asset_inspector_dialog import AssetInspectorDialog
from ui.widgets.tag_utils import (
    collect_all_collections,
    collect_all_tags,
    get_collections,
    get_tags,
    set_collections,
)
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase
from utils.logger import get_logger

logger = get_logger(__name__)


# ── Column indices ─────────────────────────────────────────────────────────────

_COL_THUMB = 0
_COL_NAME = 1
_COL_STATUS = 2
_COL_SIZE = 3
_COL_FILE = 4
_COL_ACTIONS = 5
_COLUMN_LABELS = ["Thumb", "Name", "Status", "Size", "File", "Actions"]

_THUMB_W = 48
_THUMB_H = 36
_ROW_HEIGHT = 46

_STATUS_CHOICES = ["All", "Pending", "Generated", "Approved", "Rejected", "Exported"]
_SEARCH_DEBOUNCE_MS = 250


# ── Shared styles ──────────────────────────────────────────────────────────────

_CHIP_STYLE = (
    "QPushButton {"
    f"  background-color: {Colors.SURFACE};"
    f"  border: 1px solid {Colors.BORDER};"
    "  border-radius: 12px;"
    "  padding: 3px 10px;"
    "  font-size: 12px;"
    f"  color: {Colors.TEXT_SECONDARY};"
    "}"
    "QPushButton:checked {"
    f"  background-color: {Colors.PRIMARY};"
    f"  border-color: {Colors.PRIMARY};"
    "  color: #FFFFFF;"
    "}"
    "QPushButton:hover:!checked {"
    f"  border-color: {Colors.PRIMARY};"
    f"  color: {Colors.PRIMARY_LIGHT};"
    "}"
)

_COLLECTION_BTN_STYLE = (
    "QPushButton {"
    "  background-color: transparent;"
    "  border: none;"
    "  border-radius: 6px;"
    "  padding: 3px 8px;"
    "  font-size: 12px;"
    f"  color: {Colors.TEXT_SECONDARY};"
    "  text-align: left;"
    "}"
    "QPushButton:checked {"
    f"  background-color: {Colors.PRIMARY}22;"
    f"  color: {Colors.PRIMARY_LIGHT};"
    "  font-weight: 600;"
    "}"
    "QPushButton:hover:!checked {"
    f"  background-color: {Colors.SURFACE_LIGHT};"
    f"  color: {Colors.TEXT_PRIMARY};"
    "}"
)

_SIDEBAR_FRAME_STYLE = f"""
    QFrame {{
        background-color: {Colors.SURFACE};
        border: 1px solid {Colors.BORDER};
        border-radius: 12px;
    }}
"""

_THUMB_PLACEHOLDER_STYLE = (
    f"background-color: {Colors.SURFACE_LIGHT};"
    f" border: 1px solid {Colors.BORDER};"
    " border-radius: 6px;"
    f" color: {Colors.TEXT_MUTED};"
    " font-size: 11px;"
)

_THUMB_BASE_STYLE = (
    f"background-color: {Colors.SURFACE_LIGHT};"
    f" border: 1px solid {Colors.BORDER};"
    " border-radius: 6px;"
)


# ─────────────────────────────────────────────────────────────────────────────
# _CollectionsSidebar
# ─────────────────────────────────────────────────────────────────────────────

class _CollectionsSidebar(QFrame):
    """Left panel that lists all virtual collections.

    Signals
    -------
    collection_selected(name_or_None)
        Emitted when the user picks a collection.  ``None`` = "All Assets".
    new_requested()
        User pressed the "+" button.
    rename_requested(old_name)
        User chose "Rename" from the context menu.
    delete_requested(name)
        User chose "Delete" from the context menu.
    """

    collection_selected: Signal = Signal(object)   # str | None
    new_requested: Signal = Signal()
    rename_requested: Signal = Signal(str)
    delete_requested: Signal = Signal(str)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFixedWidth(164)
        self.setStyleSheet(_SIDEBAR_FRAME_STYLE)
        self._current: Optional[str] = None
        self._build_ui()

    # ── Build ────────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 14, 10, 14)
        layout.setSpacing(4)

        # Header row: title + "+" button
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
        new_btn.clicked.connect(self.new_requested)
        hdr.addWidget(new_btn)
        layout.addLayout(hdr)

        # "All Assets" fixed button
        self._all_btn = QPushButton("All Assets")
        self._all_btn.setCheckable(True)
        self._all_btn.setChecked(True)
        self._all_btn.setFixedHeight(30)
        self._all_btn.setStyleSheet(_COLLECTION_BTN_STYLE)
        self._all_btn.clicked.connect(lambda: self._select(None))
        layout.addWidget(self._all_btn)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet(f"color: {Colors.BORDER};")
        layout.addWidget(sep)

        # Scrollable list area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self._list_widget = QWidget()
        self._list_widget.setStyleSheet("background: transparent;")
        self._list_layout = QVBoxLayout(self._list_widget)
        self._list_layout.setContentsMargins(0, 0, 0, 0)
        self._list_layout.setSpacing(2)
        self._list_layout.addStretch()
        scroll.setWidget(self._list_widget)
        layout.addWidget(scroll, stretch=1)

    # ── Public API ───────────────────────────────────────────────────────────

    def rebuild(self, names: List[str], current: Optional[str]) -> None:
        """Repopulate the list with ``names``, highlighting ``current``."""
        self._current = current

        # Remove all existing buttons (keep the trailing QSpacerItem)
        while self._list_layout.count() > 1:
            item = self._list_layout.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()

        self._all_btn.setChecked(current is None)

        for name in sorted(names, key=str.lower):
            btn = QPushButton(name)
            btn.setCheckable(True)
            btn.setChecked(
                current is not None and current.lower() == name.lower()
            )
            btn.setFixedHeight(28)
            btn.setStyleSheet(_COLLECTION_BTN_STYLE)
            btn.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
            btn.customContextMenuRequested.connect(
                lambda _pos, n=name, b=btn: self._show_context_menu(n, b)
            )
            btn.clicked.connect(lambda checked=False, n=name: self._select(n))
            self._list_layout.insertWidget(self._list_layout.count() - 1, btn)

    # ── Internals ────────────────────────────────────────────────────────────

    def _select(self, name: Optional[str]) -> None:
        """Update checked states and emit ``collection_selected``."""
        self._current = name
        self._all_btn.setChecked(name is None)
        for i in range(self._list_layout.count()):
            item = self._list_layout.itemAt(i)
            if item and isinstance(item.widget(), QPushButton):
                btn: QPushButton = item.widget()  # type: ignore[assignment]
                btn.setChecked(
                    name is not None and btn.text().lower() == name.lower()
                )
        self.collection_selected.emit(name)

    def _show_context_menu(self, name: str, btn: QPushButton) -> None:
        menu = QMenu(self)
        rename_act = menu.addAction("✏️  Rename")
        delete_act = menu.addAction("🗑  Delete")
        action = menu.exec(btn.mapToGlobal(btn.rect().bottomLeft()))
        if action == rename_act:
            self.rename_requested.emit(name)
        elif action == delete_act:
            self.delete_requested.emit(name)


# ─────────────────────────────────────────────────────────────────────────────
# _TagBar
# ─────────────────────────────────────────────────────────────────────────────

class _TagBar(QWidget):
    """Horizontal scrollable row of checkable tag-filter chips.

    Signals
    -------
    filter_changed(active_tags)
        Emitted whenever the active tag set changes.
        ``active_tags`` is a ``Set[str]`` of lowercase tag names.
    """

    filter_changed: Signal = Signal(object)   # Set[str]

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._active: Set[str] = set()
        self._build_ui()
        self.hide()

    # ── Build ────────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        outer = QHBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(8)

        label = QLabel("Tags:")
        label.setFixedWidth(38)
        outer.addWidget(label)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFixedHeight(36)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )

        self._chips_widget = QWidget()
        self._chips_layout = QHBoxLayout(self._chips_widget)
        self._chips_layout.setContentsMargins(0, 2, 0, 2)
        self._chips_layout.setSpacing(6)
        self._chips_layout.addStretch()
        scroll.setWidget(self._chips_widget)
        outer.addWidget(scroll, stretch=1)

    # ── Public API ───────────────────────────────────────────────────────────

    def rebuild(self, all_tags: List[str], active: Set[str]) -> None:
        """Rebuild chip buttons.  Preserves checks for tags still present."""
        self._active = {t.lower() for t in active} & {t.lower() for t in all_tags}

        # Remove all chips (keep the trailing QSpacerItem)
        while self._chips_layout.count() > 1:
            item = self._chips_layout.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()

        if not all_tags:
            self.hide()
            return

        self.show()
        for tag in all_tags:
            chip = QPushButton(tag)
            chip.setCheckable(True)
            chip.setChecked(tag.lower() in self._active)
            chip.setFixedHeight(26)
            chip.setStyleSheet(_CHIP_STYLE)
            chip.toggled.connect(
                lambda checked, t=tag: self._on_chip_toggled(t, checked)
            )
            self._chips_layout.insertWidget(
                self._chips_layout.count() - 1, chip
            )

    # ── Internals ────────────────────────────────────────────────────────────

    def _on_chip_toggled(self, tag: str, checked: bool) -> None:
        if checked:
            self._active.add(tag.lower())
        else:
            self._active.discard(tag.lower())
        self.filter_changed.emit(set(self._active))


# ─────────────────────────────────────────────────────────────────────────────
# LibraryTab  — coordinator
# ─────────────────────────────────────────────────────────────────────────────

class LibraryTab(WorkspaceTabBase):
    """Asset library browser — v2.

    Responsibilities
    ----------------
    Coordinator only.  All UI sub-sections are delegated:

    * _CollectionsSidebar  → left panel
    * _TagBar              → tag-filter strip
    * QTableWidget         → asset grid (built and owned here)

    Section index
    -------------
    _build_ui()           — assemble sub-widgets, wire signals
    _build_toolbar()      — search bar + status combo + action buttons
    _build_table()        — configure and return the QTableWidget

    [Data loading]
    _reload()             — full reload: DB + filters + UI rebuild
    _load_all_assets()    — query controller with server-side status filter
    _apply_client_filters() — search / tag / collection predicates

    [Table population]
    _populate_table()     — set row count and call _populate_row for each
    _populate_row()       — fill one row: thumbnail + items + actions
    _make_thumb_widget()  — synchronous QPixmap load
    _make_actions_widget() — Approve / Reject / Delete buttons

    [Filter handlers]
    _on_search_changed() / _on_search_debounced()
    _on_status_changed()
    _on_tag_filter_changed()
    _on_collection_selected()

    [Selection]
    _on_row_double_clicked()

    [Actions]
    _on_approve() / _on_reject() / _on_delete()
    _on_import()
    _on_assign_to_collection()
    _change_asset_status()
    _record_status_change()
    _record_collection_bulk_assign()

    [Collection management]
    _on_new_collection()
    _on_rename_collection()
    _on_delete_collection()

    [Helpers]
    _update_status_bar()
    _filter_match()
    """

    # ── Build UI ───────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        # ── State initialisation ─────────────────────────────────────────────
        self._asset_ctrl = AssetController(self.controller)

        # Full unfiltered result (status-filtered only — used by sidebars).
        self._all_assets: List[Asset] = []
        # Client-filtered subset shown in the table.
        self._assets: List[Asset] = []
        # All known collection names (union of DB data + user-created names).
        self._known_collections: List[str] = []

        # Active filter values
        self._query: str = ""
        self._status_filter: str = "All"
        self._tag_filter: Set[str] = set()
        self._collection_filter: Optional[str] = None

        # Search debounce timer — avoids a DB round-trip on every keystroke.
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(_SEARCH_DEBOUNCE_MS)
        self._search_timer.timeout.connect(self._on_search_debounced)

        # ── Sub-widget assembly ──────────────────────────────────────────────
        main_row = QHBoxLayout()
        main_row.setContentsMargins(0, 0, 0, 0)
        main_row.setSpacing(12)

        # Left: collections sidebar
        self._sidebar = _CollectionsSidebar()
        self._sidebar.collection_selected.connect(self._on_collection_selected)
        self._sidebar.new_requested.connect(self._on_new_collection)
        self._sidebar.rename_requested.connect(self._on_rename_collection)
        self._sidebar.delete_requested.connect(self._on_delete_collection)
        main_row.addWidget(self._sidebar)

        # Right: toolbar + tag bar + table + status label
        right = QWidget()
        right.setStyleSheet("background: transparent;")
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(8)

        right_layout.addLayout(self._build_toolbar())

        self._tag_bar = _TagBar()
        self._tag_bar.filter_changed.connect(self._on_tag_filter_changed)
        right_layout.addWidget(self._tag_bar)

        right_layout.addWidget(self._build_table(), stretch=1)

        self._status_label = QLabel("")
        self._status_label.setStyleSheet(
            f"font-size: 11px; color: {Colors.TEXT_MUTED}; padding: 2px 0;"
        )
        right_layout.addWidget(self._status_label)

        main_row.addWidget(right, stretch=1)
        self._layout.addLayout(main_row, stretch=1)

    # ── Toolbar ────────────────────────────────────────────────────────────────

    def _build_toolbar(self) -> QHBoxLayout:
        """Build and return the search + status + action button row."""
        row = QHBoxLayout()
        row.setSpacing(10)

        self._search_edit = QLineEdit()
        self._search_edit.setPlaceholderText(
            "🔍  Search by name, tag or collection…"
        )
        self._search_edit.setClearButtonEnabled(True)
        self._search_edit.textChanged.connect(self._on_search_changed)
        row.addWidget(self._search_edit, stretch=1)

        status_lbl = QLabel("Status:")
        status_lbl.setAlignment(
            Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter
        )
        row.addWidget(status_lbl)

        self._status_combo = QComboBox()
        self._status_combo.addItems(_STATUS_CHOICES)
        self._status_combo.setFixedWidth(130)
        self._status_combo.currentIndexChanged.connect(self._on_status_changed)
        row.addWidget(self._status_combo)

        assign_btn = QPushButton("📁  Assign to Collection")
        assign_btn.setProperty("cssClass", "ghost")
        assign_btn.clicked.connect(self._on_assign_to_collection)
        row.addWidget(assign_btn)

        import_btn = QPushButton("+ Import Asset")
        import_btn.setProperty("cssClass", "primary")
        import_btn.clicked.connect(self._on_import)
        row.addWidget(import_btn)

        return row

    # ── Table configuration ────────────────────────────────────────────────────

    def _build_table(self) -> QTableWidget:
        """Create, configure, and return the asset QTableWidget."""
        self._table = QTableWidget()
        self._table.setColumnCount(len(_COLUMN_LABELS))
        self._table.setHorizontalHeaderLabels(_COLUMN_LABELS)
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setSelectionMode(
            QTableWidget.SelectionMode.ExtendedSelection
        )
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._table.verticalHeader().setDefaultSectionSize(_ROW_HEIGHT)
        self._table.setColumnWidth(_COL_THUMB, 56)
        self._table.setAlternatingRowColors(True)
        self._table.cellDoubleClicked.connect(self._on_row_double_clicked)
        return self._table

    # ── Public refresh hook ────────────────────────────────────────────────────

    def refresh(self) -> None:
        """Reload data from the database and repopulate the table."""
        self._reload()

    # ── Data loading ───────────────────────────────────────────────────────────

    def _reload(self) -> None:
        """Full data reload: DB fetch + client filters + full UI rebuild."""
        self._load_all_assets()
        self._apply_client_filters()
        self._sidebar.rebuild(self._known_collections, self._collection_filter)
        self._tag_bar.rebuild(
            collect_all_tags(self._all_assets),
            self._tag_filter,
        )
        self._populate_table()

    def _load_all_assets(self) -> None:
        """Fetch assets from the DB with server-side status filter only.

        Populates ``self._all_assets`` and updates ``self._known_collections``.
        """
        if not self.workspace.project_id:
            self._all_assets = []
            self._assets = []
            self._known_collections = []
            return

        kwargs: dict = {"project_id": self.workspace.project_id}
        if self.workspace.category_id is not None:
            kwargs["category_id"] = self.workspace.category_id
        if self._status_filter != "All":
            try:
                kwargs["status"] = AssetStatus(self._status_filter.lower())
            except ValueError:
                pass

        try:
            self._all_assets = self._asset_ctrl.get_all(**kwargs)
        except Exception:
            logger.exception("Failed to load assets from controller")
            self._all_assets = []

        # Merge asset-derived collections with any user-created names so
        # collections the user created but hasn't assigned yet remain visible.
        from_assets = collect_all_collections(self._all_assets)
        merged: List[str] = list(from_assets)
        for name in self._known_collections:
            if name.lower() not in {x.lower() for x in merged}:
                merged.append(name)
        merged.sort(key=str.lower)
        self._known_collections = merged

    def _apply_client_filters(self) -> None:
        """Filter ``self._all_assets`` into ``self._assets`` client-side."""
        self._assets = [
            a for a in self._all_assets if self._filter_match(a)
        ]

    def _filter_match(self, asset: Asset) -> bool:
        """Return True if ``asset`` passes all active client-side filters."""
        tags = get_tags(asset)
        cols = get_collections(asset)

        if self._query:
            searchable = (
                asset.name.lower()
                + " "
                + " ".join(t.lower() for t in tags)
                + " "
                + " ".join(c.lower() for c in cols)
            )
            if self._query not in searchable:
                return False

        if self._tag_filter:
            asset_tags_lower = {t.lower() for t in tags}
            if not self._tag_filter.issubset(asset_tags_lower):
                return False

        if self._collection_filter:
            asset_cols_lower = {c.lower() for c in cols}
            if self._collection_filter.lower() not in asset_cols_lower:
                return False

        return True

    # ── Table population ───────────────────────────────────────────────────────

    def _populate_table(self) -> None:
        """Rebuild the entire table from ``self._assets``."""
        self._table.setRowCount(0)
        self._table.setRowCount(len(self._assets))
        for row, asset in enumerate(self._assets):
            self._populate_row(row, asset)
        self._update_status_bar()

    def _populate_row(self, row: int, asset: Asset) -> None:
        """Fill all six cells for one table row."""
        self._table.setCellWidget(
            row, _COL_THUMB, self._make_thumb_widget(asset)
        )

        self._table.setItem(row, _COL_NAME, QTableWidgetItem(asset.name))

        status_text = asset.status.value.title() if asset.status else "—"
        self._table.setItem(
            row, _COL_STATUS, QTableWidgetItem(status_text)
        )

        size_text = (
            f"{asset.width}×{asset.height}" if asset.width else "—"
        )
        self._table.setItem(row, _COL_SIZE, QTableWidgetItem(size_text))

        file_text = Path(asset.file_path).name if asset.file_path else "—"
        self._table.setItem(row, _COL_FILE, QTableWidgetItem(file_text))

        self._table.setCellWidget(
            row, _COL_ACTIONS, self._make_actions_widget(asset)
        )

    # ── Thumbnail ──────────────────────────────────────────────────────────────

    def _make_thumb_widget(self, asset: Asset) -> QWidget:
        """Create a thumbnail cell widget by loading the pixmap synchronously.

        Uses ``asset.thumbnail_path`` if present, falls back to
        ``asset.file_path``.  Shows a styled placeholder when no file exists.
        """
        container = QWidget()
        lay = QHBoxLayout(container)
        lay.setContentsMargins(4, 4, 4, 4)
        lay.setSpacing(0)

        lbl = QLabel()
        lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl.setFixedSize(_THUMB_W, _THUMB_H)

        path_str = asset.thumbnail_path or asset.file_path
        pixmap_loaded = False

        if path_str:
            path = Path(path_str)
            if path.exists():
                px = QPixmap(str(path)).scaled(
                    _THUMB_W,
                    _THUMB_H,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
                if not px.isNull():
                    lbl.setStyleSheet(_THUMB_BASE_STYLE)
                    lbl.setPixmap(px)
                    pixmap_loaded = True

        if not pixmap_loaded:
            lbl.setStyleSheet(_THUMB_PLACEHOLDER_STYLE)
            lbl.setText("—")

        lay.addWidget(lbl)
        return container

    # ── Actions widget ─────────────────────────────────────────────────────────

    def _make_actions_widget(self, asset: Asset) -> QWidget:
        """Build the Approve / Reject / Delete button group for one row."""
        container = QWidget()
        lay = QHBoxLayout(container)
        lay.setContentsMargins(4, 2, 4, 2)
        lay.setSpacing(4)

        if asset.status != AssetStatus.APPROVED:
            approve_btn = QPushButton("Approve")
            approve_btn.setProperty("cssClass", "primary")
            approve_btn.setFixedHeight(26)
            approve_btn.setFixedWidth(70)
            aid = asset.id
            approve_btn.clicked.connect(
                lambda checked=False, a=aid: self._on_approve(a)
            )
            lay.addWidget(approve_btn)

        reject_btn = QPushButton("Reject")
        reject_btn.setFixedHeight(26)
        reject_btn.setFixedWidth(60)
        aid = asset.id
        reject_btn.clicked.connect(
            lambda checked=False, a=aid: self._on_reject(a)
        )
        lay.addWidget(reject_btn)

        delete_btn = QPushButton("Delete")
        delete_btn.setProperty("cssClass", "danger")
        delete_btn.setFixedHeight(26)
        delete_btn.setFixedWidth(60)
        aid = asset.id
        name = asset.name
        delete_btn.clicked.connect(
            lambda checked=False, a=aid, n=name: self._on_delete(a, n)
        )
        lay.addWidget(delete_btn)

        return container

    # ── Status bar ─────────────────────────────────────────────────────────────

    def _update_status_bar(self) -> None:
        total = len(self._all_assets)
        shown = len(self._assets)
        suffix = "s" if total != 1 else ""
        if total == shown:
            self._status_label.setText(f"{total} asset{suffix}")
        else:
            self._status_label.setText(f"{shown} of {total} asset{suffix}")

    # ── Filter event handlers ──────────────────────────────────────────────────

    def _on_search_changed(self, _text: str) -> None:
        """Restart the debounce timer on every keystroke."""
        self._search_timer.start()

    def _on_search_debounced(self) -> None:
        """Apply the search query after the debounce delay."""
        self._query = self._search_edit.text().lower().strip()
        self._apply_client_filters()
        self._populate_table()

    def _on_status_changed(self, _index: int) -> None:
        """Status is a server-side filter: requires a full DB reload."""
        self._status_filter = self._status_combo.currentText()
        self._reload()

    def _on_tag_filter_changed(self, active_tags: Set[str]) -> None:
        """Tag filter is client-side: no DB round-trip needed."""
        self._tag_filter = active_tags
        self._apply_client_filters()
        self._populate_table()

    def _on_collection_selected(self, name: Optional[str]) -> None:
        """Collection filter is client-side: no DB round-trip needed."""
        self._collection_filter = name
        self._apply_client_filters()
        self._populate_table()

    # ── Selection ──────────────────────────────────────────────────────────────

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

    # ── Action handlers ────────────────────────────────────────────────────────

    def _on_approve(self, asset_id: int) -> None:
        self._change_asset_status(
            asset_id, AssetStatus.APPROVED, "Approve asset"
        )

    def _on_reject(self, asset_id: int) -> None:
        self._change_asset_status(
            asset_id, AssetStatus.REJECTED, "Reject asset"
        )

    def _change_asset_status(
        self,
        asset_id: int,
        new_status: AssetStatus,
        label: str,
    ) -> None:
        """Persist a status change and push it onto the undo stack."""
        asset = self.controller.assets.get_by_id(asset_id)
        if asset is None:
            return
        old_status = asset.status
        if old_status == new_status:
            return
        self._asset_ctrl.set_status(asset_id, new_status)
        self._record_status_change(
            asset_id, old_status, new_status, label, asset.name
        )

    def _record_status_change(
        self,
        asset_id: int,
        old_status: AssetStatus,
        new_status: AssetStatus,
        label: str,
        display_name: str,
    ) -> None:
        """Push a reversible status mutation onto the undo/redo stack."""
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            self.workspace.workspace_refresh.emit()
            return
        ctrl = self._asset_ctrl
        manager.record(
            label,
            undo=lambda: ctrl.set_status(asset_id, old_status),
            redo=lambda: ctrl.set_status(asset_id, new_status),
            context=display_name,
        )
        self.workspace.workspace_refresh.emit()

    def _on_delete(self, asset_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete Asset",
            f"Delete '{name}' permanently?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._asset_ctrl.delete_asset(asset_id)
            self.workspace.workspace_refresh.emit()

    def _on_import(self) -> None:
        if not self.workspace.project_id:
            return
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Import Asset",
            "",
            "Images (*.png *.jpg *.jpeg *.webp *.bmp)",
        )
        if not file_path:
            return
        name, ok = QInputDialog.getText(
            self,
            "Asset Name",
            "Name for this asset:",
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

        # Build the combined list for the picker dialog
        all_col_names: List[str] = list(self._known_collections)
        for c in collect_all_collections(self._all_assets):
            if c.lower() not in {x.lower() for x in all_col_names}:
                all_col_names.append(c)
        all_col_names.sort(key=str.lower)

        name, ok = QInputDialog.getItem(
            self,
            "Assign to Collection",
            f"Add {len(selected_rows)} asset(s) to collection:",
            all_col_names,
            editable=True,
        )
        if not ok or not name.strip():
            return
        name = name.strip()

        snapshots: List[tuple[int, List[str]]] = []
        for row in selected_rows:
            if 0 <= row < len(self._assets):
                asset = self._assets[row]
                current_cols = get_collections(asset)
                if name.lower() not in {c.lower() for c in current_cols}:
                    snapshots.append((asset.id, list(current_cols)))
                    set_collections(asset, current_cols + [name])
                    self._asset_ctrl.update_asset(asset)
                else:
                    snapshots.append((asset.id, list(current_cols)))

        if name.lower() not in {c.lower() for c in self._known_collections}:
            self._known_collections.append(name)

        affected = sum(1 for aid, _ in snapshots if aid is not None)
        if affected:
            self._record_collection_bulk_assign(snapshots, name)

        self.workspace.workspace_refresh.emit()

    def _record_collection_bulk_assign(
        self,
        snapshots: List[tuple],
        added_name: str,
    ) -> None:
        """Push a reversible bulk collection-add onto the undo/redo stack.

        ``snapshots`` is ``[(asset_id, old_collections_list), …]`` captured
        *before* the mutation.  Undo restores each asset's prior collection
        list; redo re-applies the addition.
        """
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None or not snapshots:
            return

        repo = self.controller.assets
        snap = [
            (aid, list(cols))
            for aid, cols in snapshots
            if aid is not None
        ]
        if not snap:
            return
        added = added_name

        def _undo() -> None:
            for aid, old_cols in snap:
                inst = repo.get_by_id(aid)
                if inst is None:
                    continue
                set_collections(inst, list(old_cols))
                repo.update(inst)

        def _redo() -> None:
            for aid, _old in snap:
                inst = repo.get_by_id(aid)
                if inst is None:
                    continue
                current = get_collections(inst)
                if any(c.lower() == added.lower() for c in current):
                    continue
                set_collections(inst, current + [added])
                repo.update(inst)

        manager.record(
            f"Assign {len(snap)} asset(s) to collection",
            undo=_undo,
            redo=_redo,
            context=added,
        )

    # ── Collection management ──────────────────────────────────────────────────

    def _on_new_collection(self) -> None:
        name, ok = QInputDialog.getText(
            self, "New Collection", "Collection name:"
        )
        if not ok or not name.strip():
            return
        name = name.strip()
        if name.lower() not in {c.lower() for c in self._known_collections}:
            self._known_collections.append(name)
        self._sidebar.rebuild(self._known_collections, self._collection_filter)

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
                new_name if c.lower() == old_name.lower() else c
                for c in cols
            ]
            if updated != cols:
                set_collections(asset, updated)
                self._asset_ctrl.update_asset(asset)

        if (
            self._collection_filter
            and self._collection_filter.lower() == old_name.lower()
        ):
            self._collection_filter = new_name

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
            self._collection_filter
            and self._collection_filter.lower() == name.lower()
        ):
            self._collection_filter = None

        self._known_collections = [
            c for c in self._known_collections if c.lower() != name.lower()
        ]
        self.workspace.workspace_refresh.emit()
