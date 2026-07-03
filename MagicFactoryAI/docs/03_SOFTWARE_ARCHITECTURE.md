# MagicFactoryAI — Software Architecture

**Status:** Authoritative blueprint for V2 implementation and forward
**Audience:** Engineers, architects, technical reviewers, plugin developers
**Last revised:** V2 architectural freeze (prior to V2.0 sprint start)

---

## 1. Architectural Principles

MagicFactoryAI's architecture is governed by twelve principles, applied in order of priority. Each subsequent principle yields to a higher-priority one in conflicts.

1. **Sovereignty of user data** — the creator's library, agents, and metadata live on the creator's machine with verifiable provenance.
2. **Modular monolith first** — start as a single-process modular monolith; expose hardened seams so extraction to micro-services is possible at V3+ scale.
3. **SOLID + plugin-first** — every feature is designed as if a competitor could re-implement it as a plugin.
4. **Event-driven** — features communicate via a typed event bus; direct cross-module imports are discouraged past layer-defined boundaries.
5. **AI-first abstraction** — every AI operation enters through the multi-modal provider abstraction, never direct provider-specific code in UI/Controllers/Services.
6. **Offline-first** — every feature works without network connectivity; cloud is opt-in.
7. **Print-grade correctness** — color space, DPI, bleed, and pre-flight are first-class invariants validated at export.
8. **Testability** — every module and controller has a greenfield test path; integration tests exercise seam contracts.
9. **Layered dependency direction** — UI → Controllers → Services → Repositories → Models. UI never imports Services directly. Services never import UI.
10. **Observable** — every module emits structured logs against a known event taxonomy; metrics, traces, and audit records are first-class.
11. **Versioned** — every public API, plugin manifest, schema, and pack format carries an explicit version; backward compatibility is a feature.
12. **Recoverable** — every stateful subsystem has a documented recovery story from crash, kill -9, power loss, partial write, and orphaned tmp file scenarios.

---

## 2. Module Layout (logical)

```
MagicFactoryAI
├── app/                  # Application bootstrap, dependency wiring, controller facade
├── core/                 # Cross-cutting platform primitives (DB, settings, theming, logging, AI)
│   ├── ai/               # AI provider abstraction, prompt engine, multi-modal interface
│   ├── database/         # Connection, schema, migrations, repositories
│   ├── settings/         # App-wide settings manager
│   ├── theme/            # Theme tokens, palette resolution, dark/light tokens
│   ├── migrations/       # Background migration workers (V1→V2, V2→V3, etc.)
│   └── observability/    # Metrics, traces, audit
├── models/               # Pure data structures (no behavior beyond invariants)
│   ├── asset.py
│   ├── project.py
│   ├── prompt.py
│   ├── category.py
│   ├── job.py
│   ├── generation_task.py
│   ├── plugin.py
│   ├── agent.py
│   ├── marketplace.py
│   └── ...
├── services/             # Domain operations, no UI knowledge
│   ├── asset_service.py
│   ├── prompt_service.py
│   ├── book_service.py
│   ├── export_service.py
│   ├── recovery_manager.py
│   ├── undo_manager.py
│   ├── plugin_locator.py
│   ├── preset_manager.py
│   ├── thumbnail_cache.py
│   ├── auto_tagger.py
│   └── ...
├── engine/               # Pure computational engines
│   ├── generator/        # Batch generator, queue manager, retry manager, image processor
│   ├── export/           # PDF exporter, pack builder, KDP packager
│   ├── similarity/       # Perceptual hash, embedding index
│   ├── storage/          # Content-Addressed Store (CAS)
│   ├── quality/          # Quality gate, critic agents
│   ├── marketplace/      # Pack validation, royalty ledger
│   └── json/             # Pack schemas, serialization
├── controllers/          # Application-layer coordination (UI ↔ Services)
│   ├── app_controller.py
│   ├── workspace_controller.py
│   ├── project_controller.py
│   ├── prompt_controller.py
│   ├── asset_controller.py
│   ├── batch_controller.py
│   ├── ai_generator_controller.py
│   ├── export_controller.py
│   ├── category_controller.py
│   ├── dashboard_controller.py
│   ├── marketplace_controller.py
│   ├── plugin_controller.py
│   ├── team_controller.py
│   └── metadata_controller.py
├── ui/                   # All Qt / desktop UI
│   ├── main_window.py    # Top-level window, navigation, undo/redo, global shortcuts
│   ├── screens/          # Full-screen views (Dashboard, Project Workspace, etc.)
│   ├── widgets/          # Reusable user controls
│   │   ├── workspace/    # Workspace-scoped widgets (tabs, header, panels)
│   │   ├── library/      # Library surface widgets
│   │   ├── dialogs/      # Modal dialogs
│   │   └── ...
│   └── resources/        # Icons, stylesheets, translations
└── plugins/              # First-party plugins (e.g., magic_lab_presets)
```

