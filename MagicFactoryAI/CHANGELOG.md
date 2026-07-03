# Changelog

All notable changes to MagicFactoryAI are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0-rc1] — 2026-07-01

### Release Candidate 1 — First public release candidate

#### Added
- **Dashboard** — Real-time project statistics, recent assets, quick-action cards
- **Project management** — Create, open, and switch between multiple coloring book projects
- **Categories** — Create and manage themed asset categories with color coding
- **Prompt Studio** — Full prompt editor with collections, tags, search, and inspector
  - Prompt Collections (independent of Asset Collections)
  - Assign/remove prompts from multiple collections
  - Sidebar collection filter
  - Search across name, tags, and collection names
- **AI Generator** — Image generation via OpenAI and compatible providers
  - Generation Presets (provider, model, size, steps, guidance, seed, prefix/suffix)
  - Create / rename / duplicate / delete / set-default preset
  - Preset selector with immediate control update
- **Library V2** — Zero-crash asset library (complete rewrite)
  - Synchronous thumbnail loading (no thread crashes)
  - Import, search, status filter, tag filter, collection filter
  - Approve / Reject / Delete assets
  - Double-click asset inspector
  - Collections sidebar
- **Book Builder** — Full coloring book page layout tool
  - Drag-and-drop page ordering
  - Book Properties panel (title, subtitle, author, language, interior type, paper size, margin, age, page count)
  - New Book / Clear Book / Auto Number Pages actions
  - Cover Builder integration
- **Review workflow** — Sequential asset review with approve / reject / skip
- **KDP Export** — Batch export with JSON pack manifest for Kindle Direct Publishing
- **Undo / Redo** — Global operation history (100-step stack) with Ctrl+Z / Ctrl+Shift+Z
  - Edit menu with Undo / Redo items
- **Auto Save & Crash Recovery** — 60-second automatic recovery snapshots
  - Recovery dialog on startup when unsaved changes detected
  - Covers Book Builder, Cover Builder, Prompt edits, selections
- **Settings** — Persistent JSON-based settings for window, generator, and export preferences

#### Architecture
- MVC architecture: `app/controllers`, `models`, `ui/screens`, `ui/widgets`
- SQLite database auto-initialized at `data/magic_factory.db`
- JSON settings at `config/settings.json`
- Recovery snapshots at `data/recovery/<project_id>.json`
- PySide6 (Qt6) UI with custom dark theme

#### Fixed (during RC1 stabilization)
- Native Qt crash when opening Library tab — root cause: cross-thread `QImage` signal marshalling; fixed by complete Library V2 rewrite with synchronous thumbnail loading
- Book Builder recovery never registered with workspace auto-save timer
- New Book / Clear Book / Auto Number Pages buttons had no slot connections
- Dead `GeneratorTab` import removed from workspace screen and tab package
- Duplicate `pillow` entry removed from `requirements.txt`
- Edit menu (Undo/Redo) added to main window

---

## [0.9.0] — 2026-06-30

### Beta — Internal development milestone

- Auto Save & Crash Recovery sprint
- AI Generator Presets sprint
- Prompt Collections sprint
- Book Builder sprints (properties panel, PDF engine, cover builder)
- Library crash investigation and fix attempts
- Review queue and Export workflow implementation

---

## [0.1.0] — 2026-06-25

### Alpha — Initial implementation

- Project scaffold with MVC architecture
- SQLite schema and repositories
- Dashboard, Categories, Prompt Manager screens
- Basic Library with asset import
- Basic Export workflow
- PySide6 dark theme
