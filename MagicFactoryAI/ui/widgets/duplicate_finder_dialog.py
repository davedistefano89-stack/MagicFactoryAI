"""Duplicate Finder — detects image duplicates by SHA-256 hash."""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
from PySide6.QtWidgets import (
    QButtonGroup,
    QDialog,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMessageBox,
    QPushButton,
    QRadioButton,
    QScrollArea,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from models.asset import Asset


def _find_duplicate_groups(assets: List[Asset]) -> Dict[str, List[Asset]]:
    """Return hash→[Asset] for every hash that appears more than once."""
    hash_map: Dict[str, List[Asset]] = {}
    for asset in assets:
        if not asset.file_path:
            continue
        fp = Path(asset.file_path)
        if not fp.exists():
            continue
        try:
            digest = hashlib.sha256(fp.read_bytes()).hexdigest()
            hash_map.setdefault(digest, []).append(asset)
        except OSError:
            continue
    return {h: g for h, g in hash_map.items() if len(g) > 1}


def _load_thumb_pixmap(asset: Asset) -> Optional[QPixmap]:
    for path_str in (asset.thumbnail_path, asset.file_path):
        if not path_str:
            continue
        p = Path(path_str)
        if p.exists():
            px = QPixmap(str(p))
            if not px.isNull():
                return px.scaled(
                    64, 64,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
    return None


class DuplicateFinderDialog(QDialog):
    """Modal dialog that scans the Library for duplicate image files."""

    def __init__(
        self,
        assets: List[Asset],
        asset_ctrl,
        controller,
        on_deleted: Optional[Callable] = None,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self._asset_ctrl = asset_ctrl
        self._controller = controller
        self._on_deleted = on_deleted
        self._groups_data: List[Tuple[List[Asset], QButtonGroup]] = []

        self.setWindowTitle("Duplicate Finder")
        self.setMinimumSize(920, 580)
        self.resize(1020, 660)
        self.setModal(True)

        dup_groups = _find_duplicate_groups(assets)
        self._build_ui(dup_groups)

    def _build_ui(self, dup_groups: Dict[str, List[Asset]]) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 0)
        root.setSpacing(12)

        if not dup_groups:
            icon_lbl = QLabel("✓  No duplicate images found in the Library.")
            icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            icon_lbl.setStyleSheet("font-size: 15px; color: #10B981; padding: 40px;")
            root.addWidget(icon_lbl, 1)
            root.addWidget(self._build_footer(has_duplicates=False))
            return

        total_extra = sum(len(g) - 1 for g in dup_groups.values())
        summary = QLabel(
            f"Found <b>{len(dup_groups)}</b> duplicate group(s) — "
            f"<b>{total_extra}</b> extra file(s) can be removed. "
            f"Select which copy to <b>keep</b> in each group, then click Delete."
        )
        summary.setWordWrap(True)
        summary.setStyleSheet("color: #94A3B8; font-size: 13px;")
        root.addWidget(summary)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        container = QWidget()
        c_layout = QVBoxLayout(container)
        c_layout.setSpacing(14)
        c_layout.setContentsMargins(0, 0, 8, 8)

        for hash_val, group_assets in dup_groups.items():
            group_box, btn_group = self._build_group_widget(hash_val, group_assets)
            self._groups_data.append((group_assets, btn_group))
            c_layout.addWidget(group_box)

        c_layout.addStretch()
        scroll.setWidget(container)
        root.addWidget(scroll, 1)
        root.addWidget(self._build_footer(has_duplicates=True))

    def _build_group_widget(
        self, hash_val: str, group_assets: List[Asset]
    ) -> Tuple[QGroupBox, QButtonGroup]:
        box = QGroupBox(
            f"{len(group_assets)} copies  ·  SHA-256: {hash_val[:16]}…"
        )
        box_layout = QVBoxLayout(box)
        box_layout.setContentsMargins(8, 8, 8, 8)
        box_layout.setSpacing(4)

        table = QTableWidget()
        table.setColumnCount(6)
        table.setHorizontalHeaderLabels(
            ["Keep", "Preview", "Name", "Category", "Created", "Size"]
        )
        table.setRowCount(len(group_assets))
        table.setSelectionMode(QTableWidget.SelectionMode.NoSelection)
        table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        table.verticalHeader().setVisible(False)
        table.horizontalHeader().setStretchLastSection(False)
        table.setFixedHeight(len(group_assets) * 74 + table.horizontalHeader().height() + 4)

        hdr = table.horizontalHeader()
        hdr.setSectionResizeMode(0, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        hdr.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)

        table.setColumnWidth(0, 58)
        table.setColumnWidth(1, 74)
        table.setColumnWidth(3, 130)
        table.setColumnWidth(4, 148)
        table.setColumnWidth(5, 96)

        btn_group = QButtonGroup(table)
        btn_group.setExclusive(True)

        for i, asset in enumerate(group_assets):
            table.setRowHeight(i, 74)

            radio_cell = QWidget()
            rc_layout = QHBoxLayout(radio_cell)
            rc_layout.setContentsMargins(0, 0, 0, 0)
            rc_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
            radio = QRadioButton()
            radio.setChecked(i == 0)
            btn_group.addButton(radio, i)
            rc_layout.addWidget(radio)
            table.setCellWidget(i, 0, radio_cell)

            thumb_cell = QWidget()
            th_layout = QHBoxLayout(thumb_cell)
            th_layout.setContentsMargins(4, 4, 4, 4)
            th_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
            thumb_lbl = QLabel()
            thumb_lbl.setFixedSize(64, 64)
            thumb_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            px = _load_thumb_pixmap(asset)
            if px:
                thumb_lbl.setPixmap(px)
            else:
                thumb_lbl.setText("—")
            th_layout.addWidget(thumb_lbl)
            table.setCellWidget(i, 1, thumb_cell)

            fp = asset.file_path or ""
            table.setItem(i, 2, QTableWidgetItem(Path(fp).name if fp else "—"))

            cat_name = "—"
            if asset.category_id is not None:
                try:
                    cat = self._controller.categories.get_by_id(asset.category_id)
                    if cat:
                        cat_name = cat.name
                except Exception:
                    pass
            table.setItem(i, 3, QTableWidgetItem(cat_name))

            created = (
                asset.created_at.strftime("%Y-%m-%d %H:%M")
                if asset.created_at
                else "—"
            )
            table.setItem(i, 4, QTableWidgetItem(created))

            size_str = "—"
            if fp and Path(fp).exists():
                kb = Path(fp).stat().st_size / 1024
                size_str = f"{kb:.1f} KB"
            table.setItem(i, 5, QTableWidgetItem(size_str))

        box_layout.addWidget(table)
        return box, btn_group

    def _build_footer(self, has_duplicates: bool) -> QFrame:
        footer = QFrame()
        footer.setFrameShape(QFrame.Shape.NoFrame)
        footer.setFixedHeight(56)

        layout = QHBoxLayout(footer)
        layout.setContentsMargins(0, 8, 0, 8)
        layout.addStretch()

        if has_duplicates:
            delete_btn = QPushButton("Delete Duplicates")
            delete_btn.setProperty("cssClass", "danger")
            delete_btn.clicked.connect(self._on_delete_confirmed)
            layout.addWidget(delete_btn)

        close_btn = QPushButton("Close")
        close_btn.setFixedWidth(100)
        close_btn.clicked.connect(self.accept)
        layout.addWidget(close_btn)

        return footer

    def _on_delete_confirmed(self) -> None:
        to_delete: List[Asset] = []
        for group_assets, btn_group in self._groups_data:
            keep_idx = btn_group.checkedId()
            for i, asset in enumerate(group_assets):
                if i != keep_idx:
                    to_delete.append(asset)

        if not to_delete:
            return

        reply = QMessageBox.question(
            self,
            "Confirm Delete",
            f"Permanently delete {len(to_delete)} duplicate file(s)?\nThis cannot be undone.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return

        errors = 0
        for asset in to_delete:
            try:
                self._asset_ctrl.delete_asset(asset.id)
            except Exception:
                errors += 1

        if self._on_deleted:
            self._on_deleted()

        if errors:
            QMessageBox.warning(
                self,
                "Partial Delete",
                f"Deleted {len(to_delete) - errors} file(s). {errors} could not be removed.",
            )

        self.accept()
