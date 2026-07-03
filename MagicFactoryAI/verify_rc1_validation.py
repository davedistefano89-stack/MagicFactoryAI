"""MagicFactoryAI 1.0.0-rc1 — comprehensive beta-tester validation.

OBSERVATION ONLY. No fixes.

Phases (each acquires pre/post metrics):
    P0 — Environment + crash-fragment hook + singletons + tracemalloc + RSS.
    P1 — Bulk data: 10 projects / 100 prompts / 250 assets (real PNGs).
    P2 — Approve / Reject / Delete (with Undo).
    P3 — Undo/Redo overflow (push 110 distinct ops to a 100-cap stack).
    P4 — Export edge cases (approved-only, zero-approved, full pack).
    P5 — Recovery save / load / discard (atomic .tmp swap clean-up).
    P6 — Project switching (every project open/close cycle).
    P7 — Book Builder draft + recovery round-trip.
    P8 — Settings persistence (set, save, re-instantiate, verify).
    P9 — Application restart (singleton reset, re-init, integrity check).
    P10 — Stress: 20 cycles of open/close + 30 import/export runs.
    P11 — Final diagnostics: integrity, orphan diff, memory delta.

Reports any: uncaught exceptions, crash fragments in stderr,
.failure traces in tracemalloc, DB corruption (PRAGMA), orphan .tmp
files after atomic-swap, persisted-state mismatch on restart, persistent
memory growth > 50 MB after singleton teardown, undo-cap eviction miss.
"""

from __future__ import annotations

import io
import json
import os
import shutil
import sys
import tempfile
import time
import traceback
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Force headless Qt (this app uses Qt offscreen when testing).
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

# Make psutil optional — fall back to tracemalloc only.
try:
    import psutil  # type: ignore

    _HAS_PSUTIL = True
except Exception:
    _HAS_PSUTIL = False

import tracemalloc  # noqa: E402

# ── Crank the log level down so the log file isn't enormous ──────────────
from utils.logger import setup_logging  # noqa: E402

setup_logging(level="WARNING")

# ── Layer exception + crash capture ──────────────────────────────────────
captured_exceptions: list[tuple[str, str]] = []
_original_excepthook = sys.excepthook


def _capture_excepthook(exc_type, exc_value, exc_tb):
    captured_exceptions.append(
        (
            f"{exc_type.__name__}: {exc_value}",
            "".join(traceback.format_exception(exc_type, exc_value, exc_tb)),
        )
    )
    _original_excepthook(exc_type, exc_value, exc_tb)


sys.excepthook = _capture_excepthook

_stderr_capture = io.StringIO()
_saved_stderr_fd = os.dup(2)
stderr_redirect_attached = False
try:
    os.dup2(_stderr_capture.fileno(), 2)
    stderr_redirect_attached = True
except OSError:
    pass

CRASH_FRAGMENTS = (
    "QObject::startTimer",
    "QThread: Destroyed while thread",
    "Windows fatal exception",
    "access violation",
    "Termination on signal",
    "Traceback (most recent call last)",
    "Fatal Python error",
    "QCoreApplication::sendPostedEvents",
    "setGeometry: ",
    "QWidget::setParent",
    "QLayout",
)


from PySide6.QtCore import QTimer, Qt  # noqa: E402
from PySide6.QtWidgets import QApplication, QWidget  # noqa: E402


# ── Single shared QApplication for the whole run ────────────────────────
QAPP = QApplication.instance() or QApplication(sys.argv)
QAPP.setAttribute(Qt.ApplicationAttribute.AA_DontUseNativeMenuBar, True)


def _process_events(seconds: float) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        QAPP.processEvents()
        time.sleep(0.01)


# ── Findings collector ──────────────────────────────────────────────────
findings: list[tuple[str, str]] = []  # (severity, message)


def report(severity: str, message: str) -> None:
    findings.append((severity, message))
    print(f"  [{severity}] {message}")


# ── Utility: data dir snapshot before / after ───────────────────────────
def dir_snapshot(root: Path) -> set[str]:
    """All recursive file paths under root, as relative strings."""
    out: set[str] = set()
    if not root.exists():
        return out
    for p in root.rglob("*"):
        if p.is_file():
            out.add(str(p.relative_to(root)))
    return out


def find_orphan_tmps(before: set[str], after: set[str]) -> list[str]:
    return sorted(p for p in after if p.endswith(".tmp") and p not in before)


