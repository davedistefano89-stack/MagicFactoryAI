"""Batch asset export for Magic Colors Adventure integration."""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from engine.generator.image_processor import ImageProcessor
from models.asset import Asset, AssetStatus
from utils.logger import get_logger
from utils.paths import get_exports_dir

logger = get_logger(__name__)


@dataclass
class ExportOptions:
    output_dir: Optional[Path] = None
    format: str = "png"
    dpi: int = 300
    include_thumbnails: bool = True
    include_manifest: bool = True
    resize_width: Optional[int] = None
    resize_height: Optional[int] = None


@dataclass
class ExportResult:
    success: bool
    exported_count: int = 0
    failed_count: int = 0
    output_dir: Optional[Path] = None
    manifest_path: Optional[Path] = None
    errors: List[str] = field(default_factory=list)


class AssetExporter:
    """Exports approved assets into game-ready packages."""

    SUPPORTED_FORMATS = {"png", "jpg", "webp"}

    def __init__(self) -> None:
        self._processor = ImageProcessor()

    def export_assets(
        self,
        assets: List[Asset],
        options: Optional[ExportOptions] = None,
    ) -> ExportResult:
        opts = options or ExportOptions()
        output_dir = opts.output_dir or (
            get_exports_dir() / datetime.now().strftime("%Y%m%d_%H%M%S")
        )
        output_dir.mkdir(parents=True, exist_ok=True)

        result = ExportResult(success=True, output_dir=output_dir)
        exported_entries: list[dict] = []

        for asset in assets:
            if not asset.file_path or not Path(asset.file_path).exists():
                result.failed_count += 1
                result.errors.append(f"Missing file for asset '{asset.name}'")
                continue

            try:
                src = Path(asset.file_path)
                dest_name = f"{self._sanitize_filename(asset.name)}.{opts.format}"
                dest = output_dir / dest_name

                if opts.resize_width and opts.resize_height:
                    proc = self._processor.resize(src, dest, opts.resize_width, opts.resize_height)
                    if not proc.success:
                        raise RuntimeError(proc.error)
                else:
                    shutil.copy2(src, dest)

                entry = {
                    "id": asset.id,
                    "name": asset.name,
                    "file": dest_name,
                    "width": asset.width,
                    "height": asset.height,
                    "category_id": asset.category_id,
                }

                if opts.include_thumbnails:
                    thumb_dir = output_dir / "thumbnails"
                    thumb_path = thumb_dir / f"{self._sanitize_filename(asset.name)}_thumb.png"
                    thumb_result = self._processor.create_thumbnail(src, thumb_path)
                    if thumb_result.success:
                        entry["thumbnail"] = str(thumb_path.relative_to(output_dir))

                exported_entries.append(entry)
                result.exported_count += 1

            except Exception as exc:
                result.failed_count += 1
                result.errors.append(f"Failed to export '{asset.name}': {exc}")
                logger.exception("Export failed for asset %s", asset.name)

        if opts.include_manifest and exported_entries:
            manifest_path = output_dir / "manifest.json"
            manifest = {
                "exported_at": datetime.now().isoformat(),
                "format": opts.format,
                "dpi": opts.dpi,
                "asset_count": result.exported_count,
                "assets": exported_entries,
            }
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=2)
            result.manifest_path = manifest_path

        result.success = result.failed_count == 0
        logger.info(
            "Export complete: %d exported, %d failed → %s",
            result.exported_count,
            result.failed_count,
            output_dir,
        )
        return result

    def export_approved(
        self,
        assets: List[Asset],
        options: Optional[ExportOptions] = None,
    ) -> ExportResult:
        approved = [a for a in assets if a.status == AssetStatus.APPROVED]
        return self.export_assets(approved, options)

    @staticmethod
    def _sanitize_filename(name: str) -> str:
        safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in name)
        return safe.strip("_") or "asset"
