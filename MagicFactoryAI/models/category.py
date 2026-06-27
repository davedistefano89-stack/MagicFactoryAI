"""Category domain model."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class Category:
    """Organizes coloring book assets into themed groups."""

    name: str
    color: str = "#6366F1"
    icon: str = "folder"
    sort_order: int = 0
    id: Optional[int] = None
    project_id: Optional[int] = None
    created_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "color": self.color,
            "icon": self.icon,
            "sort_order": self.sort_order,
            "project_id": self.project_id,
            "created_at": self.created_at.isoformat(),
        }

    @classmethod
    def from_row(cls, row: dict) -> Category:
        return cls(
            id=row["id"],
            name=row["name"],
            color=row.get("color") or "#6366F1",
            icon=row.get("icon") or "folder",
            sort_order=row.get("sort_order") or 0,
            project_id=row.get("project_id"),
            created_at=datetime.fromisoformat(row["created_at"]),
        )