Layered imports are strictly downward:

- `ui/` may import from `controllers/`.
- `controllers/` may import from `services/`, `engine/`, `core/`, `models/`.
- `services/` may import from `engine/`, `core/`, `models/`.
- `engine/` may import from `core/`, `models/`.
- `core/` may depend on `models/` and standard library only.
- `models/` is leaf; depends on standard library only.

Any forward import triggers a CI lint check (`make arch-lint`).

---

## 3. Module-by-Module Responsibilities

### 3.1 `app/` — Application bootstrap

**Responsibility:** Create QApplication, install logging, load settings, wire AppController, expose main window.

**Modules:**

- `application.py` — `MagicFactoryApp` entry point; reads CLI/env flags, applies platform-specific high-DPI scaling.
- `application.py` initializes AppController singleton (see §3.3.1), theme, recovery, and audit before opening MainWindow.

**Dependencies:** PySide6 (`QtCore`, `QtGui`, `QtWidgets`), `core.settings.manager`, `core.theme`, `core.observability`.

### 3.2 `core/` — Cross-cutting platform primitives

**Responsibility:** Provide primitives shared by all higher layers.

#### 3.2.1 `core/database/`

- `connection.py` — `DatabaseConnection` singleton; provides SQLite connection pool with WAL mode, foreign keys on, busy_timeout, and `reset_instance()` for tests.
- `schema.py` — canonical schema declarations (tables, indexes, triggers).
- `migrations.py` — versioned migration runner; idempotent; runs in a transaction; supports pre/post-SQL callbacks.
- `repositories.py` — repository classes (AssetRepository, ProjectRepository, PromptRepository, etc.) implementing typed CRUD.

#### 3.2.2 `core/ai/`

- `provider_base.py` — abstract base class for `AIProvider` covering `text→image`, `image+text→image`, `text→text`, `image→text` interfaces.
- `provider_factory.py` — instantiates the configured provider (OpenAI, Stability, Ollama, local SD).
- `multi_modal_provider.py` — wrapper that exposes a uniform multi-modal interface across provider-specific capabilities.
- `ai_manager.py` — orchestrates multiple providers with auto-failover and policy (cost-aware routing).
- `prompt_builder.py` — LLM-driven prompt improvement (Smart Prompt Builder).
- `models.py` — strongly-typed request/response models (PromptRequest, ImageGenerationRequest, etc.).

#### 3.2.3 `core/settings/manager.py`

- `SettingsManager` singleton; JSON-backed; user-editable; exportable (`import_settings`, `export_settings`).
- Implements settings versioning and deprecated-key migration.

#### 3.2.4 `core/theme/`

- `colors.py`, `styles.py`, `__init__.py`. Theme tokens (light/dark palette), spacing, typography.
- Resolves theme by name; supports per-creator theme packs (post-V2.5).

#### 3.2.5 `core/migrations/`

- `background_upgrader.py` (V2+). Coordinates non-blocking upgrade passes (V1→V2 schema + re-hash; CAS migration).
- One-shot dialog at startup if a pending upgrade is detected; resumable across app restarts.

#### 3.2.6 `core/observability/`

- `metrics.py` — counters and timers by taxonomy.
- `traces.py` — span IDs and contextual logging.
- `audit.py` — append-only audit table writer.

### 3.3 `models/`

**Responsibility:** Pure data structures. No behavior beyond invariants. No I/O.

All models:

