"""Main application window with sidebar navigation."""

from __future__ import annotations

from typing import Dict, Union

from PySide6.QtCore import Qt
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication,
    QHBoxLayout,
    QLineEdit,
    QMainWindow,
    QPlainTextEdit,
    QStackedWidget,
    QTextEdit,
    QWidget,
)

from app.controllers.app_controller import AppController
from core.settings.manager import SettingsManager
from ui.screens.base_screen import BaseScreen
from ui.screens.categories_screen import CategoriesScreen
from ui.screens.dashboard_screen import DashboardScreen
from ui.screens.export_screen import ExportScreen
from ui.screens.library_screen import LibraryScreen
from ui.screens.new_project_screen import NewProjectScreen
from ui.screens.project_dashboard_screen import ProjectDashboardScreen
from ui.screens.project_workspace_screen import ProjectWorkspaceScreen
from ui.screens.prompt_manager_screen import PromptManagerScreen
from ui.screens.settings_screen import SettingsScreen
from ui.widgets.sidebar import Sidebar
from utils.logger import get_logger

logger = get_logger(__name__)


# Widget classes whose native Ctrl+Z / Ctrl+Shift+Z undo must take
# precedence over the global Undo / Redo manager.
_TEXT_INPUT_TYPES = (QLineEdit, QTextEdit, QPlainTextEdit)


class MainWindow(QMainWindow):
    """Primary window hosting sidebar navigation and screen stack."""

    def __init__(self, controller: AppController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._controller = controller
        self._settings = SettingsManager.instance()
        self._screens: Dict[str, Union[BaseScreen, ProjectWorkspaceScreen]] = {}
        self._undo_shortcut: QShortcut | None = None
        self._redo_shortcut: QShortcut | None = None

        self.setWindowTitle(self._settings.app_name)
        self._build_ui()
        self._connect_signals()
        self._install_undo_shortcuts()

    def _install_undo_shortcuts(self) -> None:
        """Wire Ctrl+Z / Ctrl+Shift+Z to ``AppController.undo_manager``.

        If the keyboard focus is inside a text-input widget (so the user
        is mid-typing into a field), the native per-field undo is
        triggered instead of the global manager. This keeps typing
        comfortable while still giving one-click global Undo / Redo
        everywhere else.
        """
        self._undo_shortcut = QShortcut(QKeySequence.StandardKey.Undo, self)
        self._undo_shortcut.setContext(Qt.ShortcutContext.WindowShortcut)
        self._undo_shortcut.activated.connect(self._handle_undo_shortcut)

        self._redo_shortcut = QShortcut(QKeySequence.StandardKey.Redo, self)
        self._redo_shortcut.setContext(Qt.ShortcutContext.WindowShortcut)
        self._redo_shortcut.activated.connect(self._handle_redo_shortcut)

    @staticmethod
    def _focused_is_text_input() -> bool:
        focused = QApplication.instance().focusWidget() if QApplication.instance() else None
        return isinstance(focused, _TEXT_INPUT_TYPES)

    def _handle_undo_shortcut(self) -> None:
        manager = self._controller.undo_manager
        try:
            if self._focused_is_text_input():
                focused = QApplication.focusWidget()
                if focused is not None and hasattr(focused, "undo"):
                    focused.undo()
                    return
            manager.undo()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Undo shortcut handler failed: %s", exc)

    def _handle_redo_shortcut(self) -> None:
        manager = self._controller.undo_manager
        try:
            if self._focused_is_text_input():
                focused = QApplication.focusWidget()
                if focused is not None and hasattr(focused, "redo"):
                    focused.redo()
                    return
            manager.redo()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redo shortcut handler failed: %s", exc)

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
            ProjectDashboardScreen,
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
        # Sprint: Book Project Dashboard PRO #1 — route project
        # selection through the per-project Dashboard first.
        self._controller.workspace.navigate_to_project_dashboard.connect(
            self._navigate_to_project_dashboard
        )
        # Round-trip: dashboard quick actions request the workspace
        # with a specific tab. Cross-screen routes (e.g. Settings)
        # flow back through the sidebar so the highlight stays in sync.
        for screen in self._screens.values():
            if isinstance(screen, ProjectDashboardScreen):
                screen.enter_workspace_tab.connect(self._enter_workspace_at_tab)
                screen.navigate_to_target.connect(self._on_navigate)

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

    def _navigate_to_project_dashboard(self, project_id: int) -> None:
        """Drop into the per-project Dashboard after a project is opened.

        Sprint: Book Project Dashboard PRO #1 — this is the new default
        landing screen when a project is selected.
        """
        self._sidebar.set_active("project_dashboard")
        index = self._nav_index_map.get("project_dashboard", 0)
        self._stack.setCurrentIndex(index)
        screen = self._screens.get("project_dashboard")
        if screen is not None:
            screen.on_show()

    def _enter_workspace_at_tab(self, tab_index: int) -> None:
        """Switch to the workspace screen and optionally a specific tab."""
        self._sidebar.set_active("workspace")
        index = self._nav_index_map.get("workspace", 0)
        self._stack.setCurrentIndex(index)
        workspace = self._screens.get("workspace")
        if isinstance(workspace, ProjectWorkspaceScreen):
            if tab_index is not None and int(tab_index) >= 0:
                workspace.set_active_tab(int(tab_index))
            workspace.on_show()
        elif workspace is not None:
            workspace.on_show()

    def open_workspace(self, project_id: int) -> None:
        """Open a project in the dedicated workspace."""
        self._controller.workspace.request_open_workspace(project_id)

    def closeEvent(self, event) -> None:
        # Sprint: Auto Save — flush any pending recovery snapshot before
        # the app exits cleanly.
        try:
            self._controller.workspace.force_save_recovery()
        except Exception:
            pass
        self._controller.shutdown()
        super().closeEvent(event)
