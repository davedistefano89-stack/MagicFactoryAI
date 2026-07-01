"""Application screen views."""

from ui.screens.base_screen import BaseScreen
from ui.screens.dashboard_screen import DashboardScreen
from ui.screens.new_project_screen import NewProjectScreen
from ui.screens.project_dashboard_screen import ProjectDashboardScreen
from ui.screens.project_workspace_screen import ProjectWorkspaceScreen
from ui.screens.categories_screen import CategoriesScreen
from ui.screens.prompt_manager_screen import PromptManagerScreen
from ui.screens.library_screen import LibraryScreen
from ui.screens.export_screen import ExportScreen
from ui.screens.settings_screen import SettingsScreen

__all__ = [
    "BaseScreen",
    "DashboardScreen",
    "NewProjectScreen",
    "ProjectDashboardScreen",
    "ProjectWorkspaceScreen",
    "CategoriesScreen",
    "PromptManagerScreen",
    "LibraryScreen",
    "ExportScreen",
    "SettingsScreen",
]