- Use dataclasses.
- Validate via `__post_init__` for invariants.
- Implement `to_dict()`, `from_dict()` (canonical serialization).
- Carry a `version` field (default 1) for forward-compat.
- Carry an `id` and `tenant_id` (for V3+ workspace awareness).

### 3.4 `services/`

**Responsibility:** Domain operations. Compose primitives; no UI knowledge.

- `asset_service.py` — orchestrates asset CRUD through repository and CAS; thumbnail generation; licensing tracking.
- `prompt_service.py` — prompt CRUD, variable resolution, template expansion, usage tracking.
- `book_service.py` — book composition, page ordering, cover assignment.
- `export_service.py` — orchestrates PDF / EPUB / pack export with print correctness validation.
- `recovery_manager.py` — periodic snapshot, load-on-startup, atomic-write.
- `undo_manager.py` — graph-based undo/redo with branching (V2+).
- `plugin_locator.py` — plugin discovery, lifecycle, sandbox invocation.
- `preset_manager.py` — first-party preset packs (style templates).
- `thumbnail_cache.py` — LRU + memory-budget bytes for thumbnails.
- `auto_tagger.py` (V2+) — vision-API tagging pipeline.
- `marketplace_service.py` (V3+) — listing, purchase, license registry.

### 3.5 `engine/`

**Responsibility:** Pure computational engines; no event flow knowledge.

- `engine/generator/batch_generator.py` — orchestrates batch generation jobs through the AI provider abstraction.
- `engine/generator/queue_manager.py` — priority queue, persistence, retry, ETA, cancellation.
- `engine/generator/image_processor.py` — decode, validate, normalize, scale, color-space-convert.
- `engine/generator/retry_manager.py` — exponential backoff, model failover, partial-result handling.
- `engine/export/exporter.py` — top-level export orchestrator.
- `engine/export/pdf_exporter.py` — PDF/X-3 compliant PDF generation with bleed/margin.
- `engine/json/pack_builder.py` — pack format (.mfpack) writer/reader.
- `engine/storage/content_store.py` — Content-Addressed Storage (SHA-256 blocks, dedup, lineage).
- `engine/similarity/perceptual_hash.py` — pHash 64-bit.
- `engine/similarity/embedding_index.py` — CLIP embedding index using sqlite-vss or Qdrant.
- `engine/quality/quality_gate.py` — quality grading (heuristic + critic LLM).
- `engine/marketplace/pack_validator.py` (V3+).

### 3.6 `controllers/`

**Responsibility:** Application-layer coordination between UI and Services. Stateless wrappers over services for UI binding; expose Qt signals for UI updates.

Controllers are skinny: hold no business logic of their own. They:

- Receive user actions from UI.
- Call services with typed arguments.
- Translate service results into the UI-facing domain model.
- Emit Qt signals for the UI to listen to.
- Handle cross-cutting concerns (auth, audit, undo integration, telemetry tagging).

Examples:

- `AssetController` exposes `import_assets(paths)`, `set_status(asset_id, new_status)`, `delete_asset(asset_id)`, and signals `assets_changed`, `thumb_ready`.
- `WorkspaceController` orchestrates tab-level state, marks dirty, schedules auto-save, drives the recovery flow.
- `MarketplaceController` (V3+) wraps marketplace service for UI: `browse`, `purchase`, `publish_listing`.

### 3.7 `ui/`

**Responsibility:** Qt-based desktop UI. Subscribes to Controller signals; emits user actions.

- `ui/main_window.py` — top-level QMainWindow with QStackedWidget of screens, navigation sidebar, Edit menu (Undo/Redo), Help menu, global shortcuts.
- `ui/screens/` — full-screen views (`DashboardScreen`, `ProjectWorkspaceScreen`, `NewProjectScreen`, `PromptManagerScreen`, `MarketplaceScreen`, `SettingsScreen`, `CloudSyncScreen`).
- `ui/widgets/workspace/` — `WorkspaceHeader`, sidebar, tabs (Library V2, Book Builder, AI Generator, Prompts, Categories, Review, Export, Agent Lab — V5+).
- `ui/widgets/library/` — Library-table widgets, filter chips, context menus.
- `ui/widgets/dialogs/` — Modal dialogs (RecoveryDialog, DuplicateFinderDialog, AssetInspectorDialog, ConflictResolver for version history).

