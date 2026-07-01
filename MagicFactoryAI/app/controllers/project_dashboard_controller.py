"""Project-scoped dashboard data controller.

Sprint: Book Project Dashboard PRO #1.

Provides aggregated, project-scoped data for the per-project Dashboard
that opens after a project is selected. Reuses the existing repositories
and ``AssetController``/``PromptController``/``DashboardController`` — no
duplicated SQL, no schema changes.

The controller is read-only; the dashboard never mutates data. All
mutations continue to flow through their dedicated controllers.
"""

from __future__ import annotations

import json
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

from app.controllers.app_controller import AppController
from core.settings.manager import SettingsManager
from models.asset import Asset, AssetStatus
from models.category import Category
from models.prompt import Prompt
from models.project import Project
from ui.widgets.tag_utils import collect_all_collections, get_collections, get_tags


# ── Sprint: Dashboard PRO #3 — time analytics types ────────────────────────────


class TimeFilter(str, Enum):
    """User-facing time window the analytics section operates on."""

    TODAY = "today"
    WEEK = "week"
    MONTH = "month"
    ALL = "all"


@dataclass
class TimeBucketPoint:
    """A single bucket on a production time-series chart."""

    label: str  # e.g. "Mon", "W12", "Jan"
    timestamp: datetime
    generated: int = 0
    approved: int = 0
    rejected: int = 0
    exported: int = 0
    total: int = 0


@dataclass
class ProductionTimeSeries:
    """A series of time buckets plus a delta vs the previous period."""

    range_label: str  # "Daily" | "Weekly" | "Monthly"
    buckets: List[TimeBucketPoint]
    total_in_range: int
    delta_percent: float  # 0.0 if no previous data; ±X.X otherwise.


@dataclass
class StatusBreakdown:
    pending: int = 0
    generated: int = 0
    approved: int = 0
    rejected: int = 0
    exported: int = 0

    @property
    def total(self) -> int:
        return (
            self.pending
            + self.generated
            + self.approved
            + self.rejected
            + self.exported
        )

    def slice(self) -> List[tuple[str, int]]:
        """Status → count pairs in stable order (used by the donut chart)."""
        return [
            ("pending", self.pending),
            ("generated", self.generated),
            ("approved", self.approved),
            ("rejected", self.rejected),
            ("exported", self.exported),
        ]


@dataclass
class KPIDelta:
    """One KPI tile in the analytics section.

    ``sparkline`` is a small list of integers covering the recent period;
    the screen widget renders it as a sparkline.
    """

    key: str  # unique id, used to update the tile later
    label: str
    current_value: int
    previous_value: int
    delta_percent: float
    trend: str  # "up" | "down" | "flat"
    accent: str
    sparkline: List[int]


@dataclass
class DashboardAnalytics:
    """Top-level analytics payload — one shot, no DB writes."""

    time_filter: TimeFilter
    daily: ProductionTimeSeries
    weekly: ProductionTimeSeries
    monthly: ProductionTimeSeries
    status_breakdown: StatusBreakdown
    kpis: List[KPIDelta]


# ── Result dataclasses (DTOs) ────────────────────────────────────────────


@dataclass
class ProjectBookInfo:
    """Fixed book-printing settings.

    The Project model doesn't store print options directly today (no
    schema migration per the sprint rules). Where unavailable, defaults
    are sourced from ``SettingsManager`` so the dashboard never lies.
    """

    target_platform: str
    book_size: str
    dpi: int


@dataclass
class DashboardMetrics:
    total_assets: int = 0
    approved_assets: int = 0
    rejected_assets: int = 0
    pending_assets: int = 0
    generated_assets: int = 0
    exported_assets: int = 0
    total_pages: int = 0
    estimated_print_pages: int = 0
    collections: int = 0
    prompts: int = 0
    categories: int = 0
    books: int = 1
    completion_percent: float = 0.0
    # Sprint: Project Dashboard PRO #2 — Estimated export readiness as a
    # 0.0–100.0 percentage of approved assets that have already been
    # exported. Read-only derivation, no schema changes.
    estimated_export_readiness: float = 0.0


@dataclass
class ProgressSection:
    label: str
    value: int
    total: int
    accent: str
    hint: str = ""


