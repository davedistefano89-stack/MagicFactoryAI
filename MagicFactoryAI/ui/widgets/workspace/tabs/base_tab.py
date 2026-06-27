"""Base class for workspace tab panels."""

from __future__ import annotations

from PySide6.QtWidgets import QVBoxLayout, QWidget

from app.controllers.app_controller import AppController
from app.controllers.workspace_controller import WorkspaceController


class WorkspaceTabBase(QWidget):
    """Base tab with workspace context and refresh hook."""

    def __init__(
        self,
        controller: AppController,
        workspace: WorkspaceController,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.controller = controller
        self.workspace = workspace
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(16, 12, 16, 12)
        self._layout.setSpacing(12)
        self._build_ui()

    def _build_ui(self) -> None:
        raise NotImplementedError

    def refresh(self) -> None:
        """Reload tab content. Override in subclasses."""
