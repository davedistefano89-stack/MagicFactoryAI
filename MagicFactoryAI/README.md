# Magic Factory AI

Professional Windows desktop application for generating and organizing coloring book assets for **Magic Colors Adventure**.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Python 3.13 |
| UI | PySide6 (Qt6) |
| Database | SQLite |
| Image Processing | Pillow, OpenCV |

## Architecture

The project follows **MVC (Model-View-Controller)** with a modular, layered design:

```
MagicFactoryAI/
├── app/                  # Application bootstrap & controllers
│   └── controllers/      # MVC controllers
├── core/                 # Infrastructure
│   ├── database/         # SQLite connection, schema, repositories
│   ├── settings/         # JSON-based settings manager
│   └── theme/            # Color palette & QSS stylesheets
├── engine/               # Business logic engines
│   ├── generator/        # Image processing (Pillow + OpenCV)
│   ├── export/           # Batch asset export
│   └── json/             # Game pack manifest builder
├── models/               # Domain dataclasses
├── ui/                   # Views
│   ├── screens/          # Full-page screen views
│   └── widgets/          # Reusable UI components
├── utils/                # Logging, path helpers
├── config/               # Default settings
├── assets/               # Static assets
├── data/                 # Runtime data (DB, library, exports)
└── logs/                 # Application logs
```

## Features

- **Dashboard** — Real-time stats and recent project overview
- **New Project** — Create and manage coloring book projects
- **Categories** — Organize assets into themed groups with color coding
- **Prompt Manager** — Create, search, and manage reusable generation prompts
- **Library** — Import, approve, reject, and manage coloring book assets
- **Export** — Batch export approved assets with JSON pack manifests
- **Settings** — Configurable window, generator, and export preferences

## Getting Started

### Prerequisites

- Python 3.13+
- Windows 10/11

### Installation

```bash
cd MagicFactoryAI
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### Run

```bash
python main.py
```

## Development

### Adding a New Screen

1. Create a screen class in `ui/screens/` extending `BaseScreen`
2. Set `screen_id` to match a `SidebarItem.id` in `ui/widgets/sidebar.py`
3. Register the screen in `ui/main_window.py`
4. Add a controller in `app/controllers/` if new business logic is needed

### Database

SQLite database is auto-created at `data/magic_factory.db` on first launch. Schema is defined in `core/database/schema.py`. Repositories in `core/database/repositories.py` provide typed CRUD access.

## License

Proprietary — Magic Factory / Magic Colors Adventure
