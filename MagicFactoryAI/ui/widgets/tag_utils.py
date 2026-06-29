"""Shared tag helpers — read/write tags stored inside metadata_json."""

from __future__ import annotations

import json
from typing import List

from models.asset import Asset


def get_tags(asset: Asset) -> List[str]:
    """Return the tag list from an asset's metadata_json. Never raises."""
    try:
        meta = json.loads(asset.metadata_json or "{}")
        raw = meta.get("tags", [])
        return [str(t) for t in raw if t]
    except (json.JSONDecodeError, TypeError):
        return []


def set_tags(asset: Asset, tags: List[str]) -> None:
    """Write a tag list into an asset's metadata_json in-place."""
    try:
        meta = json.loads(asset.metadata_json or "{}")
    except (json.JSONDecodeError, TypeError):
        meta = {}
    meta["tags"] = tags
    asset.metadata_json = json.dumps(meta)


def collect_all_tags(assets) -> List[str]:
    """Return a sorted, case-insensitive-deduped list of all tags across assets."""
    seen: dict[str, str] = {}
    for asset in assets:
        for tag in get_tags(asset):
            seen[tag.lower()] = tag
    return sorted(seen.values(), key=str.lower)
