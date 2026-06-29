"""Similar Image Finder — groups visually similar images using dHash."""

from __future__ import annotations

from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

from PIL import Image as PilImage
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QDialog,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from models.asset import Asset

_HASH_SIZE = 8
_DEFAULT_THRESHOLD = 10  # max Hamming distance out of 64 bits to be "similar"


# ---------------------------------------------------------------------------
# Perceptual hashing (dHash)
# ---------------------------------------------------------------------------

def _dhash(image_path: str, hash_size: int = _HASH_SIZE) -> int:
    """Compute difference hash (dHash) for an image file."""
    img = PilImage.open(image_path).convert("L").resize(
        (hash_size + 1, hash_size), PilImage.LANCZOS
    )
    pixels = list(img.getdata())
    bits = 0
    for row in range(hash_size):
        for col in range(hash_size):
            left = pixels[row * (hash_size + 1) + col]
            right = pixels[row * (hash_size + 1) + col + 1]
            if left > right:
                bits |= 1 << (row * hash_size + col)
    return bits


def _hamming(h1: int, h2: int) -> int:
    return bin(h1 ^ h2).count("1")


def _similarity_pct(dist: int, hash_size: int = _HASH_SIZE) -> int:
    """Convert Hamming distance to a 0-100 similarity percentage."""
    max_bits = hash_size * hash_size
    return round((1 - dist / max_bits) * 100)


# ---------------------------------------------------------------------------
# Grouping logic — union-find over pairwise dHash distances
# ---------------------------------------------------------------------------

def _find_similar_groups(
    assets: List[Asset],
    threshold: int = _DEFAULT_THRESHOLD,
) -> List[Tuple[List[Asset], Dict[int, int]]]:
    """Return list of (group_assets, hash_map) for each visually similar group.

    hash_map maps asset.id → dHash integer.
    Only groups with 2+ members are returned.
    """
    hash_map: Dict[int, int] = {}
    for asset in assets:
        if not asset.file_path:
            continue
        fp = Path(asset.file_path)
        if not fp.exists():
            continue
        try:
            hash_map[asset.id] = _dhash(str(fp))
        except Exception:
            continue

    valid = [a for a in assets if a.id in hash_map]
    n = len(valid)
    if n < 2:
        return []

    parent = list(range(n))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x: int, y: int) -> None:
        parent[find(x)] = find(y)

    for i in range(n):
        for j in range(i + 1, n):
            if _hamming(hash_map[valid[i].id], hash_map[valid[j].id]) <= threshold:
                union(i, j)

    groups: Dict[int, List[int]] = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)

    result = []
    for indices in groups.values():
        if len(indices) > 1:
            group_assets = [valid[idx] for idx in indices]
            result.append((group_assets, hash_map))

    return result


# ---------------------------------------------------------------------------
# Dialog
# ---------------------------------------------------------------------------

