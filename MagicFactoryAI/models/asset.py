"""Asset domain model."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class AssetStatus(str, Enum):
    PENDING = "pending"
    GENERATED = "generated"
    APPROVED = "approved"
    REJECTED = "rejected"
    EXPORTED = "exported"


@dataclass
class Asset:
    """A generated or imported coloring book asset."""

    name: str
    file_path: str = ""
    thumbnail_path: str = ""
    status: AssetStatus = AssetStatus.PENDING
    width: int = 0
    height: int = 0
    id: Optional[int] = None
    project_id: Optional[int] = None
    category_id: Optional[int] = None
    prompt_id: Optional[int] = None
    metadata_json: str = "{}"
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "file_path": self.file_path,
            "thumbnail_path": self.thumbnail_path,
            "status": self.status.value,
            "width": self.width,
            "height": self.height,
            "project_id": self.project_id,
            "category_id": self.category_id,
            "prompt_id": self.prompt_id,
            "metadata_json": self.metadata_json,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    @classmethod
    def from_row(cls, row: dict) -> Asset:
        return cls(
            id=row["id"],
            name=row["name"],
            file_path=row.get("file_path") or "",
            thumbnail_path=row.get("thumbnail_path") or "",
            status=AssetStatus(row["status"]),
            width=row.get("width") or 0,
            height=row.get("height") or 0,
            project_id=row.get("project_id"),
            category_id=row.get("category_id"),
            prompt_id=row.get("prompt_id"),
            metadata_json=row.get("metadata_json") or "{}",
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
        )
