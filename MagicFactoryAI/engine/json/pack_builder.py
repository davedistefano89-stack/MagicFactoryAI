"""Builds JSON asset packs for Magic Colors Adventure."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, List, Optional

from models.asset import Asset
from models.category import Category
from models.project import Project
from utils.logger import get_logger

logger = get_logger(__name__)


@dataclass
class PackManifest:
    version: str = "1.0"
    game: str = "Magic Colors Adventure"
    project_name: str = ""
    project_id: Optional[int] = None
    generated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    categories: List[dict] = field(default_factory=list)
    assets: List[dict] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "version": self.version,
            "game": self.game,
            "project": {
                "id": self.project_id,
                "name": self.project_name,
            },
            "generated_at": self.generated_at,
            "categories": self.categories,
            "assets": self.assets,
        }


class PackBuilder:
    """Assembles structured JSON packs from projects, categories, and assets."""

    def build_manifest(
        self,
        project: Project,
        categories: List[Category],
        assets: List[Asset],
    ) -> PackManifest:
        manifest = PackManifest(
            project_name=project.name,
            project_id=project.id,
        )

        category_map = {c.id: c for c in categories if c.id is not None}

        manifest.categories = [
            {
                "id": cat.id,
                "name": cat.name,
                "color": cat.color,
                "icon": cat.icon,
                "sort_order": cat.sort_order,
            }
            for cat in sorted(categories, key=lambda c: c.sort_order)
        ]

        manifest.assets = []
        for asset in assets:
            cat = category_map.get(asset.category_id)
            manifest.assets.append({
                "id": asset.id,
                "name": asset.name,
                "file": Path(asset.file_path).name if asset.file_path else "",
                "thumbnail": Path(asset.thumbnail_path).name if asset.thumbnail_path else "",
                "status": asset.status.value,
                "width": asset.width,
                "height": asset.height,
                "category": {
                    "id": cat.id,
                    "name": cat.name,
                } if cat else None,
                "metadata": self._parse_metadata(asset.metadata_json),
            })

        return manifest

    def save_manifest(self, manifest: PackManifest, output_path: Path) -> Path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(manifest.to_dict(), f, indent=2, ensure_ascii=False)
        logger.info("Pack manifest saved: %s", output_path)
        return output_path

    def load_manifest(self, path: Path) -> PackManifest:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        manifest = PackManifest(
            version=data.get("version", "1.0"),
            game=data.get("game", "Magic Colors Adventure"),
            project_name=data.get("project", {}).get("name", ""),
            project_id=data.get("project", {}).get("id"),
            generated_at=data.get("generated_at", datetime.now().isoformat()),
            categories=data.get("categories", []),
            assets=data.get("assets", []),
        )
        return manifest

    @staticmethod
    def _parse_metadata(metadata_json: str) -> dict:
        try:
            return json.loads(metadata_json) if metadata_json else {}
        except json.JSONDecodeError:
            return {}
