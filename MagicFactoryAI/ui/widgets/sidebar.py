"""Application sidebar navigation widget."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget

from core.theme.colors import Colors


@dataclass
class SidebarItem:
    id: str
    label: str
    icon: str


class SidebarButton(QPushButton):
    """Individual sidebar navigation button."""

    def __init__(self, item: SidebarItem, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.item = item
        self.setText(f"  {item.icon}  {item.label}")
        self.setCheckable(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedHeight(44)
        self._apply_style(active=False)

    def set_active(self, active: bool) -> None:
        self.setChecked(active)
        self._apply_style(active=active)

    def _apply_style(self, active: bool) -> None:
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
                }}
                QPushButton:hover {{
                    background-color: {Colors.SIDEBAR_HOVER};
                    color: {Colors.TEXT_PRIMARY};
                }}
            """)


class Sidebar(QFrame):
    """Left navigation sidebar with branded header."""

    navigation_changed = Signal(str)

    NAV_ITEMS: List[SidebarItem] = [
        SidebarItem("dashboard", "Dashboard", "📊"),
        SidebarItem("new_project", "New Project", "✨"),
        SidebarItem("workspace", "Workspace", "🗂"),
        SidebarItem("categories", "Categories", "📁"),
        SidebarItem("prompts", "Prompt Manager", "💬"),
        SidebarItem("library", "Library", "🖼"),
        SidebarItem("export", "Export", "📦"),
        SidebarItem("settings", "Settings", "⚙"),
    ]

    def __init__(self, width: int = 260, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setFixedWidth(width)
        self._buttons: dict[str, SidebarButton] = {}
        self._active_id = "dashboard"
        self._build_ui()

    def _build_ui(self) -> None:
        self.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SIDEBAR_BG};
                border-right: 1px solid {Colors.BORDER};
            }}
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 24, 16, 24)
        layout.setSpacing(4)

        brand = QLabel("🎨 Magic Factory AI")
        brand.setStyleSheet(f"""
            font-size: 18px;
            font-weight: 700;
            color: {Colors.TEXT_PRIMARY};
            padding: 8px 12px 24px 12px;
        """)
        layout.addWidget(brand)

        subtitle = QLabel("Magic Colors Adventure")
        subtitle.setStyleSheet(f"""
            font-size: 11px;
            color: {Colors.TEXT_MUTED};
            padding: 0 12px 20px 12px;
        """)
        layout.addWidget(subtitle)

        for item in self.NAV_ITEMS:
            btn = SidebarButton(item)
            btn.clicked.connect(lambda checked, i=item: self._on_nav_click(i.id))
            self._buttons[item.id] = btn
            layout.addWidget(btn)

        layout.addStretch()

        version = QLabel("v1.0.0")
        version.setStyleSheet(f"color: {Colors.TEXT_MUTED}; font-size: 11px; padding: 8px 12px;")
        version.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(version)

        self._buttons["dashboard"].set_active(True)

    def _on_nav_click(self, item_id: str) -> None:
        if item_id == self._active_id:
            return
        self.set_active(item_id)
        self.navigation_changed.emit(item_id)

    def set_active(self, item_id: str) -> None:
        self._active_id = item_id
        for nav_id, btn in self._buttons.items():
            btn.set_active(nav_id == item_id)