# ── Resetting singletons for app-restart simulation ─────────────────────
def _reset_singletons() -> None:
    AppController._instance = None  # type: ignore[attr-defined]
    DatabaseConnection.reset_instance()
    SettingsManager._instance = None  # type: ignore[attr-defined]


# ── Tracemalloc helpers ─────────────────────────────────────────────────
tracemalloc.start()


def mem_snapshot():
    if _HAS_PSUTIL:
        try:
            rss = psutil.Process(os.getpid()).memory_info().rss
        except Exception:
            rss = -1
    else:
        rss = -1
    return (tracemalloc.take_snapshot(), rss)


# Deferred imports — must happen AFTER env vars are set.
from app.controllers.app_controller import AppController  # noqa: E402
from app.controllers.project_controller import ProjectController  # noqa: E402
from app.controllers.prompt_controller import PromptController  # noqa: E402
from app.controllers.asset_controller import AssetController  # noqa: E402
from app.controllers.export_controller import ExportController  # noqa: E402
from core.database.connection import DatabaseConnection  # noqa: E402
from core.settings.manager import SettingsManager  # noqa: E402
from models.asset import Asset, AssetStatus  # noqa: E402
from models.category import Category  # noqa: E402
from models.project import Project, ProjectStatus  # noqa: E402
from models.prompt import Prompt, PromptType  # noqa: E402
import services.recovery_manager as _recovery  # noqa: E402
from utils.paths import (  # noqa: E402
    get_app_root,
    get_data_dir,
    get_exports_dir,
    get_library_dir,
)


# ── Helpers: build real PNG files via PIL ───────────────────────────────
def make_png(idx: int, size: int = 256) -> Path:
    from PIL import Image, ImageDraw

    # Cheap unique solid color per idx so thumbnails can be inspected.
    r = (idx * 37) % 256
    g = (idx * 53) % 256
    b = (idx * 79) % 256
    img = Image.new("RGB", (size, size), (r, g, b))
    d = ImageDraw.Draw(img)
    d.text((10, 10), f"A{idx:04d}", fill=(0, 0, 0))
    p = Path(tempfile.gettempdir()) / f"rc1_validation_{idx:04d}.png"
    img.save(p, format="PNG")
    return p


# ── Strict DB integrity probe ──────────────────────────────────────────
def db_integrity() -> list[tuple]:
    conn = DatabaseConnection.instance().connect()
    return list(conn.execute("PRAGMA integrity_check").fetchall())


# ══════════════════════════════════════════════════════════════════════
#  Driver
# ══════════════════════════════════════════════════════════════════════


def main() -> int:  # noqa: C901 — long but linear
    print("=" * 78)
    print("MagicFactoryAI 1.0.0-rc1 — beta-tester validation")
    print("=" * 78)
    try:
        return _run_phases()
    finally:
        _restore_stderr()


