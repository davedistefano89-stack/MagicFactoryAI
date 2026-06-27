"""Review tab within the project workspace."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QWidget,
)

from app.controllers.asset_controller import AssetController
from core.theme.colors import Colors
from models.asset import AssetStatus
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class ReviewTab(WorkspaceTabBase):
    """Review pending and generated assets for approval."""

    def _build_ui(self) -> None:
        self._asset_ctrl = AssetController(self.controller)

        hint = QLabel(
            "Assets awaiting review. Approve assets that meet quality standards "
            "or reject them to send back for revision."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet(f"color: {Colors.TEXT_SECONDARY}; padding-bottom: 4px;")
        self._layout.addWidget(hint)

        self._table = QTableWidget()
        self._table.setColumnCount(5)
        self._table.setHorizontalHeaderLabels(["Name", "Status", "Size", "File", "Actions"])
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._layout.addWidget(self._table)

    def _load_review_assets(self):
        if not self.workspace.project_id:
            return []

        kwargs: dict = {"project_id": self.workspace.project_id}
        if self.workspace.category_id is not None:
            kwargs["category_id"] = self.workspace.category_id

        all_assets = self._asset_ctrl.get_all(**kwargs)
        return [
            a for a in all_assets
            if a.status in (AssetStatus.PENDING, AssetStatus.GENERATED)
        ]

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
        assets = self._load_review_assets()
        self._table.setRowCount(len(assets))

        for row, asset in enumerate(assets):
            self._table.setItem(row, 0, QTableWidgetItem(asset.name))
            self._table.setItem(row, 1, QTableWidgetItem(asset.status.value.title()))
            size_text = f"{asset.width}×{asset.height}" if asset.width else "—"
            self._table.setItem(row, 2, QTableWidgetItem(size_text))
            self._table.setItem(
                row, 3,
                QTableWidgetItem(Path(asset.file_path).name if asset.file_path else "—"),
            )

            actions = QWidget()
            actions_layout = QHBoxLayout(actions)
            actions_layout.setContentsMargins(4, 2, 4, 2)

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
