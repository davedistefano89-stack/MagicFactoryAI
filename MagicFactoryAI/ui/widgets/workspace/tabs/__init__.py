"""Workspace tab panels."""

from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase
from ui.widgets.workspace.tabs.book_builder_tab import BookBuilderTab
from ui.widgets.workspace.tabs.categories_tab import CategoriesTab
from ui.widgets.workspace.tabs.export_tab import ExportTab
from ui.widgets.workspace.tabs.library_tab_v2 import LibraryTab
from ui.widgets.workspace.tabs.prompts_tab import PromptsTab
from ui.widgets.workspace.tabs.review_tab import ReviewTab

__all__ = [
    "WorkspaceTabBase",
    "BookBuilderTab",
    "CategoriesTab",
    "PromptsTab",
    "LibraryTab",
    "ReviewTab",
    "ExportTab",
]
