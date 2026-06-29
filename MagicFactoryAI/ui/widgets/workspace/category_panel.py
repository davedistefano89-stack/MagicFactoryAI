"""Left panel listing project categories."""

from __future__ import annotations

from typing import Optional

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QFrame,
    QLabel,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from app.controllers.workspace_controller import WorkspaceController
from core.theme.colors import Colors
from models.category import Category


class CategoryButton(QPushButton):
    """Selectable category entry in the workspace sidebar."""

    def __init__(self, category: Optional[Category], label: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.category = category
        self.setText(label)
        self.setCheckable(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedHeight(40)
        self._apply_style(active=False)

    def set_active(self, active: bool) -> None:
        self.setChecked(active)
        self._apply_style(active=active)

    def _apply_style(self, active: bool) -> None:
        color_dot = ""
        if self.category:
            color_dot = f"border-left: 3px solid {self.category.color}; padding-left: 10px;"
        if active:
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: {Colors.SIDEBAR_ACTIVE};
                    color: {Colors.TEXT_ON_PRIMARY};
                    border: none;
                    border-radius: 8px;
                    text-align: left;
                    padding-left: 12px;
                    font-weight: 600;
                    font-size: 13px;
                    {color_dot}
                }}
            """)
        else:
            self.setStyleSheet(f"""
                QPushButton {{
                    background-color: transparent;
                    color: {Colors.TEXT_SECONDARY};
                    border: none;
                    border-radius: 8px;
                    text-align: left;
                    padding-left: 12px;
                    font-size: 13px;
                    {color_dot}
                }}
                QPushButton:hover {{
                    background-color: {Colors.SIDEBAR_HOVER};
                    color: {Colors.TEXT_PRIMARY};
                }}
            """)


class CategoryPanel(QFrame):
    """Left sidebar panel with all project categories."""

    category_selected = Signal(object)

    def __init__(self, workspace: WorkspaceController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._workspace = workspace
        self._buttons: list[CategoryButton] = []
        self._active_id: Optional[int] = None
        self._build_ui()

    def _build_ui(self) -> None:
        self.setMinimumWidth(180)
        self.setSizePolicy(
            QSizePolicy.Policy.Preferred,
            QSizePolicy.Policy.Expanding,
        )
        self.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SIDEBAR_BG};
                border-right: 1px solid {Colors.BORDER};
            }}
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 16, 12, 16)
        layout.setSpacing(8)

        header = QLabel("Categories")
        header.setStyleSheet(
            f"font-size: 13px; font-weight: 700; color: {Colors.TEXT_MUTED};"
            " padding: 0 4px 8px 4px;"
        )
        layout.addWidget(header)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        self._list_container = QWidget()
        self._list_layout = QVBoxLayout(self._list_container)
        self._list_layout.setContentsMargins(0, 0, 0, 0)
        self._list_layout.setSpacing(4)
        self._list_layout.addStretch()

        scroll.setWidget(self._list_container)
        layout.addWidget(scroll, stretch=1)

    def refresh(self) -> None:
        while self._list_layout.count() > 1:
            item = self._list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self._buttons.clear()

        project = self._workspace.current_project
        if not project:
            empty = QLabel("No project open")
            empty.setStyleSheet(f"color: {Colors.TEXT_MUTED}; padding: 8px;")
            self._list_layout.insertWidget(0, empty)
            return

        all_btn = CategoryButton(None, "  📂  All Categories")
        all_btn.clicked.connect(lambda: self._on_select(None))
        self._list_layout.insertWidget(0, all_btn)
        self._buttons.append(all_btn)

        categories = self._workspace.get_categories()
        if not categories:
            hint = QLabel("No categories yet")
            hint.setStyleSheet(f"color: {Colors.TEXT_MUTED}; font-size: 12px; padding: 8px;")
            self._list_layout.insertWidget(1, hint)
        else:
            for cat in categories:
                btn = CategoryButton(cat, f"  {cat.icon}  {cat.name}")
                btn.clicked.connect(lambda _, c=cat: self._on_select(c.id))
                insert_idx = self._list_layout.count() - 1
                self._list_layout.insertWidget(insert_idx, btn)
                self._buttons.append(btn)

        self._active_id = self._workspace.category_id
        self._update_active_state()

    def _on_select(self, category_id: Optional[int]) -> None:
        self._active_id = category_id
        self._update_active_state()
        self.category_selected.emit(category_id)

    def _update_active_state(self) -> None:
        for btn in self._buttons:
            cat_id = btn.category.id if btn.category else None
            btn.set_active(cat_id == self._active_id)
