"""Category management screen."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.controllers.category_controller import CategoryController
from core.theme.colors import Colors
from ui.screens.base_screen import BaseScreen
from ui.widgets.page_header import PageHeader


class CategoriesScreen(BaseScreen):
    screen_id = "categories"

    def __init__(self, controller, parent=None) -> None:
        self._cat_ctrl = CategoryController(controller)
        super().__init__(controller, parent)

    def _build_ui(self) -> None:
        self._layout.addWidget(PageHeader(
            title="Categories",
            subtitle="Organize assets into themed groups",
            action_label="+ Add Category",
            action_callback=self._on_add,
        ))

        self._table = QTableWidget()
        self._table.setColumnCount(4)
        self._table.setHorizontalHeaderLabels(["Name", "Color", "Sort Order", "Actions"])
        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.verticalHeader().setVisible(False)
        self._layout.addWidget(self._table)

    def _on_add(self) -> None:
        name, ok = QInputDialog.getText(self, "New Category", "Category name:")
        if ok and name.strip():
            self._cat_ctrl.create_category(name.strip())
            self.refresh()

    def _on_delete(self, category_id: int, name: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete Category",
            f"Delete category '{name}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._cat_ctrl.delete_category(category_id)
            self.refresh()

    def refresh(self) -> None:
        categories = self._cat_ctrl.get_all()
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
