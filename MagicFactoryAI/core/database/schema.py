"""Database schema definitions."""

SCHEMA_VERSION = 2


def get_schema_sql() -> str:
    return """
    CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER NOT NULL
    );

    INSERT OR IGNORE INTO schema_version (version) VALUES ({version});

    CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT DEFAULT '#6366F1',
        icon TEXT DEFAULT 'folder',
        sort_order INTEGER DEFAULT 0,
        project_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS prompts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        prompt_type TEXT NOT NULL DEFAULT 'custom',
        tags TEXT DEFAULT '',
        is_favorite INTEGER DEFAULT 0,
        category_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        file_path TEXT DEFAULT '',
        thumbnail_path TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        width INTEGER DEFAULT 0,
        height INTEGER DEFAULT 0,
        project_id INTEGER,
        category_id INTEGER,
        prompt_id INTEGER,
        metadata_json TEXT DEFAULT '{{}}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (prompt_id) REFERENCES prompts(id) ON DELETE SET NULL
    );

    CREATE INDEX IF NOT EXISTS idx_categories_project ON categories(project_id);
    CREATE INDEX IF NOT EXISTS idx_prompts_category ON prompts(category_id);
    CREATE INDEX IF NOT EXISTS idx_assets_project ON assets(project_id);
    CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category_id);
    CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
    """.format(version=SCHEMA_VERSION)
