"""Data access repositories for domain models."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from core.database.connection import DatabaseConnection
from models.asset import Asset, AssetStatus
from models.category import Category
from models.project import Project, ProjectStatus
from models.prompt import Prompt, PromptType


class ProjectRepository:
    def __init__(self, db: DatabaseConnection) -> None:
        self._db = db

    def create(self, project: Project) -> Project:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            cursor = conn.execute(
                """
                INSERT INTO projects (name, description, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (project.name, project.description, project.status.value, now, now),
            )
            project.id = cursor.lastrowid
            project.created_at = datetime.fromisoformat(now)
            project.updated_at = datetime.fromisoformat(now)
        return project

    def update(self, project: Project) -> Project:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            conn.execute(
                """
                UPDATE projects
                SET name = ?, description = ?, status = ?, updated_at = ?
                WHERE id = ?
                """,
                (project.name, project.description, project.status.value, now, project.id),
            )
            project.updated_at = datetime.fromisoformat(now)
        return project

    def delete(self, project_id: int) -> None:
        with self._db.transaction() as conn:
            conn.execute("DELETE FROM projects WHERE id = ?", (project_id,))

    def get_by_id(self, project_id: int) -> Optional[Project]:
        conn = self._db.connect()
        row = conn.execute("SELECT * FROM projects WHERE id = ?", (project_id,)).fetchone()
        return Project.from_row(dict(row)) if row else None

    def get_all(self) -> List[Project]:
        conn = self._db.connect()
        rows = conn.execute("SELECT * FROM projects ORDER BY updated_at DESC").fetchall()
        return [Project.from_row(dict(r)) for r in rows]

    def count(self) -> int:
        conn = self._db.connect()
        row = conn.execute("SELECT COUNT(*) as cnt FROM projects").fetchone()
        return int(row["cnt"])


