"""Base class for all application screens."""

from __future__ import annotations

from PySide6.QtWidgets import QScrollArea, QVBoxLayout, QWidget

from app.controllers.app_controller import AppController


class BaseScreen(QScrollArea):
    """Scrollable screen base with consistent padding and refresh hook."""

    screen_id: str = "base"

    def __init__(self, controller: AppController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.controller = controller
        self.setWidgetResizable(True)
        self.setFrameShape(QScrollArea.Shape.NoFrame)

        self._container = QWidget()
        self._layout = QVBoxLayout(self._container)
        self._layout.setContentsMargins(32, 28, 32, 32)
        self._layout.setSpacing(16)
        self.setWidget(self._container)

        self._build_ui()

    def _build_ui(self) -> None:
        raise NotImplementedError

    def refresh(self) -> None:
        """Called when the screen becomes visible. Override in subclasses."""

    def on_show(self) -> None:
        self.refresh()
