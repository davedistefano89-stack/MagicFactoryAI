"""Workspace tab panels."""

from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase
from ui.widgets.workspace.tabs.categories_tab import CategoriesTab
from ui.widgets.workspace.tabs.export_tab import ExportTab
from ui.widgets.workspace.tabs.generator_tab import GeneratorTab
from ui.widgets.workspace.tabs.library_tab import LibraryTab
from ui.widgets.workspace.tabs.prompts_tab import PromptsTab
from ui.widgets.workspace.tabs.review_tab import ReviewTab

__all__ = [
    "WorkspaceTabBase",
    "CategoriesTab",
    "PromptsTab",
    "LibraryTab",
    "GeneratorTab",
    "ReviewTab",
    "ExportTab",
]
