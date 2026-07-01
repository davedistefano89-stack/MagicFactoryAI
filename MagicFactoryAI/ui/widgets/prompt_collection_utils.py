"""Prompt Collection helpers.

Collections are encoded inside prompt.tags using a ``__col__:`` prefix so
that no database migration is required.  The display-tag string (shown in the
Tags field) is always stripped of collection entries.

Example:  prompt.tags == "funny,happy,__col__:Animals,__col__:Nature"
  → display tags : "funny,happy"
  → collections  : ["Animals", "Nature"]
"""

from __future__ import annotations

from typing import List

_COL_PREFIX = "__col__:"


# ── Low-level helpers ────────────────────────────────────────────────────────

def get_prompt_collections(prompt) -> List[str]:
    """Return all collection names encoded in prompt.tags."""
    result: List[str] = []
    for part in (prompt.tags or "").split(","):
        part = part.strip()
        if part.startswith(_COL_PREFIX):
            col = part[len(_COL_PREFIX):]
            if col:
                result.append(col)
    return result


def set_prompt_collections(prompt, cols: List[str]) -> None:
    """Replace the collections encoded in prompt.tags, preserving display tags."""
    display_parts = [
        t.strip()
        for t in (prompt.tags or "").split(",")
        if t.strip() and not t.strip().startswith(_COL_PREFIX)
    ]
    col_parts = [f"{_COL_PREFIX}{c}" for c in cols]
    all_parts = display_parts + col_parts
    prompt.tags = ",".join(all_parts)


def get_display_tags(prompt) -> str:
    """Return the tags string with all collection entries removed."""
    parts = [
        t.strip()
        for t in (prompt.tags or "").split(",")
        if t.strip() and not t.strip().startswith(_COL_PREFIX)
    ]
    return ",".join(parts)


def collect_all_prompt_collections(prompts) -> List[str]:
    """Return a sorted, deduplicated list of all collection names across prompts."""
    seen: dict[str, str] = {}
    for p in prompts:
        for c in get_prompt_collections(p):
            seen[c.lower()] = c
    return sorted(seen.values(), key=str.lower)
