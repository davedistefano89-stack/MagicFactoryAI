"""Dashboard stat card widget."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFrame, QLabel, QVBoxLayout, QWidget

from core.theme.colors import Colors


class StatCard(QFrame):
    """Colorful metric card for the dashboard."""

    def __init__(
        self,
        label: str,
        value: str = "0",
        accent_color: str = Colors.PRIMARY,
        icon: str = "",
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._accent = accent_color
        self._build_ui(label, value, icon)

    def _build_ui(self, label: str, value: str, icon: str) -> None:
        self.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
                border-left: 4px solid {self._accent};
            }}
        """)
        self.setMinimumHeight(110)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)
        layout.setSpacing(4)

        top_row = QLabel(f"{icon}  {label}" if icon else label)
        top_row.setProperty("cssClass", "stat-label")
        top_row.setStyleSheet(f"color: {Colors.TEXT_SECONDARY}; font-size: 12px; font-weight: 500;")
        layout.addWidget(top_row)

        self._value_label = QLabel(value)
        self._value_label.setStyleSheet(
            f"color: {self._accent}; font-size: 32px; font-weight: 700;"
        )
        layout.addWidget(self._value_label)

        layout.addStretch()

    def set_value(self, value: str) -> None:
        self._value_label.setText(value)
