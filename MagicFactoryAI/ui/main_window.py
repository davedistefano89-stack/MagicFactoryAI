"""Main application window with sidebar navigation."""

from __future__ import annotations

from typing import Dict, Union

from PySide6.QtWidgets import QHBoxLayout, QMainWindow, QStackedWidget, QWidget

from app.controllers.app_controller import AppController
from core.settings.manager import SettingsManager
from ui.screens.base_screen import BaseScreen
from ui.screens.categories_screen import CategoriesScreen
from ui.screens.dashboard_screen import DashboardScreen
from ui.screens.export_screen import ExportScreen
from ui.screens.library_screen import LibraryScreen
from ui.screens.new_project_screen import NewProjectScreen
from ui.screens.project_workspace_screen import ProjectWorkspaceScreen
from ui.screens.prompt_manager_screen import PromptManagerScreen
from ui.screens.settings_screen import SettingsScreen
from ui.widgets.sidebar import Sidebar
from utils.logger import get_logger

logger = get_logger(__name__)


class MainWindow(QMainWindow):
    """Primary window hosting sidebar navigation and screen stack."""

    def __init__(self, controller: AppController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._controller = controller
        self._settings = SettingsManager.instance()
        self._screens: Dict[str, Union[BaseScreen, ProjectWorkspaceScreen]] = {}

        self.setWindowTitle(self._settings.app_name)
        self._build_ui()
        self._connect_signals()

    def _build_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)

        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        sidebar_width = self._settings.sidebar_width
        self._sidebar = Sidebar(width=sidebar_width)
        layout.addWidget(self._sidebar)

        self._stack = QStackedWidget()
        layout.addWidget(self._stack)

        screen_classes = [
            DashboardScreen,
            NewProjectScreen,
            ProjectWorkspaceScreen,
            CategoriesScreen,
            PromptManagerScreen,
            LibraryScreen,
            ExportScreen,
            SettingsScreen,
        ]

        for screen_cls in screen_classes:
            screen = screen_cls(self._controller)
            self._screens[screen.screen_id] = screen
            self._stack.addWidget(screen)

        nav_map = {item.id: idx for idx, item in enumerate(Sidebar.NAV_ITEMS)}
        self._nav_index_map = nav_map
        self._index_nav_map = {v: k for k, v in nav_map.items()}

    def _connect_signals(self) -> None:
        self._sidebar.navigation_changed.connect(self._on_navigate)
        self._controller.workspace.navigate_to_workspace.connect(self._navigate_to_workspace)

    def _on_navigate(self, screen_id: str) -> None:
        index = self._nav_index_map.get(screen_id, 0)
        self._stack.setCurrentIndex(index)
        screen = self._screens.get(screen_id)
        if screen:
            screen.on_show()
        logger.debug("Navigated to screen: %s", screen_id)

    def _navigate_to_workspace(self) -> None:
        self._sidebar.set_active("workspace")
        index = self._nav_index_map.get("workspace", 0)
        self._stack.setCurrentIndex(index)
        workspace = self._screens.get("workspace")
        if workspace:
            workspace.on_show()

    def open_workspace(self, project_id: int) -> None:
        """Open a project in the dedicated workspace."""
        self._controller.workspace.request_open_workspace(project_id)

    def closeEvent(self, event) -> None:
        self._controller.shutdown()
        super().closeEvent(event)
