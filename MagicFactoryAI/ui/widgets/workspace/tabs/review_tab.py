"""Review Queue — professional asset review workflow.

Keyboard shortcuts:
    A          → Approve current asset
    R          → Reject current asset
    ← / →      → Navigate prev / next
    Space      → Toggle zoom

Buttons: Approve · Reject · Skip
Auto-advances to the next pending asset after Approve or Reject.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QKeyEvent, QPixmap
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QProgressBar,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import Asset, AssetStatus
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


# ── Image preview widget ──────────────────────────────────────────────────────

class _ReviewImageLabel(QLabel):
    """
    Auto-scaling image display with zoom toggle.

    Normal mode : image scaled to fit the label area (aspect-ratio preserved).
    Zoomed mode : image shown at 2× the fit dimensions (capped at native size).
    """

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setMinimumSize(200, 200)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self._source: QPixmap | None = None
        self._zoomed: bool = False

    def set_source(self, pixmap: QPixmap | None) -> None:
        self._source = pixmap
        self._zoomed = False
        self._redraw()

    def toggle_zoom(self) -> None:
        if self._source is not None and not self._source.isNull():
            self._zoomed = not self._zoomed
            self._redraw()

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        self._redraw()

    # ── Internal ──────────────────────────────────────────────────────────────

    def _redraw(self) -> None:
        if self._source is None or self._source.isNull():
            self.clear()
            self.setText("No image available")
            return

        fit = self._source.scaled(
            self.size(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )

        if self._zoomed:
            # 2× fit, capped at native dimensions
            zoom_w = min(self._source.width(),  fit.width()  * 2)
            zoom_h = min(self._source.height(), fit.height() * 2)
            px = self._source.scaled(
                int(zoom_w), int(zoom_h),
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )
        else:
            px = fit

        self.setPixmap(px)


# ── Main Review Queue tab ─────────────────────────────────────────────────────

class ReviewTab(WorkspaceTabBase):
    """Professional Review Queue with keyboard shortcuts and progress tracking."""

    def _build_ui(self) -> None:
        self._asset_ctrl   = AssetController(self.controller)
        self._queue:  list[Asset] = []
        self._index:  int = 0
        self._total_assets: int = 0

        # The QScrollArea (self) must be focusable to receive key events
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        # ── Header: title + live progress ────────────────────────────────
        header = QHBoxLayout()
        header.setSpacing(16)

        title_lbl = QLabel("Review Queue")
        title_lbl.setStyleSheet(
            f"font-size: 16px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
        )
        header.addWidget(title_lbl)
        header.addStretch()

        self._progress_label = QLabel("0 / 0 reviewed")
        self._progress_label.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 13px;"
        )
        header.addWidget(self._progress_label)
        self._layout.addLayout(header)

        # Progress bar
        self._progress_bar = QProgressBar()
        self._progress_bar.setRange(0, 100)
        self._progress_bar.setValue(0)
        self._progress_bar.setFixedHeight(6)
        self._progress_bar.setTextVisible(False)
        self._progress_bar.setStyleSheet(f"""
            QProgressBar {{
                background: {Colors.SURFACE_LIGHT};
                border-radius: 3px;
                border: none;
            }}
            QProgressBar::chunk {{
                background: {Colors.PRIMARY};
                border-radius: 3px;
            }}
        """)
        self._layout.addWidget(self._progress_bar)

        # ── Body: large preview | info panel ─────────────────────────────
        body = QHBoxLayout()
        body.setSpacing(16)

        # Left — image preview
        preview_frame = QFrame()
        preview_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)
        pf_layout = QVBoxLayout(preview_frame)
        pf_layout.setContentsMargins(16, 16, 16, 12)
        pf_layout.setSpacing(8)

        self._image_label = _ReviewImageLabel()
        self._image_label.setStyleSheet(f"""
            background-color: {Colors.BACKGROUND};
            border: 1px solid {Colors.BORDER};
            border-radius: 8px;
            color: {Colors.TEXT_MUTED};
            font-size: 14px;
        """)
        self._image_label.setMinimumHeight(380)
        pf_layout.addWidget(self._image_label, stretch=1)

        zoom_hint = QLabel("Press  Space  to toggle zoom")
        zoom_hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        zoom_hint.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; border: none;"
        )
        pf_layout.addWidget(zoom_hint)
        body.addWidget(preview_frame, stretch=3)

        # Right — info panel
        info_panel = QFrame()
        info_panel.setFixedWidth(256)
        info_panel.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)
        ip_layout = QVBoxLayout(info_panel)
        ip_layout.setContentsMargins(20, 20, 20, 20)
        ip_layout.setSpacing(10)

        info_title = QLabel("Asset Details")
        info_title.setStyleSheet(
            f"font-size: 14px; font-weight: 600; color: {Colors.TEXT_PRIMARY}; border: none;"
        )
        ip_layout.addWidget(info_title)

        _lbl = (
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; font-weight: 500; border: none;"
        )
        _val = f"color: {Colors.TEXT_PRIMARY}; font-size: 13px; border: none;"

        for attr, label_text in (
            ("_info_name",   "Name"),
            ("_info_status", "Status"),
            ("_info_size",   "Dimensions"),
            ("_info_file",   "File"),
        ):
            lbl = QLabel(label_text)
            lbl.setStyleSheet(_lbl)
            ip_layout.addWidget(lbl)
            val = QLabel("—")
            val.setStyleSheet(_val)
            val.setWordWrap(True)
            setattr(self, attr, val)
            ip_layout.addWidget(val)

        # Position badge
        self._position_label = QLabel("—")
        self._position_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._position_label.setStyleSheet(f"""
            color: {Colors.TEXT_SECONDARY};
            background-color: {Colors.SURFACE_LIGHT};
            border: 1px solid {Colors.BORDER};
            border-radius: 8px;
            padding: 8px;
            font-size: 13px;
            font-weight: 600;
        """)
        ip_layout.addWidget(self._position_label)

        self._remaining_label = QLabel("")
        self._remaining_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._remaining_label.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 12px; border: none;"
        )
        ip_layout.addWidget(self._remaining_label)

        ip_layout.addStretch()

        # Keyboard legend
        legend = QFrame()
        legend.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.BACKGROUND};
                border: 1px solid {Colors.BORDER};
                border-radius: 8px;
            }}
        """)
        leg_layout = QVBoxLayout(legend)
        leg_layout.setContentsMargins(12, 10, 12, 10)
        leg_layout.setSpacing(5)

        _key_style = (
            f"background: {Colors.SURFACE_LIGHT}; color: {Colors.TEXT_PRIMARY};"
            " border-radius: 4px; padding: 2px 6px;"
            " font-size: 11px; font-weight: 700; font-family: monospace;"
        )
        _act_style = f"color: {Colors.TEXT_SECONDARY}; font-size: 11px; border: none;"

        for key_text, action_text in (
            ("A",      "Approve"),
            ("R",      "Reject"),
            ("←  /  →", "Navigate"),
            ("Space",  "Toggle Zoom"),
        ):
            row = QHBoxLayout()
            row.setSpacing(8)
            k = QLabel(key_text)
            k.setStyleSheet(_key_style)
            k.setFixedWidth(54)
            a = QLabel(action_text)
            a.setStyleSheet(_act_style)
            row.addWidget(k)
            row.addWidget(a)
            row.addStretch()
            leg_layout.addLayout(row)

        ip_layout.addWidget(legend)
        body.addWidget(info_panel)
        self._layout.addLayout(body, stretch=1)

        # ── Action buttons ────────────────────────────────────────────────
        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)

        self._btn_prev = QPushButton("← Previous")
        self._btn_prev.setProperty("cssClass", "ghost")
        self._btn_prev.setFixedHeight(40)
        self._btn_prev.setFixedWidth(110)
        self._btn_prev.clicked.connect(self._go_prev)

        self._btn_next = QPushButton("Next →")
        self._btn_next.setProperty("cssClass", "ghost")
        self._btn_next.setFixedHeight(40)
        self._btn_next.setFixedWidth(110)
        self._btn_next.clicked.connect(self._go_next)

        self._btn_approve = QPushButton("✅  Approve")
        self._btn_approve.setProperty("cssClass", "primary")
        self._btn_approve.setFixedHeight(40)
        self._btn_approve.clicked.connect(self._do_approve)

        self._btn_reject = QPushButton("❌  Reject")
        self._btn_reject.setFixedHeight(40)
        self._btn_reject.setStyleSheet(f"""
            QPushButton {{
                background-color: {Colors.ERROR};
                color: #FFFFFF;
                border: none;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 600;
                padding: 0 16px;
            }}
            QPushButton:hover {{
                background-color: #DC2626;
            }}
            QPushButton:disabled {{
                background-color: {Colors.SURFACE_LIGHT};
                color: {Colors.TEXT_MUTED};
            }}
        """)
        self._btn_reject.clicked.connect(self._do_reject)

        self._btn_skip = QPushButton("⏭  Skip")
        self._btn_skip.setProperty("cssClass", "ghost")
        self._btn_skip.setFixedHeight(40)
        self._btn_skip.clicked.connect(self._do_skip)

        btn_row.addWidget(self._btn_prev)
        btn_row.addWidget(self._btn_next)
        btn_row.addStretch()
        btn_row.addWidget(self._btn_approve)
        btn_row.addWidget(self._btn_reject)
        btn_row.addWidget(self._btn_skip)
        self._layout.addLayout(btn_row)

    # ── Keyboard shortcuts ────────────────────────────────────────────────────

    def keyPressEvent(self, event: QKeyEvent) -> None:
        key = event.key()
        if key == Qt.Key.Key_A:
            self._do_approve()
            event.accept()
        elif key == Qt.Key.Key_R:
            self._do_reject()
            event.accept()
        elif key in (Qt.Key.Key_Left, Qt.Key.Key_Up):
            self._go_prev()
            event.accept()
        elif key in (Qt.Key.Key_Right, Qt.Key.Key_Down):
            self._go_next()
            event.accept()
        elif key == Qt.Key.Key_Space:
            self._image_label.toggle_zoom()
            event.accept()
        else:
            super().keyPressEvent(event)

    # ── Navigation ────────────────────────────────────────────────────────────

    def _go_prev(self) -> None:
        if self._queue and self._index > 0:
            self._index -= 1
            self._show_current()

    def _go_next(self) -> None:
        if self._queue and self._index < len(self._queue) - 1:
            self._index += 1
            self._show_current()

    def _do_skip(self) -> None:
        """Advance without changing asset status."""
        if self._queue:
            if self._index < len(self._queue) - 1:
                self._index += 1
            elif self._index > 0:
                self._index -= 1
            self._show_current()
        self.setFocus()

    # ── Actions ───────────────────────────────────────────────────────────────

    def _do_approve(self) -> None:
        if not self._queue:
            return
        asset = self._queue[self._index]
        if asset.id is not None:
            self._asset_ctrl.approve_asset(asset.id)
        self.workspace.mark_dirty()
        self._pop_and_advance()
        self.workspace.workspace_refresh.emit()
        self.setFocus()

    def _do_reject(self) -> None:
        if not self._queue:
            return
        asset = self._queue[self._index]
        if asset.id is not None:
            self._asset_ctrl.reject_asset(asset.id)
        self.workspace.mark_dirty()
        self._pop_and_advance()
        self.workspace.workspace_refresh.emit()
        self.setFocus()

    def _pop_and_advance(self) -> None:
        """Remove current asset from queue; advance to next or clamp."""
        if not self._queue:
            return
        self._queue.pop(self._index)
        if self._queue:
            self._index = min(self._index, len(self._queue) - 1)
        self._update_progress()
        self._show_current()

    # ── Display ───────────────────────────────────────────────────────────────

    def _show_current(self) -> None:
        """Render the asset at _index into the preview and info panel."""
        empty = not self._queue
        self._btn_approve.setEnabled(not empty)
        self._btn_reject.setEnabled(not empty)
        self._btn_skip.setEnabled(not empty)

        if empty:
            self._image_label.set_source(None)
            for attr in ("_info_name", "_info_status", "_info_size", "_info_file"):
                getattr(self, attr).setText("—")
            self._position_label.setText("Queue empty")
            self._remaining_label.setText("All assets reviewed ✅")
            self._btn_prev.setEnabled(False)
            self._btn_next.setEnabled(False)
            return

        asset = self._queue[self._index]

        # Load image
        pixmap: QPixmap | None = None
        for path_str in (asset.file_path, asset.thumbnail_path):
            if not path_str:
                continue
            p = Path(path_str)
            if p.exists():
                px = QPixmap(str(p))
                if not px.isNull():
                    pixmap = px
                    break
        self._image_label.set_source(pixmap)

        # Info panel
        self._info_name.setText(asset.name or "—")
        self._info_status.setText(asset.status.value.title())
        self._info_size.setText(
            f"{asset.width} × {asset.height} px" if asset.width else "—"
        )
        self._info_file.setText(
            Path(asset.file_path).name if asset.file_path else "—"
        )

        total_q = len(self._queue)
        self._position_label.setText(f"{self._index + 1} / {total_q}")
        remaining = total_q - self._index - 1
        self._remaining_label.setText(
            f"{remaining} asset{'s' if remaining != 1 else ''} remaining"
        )

        self._btn_prev.setEnabled(self._index > 0)
        self._btn_next.setEnabled(self._index < total_q - 1)

    def _update_progress(self) -> None:
        reviewed = self._total_assets - len(self._queue)
        pct = int(reviewed / self._total_assets * 100) if self._total_assets else 0
        self._progress_label.setText(f"{reviewed} / {self._total_assets} reviewed")
        self._progress_bar.setValue(pct)

    # ── Refresh hook ──────────────────────────────────────────────────────────

    def refresh(self) -> None:
        """Reload the pending queue from the database."""
        if not self.workspace.project_id:
            return

        kwargs: dict = {"project_id": self.workspace.project_id}
        if self.workspace.category_id is not None:
            kwargs["category_id"] = self.workspace.category_id

        all_assets   = self._asset_ctrl.get_all(**kwargs)
        self._total_assets = len(all_assets)
        self._queue  = [
            a for a in all_assets
            if a.status in (AssetStatus.PENDING, AssetStatus.GENERATED)
        ]
        self._index  = 0

        self._update_progress()
        self._show_current()
        self.setFocus()

