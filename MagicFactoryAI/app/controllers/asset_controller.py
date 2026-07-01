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

    # ── Sprint: Performance Optimizer — pagination helpers ──
    # These do not touch the schema; they just expose the new
    # LIMIT/OFFSET repository methods that let the library tab
    # stream thousands of assets lazily.

    def count(
        self,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
        status: Optional[AssetStatus] = None,
    ) -> int:
        return self._app.assets.count(project_id, category_id, status)

    def get_page(
        self,
        limit: int,
        offset: int,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
        status: Optional[AssetStatus] = None,
    ) -> List[Asset]:
        return self._app.assets.get_page(
            limit, offset, project_id, category_id, status
        )

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

    # ── Sprint: Global Undo / Redo helpers ──────────────────────────────────
    # These helpers are intentionally small so they can be the body of an
    # undo / redo closure. They re-fetch from the DB each call so they
    # are safe to invoke multiple times in arbitrary order.

    def set_status(self, asset_id: int, status: AssetStatus) -> bool:
        """Set ``asset.status`` and persist. Returns True on success."""
        asset = self._app.assets.get_by_id(asset_id)
        if asset is None:
            return False
        if asset.status == status:
            # No-op write; harmless but skip DB roundtrip.
            return True
        asset.status = status
        self._app.assets.update(asset)
        return True

    def set_tags(self, asset_id: int, tags: list[str]) -> bool:
        """Update only the tags field of an asset's metadata_json."""
        asset = self._app.assets.get_by_id(asset_id)
        if asset is None:
            return False
        from ui.widgets.tag_utils import get_tags, set_tags as _set_tags
        current = get_tags(asset)
        if [t.lower() for t in current] == [t.lower() for t in tags]:
            return True
        _set_tags(asset, tags)
        self._app.assets.update(asset)
        return True

    def set_collections(self, asset_id: int, collections: list[str]) -> bool:
        """Update only the collections field of an asset's metadata_json."""
        asset = self._app.assets.get_by_id(asset_id)
        if asset is None:
            return False
        from ui.widgets.tag_utils import get_collections, set_collections as _set_collections
        current = get_collections(asset)
        if [c.lower() for c in current] == [c.lower() for c in collections]:
            return True
        _set_collections(asset, collections)
        self._app.assets.update(asset)
        return True

    def add_collection_bulk(
        self, asset_ids: list[int], collection: str
    ) -> list[tuple[int, list[str]]]:
        """Add ``collection`` to each asset; return old-value pairs for undo.

        Each tuple is ``(asset_id, old_collection_list)``.
        """
        from ui.widgets.tag_utils import (
            get_collections,
            set_collections as _set_collections,
        )
        snapshots: list[tuple[int, list[str]]] = []
        for aid in asset_ids:
            asset = self._app.assets.get_by_id(aid)
            if asset is None:
                continue
            current = get_collections(asset)
            if any(c.lower() == collection.lower() for c in current):
                snapshots.append((aid, list(current)))
                continue
            updated = list(current) + [collection]
            _set_collections(asset, updated)
            self._app.assets.update(asset)
            snapshots.append((aid, list(current)))
        return snapshots

    def remove_collection_bulk(
        self, asset_ids: list[int], collection: str
    ) -> list[tuple[int, list[str]]]:
        """Remove ``collection`` from each asset; return old-value pairs."""
        from ui.widgets.tag_utils import (
            get_collections,
            set_collections as _set_collections,
        )
        snapshots: list[tuple[int, list[str]]] = []
        for aid in asset_ids:
            asset = self._app.assets.get_by_id(aid)
            if asset is None:
                continue
            current = get_collections(asset)
            if not any(c.lower() == collection.lower() for c in current):
                snapshots.append((aid, list(current)))
                continue
            updated = [c for c in current if c.lower() != collection.lower()]
            _set_collections(asset, updated)
            self._app.assets.update(asset)
            snapshots.append((aid, list(current)))
        return snapshots

    def rename_collection_bulk(
        self, asset_ids: list[int], old_name: str, new_name: str
    ) -> list[tuple[int, str]]:
        """Rename ``old_name`` → ``new_name`` on each asset; return old values.

        Each tuple is ``(asset_id, old_collection_list)`` so undo can put
        every asset back into its exact pre-rename collection set.
        """
        from ui.widgets.tag_utils import (
            get_collections,
            set_collections as _set_collections,
        )
        snapshots: list[tuple[int, list[str]]] = []
        for aid in asset_ids:
            asset = self._app.assets.get_by_id(aid)
            if asset is None:
                continue
            current = get_collections(asset)
            if not any(c.lower() == old_name.lower() for c in current):
                snapshots.append((aid, list(current)))
                continue
            updated = [
                new_name if c.lower() == old_name.lower() else c
                for c in current
            ]
            _set_collections(asset, updated)
            self._app.assets.update(asset)
            snapshots.append((aid, list(current)))
        return snapshots