UI principles:

- All colors, fonts, spacing come from `core.theme` tokens. No hard-coded hex values.
- All actions pass through Controllers. UI never calls Services directly.
- Every dialog has Escape-to-cancel and Enter-to-confirm defaults.
- Every table supports keyboard navigation (Tab/Shift-Tab, Enter, Space, arrow nav).
- Every long-running operation shows progress in a non-blocking way (QProgressDialog with cancel).

---

## 4. Event Flow

MagicFactoryAI uses **two event systems** for different concerns:

- **Qt signals/slots** for UI ↔ Controller communication.
- **Domain Event Bus** (`core/events/EventBus`) for cross-service and service ↔ plugin communication.

### 4.1 Domain Event Bus

A typed event bus. All events are dataclasses with `event_type` (string ID), `payload`, `tenant_id` (workspace), `actor_id` (creator or system), `timestamp`, and `correlation_id` (for tracing).

Event taxonomy (canonical IDs):

```
asset.imported
asset.deleted
asset.status_changed
asset.tag_added
asset.tagged_by_ai
asset.duplicate_detected
asset.embedding_updated
prompt.committed
prompt.variables_resolved
book.page_added
book.page_reordered
book.exported
export.completed
export.failed
job.queued
job.started
job.completed
job.failed
job.cancelled
plugin.installed
plugin.uninstalled
plugin.activated
plugin.deactivated
marketplace.listing_published
marketplace.purchase_completed
agent.stage_completed
agent.completed
agent.failed
audit.event_logged
```

Plugins subscribe to events by ID and respond with side effects (asset tag added, asset moved, etc.). Plugins cannot stop events from propagating (no event-cancel).

### 4.2 Async communication

- Long-running operations use Qt's QThreadPool + QRunnable for CPU/IO bound work, with signals to deliver results back to the UI thread.
- All AI provider calls go through a dedicated thread pool with rate-limit-aware scheduling.
- Crash-safe persistence uses WAL-mode SQLite; cancellation is cooperative (workers check `request_stop` flag every 250ms).

### 4.3 Communication diagram (text)

```
┌────────┐    user actions    ┌─────────────┐
│   UI   │ ────────────────► │ Controllers │
└────────┘                    └─────────────┘
     ▲                            │   │
     │ Qt signals                 │   │ typed call
     │ updates                    ▼   ▼
┌────────┐                    ┌─────────────┐
│ Event  │ ◄─── publish ────  │  Services   │
│  Bus   │ ───── subscribe ─► │             │
└────────┘                    └─────────────┘
     ▲                            │
     │ emit                       │
     │                       ┌────┴────┐
     │                       │ Engine  │
     │                       │ modules │
     │                       └────┬────┘
     │                            │
     ▼                            ▼
┌────────┐                    ┌─────────────┐
│Storage │                    │  AI Layer   │
└────────┘                    └─────────────┘
```

Arrow summary:

- UI → Controller → Service → Engine → Storage / AI Layer
- Services and Engines publish to EventBus
- Plugins subscribe to EventBus; never invoked directly
- UI listens to Controller signals; never to EventBus directly

---

## 5. Service Layer

All Services:

- Are stateless; construct per-app or per-request (controller chooses).
- Receive a `DatabaseConnection` and `SettingsManager` via constructor for testability.
- Expose typed methods returning typed models.
- Publish events on EventBus for non-trivial state changes.
- Log structured events via `core.observability`.
- Are unit-tested with no Qt dependency.

Service list (V2.0):

