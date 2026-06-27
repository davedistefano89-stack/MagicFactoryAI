"""Models used by the AI engine."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(slots=True)
class AIRequest:
    """Request sent to an AI provider."""

    image_path: Path
    prompt: str

    model: str = "gpt-image-1"

    width: int = 1024
    height: int = 1024

    quality: str = "high"

    seed: Optional[int] = None


@dataclass(slots=True)
class AIResult:
    """Result returned by an AI provider."""

    success: bool

    image_bytes: bytes | None = None

    error: str | None = None

    provider: str = ""

    model: str = ""

    elapsed_time: float = 0.0