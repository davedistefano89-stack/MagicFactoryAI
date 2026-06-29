"""Mock AI provider for testing and offline development."""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw

from core.ai.provider_base import AIProvider


class MockProvider(AIProvider):
    """A simple provider that returns a generated PNG image.

    The image is white with a few black shapes so it behaves like
    a real line-art asset and is compatible with the project's
    thumbnail and processing pipeline.
    """

    def __init__(self, width: int = 1024, height: int = 1024) -> None:
        self._width = width
        self._height = height

    @property
    def name(self) -> str:
        return "MockProvider"

    def generate_image(self, image_path: Path, prompt: str) -> bytes:
        # Create a white canvas and draw simple black outlines
        img = Image.new("RGB", (self._width, self._height), "white")
        draw = ImageDraw.Draw(img)

        # Draw a few simple shapes to simulate line art
        margin = 80
        draw.rectangle([margin, margin, self._width - margin, self._height - margin], outline="black", width=10)
        draw.ellipse([margin * 2, margin * 2, self._width - margin * 2, self._height // 2], outline="black", width=8)
        draw.line([margin, self._height - margin, self._width - margin, margin], fill="black", width=6)

        # Optionally embed a short hint from the prompt as a tiny corner text
        # (kept minimal to avoid font dependencies)

        buf = BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    def test_connection(self) -> bool:
        # Always available since it does not use external services
        return True
