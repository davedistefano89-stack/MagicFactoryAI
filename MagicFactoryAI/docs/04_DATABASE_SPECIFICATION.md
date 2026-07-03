# MagicFactoryAI — Database Specification

**Status:** Authoritative schema & operations specification for V2.0 onwards
**Audience:** Engineers, plugin authors, third-party integrators, AI agent authors
**Last revised:** V2 architectural freeze (prior to V2.0 sprint start)

---

## 1. Overview

MagicFactoryAI persists its state in a **single canonical SQLite database** for each user workspace. Binaries (images, thumbnails, audio) are stored in a separate **Content-Addressed Store (CAS)** rooted at `data/cas/`. From V3 onward, the SQLite database may optionally be **mirrored** to a per-workspace Postgres instance on first-party cloud; SQLite remains canonical locally.

### 1.1 Design goals

1. **Local canonical** — every byte of structured state the user creates lives on their machine.
2. **Crash-survivable** — atomic commits, WAL journaling, busy-timeout, idempotent migrations.
3. **Append-and-version** — schema evolution is forward-compatible; never destructive.
4. **Index-rich** — common queries answered from indexes, not scans.
5. **CAS-collaborative** — binary dedup and lineage enable marketplace sharing without duplicating bytes.
6. **Tenant-aware** — every row carries `tenant_id` (workspace) from V3+ to support multi-workspace.

### 1.2 Why SQLite

- Built-in: zero install.
- Single-file portable.
- High-throughput reads with WAL.
- Sufficient for ≤1M rows per table — we are nowhere near this with V1 data.
- Well-understood tooling (sqlite3 CLI, DB Browser, sqlite-vss).

### 1.3 Why not Postgres earlier

- Adds a server-side dependency on local install.
- Operational complexity without a current need.
- Cost of portable installs across platforms.
- V3 cloud introduces Postgres as a *mirror only*, not a primary.

---

## 2. Database Connection

### 2.1 Singleton pattern

`DatabaseConnection` is a process-wide singleton (`DatabaseConnection.instance()`). For testing, `DatabaseConnection.reset_instance()` discards the instance to allow test setups to bring up a fresh DB.

### 2.2 Connection settings

```
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA temp_store = MEMORY;
PRAGMA journal_size_limit = 67108864;  -- 64 MB
PRAGMA mmap_size = 268435456;          -- 256 MB on supported platforms
```

### 2.3 Path resolution

Default location: `data/magic_factory.db`. Configurable via `settings.json`. Tests use a tmp path.

### 2.4 Concurrency

Writers serialize naturally via SQLite; the framework uses connection-level locking for write transactions. Readers never block writers in WAL mode.

The UI thread never blocks on a write: Controllers call Services via `QThreadPool` for transactional methods that touch many rows.

---

## 3. Schema versioning

The database carries a `_schema_version` row in a metadata table. Migrations live in `core/database/migrations/`. Each migration has:

- `NNNN_name.sql` — DDL.
- `NNNN_name.py` — optional data migration callback.

Migrations are versioned with a monotonic integer. The runner is idempotent: re-applying a migration is a no-op.

```
0001_init.sql
0002_v1_baseline.sql
0003_v2_job_queue.sql
...
```

A migration is reversible only if explicitly written; otherwise it is append-only and rolled back via DB restoration from snapshot.

---

## 4. Entity-Relationship Diagram (text)

The schema is described in three groups: **Core**, **AI & Generation**, **Marketplace & Cloud**, **System**.

### 4.1 Core entities

```
                ┌──────────────────┐
                │     projects     │ 1
                │                  │────────┐
                └──────────────────┘        │
                        │ 1                 │
                        │ owner             │
                        ▼ N                 │
                ┌──────────────────┐        │
                │    projects      │ N      │
                │  (sub-projects)  │◄───────┘
                └──────────────────┘
                        │ 1
                        │ has
                        ▼ N
                ┌──────────────────┐ N ────────────────┐
                │      assets      │ ──── tagged ───►   │
                └──────────────────┘      N             │
                        │ 1                   │         │
                        │ assigned            ▼ N       │
                        ▼ N             ┌──────────┐ ┌──────────────────┐
                ┌──────────────────┐   │   tags   │ │ collection_items │
                │  asset_versions  │ N │          │ │                  │
                │  (CAS lineage)   │   └──────────┘ └──────────────────┘
                └──────────────────┘                        ▲ N
                                                            │ in
                                                            │
                ┌──────────────────┐                  ┌────┴───────────┐
                │    categories    │                  │  collections    │
                │  (tree)          │                  │  (smart/manual) │
                └──────────────────┘                  └────────────────┘
```

