"""Asset library controller."""

from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from app.controllers.app_controller import AppController
from models.asset import Asset, AssetStatus
from utils.paths import get_library_dir


class AssetController:
    """CRUD and file operations for assets."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def import_asset(
        self,
        source_path: Path,
        name: str,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
    ) -> Asset:
        library_dir = get_library_dir()
        dest = library_dir / source_path.name
        counter = 1
        while dest.exists():
            dest = library_dir / f"{source_path.stem}_{counter}{source_path.suffix}"
            counter += 1

        import shutil
        shutil.copy2(source_path, dest)

        width, height = self._app.image_processor.get_dimensions(dest)
        thumb_path = library_dir / "thumbs" / f"{dest.stem}_thumb.png"
        self._app.image_processor.create_thumbnail(dest, thumb_path)

        asset = Asset(
            name=name,
            file_path=str(dest),
            thumbnail_path=str(thumb_path) if thumb_path.exists() else "",
            status=AssetStatus.GENERATED,
            width=width,
            height=height,
            project_id=project_id,
            category_id=category_id,
        )
        return self._app.assets.create(asset)

    def update_asset(self, asset: Asset) -> Asset:
        return self._app.assets.update(asset)

    def delete_asset(self, asset_id: int) -> None:
        asset = self._app.assets.get_by_id(asset_id)
        if asset:
            for path_str in (asset.file_path, asset.thumbnail_path):
                if path_str:
                    p = Path(path_str)
                    if p.exists():
                        p.unlink()
        self._app.assets.delete(asset_id)

    def get_all(
        self,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
        status: Optional[AssetStatus] = None,
    ) -> List[Asset]:
        return self._app.assets.get_all(project_id, category_id, status)

    def approve_asset(self, asset_id: int) -> Optional[Asset]:
        asset = self._app.assets.get_by_id(asset_id)
        if asset:
            asset.status = AssetStatus.APPROVED
            return self._app.assets.update(asset)
        return None

    def reject_asset(self, asset_id: int) -> Optional[Asset]:
        asset = self._app.assets.get_by_id(asset_id)
        if asset:
            asset.status = AssetStatus.REJECTED
            return self._app.assets.update(asset)
        return None
