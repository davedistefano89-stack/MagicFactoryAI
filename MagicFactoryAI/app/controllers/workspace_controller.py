"""Project workspace context controller."""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, List, Optional

from PySide6.QtCore import QObject, Signal

from models.asset import AssetStatus
from models.category import Category
from models.project import Project

if TYPE_CHECKING:
    from app.controllers.app_controller import AppController


@dataclass
class WorkspaceStats:
    total_assets: int = 0
    approved_assets: int = 0
    pending_assets: int = 0
    total_categories: int = 0
    total_prompts: int = 0


class WorkspaceController(QObject):
    """Manages active project and category context for the workspace."""

    project_changed = Signal(int)
    category_changed = Signal(object)
    workspace_refresh = Signal()
    navigate_to_workspace = Signal()

    def __init__(self, app: AppController) -> None:
        super().__init__()
        self._app = app
        self._project_id: Optional[int] = None
        self._category_id: Optional[int] = None
        self._restore_last_project()

    @property
    def project_id(self) -> Optional[int]:
        return self._project_id

    @property
    def category_id(self) -> Optional[int]:
        return self._category_id

    @property
    def current_project(self) -> Optional[Project]:
        if self._project_id is None:
            return None
        return self._app.projects.get_by_id(self._project_id)

    @property
    def current_category(self) -> Optional[Category]:
        if self._category_id is None:
            return None
        return self._app.categories.get_by_id(self._category_id)

    @property
    def has_project(self) -> bool:
        return self._project_id is not None

    def open_project(self, project_id: int) -> Optional[Project]:
        project = self._app.projects.get_by_id(project_id)
        if not project:
            return None

        self._project_id = project_id
        self._category_id = None
        self._app.settings.set("workspace.last_project_id", project_id, persist=True)
        self.project_changed.emit(project_id)
        self.workspace_refresh.emit()
        return project

    def request_open_workspace(self, project_id: int) -> Optional[Project]:
        """Open a project and signal the UI to navigate to the workspace."""
        project = self.open_project(project_id)
        if project:
            self.navigate_to_workspace.emit()
        return project

    def clear_project(self) -> None:
        self._project_id = None
        self._category_id = None
        self._app.settings.set("workspace.last_project_id", None, persist=True)
        self.project_changed.emit(-1)
        self.workspace_refresh.emit()

    def select_category(self, category_id: Optional[int]) -> None:
        if category_id is not None and self._project_id is not None:
            category = self._app.categories.get_by_id(category_id)
            if not category or category.project_id != self._project_id:
                return
        self._category_id = category_id
        self.category_changed.emit(category_id)
        self.workspace_refresh.emit()

    def get_categories(self) -> List[Category]:
        if self._project_id is None:
            return []
        return self._app.categories.get_all(self._project_id)

    def get_stats(self) -> WorkspaceStats:
        if self._project_id is None:
            return WorkspaceStats()

        project_id = self._project_id
        category_id = self._category_id

        if category_id is not None:
            assets = self._app.assets.get_all(
                project_id=project_id,
                category_id=category_id,
            )
            prompts = self._app.prompts.get_all(category_id=category_id)
            categories = [c for c in self.get_categories() if c.id == category_id]
        else:
            assets = self._app.assets.get_all(project_id=project_id)
            prompts = self._app.prompts.get_by_project(project_id)
            categories = self.get_categories()

        approved = sum(1 for a in assets if a.status == AssetStatus.APPROVED)
        pending = sum(
            1 for a in assets
            if a.status in (AssetStatus.PENDING, AssetStatus.GENERATED)
        )

        return WorkspaceStats(
            total_assets=len(assets),
            approved_assets=approved,
            pending_assets=pending,
            total_categories=len(categories),
            total_prompts=len(prompts),
        )

    def _restore_last_project(self) -> None:
        last_id = self._app.settings.get("workspace.last_project_id")
        if last_id is not None:
            project = self._app.projects.get_by_id(int(last_id))
            if project:
                self._project_id = project.id
