"""Prompt management controller."""

from __future__ import annotations

from typing import List, Optional

from app.controllers.app_controller import AppController
from models.prompt import Prompt, PromptType


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

        return self._app.prompts.create(prompt)

    def update_prompt(self, prompt: Prompt) -> Prompt:
        return self._app.prompts.update(prompt)

    def delete_prompt(self, prompt_id: int) -> None:
        self._app.prompts.delete(prompt_id)

    def get_all(
        self,
        category_id: Optional[int] = None,
        project_id: Optional[int] = None,
    ):

        prompts = self._app.prompts.get_all()

        print("PROMPTS:", len(prompts))

        for p in prompts:
            print(p.id, p.title)

        return prompts

    def search(
        self,
        query: str,
        category_id: Optional[int] = None,
        project_id: Optional[int] = None,
    ) -> List[Prompt]:
        return self._app.prompts.search(query, category_id, project_id)

    def toggle_favorite(self, prompt_id: int) -> Optional[Prompt]:

        prompt = self._app.prompts.get_by_id(prompt_id)

        if prompt:
            prompt.is_favorite = not prompt.is_favorite
            return self._app.prompts.update(prompt)

        return None