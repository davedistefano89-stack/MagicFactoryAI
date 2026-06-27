"""Dashboard data controller."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List

from app.controllers.app_controller import AppController
from models.project import Project


@dataclass
class DashboardStats:
    total_projects: int = 0
    total_categories: int = 0
    total_prompts: int = 0
    total_assets: int = 0
    pending_assets: int = 0
    approved_assets: int = 0
    exported_assets: int = 0


class DashboardController:
    """Provides aggregated data for the dashboard view."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def get_stats(self) -> DashboardStats:
        status_counts = self._app.assets.count_by_status()
        return DashboardStats(
            total_projects=self._app.projects.count(),
            total_categories=self._app.categories.count(),
            total_prompts=self._app.prompts.count(),
            total_assets=self._app.assets.count(),
            pending_assets=status_counts.get("pending", 0),
            approved_assets=status_counts.get("approved", 0),
            exported_assets=status_counts.get("exported", 0),
        )

    def get_recent_projects(self, limit: int = 5) -> List[Project]:
        return self._app.projects.get_all()[:limit]