### 4.2 AI & Generation entities

```
                ┌──────────────────┐
                │     prompts      │ 1
                │                  │────┐
                └──────────────────┘    │
                        │ N             │ uses
                        │ references    ▼ N
                        │        ┌──────────────────┐
                        │        │  prompt_templates │
                        │        │  (reusable)       │
                        │        └──────────────────┘
                        │
                        ▼ N
                ┌──────────────────┐
                │  generation_jobs │ N ──────────┐
                └──────────────────┘             │
                        │ N                      │ runs
                        │ produces               ▼
                        ▼ N                ┌─────────────────┐
                ┌──────────────────┐       │   job_queue     │
                │   generation_    │       │  (persisted)    │
                │   attempts       │       └─────────────────┘
                └──────────────────┘
                        │
                        ▼ N
                ┌──────────────────┐
                │      assets      │ +── (asset.imported event)
                └──────────────────┘
```

### 4.3 Marketplace & cloud entities (V3+)

```
                ┌──────────────────────┐
                │  marketplace_listings │ N ──┐
                └──────────────────────┘     │
                        │ 1                   │ published_by
                        ▼                     ▼ N
                ┌──────────────────────┐  ┌──────────────────┐
                │  marketplace_listing │  │   marketplace_   │
                │  _versions           │  │   sellers        │
                └──────────────────────┘  └──────────────────┘
                                                │ 1
                                                ▼ N
                                           ┌──────────────────┐
                                           │  royalty_ledger  │
                                           └──────────────────┘

                ┌──────────────────┐
                │     plugins      │ N ────┐
                └──────────────────┘       │
                ┌──────────────────┐       │ installed_by
                │ plugin_versions  │       │
                └──────────────────┘       ▼ N
                                          ┌──────────────────┐
                                          │  user_installed_ │
                                          │  plugins         │
                                          └──────────────────┘

                ┌──────────────────┐
                │   workspaces     │  (V3+) 1 ───┐
                │   (tenant)       │             │
                └──────────────────┘             ▼ N
                                          ┌──────────────────┐
                                          │ workspace_members│
                                          └──────────────────┘
```

### 4.4 System entities

```
                ┌──────────────────┐
                │   audit_log      │ ←──── every state change records here
                └──────────────────┘
                ┌──────────────────┐
                │   recovery_      │ ──── snapshots keyed by project_id
                │   snapshots      │
                └──────────────────┘
                ┌──────────────────┐
                │  saved_searches  │
                └──────────────────┘
                ┌──────────────────┐
                │  undo_branch     │ ──── branching DAG nodes
                └──────────────────┘
                ┌──────────────────┐
                │  metrics_daily   │  ─── aggregates
                └──────────────────┘
```

---

## 5. Tables in detail

### 5.1 `projects`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | autoincrement |
| tenant_id | INTEGER (FK workspaces.id; V3+) | null in V1–V2 |
| name | TEXT NOT NULL | unique within tenant |
| description | TEXT | |
| cover_asset_id | INTEGER (FK assets.id) | null until cover assigned |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |
| archived_at | TIMESTAMP NULL | |
| version | INTEGER DEFAULT 1 | schema version of row, for forward-compat |
| metadata_json | TEXT | arbitrary key-value for plugin use |

Indexes:
- `idx_projects_tenant_id` (tenant_id)
- `idx_projects_archived_at` (archived_at)
- `idx_projects_updated_at` (updated_at)

### 5.2 `assets`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| tenant_id | INTEGER | null V1–V2 |
| project_id | INTEGER NOT NULL (FK projects.id) | |
| name | TEXT NOT NULL | |
| file_path | TEXT | virtual CAS path; resolved through CAS |
| cas_hash | TEXT | SHA-256 of blob |
| mime_type | TEXT | |
| size_bytes | INTEGER | |
| width | INTEGER | |
| height | INTEGER | |
| status | TEXT | enum: draft, approved, rejected, archived |
| license | TEXT | license identifier |
| license_metadata_json | TEXT | |
| favorite | INTEGER | 0/1 |
| last_used_at | TIMESTAMP NULL | |
| perceptual_hash | TEXT NULL | perceptual hash for duplicate detection (V2+) |
| embedding_vec_id | INTEGER NULL | pointer to embeddings table (V2+) |
| quality_score | REAL NULL | critic-LLM score (V2+) |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |
| version | INTEGER DEFAULT 1 | row schema version |
| metadata_json | TEXT | |

