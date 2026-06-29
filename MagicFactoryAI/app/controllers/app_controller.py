"""Root application controller — wires services and navigation."""

from __future__ import annotations

from typing import Optional

from app.controllers.ai_generator_controller import AIGeneratorController
from app.controllers.batch_controller import BatchController
from app.controllers.workspace_controller import WorkspaceController

from core.ai.ai_manager import AIManager
from core.ai.provider_factory import AIProviderFactory

from core.database.connection import DatabaseConnection
from core.database.repositories import (
    AssetRepository,
    CategoryRepository,
    ProjectRepository,
    PromptRepository,
)

from core.settings.manager import SettingsManager

from engine.export.exporter import AssetExporter
from engine.generator.image_processor import ImageProcessor
from engine.generator.queue_manager import QueueManager
from engine.json.pack_builder import PackBuilder

from services.openai_service import OpenAIService

from utils.logger import get_logger

logger = get_logger(__name__)


class AppController:
    """
    Central application controller.
    """

    _instance: Optional["AppController"] = None

    def __init__(self) -> None:

        self.settings = SettingsManager.instance()

        self.db = DatabaseConnection.instance()
        self.db.initialize()

        # -------------------------------------------------
        # DATABASE REPOSITORIES
        # -------------------------------------------------

        self.projects = ProjectRepository(self.db)
        self.categories = CategoryRepository(self.db)
        self.prompts = PromptRepository(self.db)
        self.assets = AssetRepository(self.db)

        # -------------------------------------------------
        # ENGINES
        # -------------------------------------------------

        self.image_processor = ImageProcessor(
            line_thickness=int(
                self.settings.get(
                    "generator.line_thickness",
                    2,
                )
            )
        )

        self.exporter = AssetExporter()
        self.pack_builder = PackBuilder()

        # -------------------------------------------------
        # AI
        # -------------------------------------------------

        # Allow switching provider via settings (default: openai)
        provider_name = str(self.settings.get("ai.provider", "openai"))
        self.ai_provider = AIProviderFactory.create(provider_name)
        self.ai_manager = AIManager(self.ai_provider)

        self.queue_manager = QueueManager()

        # -------------------------------------------------
        # OPENAI (legacy compatibility)
        # -------------------------------------------------

        try:

            self.openai_service = OpenAIService()

            logger.info(
                "OpenAI Service initialized."
            )

        except Exception as exc:

            logger.exception(exc)

            self.openai_service = None

        # -------------------------------------------------
        # CONTROLLERS
        # -------------------------------------------------

        self.workspace = WorkspaceController(self)

        self.ai_generator = AIGeneratorController(
            self,
        )

        self.batch_controller = BatchController(
            self,
            self.ai_manager,
        )

        logger.info(
            "Application initialized."
        )

    @classmethod
    def instance(cls) -> "AppController":

        if cls._instance is None:
            cls._instance = cls()

        return cls._instance

    @property
    def openai_enabled(self) -> bool:

        return self.openai_service is not None

    def generate_ai_image(
        self,
        category: str,
        subject: str,
        project_id: int,
        category_id: int | None = None,
        prompt_id: int | None = None,
        age: str = "3-6",
        complexity: str = "simple",
    ):

        if self.openai_service is None:
            raise RuntimeError(
                "OpenAI service not available."
            )

        return self.ai_generator.generate(
            category=category,
            subject=subject,
            project_id=project_id,
            category_id=category_id,
            prompt_id=prompt_id,
            age=age,
            complexity=complexity,
        )

    def shutdown(self) -> None:

        self.db.close()

        logger.info(
            "Application shutdown."
        )