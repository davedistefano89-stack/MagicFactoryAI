"""AI configuration models."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class AISettings:

    provider: str = "openai"

    api_key: str = ""

    model: str = "gpt-image-1"

    image_size: str = "1024x1024"

    quality: str = "high"