Indexes:
- `idx_assets_project_id` (project_id)
- `idx_assets_status` (status)
- `idx_assets_cas_hash` (cas_hash) — UNIQUE
- `idx_assets_favorite` (favorite)
- `idx_assets_last_used_at` (last_used_at)
- `idx_assets_perceptual_hash` (perceptual_hash) — V2+
- `idx_assets_quality_score` (quality_score) — V2+

### 5.3 `tags`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT NOT NULL | unique per tenant |
| color | TEXT | hex string |
| created_at | TIMESTAMP | |

Indexes:
- `idx_tags_name` UNIQUE (name)

### 5.4 `asset_tags` (many-to-many)

| Column | Type | Notes |
|--------|------|-------|
| asset_id | INTEGER FK assets.id | |
| tag_id | INTEGER FK tags.id | |
| applied_by | TEXT | creator or 'auto-tagger' |
| applied_at | TIMESTAMP | |
| confidence | REAL | 0.0–1.0; 1.0 for manual |

Composite PK: (asset_id, tag_id).

Index: `idx_asset_tags_tag_id` (tag_id)

### 5.5 `collections`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| tenant_id | INTEGER | null V1–V2 |
| name | TEXT NOT NULL | |
| type | TEXT | 'manual' or 'smart' |
| rule_json | TEXT | smart rule DSL (smart collections) |
| cover_asset_id | INTEGER (FK assets.id) | |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

### 5.6 `collection_items`

| Column | Type | Notes |
|--------|------|-------|
| collection_id | INTEGER FK collections.id | |
| asset_id | INTEGER FK assets.id | |
| position | INTEGER | manual ordering |
| added_at | TIMESTAMP | |

Composite PK: (collection_id, asset_id).

Index: `idx_collection_items_asset_id` (asset_id)

### 5.7 `categories`

Hierarchical manual categories.

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT NOT NULL | |
| parent_id | INTEGER NULL | recursive (FK categories.id) |
| created_at | TIMESTAMP | |

Self-FK: `categories.parent_id → categories.id` enables nested trees.

### 5.8 `category_assets`

| Column | Type | Notes |
|--------|------|-------|
| category_id | INTEGER FK | |
| asset_id | INTEGER FK | |

Composite PK: (category_id, asset_id).

### 5.9 `prompts`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| tenant_id | INTEGER | |
| project_id | INTEGER FK | |
| title | TEXT | |
| body | TEXT | |
| variables_json | TEXT | declared `{var}` names |
| is_template | INTEGER | 0/1 |
| parent_template_id | INTEGER NULL | for templates referenced |
| version | INTEGER DEFAULT 1 | |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

### 5.10 `prompt_templates`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | |
| description | TEXT | |
| body | TEXT | with `{variable}` placeholders |
| recommended_variables_json | TEXT | |
| sample_invocation_json | TEXT | |

### 5.11 `generation_jobs`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| tenant_id | INTEGER | |
| project_id | INTEGER FK | |
| prompt_id | INTEGER FK | |
| provider | TEXT | (openai, stability, ollama, sd-local) |
| model | TEXT | |
| seed | INTEGER NULL | |
| count | INTEGER | number of assets to produce |
| status | TEXT | queued, running, paused, completed, failed, cancelled |
| priority | INTEGER | smaller = higher |
| eta_seconds | INTEGER NULL | estimate |
| parameters_json | TEXT | (size, steps, guidance, etc.) |
| started_at | TIMESTAMP NULL | |
| completed_at | TIMESTAMP NULL | |
| cancellation_requested | INTEGER | 0/1 |
| attempts_json | TEXT | attempts log (last 10) |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

Indexes:
- `idx_jobs_status_priority` (status, priority)
- `idx_jobs_project_id` (project_id)
- `idx_jobs_cancellation_requested` (cancellation_requested)

### 5.12 `generation_attempts`

A child log per attempt of a generation job.

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| job_id | INTEGER FK | |
| attempt_number | INTEGER | |
| provider | TEXT | |
| model | TEXT | |
| started_at | TIMESTAMP | |
| completed_at | TIMESTAMP NULL | |
| success | INTEGER | 0/1 |
| error | TEXT NULL | |
| output_asset_ids_json | TEXT | (list of newly created assets) |
| cost_estimate_usd | REAL | |

### 5.13 `saved_searches`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | |
| query_json | TEXT | structured query |
| is_pinned | INTEGER | 0/1 |
| created_by | TEXT | creator or system |
| created_at | TIMESTAMP | |

