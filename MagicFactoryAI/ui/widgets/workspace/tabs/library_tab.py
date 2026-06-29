"""Library tab within the project workspace."""

from __future__ import annotations

import json
from pathlib import Path

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QFormLayout,
    QFileDialog,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QSlider,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import Asset
from models.asset import AssetStatus
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class ImageViewerDialog(QDialog):
    """Read-only image preview with asset metadata."""

    def __init__(
        self,
        asset: Asset,
        category_name: str,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle(asset.name)
        self.resize(820, 720)

        layout = QVBoxLayout(self)

        image_label = QLabel()
        image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        pixmap = QPixmap(asset.file_path)
        if not pixmap.isNull():
            image_label.setPixmap(
                pixmap.scaled(
                    760,
                    480,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
            )
        else:
            image_label.setText("Image unavailable")
        layout.addWidget(image_label, stretch=1)

        metadata = self._metadata(asset, category_name)
        form = QFormLayout()
        for label, value in metadata:
            form.addRow(label, QLabel(value))
        layout.addLayout(form)

        button_row = QHBoxLayout()
        button_row.addStretch()
        close_btn = QPushButton("Close")
        close_btn.clicked.connect(self.accept)
        button_row.addWidget(close_btn)
        layout.addLayout(button_row)

    def _metadata(self, asset: Asset, category_name: str) -> list[tuple[str, str]]:
        try:
            metadata = json.loads(asset.metadata_json or "{}")
        except json.JSONDecodeError:
            metadata = {}

        provider = str(metadata.get("provider") or metadata.get("ai_provider") or "—")
        model = str(metadata.get("model") or "N/A")
        prompt = str(metadata.get("prompt") or "N/A")
        negative_prompt = str(metadata.get("negative_prompt") or "N/A")
        filename = Path(asset.file_path).name if asset.file_path else "—"
        resolution = f"{asset.width}×{asset.height}" if asset.width and asset.height else "—"

        return [
            ("Filename", filename),
            ("Category", category_name),
            ("Status", asset.status.value.title()),
            ("Resolution", resolution),
            ("Provider", provider),
            ("Model", model),
            ("Prompt", prompt),
            ("Negative prompt", negative_prompt),
            ("Creation date", asset.created_at.strftime("%Y-%m-%d %H:%M")),
        ]


class LibraryTab(WorkspaceTabBase):
    """Browse and manage assets scoped to the current project/category."""

    def _build_ui(self) -> None:
        self._asset_ctrl = AssetController(self.controller)
        self._thumb_size = 48
        self._category_filter_initialized = False
        self._visible_assets: list[Asset] = []

        filter_row = QHBoxLayout()

        self._search_input = QLineEdit()
        self._search_input.setPlaceholderText("Search library...")
        self._search_input.textChanged.connect(self.refresh)
        filter_row.addWidget(self._search_input, stretch=1)

        self._status_filter = QComboBox()
        self._status_filter.addItem("All Statuses", None)
        for status in AssetStatus:
            self._status_filter.addItem(status.value.title(), status)
        self._status_filter.currentIndexChanged.connect(self.refresh)
        filter_row.addWidget(self._status_filter)

        self._category_filter = QComboBox()
        self._category_filter.currentIndexChanged.connect(self.refresh)
        filter_row.addWidget(self._category_filter)

        filter_row.addWidget(QLabel("Zoom"))

        self._thumbnail_slider = QSlider(Qt.Orientation.Horizontal)
        self._thumbnail_slider.setRange(32, 96)
        self._thumbnail_slider.setValue(self._thumb_size)
        self._thumbnail_slider.valueChanged.connect(self._on_thumbnail_zoom)
        filter_row.addWidget(self._thumbnail_slider)

        self._layout.addLayout(filter_row)

        header_row = QHBoxLayout()
        header_row.addStretch()

        import_btn = QPushButton("+ Import Asset")
        import_btn.setProperty("cssClass", "primary")
        import_btn.clicked.connect(self._on_import)
        header_row.addWidget(import_btn)
        self._layout.addLayout(header_row)

        self._table = QTableWidget()
        self._table.setColumnCount(5)
        self._table.setHorizontalHeaderLabels(["Name", "Status", "Size", "File", "Actions"])
        self._table.setIconSize(QSize(self._thumb_size, self._thumb_size))
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._table.cellDoubleClicked.connect(self._on_open_viewer)
        self._layout.addWidget(self._table)

    def _load_assets(self):
        if not self.workspace.project_id:
            return []
        kwargs: dict = {"project_id": self.workspace.project_id}
        category_id = self._category_filter.currentData()
        if category_id is not None:
            kwargs["category_id"] = category_id
        return self._asset_ctrl.get_all(**kwargs)

    def _refresh_category_filter(self) -> None:
        current = (
            self._category_filter.currentData()
            if self._category_filter_initialized
            else self.workspace.category_id
        )
        self._category_filter.blockSignals(True)
        self._category_filter.clear()
        self._category_filter.addItem("All Categories", None)
        for category in self.workspace.get_categories():
            self._category_filter.addItem(category.name, category.id)

        index = self._category_filter.findData(current)
        self._category_filter.setCurrentIndex(index if index >= 0 else 0)
        self._category_filter.blockSignals(False)
        self._category_filter_initialized = True

    def _filter_assets(self, assets):
        search = self._search_input.text().strip().lower()
        status = self._status_filter.currentData()

        if status is not None:
            assets = [asset for asset in assets if asset.status == status]

        if search:
            assets = [
                asset
                for asset in assets
                if search in asset.name.lower()
                or search in Path(asset.file_path).name.lower()
            ]

        return assets

    def _on_thumbnail_zoom(self, value: int) -> None:
        self._thumb_size = value
        self._table.setIconSize(QSize(value, value))
        for row in range(self._table.rowCount()):
            self._table.setRowHeight(row, value + 12)

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
        self._asset_ctrl.approve_asset(asset_id)
        self.workspace.workspace_refresh.emit()

    def _on_reject(self, asset_id: int) -> None:
        self._asset_ctrl.reject_asset(asset_id)
        self.workspace.workspace_refresh.emit()

    def _on_delete(self, asset_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self, "Delete Asset", f"Delete '{name}' permanently?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._asset_ctrl.delete_asset(asset_id)
            self.workspace.workspace_refresh.emit()

    def _category_name(self, asset: Asset) -> str:
        if asset.category_id is None:
            return "—"
        category = self.controller.categories.get_by_id(asset.category_id)
        return category.name if category else "—"

    def _on_open_viewer(self, row: int, _column: int) -> None:
        if row < 0 or row >= len(self._visible_assets):
            return
        asset = self._visible_assets[row]
        dialog = ImageViewerDialog(
            asset,
            self._category_name(asset),
            self,
        )
        dialog.exec()

    def refresh(self) -> None:
        self._refresh_category_filter()
        assets = self._filter_assets(self._load_assets())
        self._visible_assets = assets
        self._table.setRowCount(len(assets))

        status_colors = {
            AssetStatus.PENDING: Colors.WARNING,
            AssetStatus.GENERATED: Colors.INFO,
            AssetStatus.APPROVED: Colors.SUCCESS,
            AssetStatus.REJECTED: Colors.ERROR,
            AssetStatus.EXPORTED: Colors.ACCENT,
        }

        for row, asset in enumerate(assets):
            name_item = QTableWidgetItem(asset.name)
            thumbnail_path = Path(asset.thumbnail_path or asset.file_path)
            if thumbnail_path.exists():
                name_item.setIcon(QIcon(str(thumbnail_path)))
            self._table.setItem(row, 0, name_item)
            self._table.setRowHeight(row, self._thumb_size + 12)

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
