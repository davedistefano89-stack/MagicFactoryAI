"""Regression test for the Library-tab QObject::startTimer crash.

Boots the application, constructs a LibraryTab, lets its background
thumbnail thread spin up, runs pending Qt events, then tears the tab
down (which is the exact code path that previously crashed). The teardown
is the moment the C++ destructor of the parentless ThumbnailWorker could
race with its still-running thread, so this is where we look for the
``QObject::startTimer`` warning or a fatal access violation.

We redirect stderr to a buffer so we can search it for those strings.
We reproduce the open/close cycle several times to make a single race
less likely to hide.
"""

from __future__ import annotations

import io
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Force offscreen so this test runs in a headless shell.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QTimer, Qt
from PySide6.QtWidgets import QApplication, QWidget

from app.controllers.app_controller import AppController
from ui.widgets.workspace.tabs.library_tab import LibraryTab


APP_CONTROLLER = AppController.instance()
QAPP = QApplication.instance() or QApplication(sys.argv)
QAPP.setAttribute(Qt.ApplicationAttribute.AA_DontUseNativeMenuBar, True)


def _process_events(seconds: float) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        QAPP.processEvents()
        time.sleep(0.02)


def _make_host() -> QWidget:
    """Make a throwaway host so LibraryTab has a non-null parent.

    Parent is important: the previous crash also depended on the tab's
    parent being a real (live) QWidget that the destroyed signal would
    fire on.
    """
    host = QWidget()
    host.resize(1024, 768)
    host.show()
    _process_events(0.2)
    return host


def _new_library_tab(host: QWidget) -> LibraryTab:
    tab = LibraryTab(
        APP_CONTROLLER,
        APP_CONTROLLER.workspace,
        parent=host,
    )
    tab.resize(1024, 768)
    tab.show()
    _process_events(0.5)
    # Trigger the lazy populate + thumbnail work so the worker thread
    # actually has pending work to chew through.
    if hasattr(tab, "refresh"):
        tab.refresh()
    _process_events(0.5)
    return tab


def _tear_down(tab: LibraryTab, host: QWidget) -> None:
    # Match the real UI: tab is removed from its QTabWidget, the host
    # deletes its children. This is the path that wires ``destroyed``
    # → ``_stop_thumb_worker``.
    tab.setParent(None)
    tab.deleteLater()
    host.setParent(None)
    host.deleteLater()
    # Allow ``deleteLater`` events to flush through BOTH the GUI thread
    # AND the worker thread (the previous crash thread was visualised
    # only after both threads had fully drained).
    _process_events(2.0)


CRASH_FRAGMENTS = (
    "QObject::startTimer:",
    "Windows fatal exception",
    "access violation",
    "Traceback",
)


def main() -> int:
    err_capture = io.StringIO()
    saved_stderr_fd = os.dup(2)
    try:
        # Redirect fd-level stderr (Qt prints there at C++ level,
        # bypassing Python sys.stderr).
        os.dup2(err_capture.fileno(), 2)
    except OSError:
        pass

    failures: list[str] = []

    try:
        # Repeat the open/close cycle. Even one crash would surface.
        for cycle in range(3):
            print(f"--- Cycle {cycle + 1}/3 ---")
            host = _make_host()
            tab = _new_library_tab(host)
            try:
                # Allow a brief moment where the worker thread is
                # actually decoding thumbnails (if any images exist).
                _process_events(1.0)
            finally:
                _tear_down(tab, host)
            _process_events(1.0)
    finally:
        try:
            os.dup2(saved_stderr_fd, 2)
            os.close(saved_stderr_fd)
        except OSError:
            pass

    captured = err_capture.getvalue()
    found = [frag for frag in CRASH_FRAGMENTS if frag in captured]
    if found:
        print("FAIL: crash fragments found in stderr:")
        for f in found:
            print(f"  - {f}")
        print("Full captured stderr:")
        print(captured)
        return 2

    print("PASS: no QObject::startTimer warning, no access violation, no traceback.")
    print(f"Captured stderr length: {len(captured)} chars")
    if captured.strip():
        print("Non-fatal stderr output (informational only):")
        print(captured[:4000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
