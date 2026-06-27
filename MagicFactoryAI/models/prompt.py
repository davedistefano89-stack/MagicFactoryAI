"""Prompt domain model."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class PromptType(str, Enum):
    CHARACTER = "character"
    SCENE = "scene"
    OBJECT = "object"
    BACKGROUND = "background"
    CUSTOM = "custom"


@dataclass
class Prompt:
    """Reusable prompt template for asset generation."""

    title: str
    content: str
    prompt_type: PromptType = PromptType.CUSTOM
    tags: str = ""
    is_favorite: bool = False
    id: Optional[int] = None
    category_id: Optional[int] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "content": self.content,
            "prompt_type": self.prompt_type.value,
            "tags": self.tags,
            "is_favorite": self.is_favorite,
            "category_id": self.category_id,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    @classmethod
    def from_row(cls, row: dict) -> Prompt:
        return cls(
            id=row["id"],
            title=row["title"],
            content=row["content"],
            prompt_type=PromptType(row["prompt_type"]),
            tags=row.get("tags") or "",
            is_favorite=bool(row.get("is_favorite")),
            category_id=row.get("category_id"),
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
        )