class CategoryRepository:
    def __init__(self, db: DatabaseConnection) -> None:
        self._db = db

    def create(self, category: Category) -> Category:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            cursor = conn.execute(
                """
                INSERT INTO categories (name, color, icon, sort_order, project_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    category.name,
                    category.color,
                    category.icon,
                    category.sort_order,
                    category.project_id,
                    now,
                ),
            )
            category.id = cursor.lastrowid
            category.created_at = datetime.fromisoformat(now)
        return category

    def update(self, category: Category) -> Category:
        with self._db.transaction() as conn:
            conn.execute(
                """
                UPDATE categories
                SET name = ?, color = ?, icon = ?, sort_order = ?, project_id = ?
                WHERE id = ?
                """,
                (
                    category.name,
                    category.color,
                    category.icon,
                    category.sort_order,
                    category.project_id,
                    category.id,
                ),
            )
        return category

    def delete(self, category_id: int) -> None:
        with self._db.transaction() as conn:
            conn.execute("DELETE FROM categories WHERE id = ?", (category_id,))

    def get_by_id(self, category_id: int) -> Optional[Category]:
        conn = self._db.connect()
        row = conn.execute("SELECT * FROM categories WHERE id = ?", (category_id,)).fetchone()
        return Category.from_row(dict(row)) if row else None

    def get_all(self, project_id: Optional[int] = None) -> List[Category]:
        conn = self._db.connect()
        if project_id is not None:
            rows = conn.execute(
                "SELECT * FROM categories WHERE project_id = ? ORDER BY sort_order, name",
                (project_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM categories ORDER BY sort_order, name"
            ).fetchall()
        return [Category.from_row(dict(r)) for r in rows]

    def count(self) -> int:
        conn = self._db.connect()
        row = conn.execute("SELECT COUNT(*) as cnt FROM categories").fetchone()
        return int(row["cnt"])


class PromptRepository:
    def __init__(self, db: DatabaseConnection) -> None:
        self._db = db

    def create(self, prompt: Prompt) -> Prompt:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            cursor = conn.execute(
                """
                INSERT INTO prompts
                (title, content, prompt_type, tags, is_favorite, category_id, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    prompt.title,
                    prompt.content,
                    prompt.prompt_type.value,
                    prompt.tags,
                    int(prompt.is_favorite),
                    prompt.category_id,
                    now,
                    now,
                ),
            )
            prompt.id = cursor.lastrowid
            prompt.created_at = datetime.fromisoformat(now)
            prompt.updated_at = datetime.fromisoformat(now)
        return prompt

    def update(self, prompt: Prompt) -> Prompt:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            conn.execute(
                """
                UPDATE prompts
                SET title = ?, content = ?, prompt_type = ?, tags = ?,
                    is_favorite = ?, category_id = ?, updated_at = ?
                WHERE id = ?
                """,
                (
                    prompt.title,
                    prompt.content,
                    prompt.prompt_type.value,
                    prompt.tags,
                    int(prompt.is_favorite),
                    prompt.category_id,
                    now,
                    prompt.id,
                ),
            )
            prompt.updated_at = datetime.fromisoformat(now)
        return prompt

    def delete(self, prompt_id: int) -> None:
        with self._db.transaction() as conn:
            conn.execute("DELETE FROM prompts WHERE id = ?", (prompt_id,))

    def get_by_id(self, prompt_id: int) -> Optional[Prompt]:
        conn = self._db.connect()
        row = conn.execute("SELECT * FROM prompts WHERE id = ?", (prompt_id,)).fetchone()
        return Prompt.from_row(dict(row)) if row else None

    def get_all(self, category_id: Optional[int] = None) -> List[Prompt]:
        conn = self._db.connect()
        if category_id is not None:
            rows = conn.execute(
                "SELECT * FROM prompts WHERE category_id = ? ORDER BY updated_at DESC",
                (category_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM prompts ORDER BY updated_at DESC"
            ).fetchall()
        return [Prompt.from_row(dict(r)) for r in rows]

    def get_by_project(self, project_id: int) -> List[Prompt]:
        conn = self._db.connect()
        rows = conn.execute(
            """
            SELECT p.* FROM prompts p
            INNER JOIN categories c ON p.category_id = c.id
            WHERE c.project_id = ?
            ORDER BY p.updated_at DESC
            """,
            (project_id,),
        ).fetchall()
        return [Prompt.from_row(dict(r)) for r in rows]

    def search(
        self,
        query: str,
        category_id: Optional[int] = None,
        project_id: Optional[int] = None,
    ) -> List[Prompt]:
        conn = self._db.connect()
        pattern = f"%{query}%"
        sql = """
            SELECT p.* FROM prompts p
        """
        params: list = []
        conditions = ["(p.title LIKE ? OR p.content LIKE ? OR p.tags LIKE ?)"]
        params.extend([pattern, pattern, pattern])

        if category_id is not None:
            conditions.append("p.category_id = ?")
            params.append(category_id)
        elif project_id is not None:
            sql += " INNER JOIN categories c ON p.category_id = c.id"
            conditions.append("c.project_id = ?")
            params.append(project_id)

        sql += " WHERE " + " AND ".join(conditions)
        sql += " ORDER BY p.updated_at DESC"

        rows = conn.execute(sql, params).fetchall()
        return [Prompt.from_row(dict(r)) for r in rows]

    def count(self) -> int:
        conn = self._db.connect()
        row = conn.execute("SELECT COUNT(*) as cnt FROM prompts").fetchone()
        return int(row["cnt"])


class AssetRepository:
    def __init__(self, db: DatabaseConnection) -> None:
        self._db = db

    def create(self, asset: Asset) -> Asset:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            cursor = conn.execute(
                """
                INSERT INTO assets
                (name, file_path, thumbnail_path, status, width, height,
                 project_id, category_id, prompt_id, metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    asset.name,
                    asset.file_path,
                    asset.thumbnail_path,
                    asset.status.value,
                    asset.width,
                    asset.height,
                    asset.project_id,
                    asset.category_id,
                    asset.prompt_id,
                    asset.metadata_json,
                    now,
                    now,
                ),
            )
            asset.id = cursor.lastrowid
            asset.created_at = datetime.fromisoformat(now)
            asset.updated_at = datetime.fromisoformat(now)
        return asset

    def update(self, asset: Asset) -> Asset:
        now = datetime.now().isoformat()
        with self._db.transaction() as conn:
            conn.execute(
                """
                UPDATE assets
                SET name = ?, file_path = ?, thumbnail_path = ?, status = ?,
                    width = ?, height = ?, project_id = ?, category_id = ?,
                    prompt_id = ?, metadata_json = ?, updated_at = ?
                WHERE id = ?
                """,
                (
                    asset.name,
                    asset.file_path,
                    asset.thumbnail_path,
                    asset.status.value,
                    asset.width,
                    asset.height,
                    asset.project_id,
                    asset.category_id,
                    asset.prompt_id,
                    asset.metadata_json,
                    now,
                    asset.id,
                ),
            )
            asset.updated_at = datetime.fromisoformat(now)
        return asset

    def delete(self, asset_id: int) -> None:
        with self._db.transaction() as conn:
            conn.execute("DELETE FROM assets WHERE id = ?", (asset_id,))

    def get_by_id(self, asset_id: int) -> Optional[Asset]:
        conn = self._db.connect()
        row = conn.execute("SELECT * FROM assets WHERE id = ?", (asset_id,)).fetchone()
        return Asset.from_row(dict(row)) if row else None

    def get_all(
        self,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
        status: Optional[AssetStatus] = None,
    ) -> List[Asset]:
        conn = self._db.connect()
        query = "SELECT * FROM assets WHERE 1=1"
        params: list = []

        if project_id is not None:
            query += " AND project_id = ?"
            params.append(project_id)
        if category_id is not None:
            query += " AND category_id = ?"
            params.append(category_id)
        if status is not None:
            query += " AND status = ?"
            params.append(status.value)

        query += " ORDER BY updated_at DESC"
        rows = conn.execute(query, params).fetchall()
        return [Asset.from_row(dict(r)) for r in rows]

    def count(
        self,
        project_id: Optional[int] = None,
        category_id: Optional[int] = None,
        status: Optional[AssetStatus] = None,
    ) -> int:
        conn = self._db.connect()
        query = "SELECT COUNT(*) as cnt FROM assets WHERE 1=1"
        params: list = []

        if project_id is not None:
            query += " AND project_id = ?"
            params.append(project_id)
        if category_id is not None:
            query += " AND category_id = ?"
            params.append(category_id)
        if status is not None:
            query += " AND status = ?"
            params.append(status.value)

        row = conn.execute(query, params).fetchone()
        return int(row["cnt"])

    def count_by_status(self) -> dict[str, int]:
        conn = self._db.connect()
        rows = conn.execute(
            "SELECT status, COUNT(*) as cnt FROM assets GROUP BY status"
        ).fetchall()
        return {row["status"]: int(row["cnt"]) for row in rows}
