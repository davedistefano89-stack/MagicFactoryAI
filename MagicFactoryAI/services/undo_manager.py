"""Reusable global Undo / Redo manager.

Each recorded operation stores:
    * ``name``      — human-readable action label
    * ``timestamp`` — wall-clock time the operation was committed
    * ``undo``      — callable that reverts the change
    * ``redo``      — callable that re-applies the change

The history is capped at ``MAX_HISTORY`` operations so it never grows
without bound. Whenever an operation is applied (record / undo / redo),
the ``operation_applied`` signal fires so the rest of the UI can refresh
through the existing ``workspace_refresh`` signal wiring.

Designed to be reused everywhere by attaching the single instance to
``AppController.undo_manager`` and reaching it via ``self.controller``
from any tab/widget that already holds a reference to the controller.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Callable, Optional

from PySide6.QtCore import QObject, Signal

from utils.logger import get_logger


logger = get_logger(__name__)


MAX_HISTORY = 100


@dataclass(slots=True)
class _Operation:
    """Immutable record of one reversible action."""

    name: str
    timestamp: float
    undo: Callable[[], None]
    redo: Callable[[], None]
    context: str = ""  # e.g. the entity label (asset name) for display


class UndoManager(QObject):
    """Global undo / redo stack with a 100-op cap and Qt signals."""

    #: Emitted whenever the stack changes (record / undo / redo / clear).
    history_changed = Signal()

    #: Emitted after an undo or redo is applied so the workspace can
    #: re-query the DB and repaint every open tab.
    operation_applied = Signal()

    def __init__(self, max_size: int = MAX_HISTORY) -> None:
        super().__init__()
        self._undo_stack: list[_Operation] = []
        self._redo_stack: list[_Operation] = []
        self._max_size = max(1, int(max_size))

    # ── Public API ────────────────────────────────────────────────────────────

    def record(
        self,
        name: str,
        undo: Callable[[], None],
        redo: Callable[[], None],
        context: str = "",
    ) -> None:
        """Push a new operation onto the undo stack.

        Clears the redo stack — once the user starts a new chain of edits
        the previous redo branch is no longer reachable.
        """
        if not callable(undo) or not callable(redo):
            raise TypeError("undo and redo must be callables")

        op = _Operation(
            name=str(name),
            timestamp=time.time(),
            undo=undo,
            redo=redo,
            context=str(context),
        )

        # Sprint QA PRO #1 — only collapse into the previous op if the
        # two recordings happened within a very short window. Otherwise
        # a user editing the same field repeatedly (Tag A, then Tag B,
        # then Tag C) would lose every intermediate step in the undo
        # stack. The 1.5 s window keeps caller-saved Save/Save/Save
        # sequences tidy while preserving real edits.
        if (
            self._undo_stack
            and self._undo_stack[-1].name == op.name
            and self._undo_stack[-1].context == op.context
            and (op.timestamp - self._undo_stack[-1].timestamp) < 1.5
        ):
            self._undo_stack[-1] = op

        else:
            self._undo_stack.append(op)
            if len(self._undo_stack) > self._max_size:
                # Drop oldest to keep a hard cap of MAX_HISTORY.
                self._undo_stack.pop(0)

        # A fresh edit invalidates whatever was on the redo stack.
        if self._redo_stack:
            self._redo_stack.clear()

        self.history_changed.emit()

    def undo(self) -> bool:
        """Pop the most recent op and run its undo callback. Returns True on success."""
        if not self._undo_stack:
            return False

        op = self._undo_stack.pop()
        try:
            op.undo()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Undo failed for '%s': %s", op.name, exc)
            # Drop the broken op silently and continue rather than
            # leaving the user stuck on an op that cannot be reversed.
        else:
            self._redo_stack.append(op)

        self.history_changed.emit()
        self.operation_applied.emit()
        return True

    def redo(self) -> bool:
        """Pop the most recent undone op and run its redo callback."""
        if not self._redo_stack:
            return False

        op = self._redo_stack.pop()
        try:
            op.redo()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Redo failed for '%s': %s", op.name, exc)
        else:
            self._undo_stack.append(op)

        self.history_changed.emit()
        self.operation_applied.emit()
        return True

    def clear(self) -> None:
        """Drop the entire history. Used when switching projects."""
        if not self._undo_stack and not self._redo_stack:
            return
        self._undo_stack.clear()
        self._redo_stack.clear()
        self.history_changed.emit()

    # ── Introspection (used by the toolbar to label its buttons) ──────────────

    @property
    def can_undo(self) -> bool:
        return bool(self._undo_stack)

    @property
    def can_redo(self) -> bool:
        return bool(self._redo_stack)

    @property
    def undo_label(self) -> str:
        """Human-readable label of the op that ``undo()`` would reverse."""
        if not self._undo_stack:
            return ""
        op = self._undo_stack[-1]
        return f"{op.name}: {op.context}" if op.context else op.name

    @property
    def redo_label(self) -> str:
        if not self._redo_stack:
            return ""
        op = self._redo_stack[-1]
        return f"{op.name}: {op.context}" if op.context else op.name

    @property
    def undo_count(self) -> int:
        return len(self._undo_stack)

    @property
    def redo_count(self) -> int:
        return len(self._redo_stack)

    def max_size(self) -> int:
        return self._max_size

    def peek_undo_timestamp(self) -> Optional[float]:
        """Return the timestamp of the next op to undo (for tests / display)."""
        return self._undo_stack[-1].timestamp if self._undo_stack else None


# Chainable sugar so callers can write:
#     self.controller.undo_manager.record(...)
# and at the project-editor level also write
#     from services.undo_manager import undo_manager
# (kept optional; AppController.undo_manager is the canonical accessor).
default_manager: UndoManager = UndoManager()
