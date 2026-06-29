# File:
# app/controllers/ai_generator_controller.py

from __future__ import annotations

import json
from datetime import datetime
from uuid import uuid4
from pathlib import Path

from core.ai.ai_manager import AIManager
from core.ai.models import AIRequest, AIResult
from models.asset import Asset, AssetStatus
from utils.paths import get_library_dir


class AIGeneratorController:
    def __init__(self, app):
        self._app = app
        self._ai_manager: AIManager = app.ai_manager

    def _build_metadata(
        self,
        request: AIRequest,
        result: AIResult | None,
        width: int,
        height: int,
    ) -> str:
        return json.dumps(
            {
                "provider": result.provider if result else request.provider,
                "model": result.model if result else request.model,
                "prompt": request.prompt,
                "negative_prompt": request.negative_prompt,
                "width": width,
                "height": height,
                "created_at": datetime.now().isoformat(),
            }
        )

    def generate(
        self,
        category: str,
        subject: str,
        project_id: int,
        category_id: int | None = None,
        prompt_id: int | None = None,
        age: str = "3-6",
        complexity: str = "simple",
    ) -> Asset:

        library = get_library_dir()

        thumbs = library / "thumbs"
        thumbs.mkdir(parents=True, exist_ok=True)

        filename = f"{uuid4().hex}.png"
        image_path = library / filename

        request = AIRequest(
            image_path=library,
            prompt=(
                f"Category: {category}\n"
                f"Subject: {subject}\n"
                f"Age: {age}\n"
                f"Complexity: {complexity}"
            ),
        )

        result = self._ai_manager.generate(request)

        if not result.success or not result.image_bytes:
            raise RuntimeError(result.error or "Image generation failed")

        with open(image_path, "wb") as file:
            file.write(result.image_bytes)

        thumb_path = thumbs / f"{image_path.stem}_thumb.png"

        self._app.image_processor.create_thumbnail(
            image_path,
            thumb_path,
        )

        width, height = self._app.image_processor.get_dimensions(image_path)

        asset = Asset(
            name=subject,
            file_path=str(image_path),
            thumbnail_path=str(thumb_path),
            status=AssetStatus.GENERATED,
            width=width,
            height=height,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
            metadata_json=self._build_metadata(request, result, width, height),
        )

        return self._app.assets.create(asset)

    def create_asset_from_bytes(
        self,
        category: str,
        subject: str,
        image_bytes: bytes,
        project_id: int,
        category_id: int | None = None,
        prompt_id: int | None = None,
        output_directory: Path | None = None,
        request: AIRequest | None = None,
        result: AIResult | None = None,
    ) -> Asset:
        """Create asset and thumbnail from raw image bytes."""

        library = Path(output_directory or get_library_dir())
        thumbs = library / "thumbs"
        thumbs.mkdir(parents=True, exist_ok=True)

        filename = f"{uuid4().hex}.png"
        image_path = library / filename

        with open(image_path, "wb") as file:
            file.write(image_bytes)

        thumb_path = thumbs / f"{image_path.stem}_thumb.png"

        self._app.image_processor.create_thumbnail(
            image_path,
            thumb_path,
        )

        width, height = self._app.image_processor.get_dimensions(
            image_path,
        )

        asset = Asset(
            name=subject,
            file_path=str(image_path),
            thumbnail_path=str(thumb_path),
            status=AssetStatus.GENERATED,
            width=width,
            height=height,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
            metadata_json=self._build_metadata(
                request
                or AIRequest(
                    image_path=library,
                    prompt=subject,
                    category=category,
                ),
                result,
                width,
                height,
            ),
        )

        return self._app.assets.create(asset)

    def generate_princess(
        self,
        subject: str,
        project_id: int,
        category_id: int | None = None,
    ) -> Asset:
        return self.generate(
            category="Princess",
            subject=subject,
            project_id=project_id,
            category_id=category_id,
        )

    def generate_unicorn(
        self,
        subject: str,
        project_id: int,
        category_id: int | None = None,
    ) -> Asset:
        return self.generate(
            category="Unicorn",
            subject=subject,
            project_id=project_id,
            category_id=category_id,
        )

    def generate_animal(
        self,
        subject: str,
        project_id: int,
        category_id: int | None = None,
    ) -> Asset:
        return self.generate(
            category="Animals",
            subject=subject,
            project_id=project_id,
            category_id=category_id,
        )

    def generate_vehicle(
        self,
        subject: str,
        project_id: int,
        category_id: int | None = None,
    ) -> Asset:
        return self.generate(
            category="Vehicles",
            subject=subject,
            project_id=project_id,
            category_id=category_id,
        )
