"""Crash-recovery snapshot manager.

Snapshots are written to  data/recovery/<project_id>.json
and are read back on the next application start.
No database changes — pure file I/O.

Sprint: Auto Save & Crash Recovery PRO #1
* One recovery file per project, under ``data/recovery/``.
* Saves are atomic: a sibling ``.tmp`` file is written and validated,
  then ``os.replace`` swaps it over the live snapshot in one step so
  an interrupted write can never leave a corrupted snapshot behind.
"""

from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from utils.paths import get_data_dir


def _recovery_dir() -> Path:
    d = get_data_dir() / "recovery"
    d.mkdir(parents=True, exist_ok=True)
    return d


def recovery_path(project_id: int) -> Path:
    return _recovery_dir() / f"{project_id}.json"


def _atomic_write_text(path: Path, payload: str) -> None:
    """Write ``payload`` to ``path`` atomically.

    Strategy:
    1. Serialize to a sibling temp file in the SAME directory so the
       final ``os.replace`` is a same-filesystem rename (atomic on
       both POSIX and Windows NTFS).
    2. ``flush`` + best-effort ``fsync`` so the bytes are durable
       before we move them into place. ``fsync`` is allowed to fail on
       exotic filesystems; we don't let that block the swap.
    3. ``os.replace`` performs the swap as a single filesystem op.
    4. On failure the (possibly partial) temp file is cleaned up so
       we never leak. ``open(..., 'w')`` truncates anything a prior
       crashed run left behind, so no pre-cleanup is required.
    """
    tmp_path = path.with_name(path.name + ".tmp")

    try:
        with open(tmp_path, "w", encoding="utf-8") as fh:
            fh.write(payload)
            fh.flush()
            try:
                os.fsync(fh.fileno())
            except OSError:
                # fsync on some Windows handles / network mounts may
                # raise; the swap is still atomic so carry on.
                pass
        os.replace(tmp_path, path)
    except Exception:
        # Best-effort cleanup of the temp file on failure.
        try:
            tmp_path.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def save(project_id: int, snapshot: dict) -> None:
    """Write a recovery snapshot to disk atomically.

    Mutates ``snapshot`` in place to embed ``_recovery_timestamp`` so
    the timestamp survives the JSON round-trip into the temp file.
    The serialization is validated by ``json.loads`` BEFORE the swap
    so a corrupt dictionary never overwrites a healthy snapshot.
    """
    path = recovery_path(project_id)
    snapshot["_recovery_timestamp"] = datetime.now().isoformat()
    payload = json.dumps(snapshot, indent=2, ensure_ascii=False)
    # Round-trip validation so we never swap a corrupted payload
    # over a valid existing recovery file.
    json.loads(payload)
    _atomic_write_text(path, payload)


def load(project_id: int) -> Optional[dict]:
    """Return the snapshot dict or None if no file exists."""
    path = recovery_path(project_id)
    if not path.exists():
        return None
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def discard(project_id: int) -> None:
    """Remove the recovery file if it exists."""
    path = recovery_path(project_id)
    try:
        path.unlink(missing_ok=True)
    except Exception:
        pass


def snapshot_mtime(project_id: int) -> Optional[datetime]:
    """Return the file modification time, or None if no snapshot exists."""
    path = recovery_path(project_id)
    if not path.exists():
        return None
    return datetime.fromtimestamp(os.path.getmtime(path))


def has_recovery(project_id: int) -> bool:
    """Return True when a non-empty recovery file exists for this project."""
    return recovery_path(project_id).exists()
