"""Book Builder tab within the project workspace."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PySide6.QtCore import QMimeData, QSize, Qt, QTimer
from PySide6.QtGui import QDrag, QIcon, QPixmap
from PySide6.QtWidgets import (
    QAbstractItemView,
    QComboBox,
    QFileDialog,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QSizePolicy,
    QStackedWidget,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import Asset
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


@dataclass(slots=True)
class BookPage:
    """In-memory page entry for the future Book Builder workflow."""

    asset_id: int
    page_number: int


class _AssetGrid(QListWidget):
    """Thumbnail list that drags selected asset ids as one payload."""

    MIME_TYPE = "application/x-magicfactory-asset-ids"

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setDragEnabled(True)
        self.setDefaultDropAction(Qt.DropAction.CopyAction)

    def startDrag(self, supported_actions: Qt.DropAction) -> None:
        ids = [
            str(item.data(Qt.ItemDataRole.UserRole))
            for item in self.selectedItems()
            if item.data(Qt.ItemDataRole.UserRole) is not None
        ]
        if not ids:
            return

        mime = QMimeData()
        mime.setData(self.MIME_TYPE, ",".join(ids).encode("utf-8"))

        drag = QDrag(self)
        drag.setMimeData(mime)

        first_icon = self.selectedItems()[0].icon()
        if not first_icon.isNull():
            drag.setPixmap(first_icon.pixmap(QSize(96, 96)))

        drag.exec(Qt.DropAction.CopyAction)


class _BookPagesList(QListWidget):
    """Page list that accepts assets and supports in-book reordering."""

    def __init__(
        self,
        on_assets_dropped,
        on_pages_reordered,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._on_assets_dropped = on_assets_dropped
        self._on_pages_reordered = on_pages_reordered
        self.setAcceptDrops(True)
        self.setDragEnabled(True)
        self.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.setDefaultDropAction(Qt.DropAction.MoveAction)
        self.setDropIndicatorShown(True)
        self.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.setSpacing(10)
        self.setStyleSheet(f"""
            QListWidget {{
                background-color: transparent;
                border: none;
            }}
            QListWidget::item {{
                background-color: transparent;
                border: none;
            }}
        """)
        self.model().rowsMoved.connect(lambda *_: self._on_pages_reordered())

    def dragEnterEvent(self, event) -> None:
        if event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            event.acceptProposedAction()
        else:
            super().dragEnterEvent(event)

    def dragMoveEvent(self, event) -> None:
        if event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            event.acceptProposedAction()
        else:
            super().dragMoveEvent(event)

    def dropEvent(self, event) -> None:
        if not event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            super().dropEvent(event)
            return

        raw_ids = bytes(event.mimeData().data(_AssetGrid.MIME_TYPE)).decode("utf-8")
        asset_ids = [int(value) for value in raw_ids.split(",") if value]
        self._on_assets_dropped(asset_ids)
        event.acceptProposedAction()


class _BookPagesPlaceholder(QLabel):
    """Empty-state label that accepts the first asset drop."""

    def __init__(self, on_assets_dropped, text: str, parent: QWidget | None = None) -> None:
        super().__init__(text, parent)
        self._on_assets_dropped = on_assets_dropped
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event) -> None:
        if event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event) -> None:
        if event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event) -> None:
        if not event.mimeData().hasFormat(_AssetGrid.MIME_TYPE):
            event.ignore()
            return

        raw_ids = bytes(event.mimeData().data(_AssetGrid.MIME_TYPE)).decode("utf-8")
        asset_ids = [int(value) for value in raw_ids.split(",") if value]
        self._on_assets_dropped(asset_ids)
        event.acceptProposedAction()


class _PreviewImageLabel(QLabel):
    """Fills the available space and keeps the image aspect ratio correct."""

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._source: QPixmap | None = None
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Expanding,
        )
        self.setMinimumSize(100, 100)

    def set_source(self, pixmap: QPixmap | None) -> None:
        self._source = pixmap
        self._repaint_scaled()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._repaint_scaled()

    def _repaint_scaled(self) -> None:
        if self._source is None or self._source.isNull():
            self.setPixmap(QPixmap())
            self.setText("No image available")
            return
        self.setText("")
        scaled = self._source.scaled(
            self.size(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )
        self.setPixmap(scaled)


class BookBuilderTab(WorkspaceTabBase):
    """Foundation UI for arranging assets into coloring book pages."""

    def _build_ui(self) -> None:
        self._asset_ctrl = AssetController(self.controller)
        self._assets: list[Asset] = []
        self._book_pages: list[BookPage] = []
        self._preview_index: int = 0
        self._dirty: bool = False

        # ── Internal sub-tabs: Book Pages | Cover ─────────────────────────
        self._inner_tabs = QTabWidget()
        self._inner_tabs.setDocumentMode(True)

        # ── Sub-tab 0: Book Pages ──────────────────────────────────────────
        book_pages_widget = QWidget()
        book_pages_widget.setStyleSheet("background: transparent;")
        bp_layout = QVBoxLayout(book_pages_widget)
        bp_layout.setContentsMargins(0, 8, 0, 0)
        bp_layout.setSpacing(12)

        bp_layout.addWidget(self._build_book_properties_panel())
        bp_layout.addLayout(self._build_mode_toggle())

        self._mode_stack = QStackedWidget()

        editor_widget = QWidget()
        editor_widget.setStyleSheet("background: transparent;")
        editor_layout = QHBoxLayout(editor_widget)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(16)
        editor_layout.addWidget(self._build_assets_panel(), stretch=1)
        editor_layout.addWidget(self._build_pages_panel(), stretch=1)
        self._mode_stack.addWidget(editor_widget)           # index 0

        self._mode_stack.addWidget(self._build_preview_panel())  # index 1

        bp_layout.addWidget(self._mode_stack, stretch=1)
        self._inner_tabs.addTab(book_pages_widget, "📄  Book Pages")

        # ── Sub-tab 1: Cover ───────────────────────────────────────────────
        self._inner_tabs.addTab(self._build_cover_tab(), "🎨  Cover")

        self._layout.addWidget(self._inner_tabs, stretch=1)

        # ── Auto-save / crash-recovery setup ──────────────────────────────
        self._applying_recovery: bool = False
        # Register with the workspace so the 60-second timer can pull our
        # current draft state on tick, and so a recovered snapshot can be
        # applied back onto our widgets. The workspace itself already
        # guards against missing widgets via _applying_recovery.

        for _w in (
            self._book_title, self._book_subtitle,
            self._book_author, self._book_language, self._book_age,
        ):
            _w.textChanged.connect(self._mark_dirty)
        for _w in (self._book_interior, self._book_paper, self._book_margin):
            _w.currentTextChanged.connect(self._mark_dirty)
        for _w in (self._cover_title, self._cover_subtitle, self._cover_author):
            _w.textChanged.connect(self._mark_dirty)
        self._cover_asset_combo.currentIndexChanged.connect(self._mark_dirty)

        # Single 60-second auto-save timer lives in WorkspaceController so all
        # tabs participate in one global cycle.

        # Wire this tab's draft-capture and restore callbacks so the workspace
        # auto-save timer and crash-recovery flow can snapshot and replay the
        # current book + cover state.
        self.workspace.register_recovery_section(
            "book", self._collect_book_recovery_draft
        )
        self.workspace.register_recovery_apply(
            "book", self._apply_book_recovery_draft
        )

    # ── Book Properties ──────────────────────────────────────────────────────

    def _build_book_properties_panel(self) -> QFrame:
        """Collapsible in-memory Book Properties panel (no persistence)."""

        outer = QFrame()
        outer.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        outer_layout = QVBoxLayout(outer)
        outer_layout.setContentsMargins(20, 14, 20, 16)
        outer_layout.setSpacing(12)

        # ── Header row ──────────────────────────────────────────────────────
        header_row = QHBoxLayout()
        header_row.setSpacing(8)

        icon = QLabel("📖")
        icon.setStyleSheet(
            "font-size: 15px; border: none; background: transparent;"
        )
        header_row.addWidget(icon)

        title = QLabel("Book Properties")
        title.setStyleSheet(
            f"font-size: 15px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
            " border: none; background: transparent;"
        )
        header_row.addWidget(title)
        header_row.addStretch()

        self._props_toggle_btn = QPushButton("▼")
        self._props_toggle_btn.setProperty("cssClass", "ghost")
        self._props_toggle_btn.setFixedSize(28, 28)
        self._props_toggle_btn.setToolTip("Collapse / Expand")
        self._props_toggle_btn.clicked.connect(self._toggle_book_properties)
        header_row.addWidget(self._props_toggle_btn)

        outer_layout.addLayout(header_row)

        # ── Collapsible content ──────────────────────────────────────────────
        self._props_content = QFrame()
        self._props_content.setStyleSheet(
            "QFrame { border: none; background: transparent; }"
        )

        grid = QGridLayout(self._props_content)
        grid.setContentsMargins(0, 2, 0, 0)
        grid.setHorizontalSpacing(16)
        grid.setVerticalSpacing(4)
        for col in range(4):
            grid.setColumnStretch(col, 1)

        _label_style = (
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; font-weight: 500;"
            " border: none; background: transparent;"
        )

        # Two rows of 4 fields each
        field_rows: list[list[tuple]] = [
            [
                ("Book Title",    "_book_title",    "line",  "Enter title…"),
                ("Subtitle",      "_book_subtitle", "line",  "Enter subtitle…"),
                ("Author",        "_book_author",   "line",  "Enter author…"),
                ("Language",      "_book_language", "line",  "e.g. English"),
            ],
            [
                ("Interior Type", "_book_interior", "combo",
                 ["Black & White", "Premium Color"]),
                ("Paper Size",    "_book_paper",    "combo",
                 ["8.5 x 11", "A4", "6 x 9"]),
                ("Margin Preset", "_book_margin",   "combo",
                 ["Standard", "KDP"]),
                ("Target Age",    "_book_age",      "line",  "e.g. 3–6"),
            ],
        ]

        grid_row = 0
        for row_fields in field_rows:
            for col_idx, (lbl_text, attr, wtype, spec) in enumerate(row_fields):
                lbl = QLabel(lbl_text)
                lbl.setStyleSheet(_label_style)
                grid.addWidget(lbl, grid_row, col_idx)

                if wtype == "line":
                    widget: QWidget = QLineEdit()
                    widget.setPlaceholderText(spec)  # type: ignore[attr-defined]
                else:
                    widget = QComboBox()
                    for opt in spec:
                        widget.addItem(opt)  # type: ignore[attr-defined]

                setattr(self, attr, widget)
                grid.addWidget(widget, grid_row + 1, col_idx)

            grid_row += 2

        # Number of Pages — read-only, auto-updated
        pages_lbl = QLabel("Number of Pages")
        pages_lbl.setStyleSheet(_label_style)
        grid.addWidget(pages_lbl, grid_row, 0)

        self._props_page_count = QLabel("0")
        self._props_page_count.setStyleSheet(f"""
            color: {Colors.TEXT_SECONDARY};
            background-color: {Colors.SURFACE_LIGHT};
            border: 1px solid {Colors.BORDER};
            border-radius: 8px;
            padding: 7px 12px;
            font-size: 13px;
        """)
        grid.addWidget(self._props_page_count, grid_row + 1, 0)

        outer_layout.addWidget(self._props_content)
        return outer

    def _toggle_book_properties(self) -> None:
        """Collapse or expand the Book Properties form."""
        visible = self._props_content.isVisible()
        self._props_content.setVisible(not visible)
        self._props_toggle_btn.setText("▶" if visible else "▼")

    # ── Mode toggle ───────────────────────────────────────────────────────────

    def _build_mode_toggle(self) -> QHBoxLayout:
        row = QHBoxLayout()
        row.setSpacing(4)
        row.setContentsMargins(0, 0, 0, 0)

        self._btn_editor = QPushButton("✏️   Book Editor")
        self._btn_editor.setProperty("cssClass", "primary")
        self._btn_editor.setFixedHeight(34)
        self._btn_editor.clicked.connect(self._show_editor_mode)

        self._btn_preview = QPushButton("👁   Live Preview")
        self._btn_preview.setProperty("cssClass", "ghost")
        self._btn_preview.setFixedHeight(34)
        self._btn_preview.clicked.connect(self._show_preview_mode)

        row.addWidget(self._btn_editor)
        row.addWidget(self._btn_preview)
        row.addStretch()

        self._btn_save = QPushButton("💾   Save Book")
        self._btn_save.setProperty("cssClass", "ghost")
        self._btn_save.setFixedHeight(34)
        self._btn_save.clicked.connect(self._save_book)

        self._btn_open = QPushButton("📂   Open Book")
        self._btn_open.setProperty("cssClass", "ghost")
        self._btn_open.setFixedHeight(34)
        self._btn_open.clicked.connect(self._open_book)

        self._btn_export_pdf = QPushButton("📄   Export PDF")
        self._btn_export_pdf.setProperty("cssClass", "ghost")
        self._btn_export_pdf.setFixedHeight(34)
        self._btn_export_pdf.clicked.connect(self._export_pdf)

        self._btn_preview_pdf = QPushButton("🔍   Preview PDF")
        self._btn_preview_pdf.setProperty("cssClass", "ghost")
        self._btn_preview_pdf.setFixedHeight(34)
        self._btn_preview_pdf.clicked.connect(self._preview_pdf)

        self._btn_kdp_export = QPushButton("📦   KDP Export")
        self._btn_kdp_export.setProperty("cssClass", "ghost")
        self._btn_kdp_export.setFixedHeight(34)
        self._btn_kdp_export.clicked.connect(self._kdp_export)

        row.addWidget(self._btn_save)
        row.addWidget(self._btn_open)
        row.addWidget(self._btn_export_pdf)
        row.addWidget(self._btn_preview_pdf)
        row.addWidget(self._btn_kdp_export)
        return row

    def _show_editor_mode(self) -> None:
        self._mode_stack.setCurrentIndex(0)
        self._btn_editor.setProperty("cssClass", "primary")
        self._btn_preview.setProperty("cssClass", "ghost")
        for btn in (self._btn_editor, self._btn_preview):
            btn.style().unpolish(btn)
            btn.style().polish(btn)

    def _show_preview_mode(self) -> None:
        self._mode_stack.setCurrentIndex(1)
        self._btn_editor.setProperty("cssClass", "ghost")
        self._btn_preview.setProperty("cssClass", "primary")
        for btn in (self._btn_editor, self._btn_preview):
            btn.style().unpolish(btn)
            btn.style().polish(btn)
        self._refresh_preview()

    # ── Live Preview panel ────────────────────────────────────────────────────

    def _build_preview_panel(self) -> QFrame:
        panel = QFrame()
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(20, 18, 20, 20)
        layout.setSpacing(12)

        # Navigation bar
        nav = QHBoxLayout()
        nav.setSpacing(8)

        self._prev_btn = QPushButton("← Previous")
        self._prev_btn.setProperty("cssClass", "ghost")
        self._prev_btn.setFixedWidth(120)
        self._prev_btn.setEnabled(False)
        self._prev_btn.clicked.connect(self._preview_prev)
        nav.addWidget(self._prev_btn)

        nav.addStretch()

        self._preview_page_label = QLabel("Page 0 of 0")
        self._preview_page_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._preview_page_label.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 14px; font-weight: 600;"
            " border: none; background: transparent;"
        )
        nav.addWidget(self._preview_page_label)

        nav.addStretch()

        self._next_btn = QPushButton("Next →")
        self._next_btn.setProperty("cssClass", "ghost")
        self._next_btn.setFixedWidth(120)
        self._next_btn.setEnabled(False)
        self._next_btn.clicked.connect(self._preview_next)
        nav.addWidget(self._next_btn)

        layout.addLayout(nav)

        # Image display
        self._preview_image = _PreviewImageLabel()
        self._preview_image.setStyleSheet(f"""
            background-color: {Colors.BACKGROUND};
            border: 1px solid {Colors.BORDER};
            border-radius: 8px;
            color: {Colors.TEXT_MUTED};
            font-size: 14px;
        """)
        layout.addWidget(self._preview_image, stretch=1)

        return panel

    def _preview_prev(self) -> None:
        if self._preview_index > 0:
            self._preview_index -= 1
            self._refresh_preview()

    def _preview_next(self) -> None:
        if self._preview_index < len(self._book_pages) - 1:
            self._preview_index += 1
            self._refresh_preview()

    def _refresh_preview(self) -> None:
        """Sync the Live Preview panel with current book state."""
        if not hasattr(self, "_preview_image"):
            return

        total = len(self._book_pages)

        # Clamp index
        self._preview_index = (
            max(0, min(self._preview_index, total - 1)) if total else 0
        )

        if total == 0:
            self._preview_page_label.setText("Page 0 of 0")
            self._preview_image.set_source(None)
            self._prev_btn.setEnabled(False)
            self._next_btn.setEnabled(False)
            return

        self._preview_page_label.setText(
            f"Page {self._preview_index + 1} of {total}"
        )
        self._prev_btn.setEnabled(self._preview_index > 0)
        self._next_btn.setEnabled(self._preview_index < total - 1)

        page = self._book_pages[self._preview_index]
        asset_map = {a.id: a for a in self._assets if a.id is not None}
        asset = asset_map.get(page.asset_id)
        if asset is None:
            self._preview_image.set_source(None)
            return

        pixmap: QPixmap | None = None
        for path_str in (asset.file_path, asset.thumbnail_path):
            if not path_str:
                continue
            p = Path(path_str)
            if not p.exists():
                continue
            px = QPixmap(str(p))
            if not px.isNull():
                pixmap = px
                break

        self._preview_image.set_source(pixmap)

    # ── Save / Open ───────────────────────────────────────────────────────────

    def _collect_properties(self) -> dict:
        """Read all Book Properties widgets into a plain dict."""
        return {
            "title": self._book_title.text(),
            "subtitle": self._book_subtitle.text(),
            "author": self._book_author.text(),
            "language": self._book_language.text(),
            "interior_type": self._book_interior.currentText(),
            "paper_size": self._book_paper.currentText(),
            "margin_preset": self._book_margin.currentText(),
            "target_age": self._book_age.text(),
        }

    def _apply_properties(self, props: dict) -> None:
        """Restore Book Properties widgets from a dict."""
        self._book_title.setText(props.get("title", ""))
        self._book_subtitle.setText(props.get("subtitle", ""))
        self._book_author.setText(props.get("author", ""))
        self._book_language.setText(props.get("language", ""))
        self._book_age.setText(props.get("target_age", ""))

        def _set_combo(combo: QComboBox, value: str) -> None:
            idx = combo.findText(value)
            if idx >= 0:
                combo.setCurrentIndex(idx)

        _set_combo(self._book_interior, props.get("interior_type", ""))
        _set_combo(self._book_paper, props.get("paper_size", ""))
        _set_combo(self._book_margin, props.get("margin_preset", ""))

    def _save_book(self) -> None:
        """Serialize book properties + page order to a JSON file."""
        path, _ = QFileDialog.getSaveFileName(
            self,
            "Save Book",
            "",
            "Book Files (*.json);;All Files (*)",
        )
        if not path:
            return

        data = {
            "version": 1,
            "properties": self._collect_properties(),
            "pages": [
                {"asset_id": p.asset_id, "page_number": p.page_number}
                for p in self._book_pages
            ],
        }

        try:
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(data, fh, indent=2, ensure_ascii=False)
            QMessageBox.information(
                self, "Save Book", "Book saved successfully."
            )
        except Exception as exc:
            QMessageBox.critical(self, "Save Error", str(exc))

    def _open_book(self) -> None:
        """Restore book properties + pages from a JSON file."""
        path, _ = QFileDialog.getOpenFileName(
            self,
            "Open Book",
            "",
            "Book Files (*.json);;All Files (*)",
        )
        if not path:
            return

        try:
            with open(path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception as exc:
            QMessageBox.critical(
                self, "Open Error", f"Failed to read file:\n{exc}"
            )
            return

        # Restore properties
        self._apply_properties(data.get("properties", {}))

        # Restore pages — skip any asset_id not in the current project
        known_ids = {a.id for a in self._assets if a.id is not None}
        self._book_pages = []
        skipped = 0
        for entry in data.get("pages", []):
            asset_id = entry.get("asset_id")
            page_number = entry.get("page_number", 0)
            if asset_id in known_ids:
                self._book_pages.append(
                    BookPage(asset_id=asset_id, page_number=page_number)
                )
            else:
                skipped += 1

        self._render_book_pages()
        self._show_editor_mode()
        self._mark_dirty()

        if skipped:
            QMessageBox.warning(
                self,
                "Open Book",
                f"Book loaded. {skipped} page(s) could not be restored "
                "because their assets are not in this project.",
            )

    def _kdp_export(self) -> None:
        """Open the Amazon KDP Export Wizard."""
        # ── Collect content image paths ───────────────────────────────────
        asset_map = {a.id: a for a in self._assets if a.id is not None}
        image_paths: list[str] = []
        for page in self._book_pages:
            asset = asset_map.get(page.asset_id)
            if asset is None:
                continue
            for path_str in (asset.file_path, asset.thumbnail_path):
                if path_str and Path(path_str).exists():
                    image_paths.append(path_str)
                    break

        # ── Cover from Cover Builder ───────────────────────────────────────
        cover_path: str | None = None
        if hasattr(self, "_cover_asset_combo"):
            cover_id = self._cover_asset_combo.currentData()
            if cover_id is not None:
                ca = asset_map.get(cover_id)
                if ca:
                    for p in (ca.file_path, ca.thumbnail_path):
                        if p and Path(p).exists():
                            cover_path = p
                            break

        from ui.widgets.workspace.tabs.kdp_export_wizard import KDPExportWizard
        wizard = KDPExportWizard(
            image_paths=image_paths,
            cover_path=cover_path,
            book_properties=self._collect_properties(),
            parent=self,
        )
        wizard.exec()

    def _preview_pdf(self) -> None:
        """Open the Print Preview dialog using the same rendering as BookPDFExporter."""
        if not self._book_pages:
            QMessageBox.warning(
                self, "Preview PDF", "Add at least one page before previewing."
            )
            return

        # ── Collect content image paths ───────────────────────────────────
        asset_map = {a.id: a for a in self._assets if a.id is not None}
        image_paths: list[str] = []
        for page in self._book_pages:
            asset = asset_map.get(page.asset_id)
            if asset is None:
                continue
            for path_str in (asset.file_path, asset.thumbnail_path):
                if path_str and Path(path_str).exists():
                    image_paths.append(path_str)
                    break

        # ── Cover from Cover Builder ───────────────────────────────────────
        cover_path: str | None = None
        if hasattr(self, "_cover_asset_combo"):
            cover_id = self._cover_asset_combo.currentData()
            if cover_id is not None:
                ca = asset_map.get(cover_id)
                if ca:
                    for p in (ca.file_path, ca.thumbnail_path):
                        if p and Path(p).exists():
                            cover_path = p
                            break

        if not image_paths and cover_path is None:
            QMessageBox.warning(
                self,
                "Preview PDF",
                "None of the book pages have a valid image file on disk.",
            )
            return

        # ── Book Properties ────────────────────────────────────────────────
        paper_size = (
            self._book_paper.currentText()
            if hasattr(self, "_book_paper") else "8.5 x 11"
        )
        margin_preset = (
            self._book_margin.currentText()
            if hasattr(self, "_book_margin") else "Standard"
        )

        from ui.widgets.workspace.tabs.pdf_preview_dialog import PDFPreviewDialog
        dlg = PDFPreviewDialog(
            image_paths=image_paths,
            cover_path=cover_path,
            page_size_name=paper_size,
            margin_preset=margin_preset,
            show_page_numbers=True,
            parent=self,
        )
        dlg.exec()

    def _export_pdf(self) -> None:
        """Export the current book pages as a PDF file."""
        if not self._book_pages:
            QMessageBox.warning(
                self, "Export PDF", "Add at least one page before exporting."
            )
            return

        path, _ = QFileDialog.getSaveFileName(
            self,
            "Export PDF",
            "",
            "PDF Files (*.pdf);;All Files (*)",
        )
        if not path:
            return

        # ── Collect ordered content-page image paths ──────────────────────
        asset_map = {a.id: a for a in self._assets if a.id is not None}
        image_paths: list[str] = []
        for page in self._book_pages:
            asset = asset_map.get(page.asset_id)
            if asset is None:
                continue
            for path_str in (asset.file_path, asset.thumbnail_path):
                if path_str and Path(path_str).exists():
                    image_paths.append(path_str)
                    break

        if not image_paths:
            QMessageBox.warning(
                self,
                "Export PDF",
                "None of the book pages have a valid image file on disk.",
            )
            return

        # ── Cover image from Cover Builder tab ────────────────────────────
        cover_path: str | None = None
        if hasattr(self, "_cover_asset_combo"):
            cover_asset_id = self._cover_asset_combo.currentData()
            if cover_asset_id is not None:
                cover_asset = asset_map.get(cover_asset_id)
                if cover_asset:
                    for p in (cover_asset.file_path, cover_asset.thumbnail_path):
                        if p and Path(p).exists():
                            cover_path = p
                            break

        # ── Book Properties → paper size & margin preset ──────────────────
        paper_size = (
            self._book_paper.currentText()
            if hasattr(self, "_book_paper")
            else "8.5 x 11"
        )
        margin_preset = (
            self._book_margin.currentText()
            if hasattr(self, "_book_margin")
            else "Standard"
        )

        try:
            from engine.export.pdf_exporter import BookPDFExporter
            exporter = BookPDFExporter(
                page_size_name=paper_size,
                margin_preset=margin_preset,
            )
            exporter.export(
                image_paths,
                path,
                cover_path=cover_path,
                show_page_numbers=True,
            )
            QMessageBox.information(
                self,
                "Export PDF",
                f"PDF exported successfully:\n{path}",
            )
        except Exception as exc:
            QMessageBox.critical(self, "Export Error", str(exc))

    # ── Cover Builder ─────────────────────────────────────────────────────────

    def _build_cover_tab(self) -> QWidget:
        """Two-column panel: form on the left, live cover preview on the right."""
        root = QWidget()
        root.setStyleSheet("background: transparent;")
        root_layout = QHBoxLayout(root)
        root_layout.setContentsMargins(0, 8, 0, 0)
        root_layout.setSpacing(16)

        root_layout.addWidget(self._build_cover_form(), stretch=0)
        root_layout.addWidget(self._build_cover_preview_panel(), stretch=1)
        return root

    def _build_cover_form(self) -> QFrame:
        form = QFrame()
        form.setFixedWidth(280)
        form.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(form)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QLabel("Cover Details")
        header.setStyleSheet(
            f"font-size: 15px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
            " border: none; background: transparent;"
        )
        layout.addWidget(header)

        _lbl = (
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; font-weight: 500;"
            " border: none; background: transparent;"
        )

        for attr, label, placeholder in (
            ("_cover_title",    "Title",    "Enter book title…"),
            ("_cover_subtitle", "Subtitle", "Enter subtitle…"),
            ("_cover_author",   "Author",   "Enter author name…"),
        ):
            lbl = QLabel(label)
            lbl.setStyleSheet(_lbl)
            layout.addWidget(lbl)

            field = QLineEdit()
            field.setPlaceholderText(placeholder)
            field.textChanged.connect(self._render_cover_preview)
            setattr(self, attr, field)
            layout.addWidget(field)

        # Separator
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet(f"border: none; border-top: 1px solid {Colors.BORDER};")
        sep.setFixedHeight(1)
        layout.addWidget(sep)

        cover_img_lbl = QLabel("Cover Image")
        cover_img_lbl.setStyleSheet(_lbl)
        layout.addWidget(cover_img_lbl)

        self._cover_asset_combo = QComboBox()
        self._cover_asset_combo.addItem("— No image —", None)
        self._cover_asset_combo.currentIndexChanged.connect(
            self._render_cover_preview
        )
        layout.addWidget(self._cover_asset_combo)

        layout.addStretch()
        return form

    def _build_cover_preview_panel(self) -> QFrame:
        panel = QFrame()
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(20, 18, 20, 20)
        layout.setSpacing(12)

        header = QLabel("Front Cover Preview")
        header.setStyleSheet(
            f"font-size: 15px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
            " border: none; background: transparent;"
        )
        layout.addWidget(header)

        # Image area (reuse existing auto-scaling label)
        self._cover_image = _PreviewImageLabel()
        self._cover_image.setStyleSheet(f"""
            background-color: {Colors.BACKGROUND};
            border: 1px solid {Colors.BORDER};
            border-radius: 8px;
            color: {Colors.TEXT_MUTED};
            font-size: 14px;
        """)
        layout.addWidget(self._cover_image, stretch=1)

        # Text strip below image
        text_strip = QFrame()
        text_strip.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.BACKGROUND};
                border: 1px solid {Colors.BORDER};
                border-radius: 8px;
            }}
        """)
        text_layout = QVBoxLayout(text_strip)
        text_layout.setContentsMargins(16, 12, 16, 12)
        text_layout.setSpacing(4)

        self._cover_preview_title = QLabel("")
        self._cover_preview_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._cover_preview_title.setWordWrap(True)
        self._cover_preview_title.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 16px; font-weight: 700;"
            " border: none; background: transparent;"
        )

        self._cover_preview_subtitle = QLabel("")
        self._cover_preview_subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._cover_preview_subtitle.setWordWrap(True)
        self._cover_preview_subtitle.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 13px; font-style: italic;"
            " border: none; background: transparent;"
        )

        self._cover_preview_author = QLabel("")
        self._cover_preview_author.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._cover_preview_author.setWordWrap(True)
        self._cover_preview_author.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 12px;"
            " border: none; background: transparent;"
        )

        text_layout.addWidget(self._cover_preview_title)
        text_layout.addWidget(self._cover_preview_subtitle)
        text_layout.addWidget(self._cover_preview_author)

        layout.addWidget(text_strip)
        return panel

    def _refresh_cover_assets(self) -> None:
        """Repopulate the cover image combo from the current asset list."""
        if not hasattr(self, "_cover_asset_combo"):
            return
        current_id = self._cover_asset_combo.currentData()
        self._cover_asset_combo.blockSignals(True)
        self._cover_asset_combo.clear()
        self._cover_asset_combo.addItem("— No image —", None)
        for asset in self._assets:
            self._cover_asset_combo.addItem(asset.name, asset.id)
        idx = self._cover_asset_combo.findData(current_id)
        self._cover_asset_combo.setCurrentIndex(idx if idx >= 0 else 0)
        self._cover_asset_combo.blockSignals(False)
        self._render_cover_preview()

    def _render_cover_preview(self) -> None:
        """Update live cover preview from current form values."""
        if not hasattr(self, "_cover_image"):
            return

        # Text strip
        self._cover_preview_title.setText(
            getattr(self, "_cover_title", None) and self._cover_title.text() or ""
        )
        self._cover_preview_subtitle.setText(
            getattr(self, "_cover_subtitle", None) and self._cover_subtitle.text() or ""
        )
        self._cover_preview_author.setText(
            getattr(self, "_cover_author", None) and self._cover_author.text() or ""
        )

        # Cover image
        asset_id = self._cover_asset_combo.currentData()
        if asset_id is None:
            self._cover_image.set_source(None)
            return

        asset_map = {a.id: a for a in self._assets if a.id is not None}
        asset = asset_map.get(asset_id)
        if asset is None:
            self._cover_image.set_source(None)
            return

        pixmap: QPixmap | None = None
        for path_str in (asset.file_path, asset.thumbnail_path):
            if not path_str:
                continue
            p = Path(path_str)
            if not p.exists():
                continue
            px = QPixmap(str(p))
            if not px.isNull():
                pixmap = px
                break

        self._cover_image.set_source(pixmap)

    # ── Asset panel ───────────────────────────────────────────────────────────

    def _build_assets_panel(self) -> QFrame:
        panel = QFrame()
        panel.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(20, 18, 20, 20)
        layout.setSpacing(12)

        title = QLabel("Available Assets")
        title.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
        )
        layout.addWidget(title)

        self._search = QLineEdit()
        self._search.setPlaceholderText("Search assets...")
        self._search.setClearButtonEnabled(True)
        self._search.textChanged.connect(self._apply_filters)
        layout.addWidget(self._search)

        self._category_filter = QComboBox()
        self._category_filter.currentIndexChanged.connect(self._apply_filters)
        layout.addWidget(self._category_filter)

        self._asset_grid = _AssetGrid()
        self._asset_grid.setViewMode(QListWidget.ViewMode.IconMode)
        self._asset_grid.setResizeMode(QListWidget.ResizeMode.Adjust)
        self._asset_grid.setMovement(QListWidget.Movement.Static)
        self._asset_grid.setSelectionMode(QListWidget.SelectionMode.MultiSelection)
        self._asset_grid.setIconSize(QSize(132, 132))
        self._asset_grid.setGridSize(QSize(156, 186))
        self._asset_grid.setSpacing(10)
        self._asset_grid.setWordWrap(True)
        layout.addWidget(self._asset_grid, stretch=1)

        return panel

    def _build_pages_panel(self) -> QFrame:
        panel = QFrame()
        panel.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        panel.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(20, 18, 20, 20)
        layout.setSpacing(12)

        header = QHBoxLayout()
        title = QLabel("Book Pages")
        title.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
        )
        header.addWidget(title)
        header.addStretch()

        self._total_pages_label = QLabel("Total Pages: 0")
        self._total_pages_label.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
        )
        header.addWidget(self._total_pages_label)

        self._estimated_size_label = QLabel("Estimated Book Size: 0 Pages")
        self._estimated_size_label.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
        )
        header.addWidget(self._estimated_size_label)

        _btn_new = QPushButton("New Book")
        _btn_new.setProperty("cssClass", "ghost")
        _btn_new.clicked.connect(self._on_new_book)
        header.addWidget(_btn_new)

        _btn_clear = QPushButton("Clear Book")
        _btn_clear.setProperty("cssClass", "ghost")
        _btn_clear.clicked.connect(self._on_clear_book)
        header.addWidget(_btn_clear)

        _btn_autonumber = QPushButton("Auto Number Pages")
        _btn_autonumber.setProperty("cssClass", "ghost")
        _btn_autonumber.clicked.connect(self._on_auto_number_pages)
        header.addWidget(_btn_autonumber)

        layout.addLayout(header)

        self._pages_list = _BookPagesList(
            self._on_assets_dropped,
            self._on_pages_reordered,
        )
        self._pages_list.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Expanding,
        )

        self._placeholder = _BookPagesPlaceholder(
            self._on_assets_dropped,
            "Drag images here to create your coloring book.",
        )
        self._placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._placeholder.setWordWrap(True)
        self._placeholder.setStyleSheet(
            f"""
            color: {Colors.TEXT_MUTED};
            border: 1px dashed {Colors.BORDER_LIGHT};
            border-radius: 8px;
            padding: 48px;
            font-size: 14px;
            """
        )

        layout.addWidget(self._placeholder, stretch=1)
        layout.addWidget(self._pages_list, stretch=1)
        self._pages_list.hide()

        return panel

    def refresh(self) -> None:
        self._refresh_categories()
        self._load_assets()
        self._apply_filters()
        self._refresh_cover_assets()

    def _refresh_categories(self) -> None:
        current = self._category_filter.currentData()
        self._category_filter.blockSignals(True)
        self._category_filter.clear()
        self._category_filter.addItem("All Categories", None)

        if self.workspace.project_id:
            for category in self.controller.categories.get_all(self.workspace.project_id):
                self._category_filter.addItem(category.name, category.id)

        index = self._category_filter.findData(current)
        self._category_filter.setCurrentIndex(index if index >= 0 else 0)
        self._category_filter.blockSignals(False)

    def _load_assets(self) -> None:
        if not self.workspace.project_id:
            self._assets = []
            return

        self._assets = self._asset_ctrl.get_all(project_id=self.workspace.project_id)

    def _apply_filters(self) -> None:
        if not hasattr(self, "_asset_grid"):
            return

        query = self._search.text().strip().lower()
        category_id = self._category_filter.currentData()

        filtered: list[Asset] = []
        for asset in self._assets:
            if query and query not in asset.name.lower():
                continue
            if category_id is not None and asset.category_id != category_id:
                continue
            filtered.append(asset)

        self._populate_assets(filtered)

    def _populate_assets(self, assets: list[Asset]) -> None:
        self._asset_grid.clear()

        for asset in assets:
            item = QListWidgetItem(asset.name)
            item.setData(Qt.ItemDataRole.UserRole, asset.id)
            item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            item.setToolTip(asset.name)

            icon = self._asset_icon(asset)
            if not icon.isNull():
                item.setIcon(icon)

            self._asset_grid.addItem(item)

    def _on_assets_dropped(self, asset_ids: list[int]) -> None:
        known_ids = {
            asset.id
            for asset in self._assets
            if asset.id is not None
        }

        pre_state = [
            (p.asset_id, p.page_number) for p in self._book_pages
        ]
        added: list[tuple] = []

        for asset_id in asset_ids:
            if asset_id not in known_ids:
                continue

            page = BookPage(
                asset_id=asset_id,
                page_number=len(self._book_pages) + 1,
            )
            self._book_pages.append(page)
            added.append((asset_id, page.page_number))

        self._render_book_pages()
        self._mark_dirty()
        if added:
            self._record_page_op(
                pre_state=pre_state,
                added_pages=added,
                removed_pages=[],
                label=f"Add {len(added)} page(s)",
                context=f"{len(added)} pages",
            )

    def _render_book_pages(self) -> None:
        self._renumber_pages()
        self._update_book_stats()
        self._refresh_preview()
        self._pages_list.clear()

        if not self._book_pages:
            self._placeholder.show()
            self._pages_list.hide()
            return

        self._placeholder.hide()
        self._pages_list.show()

        asset_map = {
            asset.id: asset
            for asset in self._assets
            if asset.id is not None
        }

        for page in self._book_pages:
            asset = asset_map.get(page.asset_id)
            if asset is None:
                continue

            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, page.asset_id)
            item.setSizeHint(QSize(320, 106))
            self._pages_list.addItem(item)
            self._pages_list.setItemWidget(
                item,
                self._build_page_card(page, asset),
            )

    def _build_page_card(self, page: BookPage, asset: Asset) -> QFrame:
        card = QFrame()
        card.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.BACKGROUND};
                border: 1px solid {Colors.BORDER};
                border-radius: 8px;
            }}
        """)

        layout = QHBoxLayout(card)
        layout.setContentsMargins(12, 10, 12, 10)
        layout.setSpacing(12)

        thumb = QLabel()
        thumb.setFixedSize(76, 76)
        thumb.setAlignment(Qt.AlignmentFlag.AlignCenter)
        thumb_pixmap = self._asset_pixmap(asset, 76)
        if thumb_pixmap is not None:
            thumb.setPixmap(thumb_pixmap)
        else:
            thumb.setText("-")
            thumb.setStyleSheet(f"color: {Colors.TEXT_MUTED};")
        layout.addWidget(thumb)

        text_col = QVBoxLayout()
        text_col.setSpacing(4)

        name = QLabel(asset.name)
        name.setWordWrap(True)
        name.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 13px; font-weight: 600;"
        )
        text_col.addWidget(name)

        number = QLabel(f"Page {page.page_number}")
        number.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
        )
        text_col.addWidget(number)
        text_col.addStretch()

        layout.addLayout(text_col, stretch=1)

        remove = QPushButton("Remove")
        remove.setProperty("cssClass", "ghost")
        remove.setFixedWidth(76)
        remove.clicked.connect(lambda: self._remove_page(page.page_number))
        layout.addWidget(remove)

        return card

    def _remove_page(self, page_number: int) -> None:
        pre_state = [
            (p.asset_id, p.page_number) for p in self._book_pages
        ]
        removed_pages = [
            (p.asset_id, p.page_number)
            for p in self._book_pages
            if p.page_number == page_number
        ]
        self._book_pages = [
            page
            for page in self._book_pages
            if page.page_number != page_number
        ]
        self._render_book_pages()
        self._mark_dirty()
        if removed_pages:
            self._record_page_op(
                pre_state=pre_state,
                added_pages=[],
                removed_pages=removed_pages,
                label="Remove page",
                context=f"Page {page_number}",
            )

    def _on_pages_reordered(self) -> None:
        pre_state = [
            (p.asset_id, p.page_number) for p in self._book_pages
        ]
        reordered: list[BookPage] = []

        for row in range(self._pages_list.count()):
            item = self._pages_list.item(row)
            asset_id = item.data(Qt.ItemDataRole.UserRole)
            if asset_id is None:
                continue
            reordered.append(
                BookPage(
                    asset_id=int(asset_id),
                    page_number=row + 1,
                )
            )

        new_state = [
            (p.asset_id, p.page_number) for p in reordered
        ]
        self._book_pages = reordered
        self._render_book_pages()
        self._mark_dirty()
        if pre_state != new_state:
            self._record_page_op(
                pre_state=pre_state,
                added_pages=[],
                removed_pages=[],
                label="Reorder pages",
                context=f"{len(pre_state)} pages",
            )

    def _renumber_pages(self) -> None:
        for index, page in enumerate(self._book_pages, start=1):
            page.page_number = index

    # ── Book toolbar button handlers ──────────────────────────────────────────

    def _on_new_book(self) -> None:
        """Clear the current book and start a fresh one."""
        if self._book_pages:
            from PySide6.QtWidgets import QMessageBox
            reply = QMessageBox.question(
                self,
                "New Book",
                "Create a new book? All current pages will be cleared.",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if reply != QMessageBox.StandardButton.Yes:
                return
        self._book_pages = []
        self._render_book_pages()
        self._mark_dirty()

    def _on_clear_book(self) -> None:
        """Remove all pages from the current book."""
        if not self._book_pages:
            return
        from PySide6.QtWidgets import QMessageBox
        reply = QMessageBox.question(
            self,
            "Clear Book",
            "Remove all pages from the book?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        self._book_pages = []
        self._render_book_pages()
        self._mark_dirty()

    def _on_auto_number_pages(self) -> None:
        """Sequentially renumber all pages starting from 1."""
        if not self._book_pages:
            return
        self._renumber_pages()
        self._render_book_pages()
        self._mark_dirty()

    # ── Sprint: Auto Save / Crash Recovery hooks ──────────────────────────────

    def _record_page_op(
        self,
        pre_state: list[tuple],
        added_pages: list[tuple],
        removed_pages: list[tuple],
        label: str,
        context: str = "",
    ) -> None:
        """Push a page-list mutation onto the global undo stack.

        Snapshot the pre/added/removed tuples so undo restores the old
        page list exactly and redo replays the same mutation.
        No DB writes touch this; the snapshot classes are BookPage only.
        """
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            return
        pre_snap = [
            (int(aid), int(pnum)) for aid, pnum in pre_state
        ]
        add_snap = [
            (int(aid), int(pnum)) for aid, pnum in added_pages
        ]
        drop_snap = [
            (int(aid), int(pnum)) for aid, pnum in removed_pages
        ]

        def _undo():
            try:
                self._book_pages = [
                    BookPage(asset_id=aid, page_number=pnum)
                    for aid, pnum in pre_snap
                ]
                self._renumber_pages()
                self._render_book_pages()
            except Exception:
                pass

        def _redo():
            try:
                self._book_pages = [
                    BookPage(asset_id=aid, page_number=pnum)
                    for aid, pnum in pre_snap
                ]
                for aid, _pnum in drop_snap:
                    self._book_pages = [
                        p for p in self._book_pages if p.asset_id != aid
                    ]
                for aid, pnum in add_snap:
                    if aid not in {p.asset_id for p in self._book_pages}:
                        self._book_pages.append(
                            BookPage(asset_id=aid, page_number=pnum)
                        )
                self._renumber_pages()
                self._render_book_pages()
            except Exception:
                pass

        manager.record(
            label,
            undo=_undo,
            redo=_redo,
            context=context or "",
        )

    def _mark_dirty(self) -> None:
        """Forward an 'unsaved edit' signal to the workspace."""
        if self._applying_recovery:
            return
        try:
            self.workspace.mark_dirty()
        except Exception:
            pass

    def _collect_book_recovery_draft(self) -> dict:
        """Pull-style provider: snapshot of the current Book state."""
        if not hasattr(self, "_book_title"):
            return {}
        try:
            properties = self._collect_properties()
        except Exception:
            properties = {}
        try:
            pages = [
                {"asset_id": p.asset_id, "page_number": p.page_number}
                for p in self._book_pages
            ]
        except Exception:
            pages = []
        cover = self._collect_cover_state()
        return {"properties": properties, "pages": pages, "cover": cover}

    def _collect_cover_state(self) -> dict:
        if not hasattr(self, "_cover_title"):
            return {}
        return {
            "title": self._cover_title.text(),
            "subtitle": self._cover_subtitle.text(),
            "author": self._cover_author.text(),
            "cover_asset_id": (
                self._cover_asset_combo.currentData()
                if hasattr(self, "_cover_asset_combo") else None
            ),
        }

    def _apply_book_recovery_draft(self, data: dict) -> None:
        """Push-style apply: restore the Book and Cover from a snapshot."""
        self._applying_recovery = True
        try:
            props = data.get("properties") or {}
            if props:
                try:
                    self._apply_properties(props)
                except Exception:
                    pass

            cover = data.get("cover") or {}
            if hasattr(self, "_cover_title"):
                self._cover_title.setText(str(cover.get("title", "")))
                self._cover_subtitle.setText(str(cover.get("subtitle", "")))
                self._cover_author.setText(str(cover.get("author", "")))
                cid = cover.get("cover_asset_id")
                if cid is not None and hasattr(self, "_cover_asset_combo"):
                    idx = self._cover_asset_combo.findData(cid)
                    if idx >= 0:
                        self._cover_asset_combo.setCurrentIndex(idx)
                self._render_cover_preview()

            pages = data.get("pages") or []
            known_ids = {a.id for a in self._assets if a.id is not None}
            self._book_pages = []
            for entry in pages:
                aid = entry.get("asset_id") if isinstance(entry, dict) else None
                if aid in known_ids:
                    self._book_pages.append(
                        BookPage(
                            asset_id=int(aid),
                            page_number=int(entry.get("page_number", 0)),
                        )
                    )
            self._render_book_pages()
        finally:
            self._applying_recovery = False

    def _apply_selections_recovery(self, data: dict) -> None:
        """Selections the workspace already applied; this is a no-op here."""
        return

    def _update_book_stats(self) -> None:
        total = len(self._book_pages)
        self._total_pages_label.setText(f"Total Pages: {total}")
        self._estimated_size_label.setText(
            f"Estimated Book Size: {self._estimated_book_size(total)}"
        )
        if hasattr(self, "_props_page_count"):
            self._props_page_count.setText(str(total))

    @staticmethod
    def _estimated_book_size(total: int) -> str:
        if total == 0:
            return "0 Pages"
        if total <= 24:
            return "24 Pages"
        if total <= 50:
            return "50 Pages"
        if total <= 100:
            return "100 Pages"
        return f"{total} Pages"

    def _asset_icon(self, asset: Asset) -> QIcon:
        pixmap = self._asset_pixmap(asset, 132)
        return QIcon(pixmap) if pixmap is not None else QIcon()

    def _asset_pixmap(self, asset: Asset, size: int) -> QPixmap | None:
        for path_str in (asset.thumbnail_path, asset.file_path):
            if not path_str:
                continue

            path = Path(path_str)
            if not path.exists():
                continue

            pixmap = QPixmap(str(path))
            if pixmap.isNull():
                continue

            return pixmap.scaled(
                size,
                size,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )

        return None