| Service | Responsibility | Major methods |
|---------|----------------|---------------|
| AssetService | CRUD + CAS + thumbnail + license track | `import_assets`, `set_status`, `delete`, `add_tag`, `remove_tag`, `set_favorite`, `set_metadata`, `get_by_id`, `query` |
| PromptService | CRUD + variable resolution + template expansion | `commit_prompt`, `render_with_variables`, `expand_template` |
| ProjectService | CRUD | `create_project`, `list_projects`, `rename`, `delete` |
| BookService | Composition + page ordering | `add_page`, `remove_page`, `reorder_pages`, `set_cover`, `assign_asset` |
| ExportService | Orchestration + pre-flight validation | `export_pdf`, `export_epub`, `export_pack`, `preflight_check` |
| RecoveryManager | Snapshot + restore | `force_save`, `load_latest`, `purge_orphans` |
| UndoManager | Branching graph | `push`, `undo`, `redo`, `branch_from`, `merge_branch` |
| PluginLocator | Plugin load / unload | `discover`, `activate`, `deactivate`, `invoke_hook` |
| PresetManager | First-party preset packs | `list_packs`, `install_pack`, `uninstall_pack` |
| ThumbnailCache | LRU bytes-budgeted | `get`, `put`, `invalidate`, `evict` |
| AutoTagger (V2+) | Vision-API tagging | `tag_asset`, `tag_batch` |
| MarketplaceService (V3+) | Listings + purchases | `browse`, `purchase`, `publish_listing`, `resolve_license` |

---

## 6. Controller Layer

Controllers are the only layer allowed to:

- Import `PySide6.QtCore` (for signals) and `PySide6.QtGui` (for icons).
- Hold references to UI widgets (read-only).
- Be instantiated per UI element or app-wide singleton (controller decision).

Each controller:

- Exposes 5–25 methods (target).
- Exposes a small signal set (typically `changed`, `error_occurred`, `progress`).
- Is unit-tested by stubbing services.

Controllers:

| Controller | Responsibility |
|------------|----------------|
| AppController | Global facade; service registry; workspace awareness; cloud-mirror toggle |
| WorkspaceController | Workspace-level state: current project, dirty flag, auto-save timer, recovery |
| ProjectController | Project CRUD with UI dialogs |
| PromptController | Prompt CRUD with variable editor |
| AssetController | Asset CRUD with status changes, undo-aware |
| BatchController | Batch generation orchestration; job queue visibility |
| AIGeneratorController | Single-asset generation; critic UI |
| ExportController | Export flow with pre-flight |
| CategoryController | Hierarchy + bulk tagging |
| DashboardController | Charts and stats |
| MarketplaceController (V3+) | Marketplace browse and purchase |
| PluginController (V2.5+) | Install / enable / disable plugins |
| TeamController (V3+) | Team workspace management |
| MetadataController (V2+) | Asset metadata editor |

---

## 7. UI Layer

UI is composed of:

- `MainWindow` (top-level)
- Screens (full-screen views)
- Widgets (composable reusable controls)
- Stylesheets pulled from theme tokens

### 7.1 Navigation model

- A vertical sidebar on the left with route icons (Dashboard, Projects, Marketplace, Settings, Help, Plugins).
- Each route swap replaces the QStackedWidget's current widget.
- The main window carries the Edit menu (Undo/Redo enabled regardless of focus) and Help menu.
- Global shortcuts: Ctrl+Z (undo), Ctrl+Shift+Z (redo), Ctrl+K (search everywhere), Ctrl+I (import), Ctrl+E (export), Ctrl+S (save), Ctrl+W (close view), F1 (help).

### 7.2 Workspace tabs

`ProjectWorkspaceScreen` shows workspace header + tab widget + status bar.

Tabs:

- Library V2 (always)
- AI Generator (with provider selector)
- Prompts (with variable editor)
- Categories
- Book Builder
- Review
- Export
- Agent Lab (V5+)
- Marketplace (V3+)

Tabs are pluggable (a plugin can register a tab via `WorkspaceTabRegistry`).

### 7.3 Library V2 (the canonical reference implementation)

Library V2 is the model implementation of every architectural principle. It:

- Uses CAS for asset storage (resolved paths point to content store).
- Loads thumbnails via `ThumbnailCache`.
- Streams incremental results via QAbstractTableModel + virtualization.
- Uses Search Service with backpressure and cancel via version counter on row key.
- Publishes `asset.tag_added`, `asset.status_changed` to EventBus.
- Subscribes to `asset.duplicate_detected` to mark rows visually.

---

## 8. Persistence Layer

Persistence is enforced via:

- `core.database.connection.DatabaseConnection` (singleton).
- Repositories per model in `core.database.repositories`.
- Migration runner in `core.database.migrations`.
- CAS layer in `engine.storage.content_store` for binary blobs.

### 8.1 Database Connection lifecycle

