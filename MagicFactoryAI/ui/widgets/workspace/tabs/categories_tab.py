"""Categories tab within the project workspace."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QInputDialog,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QWidget,
)

from app.controllers.category_controller import CategoryController
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class CategoriesTab(WorkspaceTabBase):
    """Manage categories scoped to the current project."""

    def _build_ui(self) -> None:
        header_row = QHBoxLayout()
        header_row.addStretch()

        add_btn = QPushButton("+ Add Category")
        add_btn.setProperty("cssClass", "primary")
        add_btn.clicked.connect(self._on_add)
        header_row.addWidget(add_btn)
        self._layout.addLayout(header_row)

        self._table = QTableWidget()
        self._table.setColumnCount(4)
        self._table.setHorizontalHeaderLabels(["Name", "Color", "Sort Order", "Actions"])
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._layout.addWidget(self._table)

    def _on_add(self) -> None:
        if not self.workspace.project_id:
            return
        name, ok = QInputDialog.getText(self, "New Category", "Category name:")
        if ok and name.strip():
            self._cat_ctrl.create_category(name.strip(), project_id=self.workspace.project_id)
            self.workspace.workspace_refresh.emit()

    def _on_delete(self, category_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete Category",
            f"Delete category '{name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._cat_ctrl.delete_category(category_id)
            if self.workspace.category_id == category_id:
                self.workspace.select_category(None)
            self.workspace.workspace_refresh.emit()

    def refresh(self) -> None:
        if not hasattr(self, "_cat_ctrl"):
            self._cat_ctrl = CategoryController(self.controller)

        project_id = self.workspace.project_id
        if not project_id:
            self._table.setRowCount(0)
            return

        category_id = self.workspace.category_id
        categories = self._cat_ctrl.get_all(project_id)
        if category_id is not None:
            categories = [c for c in categories if c.id == category_id]

        self._table.setRowCount(len(categories))
        for row, cat in enumerate(categories):
            self._table.setItem(row, 0, QTableWidgetItem(cat.name))
            color_item = QTableWidgetItem(cat.color)
            color_item.setForeground(Qt.GlobalColor.white)
            self._table.setItem(row, 1, color_item)
            self._table.setItem(row, 2, QTableWidgetItem(str(cat.sort_order)))

            actions = QWidget()
            actions_layout = QHBoxLayout(actions)
            actions_layout.setContentsMargins(4, 2, 4, 2)

            delete_btn = QPushButton("Delete")
            delete_btn.setProperty("cssClass", "danger")
            delete_btn.setFixedWidth(70)
            delete_btn.clicked.connect(
                lambda _, cid=cat.id, n=cat.name: self._on_delete(cid, n)
            )
            actions_layout.addWidget(delete_btn)
            actions_layout.addStretch()
            self._table.setCellWidget(row, 3, actions)

        self._table.resizeColumnsToContents()
