"""Dedicated project workspace screen with tabs and category panel."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QSizePolicy,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from app.controllers.app_controller import AppController
from core.theme.colors import Colors
from ui.widgets.workspace.category_panel import CategoryPanel
from ui.widgets.workspace.tabs import (
    BookBuilderTab,
    CategoriesTab,
    ExportTab,
    GeneratorTab,
    LibraryTab,
    PromptsTab,
    ReviewTab,
)
from ui.widgets.workspace.tabs.ai_generator_tab import AIGeneratorTab
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
        self._body_widget.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Expanding,
        )
        body = QHBoxLayout(self._body_widget)
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        self._category_panel = CategoryPanel(self._workspace)
        body.addWidget(self._category_panel, stretch=0)

        right_col = QVBoxLayout()
        right_col.setContentsMargins(16, 0, 0, 0)
        right_col.setSpacing(0)

        self._tab_widget = QTabWidget()
        self._tab_widget.setDocumentMode(True)
        self._tab_widget.setSizePolicy(
            QSizePolicy.Policy.Expanding,
            QSizePolicy.Policy.Expanding,
        )

        tab_defs = [
            ("categories", "Categories", CategoriesTab),
            ("prompts", "Prompts", PromptsTab),
            ("library", "Library", LibraryTab),
            ("generator", "Generator", AIGeneratorTab),
            ("review", "Review", ReviewTab),
            ("book_builder", "Book Builder", BookBuilderTab),
            ("export", "Export", ExportTab),
        ]

        for tab_id, label, tab_cls in tab_defs:
            tab = tab_cls(self.controller, self._workspace)
            self._tabs[tab_id] = tab
            self._tab_widget.addTab(tab, label)

        right_col.addWidget(self._tab_widget, stretch=1)

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

        root.addWidget(self._empty_state, stretch=1)

    def _connect_signals(self) -> None:
        self._workspace.project_changed.connect(self._on_project_changed)
        self._workspace.workspace_refresh.connect(self._refresh_all)
        self._category_panel.category_selected.connect(
            self._workspace.select_category
        )
        # Sprint: forward active tab index so it can be persisted into the
        # recovery snapshot (and restored on Recover).
        self._tab_widget.currentChanged.connect(self._on_current_tab_changed)

    def _on_current_tab_changed(self, index: int) -> None:
        try:
            self._workspace.set_active_tab_index(int(index))
        except Exception:
            pass

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

        # After re-population, sync the workspace's notion of which tab is
        # active so it gets captured in the next recovery snapshot.
        try:
            self._workspace.set_active_tab_index(self._tab_widget.currentIndex())
        except Exception:
            pass

    def open_project(self, project_id: int) -> None:
        self._workspace.open_project(project_id)

    def refresh(self) -> None:
        self._update_visibility()
        self._refresh_all()

    def on_show(self) -> None:
        self.refresh()

    def set_active_tab(self, index: int) -> None:
        """Programmatically switch tabs.

        Sprint: Book Project Dashboard PRO #1 — quick-action buttons
        emit ``enter_workspace_tab(index)``; the MainWindow calls this
        when the workspace screen becomes visible.
        """
        target = max(0, min(int(index), self._tab_widget.count() - 1))
        self._tab_widget.setCurrentIndex(target)