Singleton bootstrapped at startup. Tests can call `reset_instance()` to fully reset.

Connection settings:

- WAL mode enabled.
- Foreign keys ON.
- `busy_timeout = 5000`.
- `journal_size_limit = 64MB`.
- `synchronous = NORMAL`.

### 8.2 Repository pattern

Repositories are pure Python classes (no Qt). Methods accept typed models and return typed models. Transactions are explicit via context manager.

### 8.3 Migrations

Idempotent migration runner:

- Reads `_schema_version` from DB.
- Compares against current schema version.
- Runs additive, version-tagged SQL files in `core/database/migrations/`.
- Wraps each migration in a transaction with rollback on failure.
- Logs each migration to `audit` table.

### 8.4 CAS (Content-Addressed Storage)

Binaries (asset files, thumbnails) live under `engine.storage.content_store`. Each blob is content-addressed by SHA-256; duplicates are deduped automatically. The `assets.file_path` field becomes a virtual path resolved through CAS.

CAS levels:

- Level 0 — raw blob, in `data/cas/AB/CD/ABCD...`.
- Level 1 — derived: thumbnail at width × height, color-space-converted, etc.
- Lineage: derived assets track their source.

---

## 9. AI Layer

The AI Layer is sealed behind `core/ai/multi_modal_provider.py`. Without exception:

- **UI never imports provider-specific code.**
- **Services never reach beyond `MultiModalProvider`.**
- **Provider-specific code lives in `core/ai/providers/<name>.py`.**

### 9.1 Provider abstraction

```python
class AIProvider(Protocol):
    name: str
    capabilities: set[Capability]  # Capability = TEXT_TO_IMAGE | IMAGE_TO_IMAGE | TEXT_TO_TEXT | etc.

    def generate(self, request: AIRequest) -> AIResponse: ...
    async def agenerate(self, request: AIRequest) -> AIResponse: ...
    def available_models(self) -> list[ModelInfo]: ...
    def estimate_cost(self, request: AIRequest) -> CostEstimate: ...
```

### 9.2 Multi-modal provider

A wrapper that delegates typed requests to the configured provider and translates between provider-specific params and our canonical parametric Request model.

### 9.3 Routing

MultiModelProvider / AI Manager routes based on:

- Cost (user-max-$ preference)
- Capability match
- Local hardware availability
- Policy (e.g., for KDP-compliant assets, prefer provider A)

Auto-failover on transient failure (3 retries with exponential backoff; then next provider).

---

## 10. Plugin Layer

The Plugin Layer is V2.5+ public but conceptually exists from V2.0 onward.

### 10.1 Plugin shape

A plugin is a Python package with:

- `mfplugin.json` manifest (id, version, name, author, license, hooks, permissions, dependencies).
- Entrypoints declared in `[project.entry-points."magic_factory.plugins"]`.

### 10.2 Lifecycle

```
DISCOVERED → INSTALLED → VALIDATED → ENABLED → ACTIVE
                              ↓
                          REJECTED (quarantined)
```

A plugin starts as `DISCOVERED` when found on disk; `INSTALLED` when copied to the user-plugins directory; `VALIDATED` when its manifest and code pass sandbox lint; `ENABLED` when user toggles it on; `ACTIVE` when it's loaded and registered.

### 10.3 Sandbox

Plugins run in a constrained environment:

- Memory cap (256 MB).
- CPU cap (1 thread per process; 100% of 1 core for up to 30 seconds burst).
- Network: allowlist only (declared in manifest).
- Filesystem: read access to project assets (in current workspace only); write access restricted to plugin-private dir under `data/plugins/<plugin-id>/`.
- No direct database write: must use AssetService, PromptService, etc., through PluginLocator.

### 10.4 Seams internal to V2.0

Even before public Plugin SDK, internal seams exist:

- `EventBus.subscribe("asset.imported", callback)` — for internal modules only in V2.0.
- `WorkspaceTabRegistry.register(name, factory)` — internal team only in V2.0; opens to plugins in V2.5+.
- `AIProviderFactory.register(name, factory)` — internal only.
- `ExportBackendRegistry.register(name, factory)` — internal only.

---

## 11. Cloud Layer (V3+)

The Cloud Layer is intentionally V3+ to keep V2 focused on local-first.

