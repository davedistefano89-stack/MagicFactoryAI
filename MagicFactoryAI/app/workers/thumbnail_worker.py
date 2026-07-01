"""Background thumbnail loader with bulk cancellation via visibility.

Created for Sprint: Performance Optimizer.

Why QImage and not QPixmap here?
    QPixmap objects hold a handle to the underlying windowing system.
    Creating them on a non-GUI thread is unsupported and may crash on
    some platforms. QImage has no such binding and is safe to construct
    off-thread; the GUI thread converts it via ``QPixmap.fromImage``
    after the queued signal arrives.

Cancellation model
    The worker keeps a thread-safe set of ``cache_keys`` that the user
    can currently see (``set_visible_keys``). A scroll event triggers a
    single bulk update instead of one cancel signal per row, so we
    never flood the event loop with hundreds of cross-thread posts.
    In addition, a per-request monotonic ``version`` allows us to drop
    a stale result if two requests for the same asset raced.
"""

from __future__ import annotations

import threading
from pathlib import Path
from typing import Set, Tuple

from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtGui import QImage
from PySide6.QtCore import Qt

from utils.logger import get_logger

logger = get_logger(__name__)


class ThumbnailWorker(QObject):
    """Long-lived worker that emits decoded thumbnails to the GUI thread."""

    # asset_id, cache_key, QImage
    # Sprint CRITICAL BUG FIX: declared with the explicit QImage type
    # (not ``object``) so PySide6 registers it with Qt's meta-type
    # system. The meta-type system performs a thread-safe, deep copy
    # of QImage's implicit-shared buffer when crossing thread
    # boundaries via QueuedConnection, instead of just passing a
    # Python wrapper around the C++ object. Using ``object`` here
    # caused the GUI thread to dereference QImage memory whose
    # backing storage could be released by the worker thread's
    # shutdown — producing the native Windows access violation when
    # the GUI then called QPixmap.fromImage(qimage).
    thumbnail_ready = Signal(int, str, QImage)
    # asset_id, cache_key, reason
    thumbnail_failed = Signal(int, str, str)

    def __init__(self) -> None:
        super().__init__()
        self._versions: dict[str, int] = {}
        self._running: set[str] = set()
        self._visible_keys: set[str] = set()
        self._lock = threading.Lock()
        # Sprint CRITICAL BUG FIX: cooperative-shutdown flag. Set by
        # ``request_shutdown`` from the GUI thread just before
        # ``_stop_thumb_worker`` issues ``worker.deleteLater()`` +
        # ``thread.quit()``. ``decode`` slots check this under
        # ``self._lock`` and bail out immediately on their very next
        # critical section instead of blocking on a slow
        # ``QImage(str(path))`` decode. Without this, the worker
        # thread can be kept alive by a single in-flight decode past
        # ``thread.wait()``'s timeout, which then lets Python's GC
        # reclaim the C++ QObject from the GUI thread while the
        # worker is still running a slot — that's the cross-thread
        # access violation the previous code path triggered.
        self._stop_requested: bool = False

    # ── Visibility feed (called from GUI thread) ────────────────────────────

    def set_visible_keys(self, keys: Set[str]) -> None:
        """Replace the worker's view of which cache keys are currently
        needed. Anything scheduled but no longer visible will be dropped
        after it finishes decoding.
        """
        with self._lock:
            self._visible_keys = set(keys)

    def clear_visible(self) -> None:
        with self._lock:
            self._visible_keys.clear()

    # ── Decoding slot (runs on the worker thread) ────────────────────────────

    @Slot(int, str, str, int, int)
    def decode(
        self,
        asset_id: int,
        cache_key: str,
        path: str,
        version: int,
        max_size: int,
    ) -> None:
        """Decode a single thumbnail and emit it back to the GUI thread.

        Sprint CRITICAL BUG FIX: early-exit when
        ``_stop_requested`` is set, so a backlog of pending decodes
        drains in O(1) when the GUI calls ``request_shutdown``
        instead of forcing ``thread.wait()`` to time out.
        """
        with self._lock:
            # Cooperative shutdown — bail before doing any work.
            if self._stop_requested:
                return
            # Track version BEFORE doing any work.
            self._versions[cache_key] = version
            self._running.add(cache_key)
            visible_at_start = cache_key in self._visible_keys

        if not visible_at_start:
            self._release(cache_key)
            # Note: do not emit a failure for filtered-out rows; the
            # GUI will simply never see the result.
            return

        if not path or not Path(path).exists():
            self._release(cache_key)
            self.thumbnail_failed.emit(asset_id, cache_key, "missing")
            return

        # Re-check visibility before the potentially-expensive decode.
        # A scroll event may have scrolled the asset out of view
        # between the first check and here.
        with self._lock:
            if cache_key not in self._visible_keys:
                self._release(cache_key)
                return
            current_version = self._versions.get(cache_key, -1)
        if current_version != version:
            self._release(cache_key)
            return

        try:
            image = QImage(str(path))
        except Exception as exc:  # noqa: BLE001
            self._release(cache_key)
            self.thumbnail_failed.emit(asset_id, cache_key, str(exc))
            return

        if image.isNull():
            self._release(cache_key)
            self.thumbnail_failed.emit(asset_id, cache_key, "decode")
            return

        if image.width() > max_size or image.height() > max_size:
            image = image.scaled(
                max_size,
                max_size,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )
            if image.isNull():
                self._release(cache_key)
                self.thumbnail_failed.emit(asset_id, cache_key, "scale")
                return

        with self._lock:
            still_current = (
                self._versions.get(cache_key, -1) == version
                and cache_key in self._visible_keys
            )
        if not still_current:
            self._release(cache_key)
            return

        self._release(cache_key)
        # Use a shallow copy because PySide6 object identity is bound
        # to the creating thread in some platforms; a copy stays valid
        # across the queued connection boundary.
        self.thumbnail_ready.emit(asset_id, cache_key, image.copy())

    # ── Diagnostics ─────────────────────────────────────────────────────────

    def running_count(self) -> int:
        with self._lock:
            return len(self._running)

    # ── Lifecycle ───────────────────────────────────────────────────────────

    def reset(self) -> None:
        with self._lock:
            self._versions.clear()
            self._running.clear()
            self._visible_keys.clear()
            self._stop_requested = False

    def request_shutdown(self) -> None:
        """Mark the worker for cooperative shutdown.

        Called from the GUI thread at the top of
        ``LibraryTab._stop_thumb_worker`` — BEFORE the
        ``worker.deleteLater()`` + ``thread.quit()`` pair.
        Flips ``_stop_requested`` under ``self._lock`` so the
        worker thread's pending ``decode`` slots exit on their
        next lock acquisition. Also clears the visible-keys set
        so any later visibility-check branches also short-circuit
        to ``return`` without emitting.

        Has no effect on C++ thread affinity. Cross-thread
        ``moveToThread`` is illegal in Qt; deletion must happen
        via the worker's own event loop (see the ``deleteLater``
        ordering in ``_stop_thumb_worker``).
        """
        with self._lock:
            self._stop_requested = True
            self._visible_keys.clear()

    def _release(self, cache_key: str) -> None:
        with self._lock:
            self._running.discard(cache_key)
