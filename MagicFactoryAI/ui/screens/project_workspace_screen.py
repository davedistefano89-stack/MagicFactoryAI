"""Dedicated project workspace screen with tabs and category panel."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.controllers.app_controller import AppController
from core.theme.colors import Colors
from ui.widgets.workspace.category_panel import CategoryPanel
from ui.widgets.workspace.tabs import (
    CategoriesTab,
    ExportTab,
    GeneratorTab,
    LibraryTab,
    PromptsTab,
    ReviewTab,
)
from ui.widgets.workspace.workspace_header import WorkspaceHeader


class ProjectWorkspaceScreen(QWidget):
    """Full project workspace with header, category sidebar, and six tabs."""

    screen_id = "workspace"

    def __init__(
        self,
        controller: AppController,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)

        self.controller = controller
        self._workspace = controller.workspace
        self._tabs: dict[str, QWidget] = {}

        self._build_ui()
        self._connect_signals()

        # Inizializza subito lo stato della schermata
        self.refresh()

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(24, 20, 24, 24)
        root.setSpacing(16)

        self._header = WorkspaceHeader(self._workspace)
        root.addWidget(self._header)

        self._body_widget = QWidget()
        body = QHBoxLayout(self._body_widget)
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        self._category_panel = CategoryPanel(self._workspace)
        body.addWidget(self._category_panel)

        right_col = QVBoxLayout()
        right_col.setContentsMargins(16, 0, 0, 0)
        right_col.setSpacing(0)

        self._tab_widget = QTabWidget()
        self._tab_widget.setDocumentMode(True)

        tab_defs = [
            ("categories", "Categories", CategoriesTab),
            ("prompts", "Prompts", PromptsTab),
            ("library", "Library", LibraryTab),
            ("generator", "Generator", GeneratorTab),
            ("review", "Review", ReviewTab),
            ("export", "Export", ExportTab),
        ]

        for tab_id, label, tab_cls in tab_defs:
            tab = tab_cls(self.controller, self._workspace)
            self._tabs[tab_id] = tab
            self._tab_widget.addTab(tab, label)

        right_col.addWidget(self._tab_widget)

        body.addLayout(right_col, stretch=1)

        root.addWidget(self._body_widget, stretch=1)

        self._empty_state = QLabel(
            "No project selected.\n\n"
            "Open a project from the Dashboard or New Project screen."
        )
        self._empty_state.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._empty_state.setStyleSheet(
            f"""
            color: {Colors.TEXT_MUTED};
            font-size: 15px;
            padding: 48px;
            """
        )
        self._empty_state.hide()

        root.addWidget(self._empty_state)

    def _connect_signals(self) -> None:
        self._workspace.project_changed.connect(self._on_project_changed)
        self._workspace.workspace_refresh.connect(self._refresh_all)
        self._category_panel.category_selected.connect(
            self._workspace.select_category
        )

    def _on_project_changed(self, _project_id: int) -> None:
        self._update_visibility()
        self._refresh_all()

    def _update_visibility(self) -> None:
        has_project = self._workspace.has_project

        self._header.setVisible(has_project)
        self._body_widget.setVisible(has_project)
        self._empty_state.setVisible(not has_project)

    def _refresh_all(self) -> None:
        self._header.refresh()
        self._category_panel.refresh()

        for tab in self._tabs.values():
            tab.refresh()

    def open_project(self, project_id: int) -> None:
        self._workspace.open_project(project_id)

    def refresh(self) -> None:
        self._update_visibility()
        self._refresh_all()

    def on_show(self) -> None:
        self.refresh()