Components:

- `services/cloud_sync.py` — bidirectional sync engine.
- `services/cloud_crdt.py` — CRDT for shared library state.
- `services/cloud_auth.py` — OAuth + tenant isolation.
- `services/cloud_storage.py` — cloud-side CAS mirror.

Design decisions:

- Local SQLite remains canonical for the singleton workspace; cloud only mirrors.
- Conflict resolution via CRDT (Yjs-style) for shared library items.
- Cloud-disabled users have zero code paths affected.

---

## 12. Communication Diagram (system-level)

```
                ┌──────────────────────────────────────────┐
                │                 UI Layer                  │
                │  QMainWindow / Screens / Widgets / Theme  │
                └──────────────────────────────────────────┘
                                │
                                │ Qt signals + Controller API
                                ▼
                ┌──────────────────────────────────────────┐
                │            Controller Layer               │
                │  AppCtrl / WorkspaceCtrl / etc.          │
                └──────────────────────────────────────────┘
                                │
                                │ Typed service calls
                                ▼
                ┌──────────────────────────────────────────┐
                │              Service Layer                │
                │  AssetService / PromptService / etc.    │
                └──────────────────────────────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
   ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
   │     Engine       │ │   Event Bus  │ │   Plugin Layer   │
   │ gen/export/storage│ │ core.events  │ │ (V2.5+ public)  │
   └──────────────────┘ └──────────────┘ └──────────────────┘
            │                   ▲                   ▲
            │                   │                   │
            ▼                   │                   │
   ┌──────────────────┐        │                   │
   │  Persistence     │────────┘                   │
   │ SQLite + CAS     │                            │
   └──────────────────┘                            │
            ▲                                      │
            │                                      │
            ▼                                      │
   ┌──────────────────┐                            │
   │   AI Layer        │───────────────────────────┘
   │ MultiModalProvider│
   └──────────────────┘
            ▲
            │
            ▼
   ┌──────────────────┐
   │   Cloud Layer    │ (V3+)
   │  cloud_sync,etc. │
   └──────────────────┘
```

The diagram emphasizes: any layer can publish to the EventBus; the EventBus is the only mechanism via which plugins can hook internal behavior.

---

## 13. Future Scalability

### 13.1 Scaling milestones

- **V2**: Single machine. SQLite local. Plugin sandboxed in-process.
- **V3**: Single machine + lightweight cloud relay. First-party cloud replica of local SQLite via Postgres.
- **V4**: Multi-device. CRDT layer. BYO-cloud. Federated local indices.
- **V5**: Federated compute network (opt-in). Co-creator agents may spawn child instances on cloud.

### 13.2 Migration paths

- **V2 → V3**: bootstrap a cloud-mirror component without changing the local DB schema.
- **V3 → V4**: introduce CRDT layer between Services and Repositories for shareable items.
- **V4 → V5**: introduce Agent Orchestrator at Engine level, calling existing Engines.

### 13.3 Vertical scaling ceilings

Following are the planned ceilings before architecture must evolve:

| Resource | Ceiling | Trigger |
|----------|---------|---------|
| Asset count per project | 50K | Split projects or shard CAS |
| Library total | 1M | Switch to DB-side vector index |
| Plugin count | 100 | Process-isolate plugins |
| Concurrent jobs | 100 | Move queue to dedicated worker process |
| Cloud workspaces | 10K | Shard by workspace |

---

## 14. Build, Package, Deploy (architectural view)

- `pyproject.toml` — Python ≥ 3.11 must be supported.
- Dependencies pinned in `requirements.txt` with hash verification for production builds.
- Test dependencies declared in `requirements-dev.txt`.
- CI runs lint (`ruff`, `mypy`), unit tests (`pytest`), integration tests, headless GUI smoke tests.
- Release artifacts: Windows MSI (V2+), portable ZIP, Linux AppImage (V4+), macOS DMG (V4+).

---

## 15. Closing Note

The architecture exists for one purpose: to make the **product** (V1 → V5) implementable by a team that does not need to re-decide foundational structure each release. The principles are demanding because they protect against technology churn — Python, Qt, SQLite, and the AI provider landscape will all evolve; the architecture should let us swap components without breaking the rest.