### 5.14 `recovery_snapshots`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| project_id | INTEGER FK | |
| tenant_id | INTEGER | |
| payload_cas_hash | TEXT | SHA-256 of JSON snapshot blob in CAS |
| captured_at | TIMESTAMP | |
| trigger | TEXT | auto, manual, app_exit, crash |
| dirty_summary_json | TEXT | |
| version | INTEGER | snapshot schema version |

Indexes:
- `idx_recovery_project_id_captured_at` (project_id, captured_at)

### 5.15 `undo_branch` (V2+)

Branch/leaf nodes for branching undo graph.

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| session_id | TEXT | per-app-launch session |
| parent_id | INTEGER NULL | parent node |
| op_type | TEXT | (asset_set_status, asset_delete, prompt_commit, etc.) |
| op_payload_json | TEXT | undo + redo closures serialized |
| label | TEXT | for UI display |
| actor | TEXT | creator id |
| branch_id | INTEGER | branch this node belongs to |
| created_at | TIMESTAMP | |

### 5.16 `audit_log`

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| tenant_id | INTEGER | |
| actor | TEXT | creator id or 'system' |
| event_type | TEXT | matches EventBus taxonomy |
| entity_type | TEXT | asset, prompt, project, etc. |
| entity_id | INTEGER | nullable |
| payload_json | TEXT | scrubbed payload |
| correlation_id | TEXT | request trace id |
| timestamp | TIMESTAMP | |

Indexes:
- `idx_audit_tenant_event_ts` (tenant_id, event_type, timestamp)
- `idx_audit_entity` (entity_type, entity_id)

### 5.17 `metrics_daily`

| Column | Type | Notes |
|--------|------|-------|
| date | TEXT | YYYY-MM-DD |
| tenant_id | INTEGER | |
| metric | TEXT | |
| value | REAL | |
| dimensions_json | TEXT | optional filter dimensions |

PK: (date, tenant_id, metric).

### 5.18 `workspaces` (V3+)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | |
| owner_user_id | INTEGER | |
| type | TEXT | personal, team, business |
| created_at | TIMESTAMP | |
| cloud_mirror_enabled | INTEGER | 0/1 |

### 5.19 `workspace_members` (V3+)

| Column | Type | Notes |
|--------|------|-------|
| workspace_id | INTEGER FK | |
| user_id | INTEGER FK | |
| role | TEXT | owner, editor, reviewer, readonly |
| joined_at | TIMESTAMP | |

PK: (workspace_id, user_id).

### 5.20 `marketplace_listings` (V3+)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| seller_id | INTEGER FK users.id | |
| title | TEXT | |
| description | TEXT | |
| pack_type | TEXT | template, prompt, plugin, agent |
| pack_cas_hash | TEXT | SHA-256 of pack archive in CAS |
| version | TEXT | semver |
| price_usd_cents | INTEGER | 0 for free |
| license_type | TEXT | |
| rating_sum | INTEGER | denormalized |
| rating_count | INTEGER | denormalized |
| status | TEXT | draft, published, suspended |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

### 5.21 `marketplace_purchases` (V3+)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| buyer_user_id | INTEGER | |
| listing_id | INTEGER FK | |
| license_key | TEXT | |
| price_paid_usd_cents | INTEGER | |
| revenue_share_split_json | TEXT | |
| purchased_at | TIMESTAMP | |

### 5.22 `plugins` (V2.5+ public)

| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | plugin identifier |
| name | TEXT | |
| author | TEXT | |
| version | TEXT | semver |
| manifest_json | TEXT | full MFPlugin spec |
| signature | TEXT | cryptographic signature |
| trust_level | TEXT | first-party, verified, community, unknown |
| installed_at | TIMESTAMP | |
| enabled | INTEGER | 0/1 |

### 5.23 `agents` (V5+)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | |
| type | TEXT | co_creator, marketer, critic, refiner |
| recipe_json | TEXT | DAG of sub-agents and rules |
| memory_cas_hash | TEXT | long-term memory store reference |
| created_by | TEXT | user id or 'system' |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |
| enabled | INTEGER | 0/1 |

### 5.24 `agent_runs` (V5+)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| agent_id | INTEGER FK | |
| started_at | TIMESTAMP | |
| completed_at | TIMESTAMP NULL | |
| status | TEXT | running, paused, complete, failed, cancelled |
| spend_usd | REAL | running spend counter |
| spend_cap_usd | REAL NULL | hard cap |
| output_summary_json | TEXT | |
| correlation_id | TEXT | |