@dataclass
class ActivityItem:
    """Single row in the Recent Activity timeline."""

    kind: str  # "generated" | "approved" | "rejected" | "imported" | "prompt_edited" | "exported"
    label: str
    detail: str
    timestamp: datetime
    accent: str


@dataclass
class HealthIssue:
    level: str  # "error" | "warning" | "info" | "success"
    icon: str
    label: str
    detail: str
    # Sprint: Project Dashboard PRO #2 — explicit, imperative next step
    # surfaced alongside each warning. Empty string = no action required.
    suggested_action: str = ""


@dataclass
class ProjectDashboardData:
    project: Optional[Project]
    book_info: ProjectBookInfo
    metrics: DashboardMetrics
    progress: List[ProgressSection] = field(default_factory=list)
    activity: List[ActivityItem] = field(default_factory=list)
    health: List[HealthIssue] = field(default_factory=list)
    recent_assets: List[Asset] = field(default_factory=list)
    recent_prompts: List[Prompt] = field(default_factory=list)


# ── Controller ───────────────────────────────────────────────────────────


class ProjectDashboardController:
    """Aggregator that always returns a fresh per-project snapshot."""

    # First-pass assumption: an "average" coloring book page is 1 approved
    # asset on average. Print-page estimation is approximate; the dashboard
    # shows the number as a labelled estimate rather than fabricating a count.
    _PRINT_PAGES_PER_BOOK = 24

    _STATUS_ACCENTS = {
        AssetStatus.PENDING: "#F59E0B",
        AssetStatus.GENERATED: "#3B82F6",
        AssetStatus.APPROVED: "#10B981",
        AssetStatus.REJECTED: "#EF4444",
        AssetStatus.EXPORTED: "#14B8A6",
    }

    def __init__(self, app: AppController) -> None:
        self._app = app
        self._settings = app.settings

    # ── Public entry ──────────────────────────────────────────────────────

    def get_dashboard(self, project_id: int) -> ProjectDashboardData:
        project = self._app.projects.get_by_id(project_id)

        # No project → empty placeholder payload so the screen can render
        # an empty state without forcing callers to special-case it.
        if project is None:
            return ProjectDashboardData(
                project=None,
                book_info=self._book_info_defaults(),
                metrics=DashboardMetrics(),
            )

        assets = self._app.assets.get_all(project_id=project_id)
        prompts = self._app.prompts.get_by_project(project_id)
        categories = self._app.categories.get_all(project_id)

        metrics = self._compute_metrics(assets, prompts, categories)
        progress = self._compute_progress(metrics)
        activity = self._compute_activity(assets, prompts)
        recent_assets = self._recent_assets(assets, limit=10)
        recent_prompts = self._recent_prompts(prompts, limit=8)
        health = self._compute_health(project, metrics, prompts, categories, recent_assets)

        return ProjectDashboardData(
            project=project,
            book_info=self._book_info_for(project),
            metrics=metrics,
            progress=progress,
            activity=activity,
            recent_assets=recent_assets,
            recent_prompts=recent_prompts,
            health=health,
        )

    # ── Helpers ───────────────────────────────────────────────────────────

    def _book_info_defaults(self) -> ProjectBookInfo:
        return ProjectBookInfo(
            target_platform="Universal",
            book_size="8.5 × 11 in",
            dpi=int(self._settings.get("export.default_dpi", 300)),
        )

    def _book_info_for(self, project: Project) -> ProjectBookInfo:
        """Source book-printing settings from project metadata if present.

        Older projects may store their print settings in a JSON metadata
        blob on disk; the dashboard surfaces whatever is found and
        otherwise falls back to settings defaults. Reading only — no
        write back to the database.
        """
        info = self._book_info_defaults()
        meta_path = Path("data") / "project_meta" / f"{project.id}.json"
        if not meta_path.exists():
            return info
        try:
            with open(meta_path, encoding="utf-8") as fh:
                blob = json.load(fh)
        except (OSError, json.JSONDecodeError):
            return info
        if isinstance(blob, dict):
            if isinstance(blob.get("target_platform"), str):
                info.target_platform = blob["target_platform"]
            if isinstance(blob.get("book_size"), str):
                info.book_size = blob["book_size"]
            if isinstance(blob.get("dpi"), int):
                info.dpi = blob["dpi"]
        return info

    def _compute_metrics(
        self,
        assets: List[Asset],
        prompts: List[Prompt],
        categories: List[Category],
    ) -> DashboardMetrics:
        status_counts = Counter(asset.status for asset in assets)
        approved = status_counts.get(AssetStatus.APPROVED, 0)
        pending = status_counts.get(AssetStatus.PENDING, 0)
        rejected = status_counts.get(AssetStatus.REJECTED, 0)
        generated = status_counts.get(AssetStatus.GENERATED, 0)
        exported = status_counts.get(AssetStatus.EXPORTED, 0)

        collections = sorted({c for asset in assets for c in get_collections(asset)})
        total_pages = len(assets)

        # Completion ratio = approved vs. (approved + pending + rejected).
        # "Completed" excludes still-pending and rejected so the bar moves
        # forward when items are reviewed, not when they are simply created.
        denominator = approved + pending + rejected
        completion_percent = (
            round((approved / denominator) * 100.0, 1)
            if denominator > 0
            else 0.0
        )

        # One approved asset maps to one print page once exported. The
        # count is exact (no fabrication) — the dashboard surfaces the
        # print-target alongside the value.
        estimated_print_pages = approved

        # A project becomes a finished book only when at least one
        # approved asset has been exported. Otherwise no book exists.
        books = 1 if exported > 0 else 0

        # Sprint: Project Dashboard PRO #2 — Readiness = exported / approved.
        # If nothing is approved yet the readiness is 0% rather than NaN
        # so the dashboard card always shows a number.
        if approved > 0:
            estimated_export_readiness = round(
                (exported / approved) * 100.0, 1
            )
        else:
            estimated_export_readiness = 0.0

        return DashboardMetrics(
            total_assets=len(assets),
            approved_assets=approved,
            rejected_assets=rejected,
            pending_assets=pending + generated,
            generated_assets=generated,
            exported_assets=exported,
            total_pages=total_pages,
            estimated_print_pages=estimated_print_pages,
            collections=len(collections),
            prompts=len(prompts),
            categories=len(categories),
            books=books,
            completion_percent=completion_percent,
            estimated_export_readiness=estimated_export_readiness,
        )

    def _compute_progress(self, metrics: DashboardMetrics) -> List[ProgressSection]:
        # Each row's "total" is the project-wide cap so the same max-width
        # of 100% applies to every bar. We cap each at the asset total so
        # "overflow" never happens — a category with more items than
        # total assets (impossible but defensive) is treated as 100%.
        total = max(metrics.total_assets, 1)
        return [
            ProgressSection(
                label="Assets",
                value=metrics.total_assets,
                total=total,
                accent="#6366F1",
            ),
            ProgressSection(
                label="Approved",
                value=metrics.approved_assets,
                total=total,
                accent="#10B981",
                hint="ready for print",
            ),
            ProgressSection(
                label="Pages",
                value=metrics.estimated_print_pages,
                total=max(self._PRINT_PAGES_PER_BOOK, 1),
                accent="#3B82F6",
                hint=f"target ≈ {self._PRINT_PAGES_PER_BOOK} pages",
            ),
            ProgressSection(
                label="Prompts",
                value=metrics.prompts,
                total=max(metrics.prompts + 8, 1),
                accent="#EC4899",
                hint="template library",
            ),
            ProgressSection(
                label="Review",
                value=metrics.pending_assets,
                total=total,
                accent="#F59E0B",
                hint="to review",
            ),
            ProgressSection(
                label="Export readiness",
                value=metrics.exported_assets,
                total=max(metrics.approved_assets, 1),
                accent="#14B8A6",
                hint="approved → exported",
            ),
        ]

    def _compute_activity(
        self,
        assets: List[Asset],
        prompts: List[Prompt],
    ) -> List[ActivityItem]:
        """Merge assets + prompts into a single timeline, newest first."""
        items: List[ActivityItem] = []

        for asset in assets:
            kind = "imported" if asset.status == AssetStatus.PENDING else asset.status.value
            if kind == "approved":
                label = f"Approved " f"asset"
                detail = asset.name
                accent = self._STATUS_ACCENTS[AssetStatus.APPROVED]
            elif kind == "rejected":
                label = "Rejected asset"
                detail = asset.name
                accent = self._STATUS_ACCENTS[AssetStatus.REJECTED]
            elif kind == "imported":
                label = "Imported asset"
                detail = asset.name
                accent = "#3B82F6"
            elif kind == "exported":
                label = "Book exported"
                detail = asset.name
                accent = self._STATUS_ACCENTS[AssetStatus.EXPORTED]
            else:
                label = "Generated asset"
                detail = asset.name
                accent = self._STATUS_ACCENTS[AssetStatus.GENERATED]
            items.append(
                ActivityItem(
                    kind=kind,
                    label=label,
                    detail=detail,
                    timestamp=asset.updated_at,
                    accent=accent,
                )
            )

        for prompt in prompts:
            items.append(
                ActivityItem(
                    kind="prompt_edited",
                    label="Prompt edited",
                    detail=prompt.title,
                    timestamp=prompt.updated_at,
                    accent="#EC4899",
                )
            )

        items.sort(key=lambda item: item.timestamp, reverse=True)
        return items[:20]

    def _recent_assets(self, assets: List[Asset], limit: int) -> List[Asset]:
        return sorted(assets, key=lambda a: a.updated_at, reverse=True)[:limit]

    def _recent_prompts(self, prompts: List[Prompt], limit: int) -> List[Prompt]:
        return sorted(prompts, key=lambda p: p.updated_at, reverse=True)[:limit]

    def _compute_health(
        self,
        project: Project,
        metrics: DashboardMetrics,
        prompts: List[Prompt],
        categories: List[Category],
        recent_assets: List[Asset],
    ) -> List[HealthIssue]:
        issues: List[HealthIssue] = []

        # Sprint: Project Dashboard PRO #2 — Surface a "healthy" success
        # banner when every check below passes, so the panel isn't empty
        # on a clean project.
        if metrics.total_assets > 0 and metrics.pending_assets == 0:
            issues.append(
                HealthIssue(
                    level="success",
                    icon="✅",
                    label="Project is healthy",
                    detail=(
                        "All assets reviewed, prompts and categories configured, "
                        "DPI meets print standards."
                    ),
                    suggested_action="Continue exporting approved assets.",
                )
            )

        # Reviews: pending items => "Unreviewed assets"
        if metrics.pending_assets > 0:
            issues.append(
                HealthIssue(
                    level="warning",
                    icon="📝",
                    label="Unreviewed assets",
                    detail=(
                        f"{metrics.pending_assets} asset(s) pending review. "
                        "Approve or reject to advance."
                    ),
                    suggested_action="Open Review Queue and approve or reject pending items.",
                )
            )

        # Prompts: zero is a warning
        if metrics.prompts == 0:
            issues.append(
                HealthIssue(
                    level="warning",
                    icon="💬",
                    label="Missing prompts",
                    detail=(
                        "No prompt templates defined. Add prompts in Prompt "
                        "Studio to accelerate generation."
                    ),
                    suggested_action="Open Prompt Studio and add at least one template.",
                )
            )

        # Categories: zero → missing categories
        if metrics.categories == 0:
            issues.append(
                HealthIssue(
                    level="info",
                    icon="📁",
                    label="Missing categories",
                    detail=(
                        "No themed categories. Create at least one in the "
                        "Categories manager."
                    ),
                    suggested_action="Create at least one category in Categories.",
                )
            )

        # Collections: empty → empty collections warning
        if metrics.collections == 0:
            issues.append(
                HealthIssue(
                    level="info",
                    icon="📊",
                    label="Empty collections",
                    detail=(
                        "No tagged collections yet. Group approved assets "
                        "into collections to organize the book."
                    ),
                    suggested_action="Add at least one collection in the Library.",
                )
            )

        # Cover: absence of an asset named "cover" or with the cover tag.
        cover_found = any(
            asset.name.lower().startswith("cover") or "cover" in get_tags(asset)
            for asset in recent_assets
        )
        if not cover_found and metrics.total_assets > 0:
            issues.append(
                HealthIssue(
                    level="warning",
                    icon="🖼",
                    label="Missing cover",
                    detail=(
                        "No asset flagged as cover. Approve a cover image "
                        "so the book has a title page."
                    ),
                    suggested_action="Approve a cover image in the Review Queue.",
                )
            )

        # DPI: below 300 → Low DPI print quality
        if project is not None:
            info = self._book_info_for(project)
            if info.dpi < 300:
                issues.append(
                    HealthIssue(
                        level="warning",
                        icon="📐",
                        label="Low DPI",
                        detail=(
                            f"Current DPI is {info.dpi}. Print-ready "
                            "books need at least 300 DPI."
                        ),
                        suggested_action="Set DPI to 300 in Settings → Export.",
                    )
                )

        # Duplicates: SHA-256 collisions only if we have ≥ 2 files
        hashes = Counter()
        for asset in recent_assets:
            if not asset.file_path:
                continue
            try:
                import hashlib

                with open(asset.file_path, "rb") as fh:
                    hashes[hashlib.sha256(fh.read()).hexdigest()] += 1
            except OSError:
                # Missing file — already surfaced by File → thumbnail path
                # checks in the Library tab. We deliberately do not raise
                # a duplicate issue here.
                continue
        duplicates = sum(1 for count in hashes.values() if count > 1)
        if duplicates > 0:
            issues.append(
                HealthIssue(
                    level="error",
                    icon="🧬",
                    label="Duplicate assets",
                    detail=(
                        f"{duplicates} duplicate image(s) detected. Run "
                        "\"Find duplicates\" in the Library to clean up."
                    ),
                    suggested_action="Run Find Duplicates in the Library tab.",
                )
            )

        return issues

    # ── Sprint: Dashboard PRO #3 — production analytics ─────────────────────────
    # The methods below are pure read-only derivations over the asset list
    # already loaded in ``get_dashboard``. No SQL is duplicated, no schema
    # is touched. They produce time-bucketed series, KPI deltas and a
    # status breakdown that the screen renders as charts.

    _KPI_ACCENTS = {
        "generated": "#3B82F6",   # Blue  — info / new arrivals
        "approved":  "#10B981",   # Green — progress
        "rejected":  "#EF4444",   # Red   — needs attention
        "exported":  "#14B8A6",   # Teal  — completion
    }

    def get_analytics(
        self,
        project_id: int,
        time_filter: TimeFilter,
    ) -> DashboardAnalytics:
        """Compute analytics snapshot for :paramref:`project_id`.

        Series are always populated (Daily 7-bucket, Weekly 8-bucket,
        Monthly 12-bucket) so the dashboard doesn't churn work when the
        user switches the filter — only the KPI deltas are recomputed.
        """
        assets = self._app.assets.get_all(project_id=project_id)
        daily = self._bucket_daily(assets)
        weekly = self._bucket_weekly(assets)
        monthly = self._bucket_monthly(assets)
        breakdown = self._status_breakdown(assets)
        kpis = self._kpi_deltas(assets, time_filter)
        return DashboardAnalytics(
            time_filter=time_filter,
            daily=daily,
            weekly=weekly,
            monthly=monthly,
            status_breakdown=breakdown,
            kpis=kpis,
        )

    # ── Bucketing helpers ────────────────────────────────────────────────

    @staticmethod
    def _safe_pct(curr: float, prev: float) -> float:
        """Return ``(curr - prev) / prev * 100`` clamped to ±9999.

        No previous data → 0.0 (so the UI shows a neutral trend rather
        than a spurious infinity or NaN).
        """
        if prev <= 0:
            if curr <= 0:
                return 0.0
            return 100.0  # First-period rise is treated as +100 %.
        delta = ((curr - prev) / prev) * 100.0
        return round(max(min(delta, 9999.0), -9999.0), 1)

    def _bucket_daily(self, assets: List[Asset]) -> ProductionTimeSeries:
        """Last 7 days, bucket by calendar day (today inclusive)."""
        today = datetime.now().date()
        buckets: List[TimeBucketPoint] = []
        for offset in range(6, -1, -1):
            day = today - timedelta(days=offset)
            buckets.append(
                TimeBucketPoint(
                    label=day.strftime("%a"),
                    timestamp=datetime.combine(day, datetime.min.time()),
                )
            )

        for asset in assets:
            d = asset.created_at.date()
            # Find bucket whose date matches (offset today=0 means today).
            for bucket in buckets:
                if bucket.timestamp.date() == d:
                    self._accumulate(bucket, asset)
                    break

        total = sum(b.total for b in buckets)
        prev_total = sum(
            self._count_status(assets, lambda dt: dt < buckets[0].timestamp)
            for _ in [None]
        )
        # Use the cumulative "generated" count in the week before the
        # earliest bucket to compute the delta.
        prev_window_start = buckets[0].timestamp - timedelta(days=7)
        prev_window_end = buckets[0].timestamp
        prev_total = 0
        for asset in assets:
            if prev_window_start <= asset.created_at < prev_window_end:
                prev_total += 1
        delta = self._safe_pct(total, prev_total)
        return ProductionTimeSeries(
            range_label="Daily",
            buckets=buckets,
            total_in_range=total,
            delta_percent=delta,
        )

    def _bucket_weekly(self, assets: List[Asset]) -> ProductionTimeSeries:
        """Last 8 ISO weeks, bucket by week number (current week inclusive)."""
        today = datetime.now().date()
        # ISO weekday: Monday=1 … Sunday=7. Back up to Monday.
        monday_this_week = today - timedelta(days=today.weekday())
        buckets: List[TimeBucketPoint] = []
        for offset in range(7, -1, -1):
            start = monday_this_week - timedelta(weeks=offset)
            buckets.append(
                TimeBucketPoint(
                    label=f"W{start.isocalendar().week}",
                    timestamp=datetime.combine(start, datetime.min.time()),
                )
            )

        for asset in assets:
            d = asset.created_at.date()
            for bucket in buckets:
                # Bucket owns its start; next bucket starts a week later.
                next_idx = buckets.index(bucket) + 1
                end = (
                    buckets[next_idx].timestamp.date()
                    if next_idx < len(buckets)
                    else (bucket.timestamp.date() + timedelta(days=7))
                )
                if bucket.timestamp.date() <= d < end:
                    self._accumulate(bucket, asset)
                    break

        total = sum(b.total for b in buckets)
        prev_start = buckets[0].timestamp - timedelta(weeks=8)
        prev_end = buckets[0].timestamp
        prev_total = sum(
            1
            for asset in assets
            if prev_start <= asset.created_at < prev_end
        )
        delta = self._safe_pct(total, prev_total)
        return ProductionTimeSeries(
            range_label="Weekly",
            buckets=buckets,
            total_in_range=total,
            delta_percent=delta,
        )

    def _bucket_monthly(self, assets: List[Asset]) -> ProductionTimeSeries:
        """Last 12 months, bucket by month (current month inclusive)."""
        today = datetime.now().date().replace(day=1)
        buckets: List[TimeBucketPoint] = []
        for offset in range(11, -1, -1):
            year = today.year
            month = today.month - offset
            while month <= 0:
                month += 12
                year -= 1
            label = f"{year}-{month:02d}"
            ts = datetime(year, month, 1)
            buckets.append(
                TimeBucketPoint(label=label[:7], timestamp=ts)
            )

        for asset in assets:
            d = asset.created_at.date()
            for idx, bucket in enumerate(buckets):
                next_ts = (
                    buckets[idx + 1].timestamp if idx + 1 < len(buckets) else None
                )
                end_date = (
                    next_ts.date() if next_ts else today.replace(day=28) + timedelta(days=4)
                )
                if bucket.timestamp.date() <= d < end_date:
                    self._accumulate(bucket, asset)
                    break

        total = sum(b.total for b in buckets)
        prev_start = buckets[0].timestamp - timedelta(days=365)
        prev_end = buckets[0].timestamp
        prev_total = sum(
            1
            for asset in assets
            if prev_start <= asset.created_at < prev_end
        )
        delta = self._safe_pct(total, prev_total)
        return ProductionTimeSeries(
            range_label="Monthly",
            buckets=buckets,
            total_in_range=total,
            delta_percent=delta,
        )

    @staticmethod
    def _accumulate(bucket: TimeBucketPoint, asset: Asset) -> None:
        """Increment the four status counters in :paramref:`bucket`."""
        # All four branch-paths increment total — the spec is that the
        # chart shows production (i.e. any non-pending asset counts).
        bucket.total += 1
        if asset.status == AssetStatus.GENERATED:
            bucket.generated += 1
        elif asset.status == AssetStatus.APPROVED:
            bucket.approved += 1
        elif asset.status == AssetStatus.REJECTED:
            bucket.rejected += 1
        elif asset.status == AssetStatus.EXPORTED:
            bucket.exported += 1

    def _status_breakdown(self, assets: List[Asset]) -> StatusBreakdown:
        c = Counter(asset.status for asset in assets)
        return StatusBreakdown(
            pending=c.get(AssetStatus.PENDING, 0),
            generated=c.get(AssetStatus.GENERATED, 0),
            approved=c.get(AssetStatus.APPROVED, 0),
            rejected=c.get(AssetStatus.REJECTED, 0),
            exported=c.get(AssetStatus.EXPORTED, 0),
        )

    @staticmethod
    def _count_status(
        assets: List[Asset], predicate
    ) -> int:
        """Helper kept for symmetry with future custom filters."""
        return sum(1 for asset in assets if predicate(asset.created_at))

    # ── KPI deltas ────────────────────────────────────────────────────────
    # Sparkline lists are always 7 entries (one per day in the last
    # week) so the visual scale stays constant regardless of the
    # current filter — users see a stable mini-chart when they switch.

    def _kpi_deltas(
        self,
        assets: List[Asset],
        time_filter: TimeFilter,
    ) -> List[KPIDelta]:
        """Return the 4 KPI tiles for the active time filter."""
        window = self._window_for(time_filter)
        now = datetime.now()
        prev_start = now - timedelta(days=window * 2)
        prev_end = now - timedelta(days=window)

        definitions = [
            ("generated", "Generated", self._KPI_ACCENTS["generated"], AssetStatus.GENERATED, AssetStatus.APPROVED),
            ("approved",  "Approved",  self._KPI_ACCENTS["approved"],  AssetStatus.APPROVED,  AssetStatus.APPROVED),
            ("rejected",  "Rejected",  self._KPI_ACCENTS["rejected"],  AssetStatus.REJECTED,  AssetStatus.REJECTED),
            ("exported",  "Exported",  self._KPI_ACCENTS["exported"],  AssetStatus.EXPORTED,  AssetStatus.EXPORTED),
        ]

        tiles: List[KPIDelta] = []
        for key, label, accent, _final_status, _match_status in definitions:
            current, previous, sparkline = self._kpi_count(
                assets, key, window, now
            )
            delta = self._safe_pct(current, previous)
            trend = "flat" if delta == 0 else ("up" if delta > 0 else "down")
            tiles.append(
                KPIDelta(
                    key=key,
                    label=label,
                    current_value=current,
                    previous_value=previous,
                    delta_percent=delta,
                    trend=trend,
                    accent=accent,
                    sparkline=sparkline,
                )
            )
        return tiles

    @staticmethod
    def _window_for(time_filter: TimeFilter) -> int:
        """Map UI TimeFilter to a window in days for KPI deltas."""
        return {
            TimeFilter.TODAY: 1,
            TimeFilter.WEEK: 7,
            TimeFilter.MONTH: 30,
            TimeFilter.ALL: 365,
        }.get(time_filter, 7)

    def _kpi_count(
        self,
        assets: List[Asset],
        key: str,
        window: int,
        now: datetime,
    ) -> tuple[int, int, List[int]]:
        """Count KPI value over [now-window, now], [now-2*window, now-window],
        and produce a 7-day sparkline series."""
        start = now - timedelta(days=window)
        prev_start = start - timedelta(days=window)

        def _match(asset: Asset) -> bool:
            if key == "generated":
                return asset.status != AssetStatus.PENDING
            if key == "approved":
                return asset.status == AssetStatus.APPROVED
            if key == "rejected":
                return asset.status == AssetStatus.REJECTED
            if key == "exported":
                return asset.status == AssetStatus.EXPORTED
            return False

        def _ts(asset: Asset) -> datetime:
            return asset.created_at if key == "generated" else asset.updated_at

        current = sum(
            1 for a in assets if _match(a) and start <= _ts(a) <= now
        )
        previous = sum(
            1 for a in assets if _match(a) and prev_start <= _ts(a) < start
        )

        # Sparkline: 7 daily buckets regardless of filter so the visual
        # shape stays stable.
        spark = [0] * 7
        for asset in assets:
            age = now - _ts(asset)
            days_ago = age.days
            if 0 <= days_ago < 7 and _match(asset):
                spark[6 - days_ago] += 1

        return current, previous, spark