class SimilarFinderDialog(QDialog):
    """Modal dialog that scans the Library for visually similar images."""

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
        # list of (group_assets, hash_map, list_of_QCheckBox)
        self._groups_data: List[Tuple[List[Asset], Dict[int, int], List[QCheckBox]]] = []

        self.setWindowTitle("Similar Image Finder")
        self.setMinimumSize(980, 600)
        self.resize(1060, 680)
        self.setModal(True)

        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            sim_groups = _find_similar_groups(assets)
        finally:
            QApplication.restoreOverrideCursor()

        self._build_ui(sim_groups)

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(
        self,
        sim_groups: List[Tuple[List[Asset], Dict[int, int]]],
    ) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 0)
        root.setSpacing(12)

        if not sim_groups:
            no_lbl = QLabel("✓  No visually similar images found in the Library.")
            no_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            no_lbl.setStyleSheet("font-size: 15px; color: #10B981; padding: 40px;")
            root.addWidget(no_lbl, 1)
            root.addWidget(self._build_footer(has_groups=False))
            return

        total_similar = sum(len(g) - 1 for g, _ in sim_groups)
        summary = QLabel(
            f"Found <b>{len(sim_groups)}</b> similar group(s) — "
            f"<b>{total_similar}</b> possibly redundant file(s).  "
            f"Similarity threshold: ≤ {_DEFAULT_THRESHOLD}/64 bits.  "
            f"Check the images you want to <b>delete</b>, then click Delete."
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

        for group_assets, hash_map in sim_groups:
            group_box, checkboxes = self._build_group_widget(group_assets, hash_map)
            self._groups_data.append((group_assets, hash_map, checkboxes))
            c_layout.addWidget(group_box)

        c_layout.addStretch()
        scroll.setWidget(container)
        root.addWidget(scroll, 1)
        root.addWidget(self._build_footer(has_groups=True))

    def _build_group_widget(
        self,
        group_assets: List[Asset],
        hash_map: Dict[int, int],
    ) -> Tuple[QGroupBox, List[QCheckBox]]:
        ref_hash = hash_map[group_assets[0].id]

        box = QGroupBox(
            f"{len(group_assets)} similar images  ·  "
            f"dHash reference: {ref_hash:016x}"
        )
        box_layout = QVBoxLayout(box)
        box_layout.setContentsMargins(8, 8, 8, 8)
        box_layout.setSpacing(4)

        table = QTableWidget()
        table.setColumnCount(7)
        table.setHorizontalHeaderLabels(
            ["Delete", "Preview", "Name", "Category", "Similarity", "Resolution", "Size"]
        )
        table.setRowCount(len(group_assets))
        table.setSelectionMode(QTableWidget.SelectionMode.NoSelection)
        table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        table.verticalHeader().setVisible(False)
        table.horizontalHeader().setStretchLastSection(False)
        table.setFixedHeight(
            len(group_assets) * 74 + table.horizontalHeader().height() + 4
        )

        hdr = table.horizontalHeader()
        hdr.setSectionResizeMode(0, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        hdr.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)
        hdr.setSectionResizeMode(6, QHeaderView.ResizeMode.Fixed)

        table.setColumnWidth(0, 60)
        table.setColumnWidth(1, 74)
        table.setColumnWidth(3, 130)
        table.setColumnWidth(4, 110)
        table.setColumnWidth(5, 110)
        table.setColumnWidth(6, 90)

        checkboxes: List[QCheckBox] = []

        for i, asset in enumerate(group_assets):
            table.setRowHeight(i, 74)

            # Delete checkbox
            cb_cell = QWidget()
            cb_layout = QHBoxLayout(cb_cell)
            cb_layout.setContentsMargins(0, 0, 0, 0)
            cb_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
            cb = QCheckBox()
            cb.setChecked(False)
            cb_layout.addWidget(cb)
            table.setCellWidget(i, 0, cb_cell)
            checkboxes.append(cb)

            # Preview thumbnail
            thumb_cell = QWidget()
            th_layout = QHBoxLayout(thumb_cell)
            th_layout.setContentsMargins(4, 4, 4, 4)
            th_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
            thumb_lbl = QLabel()
            thumb_lbl.setFixedSize(64, 64)
            thumb_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            px = self._load_pixmap(asset)
            if px:
                thumb_lbl.setPixmap(px)
            else:
                thumb_lbl.setText("—")
            th_layout.addWidget(thumb_lbl)
            table.setCellWidget(i, 1, thumb_cell)

            # Name
            fp = asset.file_path or ""
            table.setItem(i, 2, QTableWidgetItem(Path(fp).name if fp else "—"))

            # Category
            cat_name = "—"
            if asset.category_id is not None:
                try:
                    cat = self._controller.categories.get_by_id(asset.category_id)
                    if cat:
                        cat_name = cat.name
                except Exception:
                    pass
            table.setItem(i, 3, QTableWidgetItem(cat_name))

            # Similarity score
            if i == 0:
                sim_text = "Reference"
            else:
                dist = _hamming(hash_map[asset.id], ref_hash)
                pct = _similarity_pct(dist)
                sim_text = f"{pct}%  ({dist}/64 bits)"
            sim_item = QTableWidgetItem(sim_text)
            if i == 0:
                sim_item.setForeground(Qt.GlobalColor.cyan)
            table.setItem(i, 4, sim_item)

            # Resolution
            if asset.width and asset.height:
                res_text = f"{asset.width}×{asset.height}"
            else:
                res_text = "—"
            table.setItem(i, 5, QTableWidgetItem(res_text))

            # File size
            size_str = "—"
            if fp and Path(fp).exists():
                kb = Path(fp).stat().st_size / 1024
                size_str = f"{kb:.1f} KB"
            table.setItem(i, 6, QTableWidgetItem(size_str))

        box_layout.addWidget(table)
        return box, checkboxes

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _load_pixmap(self, asset: Asset) -> Optional[QPixmap]:
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

    def _build_footer(self, has_groups: bool) -> QFrame:
        footer = QFrame()
        footer.setFrameShape(QFrame.Shape.NoFrame)
        footer.setFixedHeight(56)

        layout = QHBoxLayout(footer)
        layout.setContentsMargins(0, 8, 0, 8)
        layout.addStretch()

        if has_groups:
            delete_btn = QPushButton("Delete Selected")
            delete_btn.setProperty("cssClass", "danger")
            delete_btn.clicked.connect(self._on_delete_confirmed)
            layout.addWidget(delete_btn)

        close_btn = QPushButton("Close")
        close_btn.setFixedWidth(100)
        close_btn.clicked.connect(self.accept)
        layout.addWidget(close_btn)

        return footer

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def _on_delete_confirmed(self) -> None:
        to_delete: List[Asset] = []
        for group_assets, _hash_map, checkboxes in self._groups_data:
            for asset, cb in zip(group_assets, checkboxes):
                if cb.isChecked():
                    to_delete.append(asset)

        if not to_delete:
            QMessageBox.information(
                self, "Nothing Selected",
                "Check the images you want to delete first.",
            )
            return

        reply = QMessageBox.question(
            self,
            "Confirm Delete",
            f"Permanently delete {len(to_delete)} selected image(s)?\nThis cannot be undone.",
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