---

## 6. Indexes, summary

Beyond `assets`/`projects` indexes above, the schema enforces:

- All many-to-many join tables have composite PKs.
- All FK columns are indexed.
- The `audit_log` table has composite index for the dominant query pattern (`WHERE tenant_id = ? AND event_type = ? AND timestamp BETWEEN ? AND ?`).
- The `generation_jobs` table has composite priority index to make queue dispatch an O(log n) operation.

---

## 7. Migrations

### 7.1 Migration policy

- Every migration is **forward-compatible**; no destructive column drops, no type narrowing.
- New columns are added with sensible defaults.
- Renames are simulated as: add new column → backfill from old → keep old as deprecated for one major version → drop in next major.
- Schema tests assert that V1 data runs unmodified through V2 DB and back through columns it drops.

### 7.2 Migration list forward

| Version | Migration | Adds |
|---------|-----------|------|
| 1 | `0001_init` | Initial schema (V1.0) |
| 2 | `0002_v1_metadata_json` | Add `metadata_json` to projects, prompts, collections |
| 3 | `0003_v2_job_queue` | Add `generation_jobs`, `generation_attempts` |
| 4 | `0004_v2_perceptual_hash` | Add `perceptual_hash` to assets; `idx_assets_perceptual_hash` |
| 5 | `0005_v2_embeddings` | Add `embeddings` table (`asset_id`, `vec BLOB`, `model_id`) |
| 6 | `0006_v2_quality_scores` | Add `quality_score` to assets |
| 7 | `0007_v2_undo_branch` | Add `undo_branch` |
| 8 | `0008_v2_tags_color` | Add `color` to tags |
| 9 | `0009_v25_plugins` | Add `plugins` table |
| 10 | `0010_v25_brand_kits` | Add `brand_kits`, `brand_kit_assets` |
| 11 | `0011_v3_workspaces` | Add `workspaces`, `workspace_members`, `tenant_id` columns to major tables |
| 12 | `0012_v3_marketplace` | Add `marketplace_listings`, `marketplace_purchases` |
| 13 | `0013_v4_metrics_daily` | Add `metrics_daily` |
| 14 | `0014_v5_agents` | Add `agents`, `agent_runs` |
| ... | ... | ... |

### 7.3 Background migrator

V2+ ships a `BackgroundUpgrader` that:

- Detects pending migrations at app startup.
- Performs schema migrations immediately (fast, additive).
- Performs **content** migrations (re-hashing, embedding compute) in the background with progress dialog.
- Is resumable across app restarts.
- Emits `migration.progress` events to EventBus.

---

## 8. Caching strategy

| Cache | Scope | Invalidation |
|-------|-------|--------------|
| `ThumbnailCache` | process-wide LRU bytes-budget | On asset version change, on status change |
| `prompt_template_render_cache` | process | On template body change |
| `search_results_cache` | per-session | On any filter change |
| `embedding_cache` | persistent (file) | Re-computed on model_id change |
| `cas_resolution_cache` | process | Hash collision impossible; no invalidation needed |
| `settings_cache` | process | On settings change |
| `plugin_metadata_cache` | process | On plugin install/uninstall |

Cache invalidation events are bus-subscribed; on `asset.updated`, the related caches invalidate.

---

## 9. Search strategy

### 9.1 Search taxonomy

Five search modalities:

1. **Text search** on prompts, collections, project names — `LIKE` queries against indexed columns.
2. **Field-filter search** on assets (status, tag, license, dimensions, dates) — composite indexed query.
3. **Saved searches** — serialized structured query.
4. **Perceptual similarity (V2+)** — perceptual_hash (Hamming distance ≤ 5).
5. **Semantic similarity (V2+)** — CLIP embedding ANN index.

### 9.2 Implementation

- V2 introduces an `embedding_index` table (or vector file) with sqlite-vss or Qdrant as backing.
- All asset inserts trigger an embedding compute background job (rate-limited; cancellable).
- Search service exposes a uniform `query(SearchRequest) → SearchResponse` interface.

### 9.3 Backpressure

- Embedding compute runs as background job; UI never blocks.
- Search is debounced (300ms) on user typing.
- Cancel via per-row version counter; superseded search requests are dropped.

---

## 10. Content-Addressed Storage (CAS)

### 10.1 Strategy

Every immutable blob is content-addressed by SHA-256. The CAS is structured:

