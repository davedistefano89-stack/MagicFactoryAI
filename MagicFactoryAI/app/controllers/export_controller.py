"""Export controller."""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from app.controllers.app_controller import AppController
from engine.export.exporter import ExportOptions, ExportResult
from engine.json.pack_builder import PackManifest
from models.asset import Asset, AssetStatus
from models.project import Project


class ExportController:
    """Orchestrates asset export and pack generation."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def export_approved_assets(
        self,
        options: Optional[ExportOptions] = None,
    ) -> ExportResult:
        assets = self._app.assets.get_all(status=AssetStatus.APPROVED)
        return self._app.exporter.export_assets(assets, options)

    def export_project(
        self,
        project_id: int,
        options: Optional[ExportOptions] = None,
    ) -> ExportResult:
        assets = self._app.assets.get_all(project_id=project_id)
        approved = [
            a for a in assets
            if a.status in (AssetStatus.APPROVED, AssetStatus.EXPORTED)
        ]

        result = self._app.exporter.export_assets(approved, options)

        if result.success and result.output_dir:
            self._build_project_pack(project_id, result.output_dir)

        return result

    def _build_project_pack(
        self,
        project_id: int,
        output_dir: Path,
    ) -> Optional[PackManifest]:
        project = self._app.projects.get_by_id(project_id)
        if project is None:
            return None

        categories = self._app.categories.get_all(project_id)
        assets = self._app.assets.get_all(project_id)

        manifest = self._app.pack_builder.build_manifest(
            project,
            categories,
            assets,
        )

        self._app.pack_builder.save_manifest(
            manifest,
            output_dir / "pack.json",
        )

        return manifest

    def get_exportable_assets(
        self,
        project_id: Optional[int] = None,
    ) -> List[Asset]:
        return self._app.assets.get_all(
            project_id=project_id,
            status=AssetStatus.APPROVED,
        )

    def get_projects_with_assets(self) -> List[Project]:
        """Return projects that contain at least one asset."""
        projects = self._app.projects.get_all()
        result: List[Project] = []

        for project in projects:
            assets = self._app.assets.get_all(project_id=project.id)
            if assets:
                result.append(project)

        return result