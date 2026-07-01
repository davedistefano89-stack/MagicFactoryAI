"""Prompt management controller."""

from __future__ import annotations

from typing import List, Optional

from app.controllers.app_controller import AppController
from models.prompt import Prompt, PromptType
from utils.logger import get_logger

logger = get_logger(__name__)


class PromptController:
    """CRUD and search operations for prompts."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def create_prompt(
        self,
        title: str,
        content: str,
        prompt_type: PromptType | str = PromptType.CUSTOM,
        tags: str = "",
        category_id: Optional[int] = None,
    ) -> Prompt:

        if isinstance(prompt_type, str):
            prompt_type = PromptType(prompt_type)

        prompt = Prompt(
            title=title,
            content=content,
            prompt_type=prompt_type,
            tags=tags,
            category_id=category_id,
        )

        created = self._app.prompts.create(prompt)

        logger.info("Prompt created: %s", created.title)

        return created

    def update_prompt(self, prompt: Prompt) -> Prompt:
        updated = self._app.prompts.update(prompt)
        logger.info("Prompt updated: %s", updated.title)
        return updated

    def delete_prompt(self, prompt_id: int) -> None:
        self._app.prompts.delete(prompt_id)
        logger.info("Prompt deleted: %s", prompt_id)

    def get_all(
        self,
        category_id: Optional[int] = None,
        project_id: Optional[int] = None,
    ) -> List[Prompt]:

        prompts = self._app.prompts.get_all()

        logger.debug("Loaded %d prompts.", len(prompts))

        return prompts

    def search(
        self,
        query: str,
        category_id: Optional[int] = None,
        project_id: Optional[int] = None,
    ) -> List[Prompt]:

        results = self._app.prompts.search(
            query,
            category_id,
            project_id,
        )

        logger.debug(
            "Prompt search '%s' returned %d results.",
            query,
            len(results),
        )

        return results

    def toggle_favorite(
        self,
        prompt_id: int,
    ) -> Optional[Prompt]:

        prompt = self._app.prompts.get_by_id(prompt_id)

        if prompt:
            prompt.is_favorite = not prompt.is_favorite
            updated = self._app.prompts.update(prompt)

            logger.info(
                "Prompt '%s' favorite=%s",
                updated.title,
                updated.is_favorite,
            )

            return updated

        return None

    # ── Sprint: Global Undo / Redo helpers ──────────────────────────────────
    # Small closure-friendly helpers so undo / redo lambdas can call them.

    def set_collections(self, prompt_id: int, collections: list[str]) -> bool:
        """Update only the collections field of a prompt's tags string."""
        prompt = self._app.prompts.get_by_id(prompt_id)
        if prompt is None:
            return False
        from ui.widgets.prompt_collection_utils import (
            get_prompt_collections,
            set_prompt_collections,
        )
        current = get_prompt_collections(prompt)
        if [c.lower() for c in current] == [c.lower() for c in collections]:
            return True
        set_prompt_collections(prompt, collections)
        self._app.prompts.update(prompt)
        return True

    def save_prompt(
        self,
        prompt_id: int,
        title: str,
        content: str,
        prompt_type: PromptType,
        tags: str,
    ) -> bool:
        """Update the editable fields of an existing prompt."""
        prompt = self._app.prompts.get_by_id(prompt_id)
        if prompt is None:
            return False
        # No-op if nothing actually changed.
        if (
            prompt.title == title
            and prompt.content == content
            and prompt.prompt_type == prompt_type
            and prompt.tags == tags
        ):
            return True
        prompt.title = title
        prompt.content = content
        prompt.prompt_type = prompt_type
        prompt.tags = tags
        self._app.prompts.update(prompt)
        return True