```
data/cas/
  AB/
    CD/
      ABCDEF....            # raw blob for hash starting with AB CD
  thumbs/
    <hash>_<width>x<height>.png
  derived/
    <parent_hash>_<transform_type>_<params>.png
  packs/
    <pack_name>.mfpack
```

### 10.2 CAS operations

- `put(blob) → hash` — write atomically with rename.
- `get(hash) → bytes` — read with integrity check.
- `exists(hash) → bool` — O(1).
- `delete_unreferenced(referenced_hashes)` — periodic GC.

### 10.3 Lineage

Every derived asset records its source `parent_hash` and `transform_type` (thumbnail, color-space-convert, upscale, edit). This forms the DAG that powers Version History.

### 10.4 Cloud CAS mirror (V3+)

- Cloud stores the same blobs; mirror is read-only by default.
- Local canonical; cloud optional.

---

## 11. Metadata

### 11.1 Asset metadata

Three layers:

1. **Built-in columns** for first-class fields (status, license, dimensions).
2. **Custom fields** via `metadata_json` — arbitrary key-value.
3. **EXIF / IPTC** embedded in original binary; preserved through CAS round-trip.

Metadata editor (V2+) supports custom field types (text, number, choice, color, date).

### 11.2 Project metadata

`projects.metadata_json` — same pattern.

### 11.3 Plugin-extension metadata

Plugins may add keys to `metadata_json` with a reserved namespace (`plugin:<plugin_id>:<key>`).

---

## 12. History

### 12.1 Project version history (V3+)

Powered by CAS lineage. Each "save point" of a project is recorded as a vertex linking to:

- A `projects.snapshot` row with metadata.
- A set of CAS hashes representing the project's asset pointers at that point.

Restore = re-point current project's assets to the snapshot's set.

### 12.2 Branching & merging

Branches are alternative DAG paths. Merging is asset-level: pick one asset version per conflict; UI shows diff and lets user resolve.

### 12.3 Asset version history

CAS-based; every edit creates a new version in CAS; original is preserved.

---

## 13. Collections & smart collections (V2+)

### 13.1 Manual collections

`collection_items` rows; manual ordering via `position`.

### 13.2 Smart collections

`collections.type = 'smart'`; rule stored in `rule_json` as a structured DSL:

```json
{
  "filters": [
    {"field": "status", "op": "eq", "value": "approved"},
    {"field": "tags", "op": "contains_all", "value": ["unicorn", "winter"]},
    {"field": "dimensions.width", "op": "gte", "value": 2000}
  ]
}
```

The collection's membership is **recomputed on-demand** when opened or on `event.asset.*` publication.

### 13.3 Membership indexes

For frequently-accessed smart collections, the membership result is cached in `collection_items` with a synthetic marker `is_smart = 1` and refreshed periodically.

---

## 14. Versioning & forward compatibility

### 14.1 Row-level version

Every persistent model carries `version` (default `1`). The model loader recognizes the row schema version and dispatches to a per-version deserializer. New columns are added to a new row version; old readers ignore unknown columns.

### 14.2 Backups & restore

A backup is a SQLite snapshot **plus** a CAS directory mirror:

```
backup_<timestamp>/
  magic_factory.db
  cas/
```

Restore = replace current DB + CAS directory.

### 14.3 Encryption at rest (V4+ Optional)

SQLCipher-compatible build. Migration from non-encrypted to encrypted is supported via one-shot upgrade.

---

## 15. Operational concerns

### 15.1 WAL disk usage

WAL files grow. Bookkeeping: checkpoint after every auto-save snapshot. WARN if WAL > 32MB.

### 15.2 VACUUM policy

Auto-VACUUM = INCREMENTAL enabled. Manual VACUUM at user request.

### 15.3 Integrity check

`PRAGMA integrity_check` runs at startup and after every migration. Result is logged; user notified if non-`ok`.

### 15.4 Backup policy

- Local automatic backup before any destructive migration.
- Optional cloud backup (V3+) runs hourly with delta sync.
- Recovery from local backup: `Settings → Backup → Restore` wizard.

### 15.5 Test fixtures

Tests use a `TestDatabase` helper that:

- Creates a tmp DB per test.
- Pre-applies all migrations.
- Provides seeded test data.

---

## 16. Closing note

The schema's center of gravity is `assets` — everything else exists to support asset states, derivations, and workflows around them. **Vertical integration is achieved partly by being able to express the full pipeline in the database**: from `prompts` to `generation_jobs` to `assets` to `recovery_snapshots` to `marketplace_listings`. Every artifact traces back to creator intent.
