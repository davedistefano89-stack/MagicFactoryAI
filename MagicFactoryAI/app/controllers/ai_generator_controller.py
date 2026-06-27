# File:
# app/controllers/ai_generator_controller.py

from __future__ import annotations

from uuid import uuid4

from models.asset import Asset, AssetStatus
from services.openai_service import OpenAIService
from utils.paths import get_library_dir


class AIGeneratorController:
    def __init__(self, app):
        self._app = app
        self._service = OpenAIService()

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

        image_path = self._service.generate_coloring_page(
            category=category,
            subject=subject,
            output_folder=library,
            filename=filename,
            age=age,
            complexity=complexity,
        )

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