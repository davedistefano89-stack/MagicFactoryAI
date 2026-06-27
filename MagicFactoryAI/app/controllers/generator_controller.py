"""Asset generation controller for the workspace generator tab."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from app.controllers.app_controller import AppController
from models.asset import Asset, AssetStatus
from utils.paths import get_library_dir


class GeneratorController:
    """Generates coloring book assets from source images and prompts."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def generate_from_image(
        self,
        source_path: Path,
        name: str,
        project_id: int,
        category_id: Optional[int] = None,
        prompt_id: Optional[int] = None,
        threshold: int = 128,
    ) -> Asset:
        library_dir = get_library_dir()
        output_name = f"{source_path.stem}_lineart.png"
        output_path = library_dir / output_name
        counter = 1
        while output_path.exists():
            output_path = library_dir / f"{source_path.stem}_lineart_{counter}.png"
            counter += 1

        result = self._app.image_processor.convert_to_line_art(
            source_path, output_path, threshold=threshold,
        )
        if not result.success or not result.output_path:
            raise RuntimeError(result.error or "Line art conversion failed")

        thumb_path = library_dir / "thumbs" / f"{output_path.stem}_thumb.png"
        self._app.image_processor.create_thumbnail(result.output_path, thumb_path)

        asset = Asset(
            name=name,
            file_path=str(result.output_path),
            thumbnail_path=str(thumb_path) if thumb_path.exists() else "",
            status=AssetStatus.GENERATED,
            width=result.width,
            height=result.height,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
        )
        return self._app.assets.create(asset)
