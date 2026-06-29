"""Library tab within the project workspace."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFileDialog,
    QHBoxLayout,
    QInputDialog,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import AssetStatus
from ui.widgets.asset_inspector_dialog import AssetInspectorDialog
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class LibraryTab(WorkspaceTabBase):
    """Browse and manage assets scoped to the current project/category."""

    def _build_ui(self) -> None:
        self._asset_ctrl = AssetController(self.controller)

        header_row = QHBoxLayout()
        header_row.addStretch()

        import_btn = QPushButton("+ Import Asset")
        import_btn.setProperty("cssClass", "primary")
        import_btn.clicked.connect(self._on_import)
        header_row.addWidget(import_btn)
        self._layout.addLayout(header_row)

        self._assets: list = []

        self._table = QTableWidget()
        self._table.setColumnCount(5)
        self._table.setHorizontalHeaderLabels(["Name", "Status", "Size", "File", "Actions"])
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._table.cellDoubleClicked.connect(self._on_row_double_clicked)
        self._layout.addWidget(self._table)

    def _load_assets(self):
        if not self.workspace.project_id:
            return []
        kwargs: dict = {"project_id": self.workspace.project_id}
        if self.workspace.category_id is not None:
            kwargs["category_id"] = self.workspace.category_id
        return self._asset_ctrl.get_all(**kwargs)

    def _on_row_double_clicked(self, row: int, _col: int) -> None:
        if 0 <= row < len(self._assets):
            dlg = AssetInspectorDialog(self._assets[row], self.controller, parent=self)
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

    def refresh(self) -> None:
        assets = self._load_assets()
        self._assets = assets
        self._table.setRowCount(len(assets))

        status_colors = {
            AssetStatus.PENDING: Colors.WARNING,
            AssetStatus.GENERATED: Colors.INFO,
            AssetStatus.APPROVED: Colors.SUCCESS,
            AssetStatus.REJECTED: Colors.ERROR,
            AssetStatus.EXPORTED: Colors.ACCENT,
        }

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
