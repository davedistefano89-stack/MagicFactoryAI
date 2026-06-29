"""Models used by the AI engine."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(slots=True)
class AIRequest:
    """Request sent to an AI provider."""

    # Required
    image_path: Path
    prompt: str

    # Provider configuration
    provider: str = "openai"
    model: str = "gpt-image-1"

    # Output
    width: int = 1024
    height: int = 1024
    quality: str = "high"
    output_format: str = "png"

    # Prompt options
    negative_prompt: str = ""
    style: str = ""
    background: str = "white"
    line_thickness: str = "medium"

    # Generation
    seed: int | None = None

    # Organization
    category: str = ""
    tags: list[str] = field(default_factory=list)

    # Future extensions
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class AIResult:
    """Result returned by an AI provider."""

    success: bool

    image_bytes: bytes | None = None

    error: str | None = None

    provider: str = ""

    model: str = ""

    elapsed_time: float = 0.0

    revised_prompt: str = ""

    output_path: Path | None = None

    warnings: list[str] = field(default_factory=list)

    metadata: dict[str, Any] = field(default_factory=dict)