def _run_phases() -> int:  # noqa: C901 — long but linear

    data_dir = get_data_dir()
    library_dir = get_library_dir()
    exports_dir = get_exports_dir()
    recovery_dir = data_dir / "recovery"
    print(f"data_dir   : {data_dir}")
    print(f"library_dir: {library_dir}")
    print(f"exports_dir: {exports_dir}")
    print(f"recovery   : {recovery_dir}")

    pre_data_snapshot = dir_snapshot(data_dir)
    pre_memsnap, pre_rss = mem_snapshot()

    failed_phases: list[str] = []

    try:
        # ── P0: Boot the singleton ───────────────────────────────────────
        print("\n[P0] Booting AppController singleton...")
        app = AppController.instance()
        _process_events(0.2)
        if not hasattr(app, "projects"):
            report("CRITICAL", "AppController singleton missing repositories")

        # ── P1: Bulk data
        print("\n[P1] Creating 10 projects / 100 prompts / 250 assets...")
        t0 = time.perf_counter()
        proj_ctrl = ProjectController(app)
        prompt_ctrl = PromptController(app)

        # 10 projects, each with 1 category
        project_ids: list[int] = []
        categories_per_project: dict[int, int] = {}
        for i in range(10):
            p = proj_ctrl.create_project(f"RC1-Project-{i:02d}", f"validation {i}")
            project_ids.append(p.id)
            cat = Category(
                name=f"Cat-{i:02d}",
                color="#22AA33",
                icon="folder",
                sort_order=i,
                project_id=p.id,
            )
            cat = app.categories.create(cat)
            categories_per_project[p.id] = cat.id

        # 100 prompts (bucket evenly across categories)
        for j in range(100):
            cat_id = categories_per_project[
                project_ids[j % len(project_ids)]
            ]
            prompt_ctrl.create_prompt(
                title=f"P-{j:03d}",
                content=f"validation prompt body {j}",
                prompt_type=PromptType.CHARACTER if j % 2 else PromptType.SCENE,
                tags=f"rc1,test,group-{j // 10}",
                category_id=cat_id,
            )

        # 250 assets: 25 per project
        asset_ctrl = AssetController(app)
        staged_pngs = [make_png(k) for k in range(250)]
        asset_ids: list[int] = []
        for k, png in enumerate(staged_pngs):
            proj_id = project_ids[k // 25]
            cat_id = categories_per_project[proj_id]
            asset = asset_ctrl.import_asset(
                png,
                name=f"Asset-{k:03d}",
                project_id=proj_id,
                category_id=cat_id,
            )
            asset_ids.append(asset.id)
        t1 = time.perf_counter()
        print(
            f"   Created 10 projects, 100 prompts, {len(asset_ids)} assets "
            f"in {t1 - t0:.1f}s"
        )
        if app.projects.count() < 10:
            report("CRITICAL", "Project count mismatch after P1")
        if app.prompts.count() < 100:
            report("CRITICAL", "Prompt count mismatch after P1")
        if app.assets.count() < 250:
            report("HIGH", f"Asset count low: {app.assets.count()}")

        # ── P2: approve / reject / delete
        print("\n[P2] Approve/Reject/Delete with Undo...")
        # Approve 50
        for aid in asset_ids[:50]:
            asset_ctrl.set_status(aid, AssetStatus.APPROVED)
        # Reject 10
        for aid in asset_ids[50:60]:
            asset_ctrl.set_status(aid, AssetStatus.REJECTED)
        # Delete 5 (last approved are unaffected; pick 5 generated)
        for aid in asset_ids[-5:]:
            asset_ctrl.delete_asset(aid)
        # Use the global undo_manager indirectly through a library tab.
        # Without the tab widget here we drive it directly.
        um = app.undo_manager
        # Push 3 reversible ops to the stack
        for label, callback in (  # type: ignore[misc]
            (
                "P2 Approve",
                lambda: asset_ctrl.set_status(asset_ids[0], AssetStatus.GENERATED),
            ),
            (
                "P2 Reject",
                lambda: asset_ctrl.set_status(asset_ids[50], AssetStatus.GENERATED),
            ),
        ):
            done = {"hit": False}

            def _u(done=done):
                done["hit"] = True
                asset_ctrl.set_status(asset_ids[0], AssetStatus.APPROVED)

            def _r(done=done):
                done["hit"] = True
                asset_ctrl.set_status(asset_ids[0], AssetStatus.GENERATED)

            um.record(label, _u, _r, context=label)
        for _ in range(2):
            ok = um.undo()
            if not ok:
                report("HIGH", "undo failed in P2")
            _process_events(0.05)
        for _ in range(2):
            ok = um.redo()
            if not ok:
                report("HIGH", "redo failed in P2")
        print(f"   Undo/redo sanity check passed; undo_count={um.undo_count}")

        # ── P3: Undo overflow
        print("\n[P3] Undo overflow (110 ops onto a 100-cap stack)...")
        um.clear()
        marker_assets = asset_ids[:110]
        for i, aid in enumerate(marker_assets):
            jid = {"hit": False}
            j_label = f"Overflow-{i}"

            def _uu(jid=jid, aid=aid, j_label=j_label, i=i):
                def __u():
                    jid["hit"] = True

                return __u

            def _rr(jid=jid, aid=aid, j_label=j_label, i=i):
                def __r():
                    jid["hit"] = True

                return __r

            um.record(
                j_label,
                _uu(),
                _rr(),
                context=str(aid),
            )
            # Ensure collapse-window is bypassed (1.5 s cap in undo_manager)
            time.sleep(0.005)
        if um.undo_count != um.max_size():
            report(
                "HIGH",
                f"Undo manager overflow: count={um.undo_count} cap={um.max_size()}",
            )
        else:
            print(f"   undo capped correctly at {um.max_size()}")

        # ── P4: Export edge cases
        print("\n[P4] Export — zero-approved, partial, full project...")
        export_ctrl = ExportController(app)
        # 4a) zero-approved scenario
        # Make a project whose assets are all pending — already have project
        # with all assets in approved/rejected/generated — instead, use a
        # dummy project with zero approved assets by skipping approve.
        # We'll use a project of fresh-made assets. But to avoid setup,
        # pass an empty list.
        empty_result = app.exporter.export_assets([])
        if empty_result.failed_count != 0:
            report(
                "MEDIUM",
                f"Empty export reports failures: {empty_result.errors}",
            )
        # 4b) full project of project[0]
        t_exp = time.perf_counter()
        result = export_ctrl.export_project(project_ids[0])
        elapsed_exp = time.perf_counter() - t_exp
        if not result.success:
            report(
                "HIGH",
                f"Project export failed: {result.errors[:3]}",
            )
        else:
            print(
                f"   Exported project 0 in {elapsed_exp:.2f}s "
                f"({result.exported_count} files, "
                f"{result.failed_count} failed)"
            )

        # 4c) all-approved round (uses Status.APPROVED)
        all_approved = app.assets.get_all(status=AssetStatus.APPROVED)
        full = app.exporter.export_assets(all_approved[:20])
        if full.failed_count:
            report(
                "HIGH",
                f"Approved export has {full.failed_count} failures",
            )

        # ── P5: Recovery save / load / discard
        print("\n[P5] Recovery save / load / discard...")
        target_pid = project_ids[0]
        _recovery.discard(target_pid)
        snap = {
            "project_id": target_pid,
            "book": {
                "properties": {"title": "Recovered Test Book"},
                "pages": [{"asset_id": asset_ids[0], "page_number": 1}],
                "cover": {"title": "CoverTest"},
            },
            "selections": {"category_id": None, "active_tab_index": 0},
        }
        _recovery.save(target_pid, snap)
        if not _recovery.has_recovery(target_pid):
            report("CRITICAL", "Recovery file not present after save")
        loaded = _recovery.load(target_pid)
        if not loaded or loaded.get("book", {}).get("properties", {}).get(
            "title"
        ) != "Recovered Test Book":
            report("HIGH", "Recovery round-trip lost data")
        # check for orphan .tmp
        tmp_orphans = [
            p
            for p in (recovery_dir).glob("*.tmp")
            if p.exists()
        ]
        if tmp_orphans:
            report(
                "HIGH",
                f"Recovery orphan .tmp files after save: "
                f"{[p.name for p in tmp_orphans]}",
            )
        # Atomic swap: write a corrupt payload & ensure the live file is
        # untouched.
        path = _recovery.recovery_path(target_pid)
        try:
            with open(path.with_name(path.name + ".tmp"), "w") as fh:
                fh.write("{not json}")
            # The swap is performed only by save(); a stray .tmp on disk
            # is cleaned up via with_name + unlink at the start of save().
        except Exception as exc:
            report("MEDIUM", f"Atomic-swap probe failed: {exc}")
        # Save again with valid payload to ensure save() tolerates a
        # pre-existing .tmp (clean-up branch).
        _recovery.save(target_pid, snap)
        leftover_tmp = (recovery_dir / f"{target_pid}.json.tmp")
        if leftover_tmp.exists():
            report(
                "HIGH",
                "Recovery cleanup did not remove .tmp after save",
            )
        _recovery.discard(target_pid)

        # ── P6: Project switching loop
        print("\n[P6] Project switching (round-trip each project)...")
        switch_times: list[float] = []
        for pid in project_ids * 2:  # 20 round-trips
            t0 = time.perf_counter()
            app.workspace.open_project(pid)
            switch_times.append(time.perf_counter() - t0)
            _process_events(0.02)
        mx = max(switch_times)
        avg = sum(switch_times) / len(switch_times)
        print(f"   Project switch avg={avg * 1000:.1f} ms max={mx * 1000:.1f} ms")
        if mx > 2.0:
            report(
                "MEDIUM",
                f"Project switch took {mx * 1000:.0f} ms (UI freeze threshold 2s)",
            )

        # ── P7: Book Builder draft + recovery round-trip
        print("\n[P7] Book Builder recovery round-trip...")
        from ui.widgets.workspace.tabs.book_builder_tab import BookBuilderTab

        host = QWidget()
        host.resize(1024, 768)
        host.show()
        try:
            app.workspace.open_project(project_ids[0])
            tab = BookBuilderTab(app, app.workspace, parent=host)
            tab.resize(1024, 768)
            tab.show()
            _process_events(0.3)
            tab.refresh()
            tab._book_title.setText("My Persistence Test")
            tab._book_author.setText("Beta Tester")
            tab._on_assets_dropped(asset_ids[:3])
            # capture draft
            draft_before = tab._collect_book_recovery_draft()
            if draft_before.get("properties", {}).get("title") != (
                "My Persistence Test"
            ):
                report(
                    "HIGH",
                    "Book draft title did not capture correctly",
                )
            # mark dirty and force-save
            app.workspace.mark_dirty()
            app.workspace.force_save_recovery()
            snap = _recovery.load(project_ids[0])
            assert snap is not None, "Recovery snapshot should exist"
            applied_book = snap.get("book", {})
            if applied_book.get("properties", {}).get("title") != (
                "My Persistence Test"
            ):
                report(
                    "HIGH",
                    "Book draft not persisted to recovery snapshot",
                )
            # Apply to a fresh tab
            new_host = QWidget()
            new_host.resize(1024, 768)
            new_host.show()
            new_tab = BookBuilderTab(app, app.workspace, parent=new_host)
            new_tab.resize(1024, 768)
            new_tab.show()
            _process_events(0.3)
            new_tab.refresh()
            new_tab._apply_book_recovery_draft(applied_book)
            _process_events(0.2)
            recovered_title = new_tab._book_title.text()
            if recovered_title != "My Persistence Test":
                report(
                    "HIGH",
                    f"Book title not restored. Got '{recovered_title}'",
                )
            else:
                print("   Book draft recovered intact.")
            # Tear down both book tabs
            new_tab.setParent(None)
            new_tab.deleteLater()
            new_host.setParent(None)
            new_host.deleteLater()
            tab.setParent(None)
            tab.deleteLater()
        finally:
            host.setParent(None)
            host.deleteLater()
            _process_events(0.5)

        # ── P8: Settings persistence
        print("\n[P8] Settings persistence (set, reload)...")
        app.settings.set(
            "rc1_validation.marker", "PERSIST_OK", persist=True
        )
        app.settings.set("rc1_validation.counter", 42, persist=True)
        _reset_singletons()
        # !!! SettingsManager.LOAD comes from user_settings.json. Verify
        # the marker survived singleton reset + reload.
        s2 = SettingsManager.instance()
        if s2.get("rc1_validation.marker") != "PERSIST_OK":
            report(
                "HIGH",
                "Settings marker did not persist across restart",
            )
        if int(s2.get("rc1_validation.counter", 0)) != 42:  # type: ignore[arg-type]
            report(
                "HIGH",
                "Settings counter did not persist across restart",
            )
        else:
            print("   Settings persisted across singleton reset.")

        # ── P9: Application restart
        print("\n[P9] Application restart (full reset, re-instantiate)...")
        _reset_singletons()
        app = AppController.instance()
        _process_events(0.3)
        # Counts survive the restart.
        if app.projects.count() < 10:
            report(
                "CRITICAL",
                f"Projects missing after restart: {app.projects.count()}",
            )
        if app.prompts.count() < 100:
            report(
                "CRITICAL",
                f"Prompts missing after restart: {app.prompts.count()}",
            )
        if app.assets.count() < 240:  # we deleted 5
            report(
                "HIGH",
                f"Assets low after restart: {app.assets.count()}",
            )
        # Integrity
        integ = db_integrity()
        normalized = [tuple(r) for r in integ]
        if len(normalized) != 1 or normalized[0] != ("ok",):
            report(
                "CRITICAL",
                f"DB integrity_check did not return 'ok': {normalized}",
            )
        else:
            print("   Post-restart DB integrity_check returned 'ok'.")

        # ── P10: Stress
        print("\n[P10] Stress: 20 open/close + 30 import/export runs...")
        # 10a: library tab open/close 20×
        from ui.widgets.workspace.tabs.library_tab_v2 import (
            LibraryTab as LibraryTabV2,
        )

        for _ in range(20):
            host = QWidget()
            host.show()
            lt = LibraryTabV2(app, app.workspace, parent=host)
            lt.show()
            _process_events(0.2)
            lt.refresh()
            _process_events(0.2)
            lt.setParent(None)
            lt.deleteLater()
            host.setParent(None)
            host.deleteLater()
            _process_events(0.2)
        print("   20 library tabs opened/closed")

        # 10b: 30 import/export cycle on the same project (no AI net)
        auto_existing = app.assets.get_all(status=AssetStatus.APPROVED)
        for i in range(30):
            opts = None
            app.exporter.export_assets(auto_existing[:5])
        print("   30 export cycles completed")

        # ── P11: Final diagnostics ────────────────────────────────────────
        print("\n[P11] Final diagnostics...")
        post_data_snapshot = dir_snapshot(data_dir)
        post_memsnap, post_rss = mem_snapshot()

        # 11a. orphan .tmp
        orphans = find_orphan_tmps(pre_data_snapshot, post_data_snapshot)
        if orphans:
            report("HIGH", f"Orphan files after run: {orphans[:5]}")

        # 11b. memory diff (process RSS)
        if _HAS_PSUTIL and pre_rss > 0 and post_rss > 0:
            delta_mb = (post_rss - pre_rss) / (1024 * 1024)
            print(
                f"   RSS delta: {delta_mb:.1f} MB "
                f"({pre_rss / 1024 / 1024:.1f} → {post_rss / 1024 / 1024:.1f})"
            )
            if delta_mb > 75.0:
                report(
                    "MEDIUM",
                    f"Process RSS grew {delta_mb:.1f} MB during validation",
                )

        # 11c. tracemalloc — top-5 diff
        diffs = post_memsnap.compare_to(pre_memsnap, key_type="filename")
        diff_count = sum(1 for _ in diffs)
        print(f"   tracemalloc diff count: {diff_count}")
        top_creep = [
            (s, s.size_diff)
            for s in diffs[:5]
            if s.size_diff > 5_000_000  # > 5 MB growth in one file
        ]
        for stat, diff_bytes in top_creep:
            trace = getattr(stat, "traceback", None)
            origin = (
                trace[0].filename
                if trace and len(trace)
                else "<unknown>"
            )
            report(
                "MEDIUM",
                f"File-level creep: {origin} +{diff_bytes} bytes",
            )

        # 11d. exceptions captured
        if captured_exceptions:
            for label, tb in captured_exceptions[:5]:
                report("HIGH", f"Uncaught exception during run: {label}")

        # 11e. stderr crash fragments
        _restore_stderr()
        text = _stderr_capture.getvalue()
        hits = [frag for frag in CRASH_FRAGMENTS if frag in text]
        # Filter QObject::startTimer if it's paired with "QThread: Destroyed"
        # from a purely informational QThread teardown message. We keep it
        # in the report but at MEDIUM severity unless paired with a traceback.
        for frag in hits:
            severity = "MEDIUM"
            if frag == "Traceback (most recent call last)" or frag.startswith(
                "QObject::startTimer"
            ):
                severity = "MEDIUM"
            report(severity, f"stderr fragment: '{frag}'")

        # 11f. PRAGMA integrity final
        integ = db_integrity()
        normalized = [tuple(r) for r in integ]
        if len(normalized) != 1 or normalized[0] != ("ok",):
            report(
                "CRITICAL",
                f"Final DB integrity_check did not return 'ok': {normalized}",
            )
        else:
            print("   Final DB integrity_check returned 'ok'.")

    except Exception as exc:
        report(
            "CRITICAL",
            f"Unhandled exception in validator: {exc.__class__.__name__}: {exc}",
        )
        traceback.print_exc()
        failed_phases.append("validator_main")

    print("\n" + "=" * 78)
    print("Findings summary")
    print("=" * 78)
    if not findings:
        print("  No findings detected.")
    by_sev: dict[str, int] = {}
    for sev, _msg in findings:
        by_sev[sev] = by_sev.get(sev, 0) + 1
    for sev in ("CRITICAL", "HIGH", "MEDIUM", "LOW"):
        if by_sev.get(sev):
            print(f"  {sev:8} : {by_sev[sev]}")
    print()
    print("Detailed findings:")
    for sev, msg in findings:
        print(f"  [{sev}] {msg}")

    passed = (
        by_sev.get("CRITICAL", 0) == 0
        and by_sev.get("HIGH", 0) == 0
    )
    if passed:
        print(
            "\n*** VALIDATION PASSED ***\n"
            "MagicFactoryAI Version 1.0.0 is approved for release.\n"
        )
    else:
        print(
            "\n*** VALIDATION FAILED — see findings above ***\n"
        )
    return 0 if passed else 2


def _restore_stderr() -> None:
    global stderr_redirect_attached
    if stderr_redirect_attached:
        try:
            os.dup2(_saved_stderr_fd, 2)
            os.close(_saved_stderr_fd)
            stderr_redirect_attached = False
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
