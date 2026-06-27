"""Category management controller."""

from __future__ import annotations

from typing import List, Optional

from app.controllers.app_controller import AppController
from core.theme.colors import Colors
from models.category import Category


class CategoryController:
    """CRUD operations for categories."""

    def __init__(self, app: AppController) -> None:
        self._app = app

    def create_category(
        self,
        name: str,
        project_id: Optional[int] = None,
        color: Optional[str] = None,
    ) -> Category:
        existing = self._app.categories.get_all(project_id)
        palette = Colors.category_palette()
        color = color or palette[len(existing) % len(palette)]
        category = Category(
            name=name,
            color=color,
            sort_order=len(existing),
            project_id=project_id,
        )
        return self._app.categories.create(category)

    def update_category(self, category: Category) -> Category:
        return self._app.categories.update(category)

    def delete_category(self, category_id: int) -> None:
        self._app.categories.delete(category_id)

    def get_all(self, project_id: Optional[int] = None) -> List[Category]:
        return self._app.categories.get_all(project_id)

    def get_by_id(self, category_id: int) -> Optional[Category]:
        return self._app.categories.get_by_id(category_id)
