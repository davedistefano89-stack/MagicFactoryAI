"""Per-project Dashboard PRO #2.

Sprint: Book Project Dashboard PRO #2 — premium UI rewrite.

This screen is opened immediately after a project is selected. It
reuses the existing ``ProjectDashboardController`` (read-only) so the
underlying SQL queries live in one place and aren't duplicated.

Sections rendered (per spec):

* Project Card PRO — 16 metadata fields on a responsive grid
* Quick Actions PRO — 8 hero cards with hover lift animation
* Project Health PRO — Green/Yellow/Orange/Red severity warnings with
  suggested actions
* Live Statistics — 10 modern stat cards
* Recent Assets — horizontal thumbnail gallery (max 10), with status
  badge, creation date and Open button per card
* Recent Activity PRO — modern timeline with the 6 spec icons,
  newest first

The screen never mutates data; mutations continue to flow through
the existing controllers.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import List, Optional

from PySide6.QtCore import QEasingCurve, QPropertyAnimation, Qt, Signal
from PySide6.QtGui import QColor, QPixmap
from PySide6.QtWidgets import (
    QDialog,
    QFrame,
    QGraphicsDropShadowEffect,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLayout,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from app.controllers.project_dashboard_controller import (
    ActivityItem,
    DashboardAnalytics,
    DashboardMetrics,
    HealthIssue,
    ProjectDashboardController,
    ProjectDashboardData,
    TimeFilter,
)
from core.theme.colors import Colors
from models.asset import Asset, AssetStatus
from models.project import Project, ProjectStatus
from ui.screens.base_screen import BaseScreen
from ui.widgets.asset_inspector_dialog import AssetInspectorDialog
from ui.widgets.charts import (
    AnimatedKpiTile,
    BarChart,
    DonutChart,
    TimeFilterBar,
)
from utils.logger import get_logger

logger = get_logger(__name__)


# ── Local styling constants ──────────────────────────────────────────────

_STATUS_COLORS = {
    ProjectStatus.DRAFT: Colors.TEXT_MUTED,
    ProjectStatus.ACTIVE: Colors.SUCCESS,
    ProjectStatus.ARCHIVED: Colors.WARNING,
}

_ASSET_THUMB_SIZE = 132
_ASSET_THUMB_BG = Colors.SURFACE_LIGHT

# Sprint: Project Dashboard PRO #2 — 6 spec-mandated activity icons.
# Keys collide with the controller's "kind" strings (generated,
# approved, rejected, imported, prompt_edited, exported).
_KIND_ICONS = {
    "generated": "🎨",
    "approved": "✅",
    "rejected": "❌",
    "imported": "📁",
    "prompt_edited": "🧠",
    "exported": "📦",
}

# Severity → colour map. Spec explicitly calls for Green / Yellow /
# Orange / Red. We promote the controller's "info" level to Yellow
# (was Blue) so the four-bucket palette applies cleanly. "success"
# maps to Green so healthy projects remain visually distinct.
_SEVERITY_COLORS = {
    "success": Colors.SUCCESS,            # Green
    "info": "#FACC15",                    # Yellow (warn-equivalent)
    "warning": Colors.WARNING,            # Orange
    "error": Colors.ERROR,                # Red
}


# ── Hover animation primitive ──────────────────────────────────────────


class HoverCard(QFrame):
    """Card with a soft glow/lift animation on hover.

    Uses QPropertyAnimation on the blurRadius of a single
    QGraphicsDropShadowEffect to deliver a subtle "glow + lift" effect
    without overlap (effect paints outside the widget rect but the
    surrounding layout's setSpacing absorbs it).
    """

    def __init__(
        self,
        accent_hex: str,
        radius: int = 12,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._accent = accent_hex
        self.setObjectName("HoverCard")
        self._base_css = (
            "QFrame#HoverCard {"
            f" background-color: {Colors.SURFACE};"
            f" border: 1px solid {Colors.BORDER};"
            f" border-radius: {radius}px;"
            " }"
            "QFrame#HoverCard:hover {"
            f"  border: 1px solid {accent_hex};"
            f"  background-color: {Colors.SURFACE_LIGHT};"
            " }"
        )
        self.setStyleSheet(self._base_css)

        # Glow shadow.
        self._shadow = QGraphicsDropShadowEffect(self)
        self._shadow.setBlurRadius(8)
        self._shadow.setOffset(0, 4)
        glow = QColor(accent_hex)
        glow.setAlpha(0)
        self._shadow.setColor(glow)
        self.setGraphicsEffect(self._shadow)

        self._shadow_anim = QPropertyAnimation(self._shadow, b"blurRadius")
        self._shadow_anim.setDuration(220)
        self._shadow_anim.setEasingCurve(QEasingCurve.Type.OutQuad)


    def enterEvent(self, event) -> None:  # type: ignore[override]
        glow = QColor(self._accent)
        glow.setAlpha(70)
        self._shadow.setColor(glow)
        self._shadow_anim.stop()
        self._shadow_anim.setStartValue(self._shadow.blurRadius())
        self._shadow_anim.setEndValue(24)
        self._shadow_anim.start()
        super().enterEvent(event)

    def leaveEvent(self, event) -> None:  # type: ignore[override]
        self._shadow_anim.stop()
        self._shadow_anim.setStartValue(self._shadow.blurRadius())
        self._shadow_anim.setEndValue(8)
        self._shadow_anim.start()
        glow = QColor(self._accent)
        glow.setAlpha(0)
        self._shadow.setColor(glow)
        super().leaveEvent(event)


# ── Screen ──────────────────────────────────────────────────────────────


class ProjectDashboardScreen(BaseScreen):
    """Per-project Dashboard PRO #2 + Sprint PRO #3 analytics."""

    screen_id = "project_dashboard"

    # Same signals as before — MainWindow wires these already.
    enter_workspace_tab = Signal(int)
    navigate_to_target = Signal(str)

    def __init__(self, controller, parent=None) -> None:
        self._dash_ctrl = ProjectDashboardController(controller)
        self._data: Optional[ProjectDashboardData] = None
        self._analytics: Optional[DashboardAnalytics] = None
        # Reusable layout handles so refresh() can rebuild in-place.
        self._actions_grid: Optional[QGridLayout] = None
        self._health_box: Optional[QVBoxLayout] = None
        self._activity_box: Optional[QVBoxLayout] = None
        self._assets_strip: Optional[QHBoxLayout] = None
        self._stats_grid: Optional[QGridLayout] = None
        self._meta_widgets: dict = {}
        # Sprint: Dashboard PRO #3 — interactive analytics widgets.
        self._filter_bar: Optional[TimeFilterBar] = None
        self._kpi_tiles: dict = {}
        self._daily_chart: Optional[BarChart] = None
        self._weekly_chart: Optional[BarChart] = None
        self._monthly_chart: Optional[BarChart] = None
        self._status_donut: Optional[DonutChart] = None
        self._active_filter: TimeFilter = TimeFilter.WEEK
        super().__init__(controller, parent)

    # ── UI construction ─────────────────────────────────────────────

    def _build_ui(self) -> None:
        # Generous spacing prevents HoverCard glow shadows from clipping.
        self._layout.setContentsMargins(28, 24, 28, 32)
        self._layout.setSpacing(22)

        # Section 1 — Project Card PRO.
        self._project_card = self._build_project_card()
        self._layout.addWidget(self._project_card)

        # Section 2 — Quick Actions PRO.
        actions_section = self._build_card_section(
            "Quick Actions",
            self._build_actions_grid(),
        )
        self._layout.addWidget(actions_section)

        # Section 3 — Production Analytics (Sprint PRO #3).
        analytics_section = self._build_analytics_section()
        self._layout.addWidget(analytics_section)

        # Section 4 — Health + Statistics in a horizontal split.
        split = QHBoxLayout()
        split.setSpacing(20)

        health_section = self._build_card_section(
            "Project Health",
            self._build_health_box(),
        )
        split.addWidget(health_section, stretch=4)

        stats_section = self._build_card_section(
            "Live Statistics",
            self._build_stats_grid(),
        )
        split.addWidget(stats_section, stretch=6)

        self._layout.addLayout(split)

        # Section 5 — Recent Assets gallery.
        strip_section = self._build_card_section(
            "Recent Assets",
            self._build_assets_strip(),
        )
        self._layout.addWidget(strip_section)

        # Section 6 — Recent Activity PRO timeline.
        activity_section = self._build_card_section(
            "Recent Activity",
            self._build_activity_box(),
        )
        self._layout.addWidget(activity_section)

        self._layout.addStretch(1)

    # ── Analytics section (Sprint: Dashboard PRO #3) ────────────────────────

    def _build_analytics_section(self) -> QFrame:
        """Return the production-analytics card with filter bar + KPIs +
        bar charts (daily/weekly/monthly) + status donut."""
        card = QFrame()
        card.setStyleSheet(
            f"background-color: {Colors.SURFACE}; border: 1px solid {Colors.BORDER};"
            " border-radius: 16px;"
        )

        outer = QVBoxLayout(card)
        outer.setContentsMargins(24, 20, 24, 24)
        outer.setSpacing(16)

        # ── Header: title + filter bar ──
        header_row = QHBoxLayout()
        header_row.setSpacing(8)

        header_dot = QFrame()
        header_dot.setFixedSize(8, 8)
        header_dot.setStyleSheet(
            f"background-color: {Colors.PRIMARY}; border-radius: 4px; border: none;"
        )
        header_row.addWidget(header_dot)
        header = QLabel("Production Analytics")
        header.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 16px; font-weight: 800;"
            " background: transparent; border: none;"
        )
        header_row.addWidget(header)
        header_row.addStretch(1)
        outer.addLayout(header_row)

        self._filter_bar = TimeFilterBar(
            initial=self._active_filter,
            accent=Colors.PRIMARY,
        )
        self._filter_bar.filter_changed.connect(self._on_filter_changed)
        outer.addWidget(self._filter_bar)

        # ── KPI grid ──
        kpi_row = QHBoxLayout()
        kpi_row.setSpacing(12)
        kpi_definitions = [
            ("generated", "Generated", Colors.CARD_BLUE),
            ("approved",  "Approved",  Colors.SUCCESS),
            ("rejected",  "Rejected",  Colors.ERROR),
            ("exported",  "Exported",  Colors.CARD_TEAL),
        ]
        self._kpi_tiles = {}
        for key, label, accent in kpi_definitions:
            tile = AnimatedKpiTile(key=key, label=label, accent=accent)
            kpi_row.addWidget(tile)
            self._kpi_tiles[key] = tile
        outer.addLayout(kpi_row)

        # ── Charts row: 3 bar charts (Daily / Weekly / Monthly) + donut ──
        charts_row = QHBoxLayout()
        charts_row.setSpacing(12)

        charts_col = QVBoxLayout()
        charts_col.setSpacing(10)
        self._daily_chart = BarChart("DAILY · LAST 7 DAYS", Colors.CARD_BLUE)
        self._weekly_chart = BarChart("WEEKLY · LAST 8 WEEKS", Colors.CARD_PURPLE)
        self._monthly_chart = BarChart("MONTHLY · LAST 12 MONTHS", Colors.ACCENT)
        charts_col.addWidget(self._daily_chart)
        charts_col.addWidget(self._weekly_chart)
        charts_col.addWidget(self._monthly_chart)
        charts_row.addLayout(charts_col, stretch=7)

        self._status_donut = DonutChart()
        charts_row.addWidget(self._status_donut, stretch=4)
        outer.addLayout(charts_row)

        return card

    def _on_filter_changed(self, time_filter: TimeFilter) -> None:
        """Time-filter bar callback — recompute only the KPI tiles.

        Bar charts and donut charts are time-independent so we don't
        pay for re-bucketing here. The screen reads ``self._analytics``
        which was populated by the last full refresh().
        """
        self._active_filter = time_filter
        if self._analytics is not None:
            self._render_kpis(self._analytics)

    def _render_analytics(self, project_id: int) -> None:
        """Pull a fresh snapshot from the controller and repaint."""
        self._analytics = self._dash_ctrl.get_analytics(
            project_id, self._active_filter
        )
        analytics = self._analytics

        # KPI tiles.
        self._render_kpis(analytics)

        # Daily bar chart.
        daily = analytics.daily
        self._daily_chart.set_data(
            [b.label for b in daily.buckets],
            [b.total for b in daily.buckets],
            [Colors.CARD_BLUE] * len(daily.buckets),
        )

        # Weekly bar chart.
        weekly = analytics.weekly
        self._weekly_chart.set_data(
            [b.label for b in weekly.buckets],
            [b.total for b in weekly.buckets],
            [Colors.CARD_PURPLE] * len(weekly.buckets),
        )

        # Monthly bar chart.
        monthly = analytics.monthly
        self._monthly_chart.set_data(
            [b.label for b in monthly.buckets],
            [b.total for b in monthly.buckets],
            [Colors.ACCENT] * len(monthly.buckets),
        )

        # Status donut with explicit colour mapping per spec.
        self._status_donut.set_slices(self._status_slices(analytics))

    def _render_kpis(self, analytics: DashboardAnalytics) -> None:
        for kpi in analytics.kpis:
            tile = self._kpi_tiles.get(kpi.key)
            if tile is None:
                continue
            tile.set_value(
                value=kpi.current_value,
                delta_pct=kpi.delta_percent,
                trend=kpi.trend,
                sparkline=kpi.sparkline,
            )

    @staticmethod
    def _status_slices(
        analytics: DashboardAnalytics,
    ) -> List[Tuple[str, int, str]]:
        # Map status → CSS colour so the donut reads in the same palette
        # as everything else in the dashboard. Order matches the
        # controller's StatusBreakdown.slice() output so percentages
        # are reproducible.
        status_color = {
            "pending": Colors.WARNING,
            "generated": Colors.CARD_BLUE,
            "approved": Colors.SUCCESS,
            "rejected": Colors.ERROR,
            "exported": Colors.CARD_TEAL,
        }
        return [
            (label, value, status_color.get(label, Colors.PRIMARY))
            for label, value in analytics.status_breakdown.slice()
        ]  # type: ignore[misc] — slice is List[tuple[str, int]]

    # ── Section builders ───────────────────────────────────────────────

    def _build_project_card(self) -> QFrame:
        """Hero card with 16 metadata fields on a responsive 4-col grid."""
        card = QFrame()
        card.setStyleSheet(
            f"""
            QFrame {{
                background: qlineargradient(
                    x1:0, y1:0, x2:1, y2:1,
                    stop:0 {Colors.PRIMARY_DARK},
                    stop:1 {Colors.SURFACE}
                );
                border: 1px solid {Colors.PRIMARY};
                border-radius: 16px;
            }}
            QLabel {{ color: {Colors.TEXT_PRIMARY}; background: transparent; border: none; }}
            """
        )

        outer = QVBoxLayout(card)
        outer.setContentsMargins(32, 28, 32, 28)
        outer.setSpacing(16)

        # Title row — name + status chip + open-workspace button.
        title_row = QHBoxLayout()
        title_row.setSpacing(14)

        self._project_name = QLabel("Select a project")
        self._project_name.setStyleSheet(
            f"font-size: 28px; font-weight: 800; color: {Colors.TEXT_PRIMARY};"
            " letter-spacing: -0.5px;"
        )
        title_row.addWidget(self._project_name)

        self._project_status_chip = QLabel("—")
        self._project_status_chip.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._project_status_chip.setMinimumWidth(80)
        self._project_status_chip.setStyleSheet(
            "color: white; padding: 6px 14px; border-radius: 14px;"
            " font-weight: 800; font-size: 11px; letter-spacing: 1px;"
        )
        title_row.addWidget(self._project_status_chip)
        title_row.addStretch()

        self._open_workspace_btn = QPushButton("Open Workspace  →")
        self._open_workspace_btn.setProperty("cssClass", "primary")
        self._open_workspace_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self._open_workspace_btn.clicked.connect(
            lambda: self.enter_workspace_tab.emit(-1)
        )
        title_row.addWidget(self._open_workspace_btn)
        outer.addLayout(title_row)

        # Subtitle row (description).
        self._project_subtitle = QLabel(
            "Open a project from the Dashboard or New Project screen."
        )
        self._project_subtitle.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 14px;"
        )
        outer.addWidget(self._project_subtitle)

        # Divider hairline.
        divider = QFrame()
        divider.setFrameShape(QFrame.Shape.HLine)
        divider.setFixedHeight(1)
        divider.setStyleSheet(
            f"background-color: {Colors.BORDER_LIGHT}; border: none;"
        )
        outer.addWidget(divider)

        # Responsive 4-col metadata grid (14 spec fields / 4 cols ≈ 4 rows).
        meta = QGridLayout()
        meta.setHorizontalSpacing(48)
        meta.setVerticalSpacing(18)

        # Sprint: Project Dashboard PRO #2 — strict spec: 14 in-grid fields
        # (Name + Status render above). Two of them (Completion %, Export
        # Readiness %) get an inline progress bar to keep the values
        # visually scannable. Books / Print Pages live in Statistics.
        fields: list[tuple[str, str, bool]] = [
            ("created_at", "CREATED", False),
            ("updated_at", "LAST MODIFIED", False),
            ("target_platform", "PLATFORM", False),
            ("book_size", "BOOK SIZE", False),
            ("dpi", "DPI", False),
            ("generated_assets", "GENERATED", False),
            ("approved_assets", "APPROVED", False),
            ("rejected_assets", "REJECTED", False),
            ("collections", "COLLECTIONS", False),
            ("categories", "CATEGORIES", False),
            ("prompt_templates", "PROMPT TEMPLATES", False),
            ("total_pages", "TOTAL PAGES", False),
            ("completion", "ESTIMATED COMPLETION", True),
            ("readiness", "EXPORT READINESS", True),
        ]  # 14 entries → 4 cols × 3.5 rows, fully responsive.

        self._meta_widgets = {}
        cols = 4
        for idx, (key, title, has_bar) in enumerate(fields):
            r, c = idx // cols, idx % cols
            block = QVBoxLayout()
            block.setSpacing(4)

            title_lbl = QLabel(title)
            title_lbl.setStyleSheet(
                f"color: {Colors.PRIMARY_LIGHT}; font-size: 10px;"
                " font-weight: 800; letter-spacing: 1.2px;"
                " background: transparent; border: none;"
            )
            block.addWidget(title_lbl)

            if has_bar:
                row_inner = QHBoxLayout()
                row_inner.setSpacing(8)
                val_lbl = QLabel("0%")
                val_lbl.setStyleSheet(
                    f"color: {Colors.TEXT_PRIMARY}; font-size: 18px;"
                    " font-weight: 700;"
                )
                bar = QProgressBar()
                bar.setRange(0, 100)
                bar.setValue(0)
                bar.setTextVisible(False)
                bar.setFixedHeight(6)
                bar.setFixedWidth(72)
                accent = Colors.ACCENT if key == "readiness" else Colors.PRIMARY
                bar.setStyleSheet(
                    f"QProgressBar {{ background: rgba(255,255,255,0.08);"
                    "  border: none; border-radius: 3px; }"
                    f"QProgressBar::chunk {{ background: {accent};"
                    "  border-radius: 3px; }"
                )
                row_inner.addWidget(val_lbl)
                row_inner.addWidget(bar)
                row_inner.addStretch(1)
                self._meta_widgets[f"{key}_val"] = val_lbl
                self._meta_widgets[f"{key}_bar"] = bar
                block.addLayout(row_inner)
            else:
                val_lbl = QLabel("—")
                val_lbl.setStyleSheet(
                    f"color: {Colors.TEXT_PRIMARY}; font-size: 18px;"
                    " font-weight: 700;"
                )
                self._meta_widgets[key] = val_lbl
                block.addWidget(val_lbl)

            meta.addLayout(block, r, c)

        outer.addLayout(meta)

        return card

    # ── Quick Actions PRO ──────────────────────────────────────────────

    def _build_actions_grid(self) -> QGridLayout:
        grid = QGridLayout()
        grid.setHorizontalSpacing(16)
        grid.setVerticalSpacing(16)

        # 8 cards: large emoji icon, bold title, short description,
        # colour-accented glow on hover. The first one is highlighted
        # as the project's primary action.
        actions = [
            ("Generate Images", "Spin up new AI assets",  "🎨", Colors.PRIMARY, 3),
            ("Library",         "Browse & curate assets", "📚", Colors.CARD_BLUE, 2),
            ("Prompt Studio",    "Tune reusable templates", "🧠", Colors.CARD_PURPLE, 1),
            ("Book Builder",    "Assemble layouts",         "📖", Colors.CARD_TEAL, 5),
            ("Review Queue",    "Approve / reject",         "✅", Colors.SUCCESS, 4),
            ("Export PDF",      "Print-ready PDF",          "📦", Colors.TEXT_PRIMARY, 6),
            ("Export KDP",      "Amazon KDP bundle",         "☁", Colors.SECONDARY, 6),
            ("Settings",         "Configure workspace",     "⚙", Colors.TEXT_MUTED, -1),
        ]
        cols = 4
        for idx, (label, desc, icon, accent, tab_index) in enumerate(actions):
            card = HoverCard(accent, radius=14)
            card.setMinimumHeight(124)
            card.setSizePolicy(
                QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
            )

            v = QVBoxLayout(card)
            v.setContentsMargins(18, 18, 18, 18)
            v.setSpacing(6)

            ic = QLabel(icon)
            ic.setAlignment(Qt.AlignmentFlag.AlignCenter)
            ic.setStyleSheet(
                f"font-size: 30px; background: transparent; border: none;"
            )
            ti = QLabel(label)
            ti.setAlignment(Qt.AlignmentFlag.AlignCenter)
            ti.setStyleSheet(
                f"color: {Colors.TEXT_PRIMARY}; font-size: 14px;"
                " font-weight: 800; background: transparent; border: none;"
            )
            ds = QLabel(desc)
            ds.setAlignment(Qt.AlignmentFlag.AlignCenter)
            ds.setStyleSheet(
                f"color: {Colors.TEXT_SECONDARY}; font-size: 11px;"
                " background: transparent; border: none;"
            )

            for w in (ic, ti, ds):
                w.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
                v.addWidget(w)

            # Make the whole card clickable, not just the children.
            card.setCursor(Qt.CursorShape.PointingHandCursor)
            card.mouseReleaseEvent = (  # type: ignore[method-assign]
                lambda _event, lbl=label, ti=tab_index: self._on_quick_action(lbl, ti)
            )

            grid.addWidget(card, idx // cols, idx % cols)
        self._actions_grid = grid
        return grid

    def _on_quick_action(self, label: str, tab_index: int) -> None:
        if label == "Settings":
            self.navigate_to_target.emit("settings")
            return
        self.enter_workspace_tab.emit(tab_index)

    # ── Project Health PRO ─────────────────────────────────────────────

    def _build_health_box(self) -> QVBoxLayout:
        box = QVBoxLayout()
        box.setSpacing(10)
        self._health_box = box
        return box

    def _populate_health(self, issues: List[HealthIssue]) -> None:
        self._clear_layout(self._health_box)
        if not issues:
            placeholder = QLabel("No project data to analyse yet.")
            placeholder.setStyleSheet(
                f"color: {Colors.TEXT_MUTED}; font-size: 12px;"
            )
            self._health_box.addWidget(placeholder)
            self._health_box.addStretch(1)
            return

        for issue in issues:
            self._health_box.addWidget(self._build_health_row(issue))
        self._health_box.addStretch(1)

    @staticmethod
    def _build_health_row(issue: HealthIssue) -> QFrame:
        accent = _SEVERITY_COLORS.get(issue.level, Colors.TEXT_MUTED)
        row = HoverCard(accent, radius=10)
        row.setStyleSheet(
            f"""
            QFrame#HoverCard {{
                background-color: {Colors.BACKGROUND};
                border: 1px solid {Colors.BORDER};
                border-left: 4px solid {accent};
                border-radius: 10px;
            }}
            QFrame#HoverCard:hover {{
                border: 1px solid {accent};
                border-left: 4px solid {accent};
                background-color: {Colors.SURFACE_LIGHT};
            }}
            """
        )

        layout = QHBoxLayout(row)
        layout.setContentsMargins(14, 12, 14, 12)
        layout.setSpacing(12)

        icon = QLabel(issue.icon)
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon.setStyleSheet(
            "font-size: 26px; background: transparent; border: none;"
        )
        icon.setFixedWidth(38)
        layout.addWidget(icon)

        body = QVBoxLayout()
        body.setSpacing(2)

        title_row = QHBoxLayout()
        title_row.setSpacing(8)
        title = QLabel(issue.label)
        title.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 13px; font-weight: 700;"
            " background: transparent; border: none;"
        )
        severity_chip = QLabel(issue.level.upper())
        severity_chip.setStyleSheet(
            f"color: white; background-color: {accent}; padding: 2px 8px;"
            " border-radius: 8px; font-size: 10px; font-weight: 800;"
        )
        title_row.addWidget(title)
        title_row.addWidget(severity_chip)
        title_row.addStretch()
        body.addLayout(title_row)

        detail = QLabel(issue.detail)
        detail.setWordWrap(True)
        detail.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
            " background: transparent; border: none;"
        )
        body.addWidget(detail)

        if issue.suggested_action:
            arrow = QLabel(f"➜  {issue.suggested_action}")
            arrow.setWordWrap(True)
            arrow.setStyleSheet(
                f"color: {accent}; font-size: 12px; font-weight: 600;"
                " background: transparent; border: none;"
            )
            body.addWidget(arrow)

        layout.addLayout(body, stretch=1)
        return row

    # ── Live Statistics PRO ────────────────────────────────────────────

    def _build_stats_grid(self) -> QGridLayout:
        grid = QGridLayout()
        grid.setHorizontalSpacing(12)
        grid.setVerticalSpacing(12)
        self._stats_grid = grid
        return grid

    def _populate_stats(self, m: DashboardMetrics) -> None:
        self._clear_grid(self._stats_grid)

        # The 10 statistics required by the spec — order chosen so the
        # two rows render Assets/Approved/Rejected/Collections/Categories
        # on row 1 and Prompts/Books/Print Pages/Exported/Completion %
        # on row 2 (5 cols × 2 rows). Each card is a richly coloured
        # tile with the metric font-sized for prominence.
        cards = [
            ("Assets",      str(m.total_assets),                 Colors.TEXT_PRIMARY),
            ("Approved",    str(m.approved_assets),              Colors.SUCCESS),
            ("Rejected",    str(m.rejected_assets),              Colors.ERROR),
            ("Collections", str(m.collections),                  Colors.CARD_PURPLE),
            ("Categories",  str(m.categories),                   Colors.CARD_PINK),
            ("Prompts",     str(m.prompts),                      Colors.CARD_AMBER),
            ("Books",       str(m.books),                        Colors.PRIMARY),
            ("Print Pages", str(m.estimated_print_pages),        Colors.TEXT_PRIMARY),
            ("Exported",    str(m.exported_assets),              Colors.CARD_TEAL),
            ("Completion %", f"{m.completion_percent:g}%",      Colors.CARD_BLUE),
        ]
        cols = 5
        for idx, (label, value, accent) in enumerate(cards):
            tile = self._build_stat_tile(label, value, accent)
            self._stats_grid.addWidget(tile, idx // cols, idx % cols)

    @staticmethod
    def _build_stat_tile(label: str, value: str, accent: str) -> QFrame:
        tile = QFrame()
        tile.setMinimumHeight(96)
        tile.setStyleSheet(
            f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
                border-top: 3px solid {accent};
            }}
            """
        )
        v = QVBoxLayout(tile)
        v.setContentsMargins(16, 12, 16, 12)
        v.setSpacing(2)
        # Type label (small, uppercase, muted).
        cap = QLabel(label.upper())
        cap.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 10px;"
            " font-weight: 700; letter-spacing: 1px;"
            " background: transparent; border: none;"
        )
        val = QLabel(value)
        val.setStyleSheet(
            f"color: {accent}; font-size: 28px; font-weight: 800;"
            " background: transparent; border: none;"
        )
        v.addWidget(cap)
        v.addWidget(val)
        v.addStretch(1)
        return tile

    # ── Recent Assets strip ────────────────────────────────────────────

    def _build_assets_strip(self) -> QWidget:
        """Horizontal thumbnail gallery (max 10) with status badge +
        creation date + Open button per tile."""
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFixedHeight(_ASSET_THUMB_SIZE + 78)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAsNeeded
        )
        scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )

        container = QWidget()
        container.setStyleSheet("background: transparent;")
        layout = QHBoxLayout(container)
        layout.setContentsMargins(0, 4, 0, 4)
        layout.setSpacing(14)
        layout.addStretch(1)
        self._assets_strip = layout

        scroll.setWidget(container)
        return scroll

    def _populate_recent_assets(self, assets: List[Asset]) -> None:
        self._clear_layout(self._assets_strip)
        if not assets:
            placeholder = QLabel("No assets to display yet.")
            placeholder.setStyleSheet(
                f"color: {Colors.TEXT_MUTED}; font-size: 13px;"
            )
            self._assets_strip.insertWidget(0, placeholder)
            self._assets_strip.addStretch(1)
            return

        for asset in assets[:10]:
            self._assets_strip.insertWidget(
                self._assets_strip.count() - 1,
                self._build_asset_card(asset),
            )

    def _build_asset_card(self, asset: Asset) -> QFrame:
        """Asset tile = thumbnail + name + status badge + date + Open.

        Per spec this is the entire Recent-Assets cell: every element
        is rendered so users can identify and act on the asset without
        a context menu.
        """
        # Use a colored border per status so the tile reads at-a-glance
        # even before the badge is read.
        status_border_map = {
            AssetStatus.PENDING: Colors.WARNING,
            AssetStatus.GENERATED: Colors.INFO,
            AssetStatus.APPROVED: Colors.SUCCESS,
            AssetStatus.REJECTED: Colors.ERROR,
            AssetStatus.EXPORTED: Colors.CARD_TEAL,
        }
        border_color = status_border_map.get(asset.status, Colors.BORDER)

        card = QFrame()
        card.setFixedSize(_ASSET_THUMB_SIZE + 24, _ASSET_THUMB_SIZE + 72)
        card.setStyleSheet(
            f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-top: 3px solid {border_color};
                border-radius: 12px;
            }}
            """
        )

        v = QVBoxLayout(card)
        v.setContentsMargins(10, 10, 10, 8)
        v.setSpacing(4)

        # 1. Thumbnail.
        thumb = QLabel()
        thumb.setFixedSize(_ASSET_THUMB_SIZE, _ASSET_THUMB_SIZE)
        thumb.setAlignment(Qt.AlignmentFlag.AlignCenter)
        thumb.setStyleSheet(
            f"""
            QLabel {{
                background-color: {_ASSET_THUMB_BG};
                border-radius: 8px;
                color: {Colors.TEXT_MUTED};
                font-size: 12px;
                border: none;
            }}
            """
        )
        pix = self._load_thumb(asset)
        if pix is not None and not pix.isNull():
            thumb.setPixmap(
                pix.scaled(
                    _ASSET_THUMB_SIZE,
                    _ASSET_THUMB_SIZE,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
            )
        else:
            fallback = {
                AssetStatus.APPROVED: "✓",
                AssetStatus.REJECTED: "✕",
                AssetStatus.EXPORTED: "↗",
            }.get(asset.status, "—")
            thumb.setText(fallback)
        v.addWidget(thumb)

        # 2. Asset name (elided).
        name = QLabel(asset.name)
        name.setAlignment(Qt.AlignmentFlag.AlignCenter)
        fm = name.fontMetrics()
        name.setText(
            fm.elidedText(asset.name, Qt.TextElideMode.ElideRight, _ASSET_THUMB_SIZE + 20)
        )
        name.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 11px; font-weight: 600;"
            " background: transparent; border: none;"
        )
        v.addWidget(name)

        # 3. Status badge + creation date in one row.
        meta_row = QHBoxLayout()
        meta_row.setSpacing(6)

        badge = QLabel(asset.status.value.upper())
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        badge.setStyleSheet(
            f"color: white; background-color: {border_color}; padding: 2px 7px;"
            " border-radius: 7px; font-size: 9px; font-weight: 800;"
        )
        meta_row.addWidget(badge)

        date_lbl = QLabel(asset.created_at.strftime("%b %d"))
        date_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        date_lbl.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 10px;"
            " background: transparent; border: none;"
        )
        meta_row.addWidget(date_lbl)
        meta_row.addStretch(1)
        v.addLayout(meta_row)

        # 4. "Open" button — opens the existing AssetInspectorDialog.
        btn_row = QHBoxLayout()
        btn_row.setContentsMargins(0, 0, 0, 0)
        open_btn = QPushButton("Open")
        open_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        open_btn.setStyleSheet(
            f"""
            QPushButton {{
                background-color: {Colors.SURFACE_LIGHT};
                color: {Colors.TEXT_PRIMARY};
                border: 1px solid {Colors.BORDER};
                border-radius: 6px;
                padding: 4px 10px;
                font-size: 11px;
                font-weight: 600;
            }}
            QPushButton:hover {{
                background-color: {Colors.PRIMARY};
                border: 1px solid {Colors.PRIMARY};
                color: {Colors.TEXT_ON_PRIMARY};
            }}
            """
        )
        open_btn.clicked.connect(lambda: self._open_asset(asset))
        btn_row.addStretch(1)
        btn_row.addWidget(open_btn)
        btn_row.addStretch(1)
        v.addLayout(btn_row)
        return card

    @staticmethod
    def _load_thumb(asset: Asset) -> Optional[QPixmap]:
        candidate = asset.thumbnail_path or asset.file_path
        if not candidate:
            return None
        path = Path(candidate)
        if not path.exists():
            return None
        return QPixmap(str(path))

    def _open_asset(self, asset: Asset) -> None:
        """Open the existing AssetInspectorDialog for an asset."""
        try:
            dlg = AssetInspectorDialog(asset, self.controller, self)
            dlg.open()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Failed to open asset inspector: %s", exc)

    # ── Recent Activity PRO ────────────────────────────────────────────

    def _build_activity_box(self) -> QVBoxLayout:
        box = QVBoxLayout()
        box.setSpacing(0)
        self._activity_box = box
        return box

    def _populate_activity(self, items: List[ActivityItem]) -> None:
        self._clear_layout(self._activity_box)
        if not items:
            placeholder = QLabel("No recent activity.")
            placeholder.setStyleSheet(
                f"color: {Colors.TEXT_MUTED}; font-size: 12px;"
            )
            self._activity_box.addWidget(placeholder)
            return

        # Spec: 6 specific activity icons. Show the most recent items
        # first (already sorted in the controller). Limit to the top
        # 12 so the panel doesn't grow unbounded on big projects.
        top = items[:12]
        for idx, item in enumerate(top):
            self._activity_box.addWidget(self._build_activity_row(item))
            if idx < len(top) - 1:
                self._activity_box.addWidget(self._build_activity_divider())

        self._activity_box.addStretch(1)

    def _build_activity_row(self, item: ActivityItem) -> QFrame:
        row = QFrame()
        row.setStyleSheet("background: transparent; border: none;")
        outer = QHBoxLayout(row)
        outer.setContentsMargins(4, 8, 4, 8)
        outer.setSpacing(14)

        # Timeline dot in the same colour family as the activity icon.
        accent = item.accent or Colors.PRIMARY
        dot = QFrame()
        dot.setFixedSize(14, 14)
        dot.setStyleSheet(
            f"background-color: {accent}; border-radius: 7px; border: none;"
        )
        outer.addWidget(dot, 0, Qt.AlignmentFlag.AlignTop)

        # Override icon with the spec-required glyph for the 6 kinds.
        icon_glyph = _KIND_ICONS.get(item.kind, item.kind)
        icon_lbl = QLabel(icon_glyph)
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_lbl.setStyleSheet(
            "font-size: 18px; background: transparent; border: none;"
        )
        icon_lbl.setFixedWidth(28)
        outer.addWidget(icon_lbl, 0, Qt.AlignmentFlag.AlignTop)

        # Two-line body: label + detail.
        body = QVBoxLayout()
        body.setSpacing(1)
        line1 = QLabel(item.label)
        line1.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 13px; font-weight: 700;"
            " background: transparent; border: none;"
        )
        line2 = QLabel(item.detail)
        line2.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px;"
            " background: transparent; border: none;"
        )
        body.addWidget(line1)
        body.addWidget(line2)
        outer.addLayout(body, stretch=1)

        ts = QLabel(_format_relative(item.timestamp))
        ts.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 11px;"
            " background: transparent; border: none;"
        )
        ts.setAlignment(Qt.AlignmentFlag.AlignTop)
        outer.addWidget(ts, 0, Qt.AlignmentFlag.AlignTop)

        return row

    @staticmethod
    def _build_activity_divider() -> QFrame:
        line = QFrame()
        line.setFrameShape(QFrame.Shape.HLine)
        line.setFixedHeight(1)
        line.setStyleSheet(
            f"background-color: {Colors.BORDER}; border: none;"
        )
        return line

    # ── Generic card-section frame ─────────────────────────────────────

    @staticmethod
    def _build_card_section(title: str, content) -> QFrame:
        frame = QFrame()
        frame.setStyleSheet(
            f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 16px;
            }}
            """
        )
        outer = QVBoxLayout(frame)
        outer.setContentsMargins(24, 20, 24, 24)
        outer.setSpacing(16)

        header_row = QHBoxLayout()
        header_row.setSpacing(8)
        header_dot = QFrame()
        header_dot.setFixedSize(8, 8)
        header_dot.setStyleSheet(
            f"background-color: {Colors.PRIMARY}; border-radius: 4px; border: none;"
        )
        header_row.addWidget(header_dot)
        header = QLabel(title)
        header.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 16px; font-weight: 800;"
            " background: transparent; border: none;"
        )
        header_row.addWidget(header)
        header_row.addStretch(1)
        outer.addLayout(header_row)

        if isinstance(content, QLayout):
            outer.addLayout(content)
        elif isinstance(content, QWidget):
            outer.addWidget(content)
        return frame

    # ── Refresh hooks ─────────────────────────────────────────────────

    def refresh(self) -> None:
        project_id = self.controller.workspace.project_id
        if project_id is None:
            self._render_empty()
            return

        self._data = self._dash_ctrl.get_dashboard(project_id)
        if self._data.project is None:
            self._render_empty()
            return
        self._render_data(self._data)
        # Sprint: Dashboard PRO #3 — repaint analytics whenever the
        # dashboard itself refreshes (project switch, workbox reload,
        # review actions from other tabs, etc.).
        if self._filter_bar is not None:
            self._render_analytics(int(project_id))

    def on_show(self) -> None:
        self.refresh()

    # ── Renderers ─────────────────────────────────────────────────────

    def _render_empty(self) -> None:
        self._project_name.setText("No project selected")
        self._project_subtitle.setText(
            "Open a project from the Dashboard, the New Project screen, "
            "or the recent-projects list."
        )
        self._project_status_chip.setText("—")
        status_bg = _STATUS_COLORS.get(ProjectStatus.DRAFT, Colors.PRIMARY)
        self._project_status_chip.setStyleSheet(
            f"color: white; background-color: {status_bg}; padding: 6px 14px;"
            " border-radius: 14px; font-weight: 800; font-size: 11px;"
            " letter-spacing: 1px;"
        )
        for key, widget in self._meta_widgets.items():
            if isinstance(widget, QProgressBar):
                widget.setValue(0)
            elif isinstance(widget, QLabel):
                widget.setText("—")
        self._open_workspace_btn.setEnabled(False)

        self._populate_health([
            HealthIssue(
                level="info",
                icon="ℹ️",
                label="No active project",
                detail="Open or create a project to populate the dashboard.",
                suggested_action="Open a project or create one in New Project.",
            )
        ])
        self._populate_stats(DashboardMetrics())
        self._populate_recent_assets([])
        self._populate_activity([])

    def _render_data(self, data: ProjectDashboardData) -> None:
        p: Project = data.project
        m = data.metrics
        info = data.book_info

        self._project_name.setText(p.name)
        self._project_subtitle.setText(
            p.description
            or f"Created {p.created_at.strftime('%b %d, %Y')}"
        )
        status_bg = _STATUS_COLORS.get(p.status, Colors.PRIMARY)
        self._project_status_chip.setText(p.status.value.upper())
        self._project_status_chip.setStyleSheet(
            f"color: white; background-color: {status_bg}; padding: 6px 14px;"
            " border-radius: 14px; font-weight: 800; font-size: 11px;"
            " letter-spacing: 1px;"
        )

        # Static metadata.
        self._meta_widgets["created_at"].setText(
            p.created_at.strftime("%b %d, %Y")
        )
        self._meta_widgets["updated_at"].setText(
            p.updated_at.strftime("%b %d, %Y")
        )
        self._meta_widgets["target_platform"].setText(info.target_platform)
        self._meta_widgets["book_size"].setText(info.book_size)
        self._meta_widgets["dpi"].setText(f"{info.dpi} DPI")
        self._meta_widgets["total_pages"].setText(str(m.total_assets))
        self._meta_widgets["generated_assets"].setText(str(m.generated_assets))
        self._meta_widgets["approved_assets"].setText(str(m.approved_assets))
        self._meta_widgets["rejected_assets"].setText(str(m.rejected_assets))
        self._meta_widgets["collections"].setText(str(m.collections))
        self._meta_widgets["categories"].setText(str(m.categories))
        self._meta_widgets["prompt_templates"].setText(str(m.prompts))

        # Animated metrics (Completion % + Export Readiness %).
        self._meta_widgets["completion_val"].setText(f"{m.completion_percent:g}%")
        self._meta_widgets["completion_bar"].setValue(int(m.completion_percent))
        self._meta_widgets["readiness_val"].setText(
            f"{m.estimated_export_readiness:g}%"
        )
        self._meta_widgets["readiness_bar"].setValue(
            int(m.estimated_export_readiness)
        )

        self._open_workspace_btn.setEnabled(True)

        self._populate_health(data.health)
        self._populate_stats(m)
        self._populate_recent_assets(data.recent_assets)
        self._populate_activity(data.activity)

    # ── Layout clearing helpers ───────────────────────────────────────

    @staticmethod
    def _clear_grid(grid: Optional[QGridLayout]) -> None:
        if grid is None:
            return
        while grid.count():
            item = grid.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.setParent(None)
                widget.deleteLater()
            child_layout = item.layout()
            if child_layout is not None:
                ProjectDashboardScreen._clear_inner_layout(child_layout)

    @staticmethod
    def _clear_layout(layout: Optional[QLayout]) -> None:
        if layout is None:
            return
        while layout.count():
            item = layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.setParent(None)
                widget.deleteLater()
            child_layout = item.layout()
            if child_layout is not None:
                ProjectDashboardScreen._clear_inner_layout(child_layout)

    @staticmethod
    def _clear_inner_layout(layout, _seen: Optional[set] = None) -> None:
        if layout is None:
            return
        if _seen is None:
            _seen = set()
        if id(layout) in _seen:
            return
        _seen.add(id(layout))
        while layout.count():
            item = layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.setParent(None)
                widget.deleteLater()
            inner = item.layout()
            if inner is not None:
                ProjectDashboardScreen._clear_inner_layout(inner, _seen)


# ── Helpers ─────────────────────────────────────────────────────────────


def _format_relative(ts: datetime) -> str:
    """Render a short, human-friendly timestamp for the timeline."""
    try:
        delta = datetime.now() - ts
    except TypeError:
        return ts.strftime("%b %d")
    seconds = int(delta.total_seconds())
    if seconds < 60:
        return "just now"
    if seconds < 3600:
        return f"{seconds // 60}m ago"
    if seconds < 86_400:
        return f"{seconds // 3600}h ago"
    days = seconds // 86_400
    if days < 7:
        return f"{days}d ago"
    return ts.strftime("%b %d")
