"""Asset library screen."""

from __future__ import annotations

from pathlib import Path
from typing import List

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
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
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import Asset, AssetStatus
from ui.screens.base_screen import BaseScreen
from ui.widgets.asset_inspector_dialog import AssetInspectorDialog
from ui.widgets.duplicate_finder_dialog import DuplicateFinderDialog
from ui.widgets.page_header import PageHeader
from ui.widgets.similar_finder_dialog import SimilarFinderDialog
from ui.widgets.tag_utils import collect_all_tags, get_tags

_FILTER_CHIP_STYLE = (
    "QPushButton { background-color: #1E293B; border: 1px solid #334155;"
    " border-radius: 12px; padding: 3px 10px; font-size: 12px; color: #94A3B8; }"
    " QPushButton:checked { background-color: #6366F1; border-color: #6366F1; color: #FFFFFF; }"
    " QPushButton:hover:!checked { border-color: #6366F1; color: #818CF8; }"
)

_STATUS_CHOICES = ["All", "Pending", "Generated", "Approved", "Rejected", "Exported"]


class LibraryScreen(BaseScreen):
    screen_id = "library"

    def __init__(self, controller, parent=None) -> None:
        self._asset_ctrl = AssetController(controller)
        self._all_assets: List[Asset] = []
        self._assets: List[Asset] = []
        self._selected_tags: set = set()
        super().__init__(controller, parent)

    def _build_ui(self) -> None:
        self._layout.addWidget(PageHeader(
            title="Library",
            subtitle="Browse, import, and manage coloring book assets",
            action_label="+ Import Asset",
            action_callback=self._on_import,
        ))

        filter_row = QHBoxLayout()
        filter_row.setSpacing(10)

        self._search_edit = QLineEdit()
        self._search_edit.setPlaceholderText("🔍  Search by name or tag…")
        self._search_edit.setClearButtonEnabled(True)
        self._search_edit.textChanged.connect(self._apply_filters)
        filter_row.addWidget(self._search_edit, 1)

        status_lbl = QLabel("Status:")
        status_lbl.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        filter_row.addWidget(status_lbl)

        self._status_combo = QComboBox()
        self._status_combo.addItems(_STATUS_CHOICES)
        self._status_combo.setFixedWidth(130)
        self._status_combo.currentIndexChanged.connect(self._apply_filters)
        filter_row.addWidget(self._status_combo)

        dup_btn = QPushButton("Find Duplicates")
        dup_btn.setProperty("cssClass", "ghost")
        dup_btn.clicked.connect(self._on_find_duplicates)
        filter_row.addWidget(dup_btn)

        sim_btn = QPushButton("Find Similar")
        sim_btn.setProperty("cssClass", "ghost")
        sim_btn.clicked.connect(self._on_find_similar)
        filter_row.addWidget(sim_btn)

        self._layout.addLayout(filter_row)

        tag_row = QHBoxLayout()
        tag_row.setSpacing(8)

        tags_lbl = QLabel("Tags:")
        tags_lbl.setFixedWidth(38)
        tag_row.addWidget(tags_lbl)

        self._tag_scroll = QScrollArea()
        self._tag_scroll.setWidgetResizable(True)
        self._tag_scroll.setFixedHeight(36)
        self._tag_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self._tag_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._tag_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

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
        self._layout.addWidget(self._tag_row_widget)

        self._table = QTableWidget()
        self._table.setColumnCount(5)
        self._table.setHorizontalHeaderLabels(["Name", "Status", "Size", "File", "Actions"])
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._table.cellDoubleClicked.connect(self._on_row_double_clicked)
        self._layout.addWidget(self._table)

    def _rebuild_tag_chips(self) -> None:
        all_tags = collect_all_tags(self._all_assets)

        existing_lower = {t.lower() for t in all_tags}
        self._selected_tags = {t for t in self._selected_tags if t in existing_lower}

        while self._tag_chips_layout.count() > 1:
            item = self._tag_chips_layout.takeAt(0)
            if item.widget():
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
            chip.toggled.connect(lambda checked, t=tag: self._on_tag_filter_toggled(t, checked))
            self._tag_chips_layout.insertWidget(
                self._tag_chips_layout.count() - 1, chip
            )

    def _on_tag_filter_toggled(self, tag: str, checked: bool) -> None:
        if checked:
            self._selected_tags.add(tag.lower())
        else:
            self._selected_tags.discard(tag.lower())
        self._apply_filters()

    def _apply_filters(self) -> None:
        query = self._search_edit.text().lower().strip()
        status_text = self._status_combo.currentText()

        result: List[Asset] = []
        for asset in self._all_assets:
            tags = get_tags(asset)

            if query:
                searchable = asset.name.lower() + " " + " ".join(t.lower() for t in tags)
                if query not in searchable:
                    continue

            if status_text != "All":
                if asset.status.value.title() != status_text:
                    continue

            if self._selected_tags:
                asset_tags_lower = {t.lower() for t in tags}
                if not self._selected_tags.issubset(asset_tags_lower):
                    continue

            result.append(asset)

        self._assets = result
        self._populate_table(result)

    def _populate_table(self, assets: List[Asset]) -> None:
        status_colors = {
            AssetStatus.PENDING: Colors.WARNING,
            AssetStatus.GENERATED: Colors.INFO,
            AssetStatus.APPROVED: Colors.SUCCESS,
            AssetStatus.REJECTED: Colors.ERROR,
            AssetStatus.EXPORTED: Colors.ACCENT,
        }

        self._table.setRowCount(len(assets))

        for row, asset in enumerate(assets):
            self._table.setItem(row, 0, QTableWidgetItem(asset.name))

            status_item = QTableWidgetItem(asset.status.value.title())
            status_colors.get(asset.status, Colors.TEXT_SECONDARY)
            status_item.setForeground(Qt.GlobalColor.white)
            self._table.setItem(row, 1, status_item)

            size_text = f"{asset.width}×{asset.height}" if asset.width else "—"
            self._table.setItem(row, 2, QTableWidgetItem(size_text))
            self._table.setItem(
                row, 3,
                QTableWidgetItem(Path(asset.file_path).name if asset.file_path else "—"),
            )

            actions = QWidget()
            actions_layout = QHBoxLayout(actions)
            actions_layout.setContentsMargins(4, 2, 4, 2)

            if asset.status != AssetStatus.APPROVED:
                approve_btn = QPushButton("Approve")
                approve_btn.setProperty("cssClass", "primary")
                approve_btn.setFixedWidth(70)
                approve_btn.clicked.connect(lambda _, aid=asset.id: self._on_approve(aid))
                actions_layout.addWidget(approve_btn)

            reject_btn = QPushButton("Reject")
            reject_btn.setFixedWidth(60)
            reject_btn.clicked.connect(lambda _, aid=asset.id: self._on_reject(aid))
            actions_layout.addWidget(reject_btn)

            delete_btn = QPushButton("Delete")
            delete_btn.setProperty("cssClass", "danger")
            delete_btn.setFixedWidth(60)
            delete_btn.clicked.connect(
                lambda _, aid=asset.id, n=asset.name: self._on_delete(aid, n)
            )
            actions_layout.addWidget(delete_btn)

            self._table.setCellWidget(row, 4, actions)

        self._table.resizeColumnsToContents()

    def _on_import(self) -> None:
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
                self._asset_ctrl.import_asset(Path(file_path), name.strip())
                self.refresh()
            except Exception as exc:
                QMessageBox.critical(self, "Import Failed", str(exc))

    def _on_find_similar(self) -> None:
        dlg = SimilarFinderDialog(
            self._all_assets,
            self._asset_ctrl,
            self.controller,
            on_deleted=self.refresh,
            parent=self,
        )
        dlg.exec()

    def _on_find_duplicates(self) -> None:
        dlg = DuplicateFinderDialog(
            self._all_assets,
            self._asset_ctrl,
            self.controller,
            on_deleted=self.refresh,
            parent=self,
        )
        dlg.exec()

    def _on_row_double_clicked(self, row: int, _col: int) -> None:
        if 0 <= row < len(self._assets):
            dlg = AssetInspectorDialog(
                self._assets[row],
                self.controller,
                known_tags=collect_all_tags(self._all_assets),
                on_tags_changed=self.refresh,
                parent=self,
            )
            dlg.exec()

    def _on_approve(self, asset_id: int) -> None:
        self._asset_ctrl.approve_asset(asset_id)
        self.refresh()

    def _on_reject(self, asset_id: int) -> None:
        self._asset_ctrl.reject_asset(asset_id)
        self.refresh()

    def _on_delete(self, asset_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self, "Delete Asset", f"Delete '{name}' permanently?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._asset_ctrl.delete_asset(asset_id)
            self.refresh()

    def refresh(self) -> None:
        self._all_assets = self._asset_ctrl.get_all()
        self._rebuild_tag_chips()
        self._apply_filters()
