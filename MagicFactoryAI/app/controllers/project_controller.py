"""Project management controller."""

from __future__ import annotations

from typing import List, Optional

from app.controllers.app_controller import AppController
from models.project import Project, ProjectStatus


class ProjectController:
    """CRUD operations for projects."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def create_project(self, name: str, description: str = "") -> Project:
        project = Project(name=name, description=description, status=ProjectStatus.DRAFT)
        return self._app.projects.create(project)

    def update_project(self, project: Project) -> Project:
        return self._app.projects.update(project)

    def delete_project(self, project_id: int) -> None:
        self._app.projects.delete(project_id)

    def get_project(self, project_id: int) -> Optional[Project]:
        return self._app.projects.get_by_id(project_id)

    def get_all_projects(self) -> List[Project]:
        return self._app.projects.get_all()

    def activate_project(self, project_id: int) -> Optional[Project]:
        project = self._app.projects.get_by_id(project_id)
        if project:
            project.status = ProjectStatus.ACTIVE
            return self._app.projects.update(project)
        return None

    def archive_project(self, project_id: int) -> Optional[Project]:
        project = self._app.projects.get_by_id(project_id)
        if project:
            project.status = ProjectStatus.ARCHIVED
            return self._app.projects.update(project)
        return None
