"""Reusable page header with title and optional action button."""

from __future__ import annotations

from typing import Callable, Optional

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget

from core.theme.colors import Colors


class PageHeader(QWidget):
    """Top-of-page header with title, subtitle, and optional action."""

    def __init__(
        self,
        title: str,
        subtitle: str = "",
        action_label: str = "",
        action_callback: Optional[Callable[[], None]] = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._build_ui(title, subtitle, action_label, action_callback)

    def _build_ui(
        self,
        title: str,
        subtitle: str,
        action_label: str,
        action_callback: Optional[Callable[[], None]],
    ) -> None:
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 16)

        text_col = QVBoxLayout()
        text_col.setSpacing(4)

        title_label = QLabel(title)
        title_label.setProperty("cssClass", "title")
        title_label.setStyleSheet(
            f"font-size: 26px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
        )
        text_col.addWidget(title_label)

        if subtitle:
            sub = QLabel(subtitle)
            sub.setProperty("cssClass", "subtitle")
            sub.setStyleSheet(f"color: {Colors.TEXT_SECONDARY}; font-size: 14px;")
            text_col.addWidget(sub)

        layout.addLayout(text_col)
        layout.addStretch()

        if action_label and action_callback:
            btn = QPushButton(action_label)
            btn.setProperty("cssClass", "primary")
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.clicked.connect(action_callback)
            layout.addWidget(btn)
