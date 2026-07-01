"""Project workspace context controller."""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Callable, List, Optional

from PySide6.QtCore import QObject, QTimer, Signal
from PySide6.QtWidgets import QApplication, QDialog

import services.recovery_manager as _recovery
from models.asset import AssetStatus
from models.category import Category
from models.project import Project
from utils.logger import get_logger

if TYPE_CHECKING:
    from app.controllers.app_controller import AppController


logger = get_logger(__name__)


@dataclass
class WorkspaceStats:
    total_assets: int = 0
    approved_assets: int = 0
    pending_assets: int = 0
    total_categories: int = 0
    total_prompts: int = 0


_AUTO_SAVE_INTERVAL_MS = 60_000


class WorkspaceController(QObject):
    """Manages active project and category context for the workspace."""

    project_changed = Signal(int)
    category_changed = Signal(object)
    workspace_refresh = Signal()
    navigate_to_workspace = Signal()
    # Sprint: Book Project Dashboard PRO #1 emitted after a project is
    # selected from any screen. The main window routes it to the
    # per-project Dashboard, which is the new first screen.
    navigate_to_project_dashboard = Signal(int)
    project_dirty_changed = Signal(bool)

    def __init__(self, app: AppController) -> None:
        super().__init__()
        self._app = app
        self._project_id: Optional[int] = None
        self._category_id: Optional[int] = None

        # ── Sprint: Auto Save / Crash Recovery state ────────────────────────
        self._dirty: bool = False
        self._active_tab_index: int = 0
        self._recovery_offered_for: set[int] = set()
        self._recovery_sections: dict[str, Callable[[], dict]] = {}
        self._recovery_apply_handlers: dict[str, Callable[[dict], None]] = {}

        self._auto_save_timer = QTimer(self)
        self._auto_save_timer.setInterval(_AUTO_SAVE_INTERVAL_MS)
        self._auto_save_timer.timeout.connect(self._auto_save_tick)
        self._auto_save_timer.start()

        self._restore_last_project()

    @property
    def project_id(self) -> Optional[int]:
        return self._project_id

    @property
    def category_id(self) -> Optional[int]:
        return self._category_id

    @property
    def current_project(self) -> Optional[Project]:
        if self._project_id is None:
            return None
        return self._app.projects.get_by_id(self._project_id)

    @property
    def current_category(self) -> Optional[Category]:
        if self._category_id is None:
            return None
        return self._app.categories.get_by_id(self._category_id)

    @property
    def has_project(self) -> bool:
        return self._project_id is not None

    def open_project(self, project_id: int) -> Optional[Project]:
        # Save any pending snapshot from the previous project before switching.
        self.force_save_recovery()

        project = self._app.projects.get_by_id(project_id)
        if not project:
            return None

        self._project_id = project_id
        self._category_id = None
        self._app.settings.set("workspace.last_project_id", project_id, persist=True)
        self.project_changed.emit(project_id)
        self.workspace_refresh.emit()

        # Sprint: offer recovery for the project just opened (lazy, non-blocking).
        parent = QApplication.activeWindow()
        if parent is not None:
            QTimer.singleShot(0, lambda p=parent: self.maybe_offer_recovery(p))
        return project

    def request_open_workspace(self, project_id: int) -> Optional[Project]:
        """Open a project and signal the UI to navigate to the workspace.

        Sprint: Book Project Dashboard PRO #1 — the first screen
        shown after selecting a project is the per-project Dashboard,
        not the tabbed workspace. The Dashboard's quick actions then
        route the user into a specific workspace tab via
        ``enter_workspace_tab``.
        """
        project = self.open_project(project_id)
        if project:
            self.navigate_to_project_dashboard.emit(int(project_id))
        return project

    def enter_workspace(self, project_id: int | None = None) -> Optional[Project]:
        """Drop into the tabbed project workspace from the Dashboard."""
        if project_id is not None:
            project = self._app.projects.get_by_id(int(project_id))
            if project and project.id != self._project_id:
                # Re-open if the caller passed a different id.
                self.open_project(int(project_id))
        self.navigate_to_workspace.emit()
        return self.current_project

    def clear_project(self) -> None:
        # Sprint: flush any pending snapshot before dropping the project.
        self.force_save_recovery()
        self._project_id = None
        self._category_id = None
        self._app.settings.set("workspace.last_project_id", None, persist=True)
        self.project_changed.emit(-1)
        self.workspace_refresh.emit()

    def select_category(self, category_id: Optional[int]) -> None:
        if category_id is not None and self._project_id is not None:
            category = self._app.categories.get_by_id(category_id)
            if not category or category.project_id != self._project_id:
                return
        self._category_id = category_id
        self.category_changed.emit(category_id)
        self.workspace_refresh.emit()

    def get_categories(self) -> List[Category]:
        if self._project_id is None:
            return []
        return self._app.categories.get_all(self._project_id)

    def get_stats(self) -> WorkspaceStats:
        if self._project_id is None:
            return WorkspaceStats()

        project_id = self._project_id
        category_id = self._category_id

        if category_id is not None:
            assets = self._app.assets.get_all(
                project_id=project_id,
                category_id=category_id,
            )
            prompts = self._app.prompts.get_all(category_id=category_id)
            categories = [c for c in self.get_categories() if c.id == category_id]
        else:
            assets = self._app.assets.get_all(project_id=project_id)
            prompts = self._app.prompts.get_by_project(project_id)
            categories = self.get_categories()

        approved = sum(1 for a in assets if a.status == AssetStatus.APPROVED)
        pending = sum(
            1 for a in assets
            if a.status in (AssetStatus.PENDING, AssetStatus.GENERATED)
        )

        return WorkspaceStats(
            total_assets=len(assets),
            approved_assets=approved,
            pending_assets=pending,
            total_categories=len(categories),
            total_prompts=len(prompts),
        )

    def _restore_last_project(self) -> None:
        last_id = self._app.settings.get("workspace.last_project_id")
        if last_id is not None:
            project = self._app.projects.get_by_id(int(last_id))
            if project:
                self._project_id = project.id

    # ── Sprint: Auto Save & Crash Recovery ─────────────────────────────────────

    def mark_dirty(self) -> None:
        """Mark the active project as having unsaved in-progress edits."""
        if self._project_id is None:
            return
        if not self._dirty:
            self._dirty = True
            self.project_dirty_changed.emit(True)

    def clear_dirty(self) -> None:
        if self._dirty:
            self._dirty = False
            self.project_dirty_changed.emit(False)

    def is_dirty(self) -> bool:
        return self._dirty

    def set_active_tab_index(self, index: int) -> None:
        self._active_tab_index = int(index)
        
    def register_recovery_section(
        self, section: str, getter: Callable[[], dict]
    ) -> None:
        """Register a callback that returns the section's current draft state."""
        self._recovery_sections[section] = getter

    def register_recovery_apply(
        self, section: str, handler: Callable[[dict], None]
    ) -> None:
        """Register a callback that consumes a recovered section payload."""
        # Always overwrite so tab rebuilds (e.g. after refresh) take effect.
        self._recovery_apply_handlers[section] = handler

    def _auto_save_tick(self) -> None:
        if not self._dirty or self._project_id is None:
            return
        try:
            snapshot = self._build_snapshot()
            _recovery.save(self._project_id, snapshot)
            logger.debug(
                "Auto-saved recovery snapshot for project %s", self._project_id
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("Recovery snapshot write failed: %s", exc)

    def force_save_recovery(self) -> None:
        """Write a snapshot now if dirty (called on project switch / close)."""
        if not self._dirty or self._project_id is None:
            return
        try:
            _recovery.save(self._project_id, self._build_snapshot())
        except Exception as exc:  # noqa: BLE001
            logger.warning("Force-save recovery failed: %s", exc)

    def _build_snapshot(self) -> dict:
        snap: dict = {"project_id": self._project_id}
        for section, getter in self._recovery_sections.items():
            try:
                snap[section] = getter() or {}
            except Exception as exc:  # noqa: BLE001
                logger.warning("Recovery getter for %s failed: %s", section, exc)
                snap[section] = {}
        snap["selections"] = {
            "category_id": self._category_id,
            "active_tab_index": self._active_tab_index,
        }
        return snap

    def maybe_offer_recovery(self, parent_widget=None) -> bool:
        """If a recovery snapshot is newer than the project's last save, ask
        the user whether to recover or discard it. Returns True if a dialog
        was shown.
        """
        if self._project_id is None:
            return False
        if self._project_id in self._recovery_offered_for:
            return False
        if not _recovery.has_recovery(self._project_id):
            return False

        try:
            snapshot = _recovery.load(self._project_id)
        except Exception:
            snapshot = None
        if not isinstance(snapshot, dict):
            return False

        rec_mtime = _recovery.snapshot_mtime(self._project_id)
        if rec_mtime is None:
            return False

        project = self._app.projects.get_by_id(self._project_id)
        if project is None:
            _recovery.discard(self._project_id)
            return False

        if rec_mtime <= project.updated_at:
            # Stale snapshot — discard silently.
            _recovery.discard(self._project_id)
            return False

        self._recovery_offered_for.add(self._project_id)

        from ui.widgets.recovery_dialog import RecoveryDialog

        dlg = RecoveryDialog(
            project_name=project.name,
            recovery_at=rec_mtime,
            project_saved_at=project.updated_at,
            parent=parent_widget,
        )
        user_chose_recover = False
        if dlg.exec() == QDialog.DialogCode.Accepted:
            user_chose_recover = bool(dlg.recover)

        if user_chose_recover:
            self._apply_recovery(snapshot)
            # Mark dirty so the next 60s tick writes a refreshed snapshot.
            self._dirty = True
            self.project_dirty_changed.emit(True)

        # Always remove the file after a decision has been made.
        _recovery.discard(self._project_id)
        return True

    def _apply_recovery(self, snapshot: dict) -> None:
        for section, handler in list(self._recovery_apply_handlers.items()):
            data = snapshot.get(section)
            if not data:
                continue
            try:
                handler(data)
            except Exception as exc:  # noqa: BLE001
                logger.warning("Apply recovery for %s failed: %s", section, exc)

        selections = snapshot.get("selections") or {}
        cat_id = selections.get("category_id")
        if cat_id is not None:
            try:
                self.select_category(int(cat_id))
            except Exception:
                pass

        # project_changed/workspace_refresh are already emitted above; the
        # ProjectWorkspaceScreen hooks this signal and calls every tab's
        # refresh() so recovered state settles into the widgets.
